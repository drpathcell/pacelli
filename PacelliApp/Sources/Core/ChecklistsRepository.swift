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
        var legacy: [(id: String, plaintext: String)] = []
        for doc in itemsSnap.documents {
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            // `quantity` is mid-migration: ciphertext on anything written since
            // 1.7.0, plaintext on everything before it. See QuantityMigration.
            let qty = PacelliCrypto.readMigrating(data["quantity"] as? String, key: key)
            if let shown = qty.displayValue {
                data["quantity"] = shown
            } else {
                data["quantity"] = NSNull()
            }
            guard let item = ChecklistItem(map: data), !item.checklistId.isEmpty
            else { continue }
            if qty.needsMigration, let plaintext = qty.displayValue {
                legacy.append((item.id, plaintext))
            }
            itemsByChecklist[item.checklistId, default: []].append(item)
        }
        QuantityMigration.backfill(
            collection: "checklist_items", items: legacy, key: key)
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
        map["quantity"] = try PacelliCrypto.encryptNullable(quantity, key: key) ?? NSNull()

        try await db.collection("checklist_items").document(item.id).setData(map)
        return item
    }

    /// Edits an item's title and/or quantity in place.
    ///
    /// Added 1.5.0: before this the only way to change "White pepper ×1" to
    /// "×2" was to delete the item and retype it, which also lost its
    /// created_at ordering and its checked state.
    ///
    /// Both `title` and `quantity` are encrypted. Until 1.7.0 `quantity` was
    /// written in the clear — an inheritance from the Dart schema that made a
    /// shopping list's amounts readable on the server while its item names were
    /// not. Old plaintext values are still out there and are migrated lazily on
    /// read; see ``QuantityMigration``.
    static func updateItem(
        _ item: ChecklistItem, title: String, quantity: String?
    ) async throws {
        guard let key = await KeyManager.shared.loadHouseholdKey(item.householdId)
        else { throw PacelliError.missingHouseholdKey }
        try await db.collection("checklist_items").document(item.id).updateData([
            "title": try PacelliCrypto.encrypt(title, key: key),
            // NSNull, not omission: clearing the quantity has to erase the
            // stored value, and leaving the key out would silently keep it.
            "quantity": try PacelliCrypto.encryptNullable(
                (quantity?.isEmpty == false) ? quantity : nil, key: key) ?? NSNull(),
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

    // MARK: - Templates

    /// Every saved template in the household, newest first.
    ///
    /// A template whose blob will not decrypt is returned with an empty item
    /// list rather than dropped, so it stays visible and deletable instead of
    /// silently vanishing from the UI.
    static func fetchTemplates(householdId: String) async throws -> [ChecklistTemplate] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("checklist_templates")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()

        return snap.documents.compactMap { doc -> ChecklistTemplate? in
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            guard let id = data["id"] as? String,
                  let hh = data["household_id"] as? String,
                  let title = data["title"] as? String,
                  let createdBy = data["created_by"] as? String,
                  let createdAt = DartISO8601.date(from: data["created_at"] as? String)
            else { return nil }

            var items: [TemplateItem] = []
            if let blob = data["items"] as? String,
               let json = PacelliCrypto.decryptNullable(blob, key: key) {
                items = ChecklistTemplate.decodeItems(json)
            }
            return ChecklistTemplate(
                id: id, householdId: hh, title: title, items: items,
                createdBy: createdBy, createdAt: createdAt,
                updatedAt: DartISO8601.date(from: data["updated_at"] as? String))
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Snapshots a checklist's items into a reusable template.
    ///
    /// A snapshot, not a link: editing the checklist afterwards does not
    /// change the template, and using the template does not touch the
    /// checklist. Anything else would mean "tick the milk off this week's shop"
    /// silently editing next week's.
    ///
    /// Checked state is deliberately not carried over — a template exists to
    /// produce a fresh list, and a template that remembered what you had
    /// already bought would be useless the second time.
    static func saveAsTemplate(
        _ checklist: Checklist, title: String
    ) async throws -> ChecklistTemplate {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(checklist.householdId)
        else { throw PacelliError.missingHouseholdKey }

        let items = checklist.items.map {
            TemplateItem(title: $0.title, quantity: $0.quantity)
        }
        let template = ChecklistTemplate(
            id: UUID().uuidString.lowercased(),
            householdId: checklist.householdId,
            title: title,
            items: items,
            createdBy: uid,
            createdAt: Date())

        var map = template.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)
        // One ciphertext for the whole list: an array of maps would leave every
        // quantity, and the item count, readable on the server.
        map["items"] = try PacelliCrypto.encrypt(
            ChecklistTemplate.encodeItems(items), key: key)

        try await db.collection("checklist_templates").document(template.id)
            .setData(map)
        return template
    }

    static func deleteTemplate(_ template: ChecklistTemplate) async throws {
        try await db.collection("checklist_templates").document(template.id).delete()
    }

    /// Stamps a template into a real, unchecked checklist.
    ///
    /// One batch: a half-written checklist — the doc with none of its items —
    /// is worse than a failure, because it looks like it worked.
    static func createChecklist(
        from template: ChecklistTemplate
    ) async throws -> Checklist {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(template.householdId)
        else { throw PacelliError.missingHouseholdKey }

        let now = Date()
        var checklist = Checklist(
            id: UUID().uuidString.lowercased(),
            householdId: template.householdId,
            title: template.title,
            createdBy: uid,
            createdAt: now)

        var listMap = checklist.toMap()
        listMap["title"] = try PacelliCrypto.encrypt(template.title, key: key)

        let batch = db.batch()
        batch.setData(listMap, forDocument:
            db.collection("checklists").document(checklist.id))

        var created: [ChecklistItem] = []
        for entry in template.items {
            let item = ChecklistItem(
                id: UUID().uuidString.lowercased(),
                checklistId: checklist.id,
                householdId: template.householdId,
                title: entry.title,
                quantity: entry.quantity,
                createdBy: uid,
                createdAt: now)
            var itemMap = item.toMap()
            itemMap["title"] = try PacelliCrypto.encrypt(entry.title, key: key)
            itemMap["quantity"] =
                try PacelliCrypto.encryptNullable(entry.quantity, key: key) ?? NSNull()
            batch.setData(itemMap, forDocument:
                db.collection("checklist_items").document(item.id))
            created.append(item)
        }

        try await batch.commit()
        checklist.items = created
        return checklist
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
