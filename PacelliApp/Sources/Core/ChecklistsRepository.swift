import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Checklist reads/writes. Parity with the Dart repository —
/// `checklists/{uuid}` + `checklist_items/{uuid}` flat docs, encrypted
/// titles, `household_id` denormalized for the rules.
enum ChecklistsRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// All checklists with their items attached, newest first.
    /// (Dart uses a server-side orderBy + composite index; we sort
    /// client-side like the tasks port to avoid the index dependency.)
    static func fetchChecklists(householdId: String) async throws -> [Checklist] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("checklists")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        var checklists = snap.documents
            .compactMap { doc -> Checklist? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                return Checklist(map: data)
            }
            .sorted { $0.createdAt > $1.createdAt }

        guard !checklists.isEmpty else { return [] }

        // One rules-compatible query for all the household's items,
        // grouped client-side.
        let itemsSnap = try await db.collection("checklist_items")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        var itemsByChecklist: [String: [ChecklistItem]] = [:]
        for doc in itemsSnap.documents {
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            guard let item = ChecklistItem(map: data), !item.checklistId.isEmpty
            else { continue }
            itemsByChecklist[item.checklistId, default: []].append(item)
        }
        for i in checklists.indices {
            checklists[i].items = (itemsByChecklist[checklists[i].id] ?? [])
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        }
        return checklists
    }

    /// Creates an empty checklist (encrypted title). Mirrors Dart shape.
    static func createChecklist(householdId: String, title: String) async throws -> Checklist {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let now = Date()
        let checklist = Checklist(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            createdBy: uid,
            createdAt: now,
            updatedAt: now)

        var map = checklist.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("checklists").document(checklist.id).setData(map)
        return checklist
    }

    /// Renames a checklist. Mirrors Dart `updateChecklist`.
    static func updateChecklist(_ checklist: Checklist, title: String) async throws {
        guard let key = await KeyManager.shared.loadHouseholdKey(checklist.householdId)
        else { throw PacelliError.missingHouseholdKey }
        try await db.collection("checklists").document(checklist.id).updateData([
            "title": try PacelliCrypto.encrypt(title, key: key),
            "updated_at": DartISO8601.string(from: Date()),
        ])
    }

    /// Deletes a checklist and its items in one batch. Mirrors Dart —
    /// item query filters on `household_id` (rules) + `checklist_id`.
    static func deleteChecklist(_ checklist: Checklist) async throws {
        let items = try await db.collection("checklist_items")
            .whereField("household_id", isEqualTo: checklist.householdId)
            .whereField("checklist_id", isEqualTo: checklist.id)
            .getDocuments()

        let batch = db.batch()
        for doc in items.documents {
            batch.deleteDocument(doc.reference)
        }
        batch.deleteDocument(db.collection("checklists").document(checklist.id))
        try await batch.commit()
    }

    // MARK: - Items

    /// Adds an item (encrypted title). Mirrors Dart `addChecklistItem`.
    static func addItem(
        checklistId: String, householdId: String, title: String, quantity: String? = nil
    ) async throws -> ChecklistItem {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let item = ChecklistItem(
            id: UUID().uuidString.lowercased(),
            checklistId: checklistId,
            householdId: householdId,
            title: title,
            quantity: quantity,
            createdBy: uid,
            createdAt: Date())

        var map = item.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("checklist_items").document(item.id).setData(map)
        return item
    }

    /// Edits an item's title and/or quantity in place.
    ///
    /// Added 1.5.0: before this the only way to change "White pepper ×1" to
    /// "×2" was to delete the item and retype it, which also lost its
    /// created_at ordering and its checked state.
    ///
    /// `title` is encrypted, matching `addItem`. `quantity` is NOT — it is
    /// written in the clear exactly as `addItem` already writes it, because
    /// encrypting it here and not there would make old and new items
    /// undecryptable in different directions. That inconsistency is real and
    /// is recorded for the audit rather than half-fixed in a UI change.
    static func updateItem(
        _ item: ChecklistItem, title: String, quantity: String?
    ) async throws {
        guard let key = await KeyManager.shared.loadHouseholdKey(item.householdId)
        else { throw PacelliError.missingHouseholdKey }
        try await db.collection("checklist_items").document(item.id).updateData([
            "title": try PacelliCrypto.encrypt(title, key: key),
            // NSNull, not omission: clearing the quantity has to erase the
            // stored value, and leaving the key out would silently keep it.
            "quantity": (quantity?.isEmpty == false) ? quantity! : NSNull(),
            "updated_at": DartISO8601.string(from: Date()),
        ])
    }

    /// Mirrors Dart `toggleChecklistItem` (checked_at/checked_by shape).
    static func setChecked(_ item: ChecklistItem, checked: Bool) async throws {
        guard let uid else { throw PacelliError.notSignedIn }
        let updates: [String: Any] = checked
            ? [
                "is_checked": true,
                "checked_at": DartISO8601.string(from: Date()),
                "checked_by": uid,
            ]
            : [
                "is_checked": false,
                "checked_at": NSNull(),
                "checked_by": NSNull(),
            ]
        try await db.collection("checklist_items").document(item.id).updateData(updates)
    }

    /// Mirrors Dart `deleteChecklistItem`.
    static func deleteItem(_ item: ChecklistItem) async throws {
        try await db.collection("checklist_items").document(item.id).delete()
    }

    /// Converts an item into a shared task due today, then removes the item.
    /// Mirrors Dart `pushChecklistItemAsTask`.
    static func pushItemAsTask(_ item: ChecklistItem) async throws {
        let now = Date()
        _ = try await TasksRepository.createTask(
            householdId: item.householdId, title: item.title,
            dueDate: now, startDate: now, isShared: true)
        try await deleteItem(item)
    }
}
