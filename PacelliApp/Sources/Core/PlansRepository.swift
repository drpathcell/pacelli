import FirebaseAuth
import FirebaseFirestore
import Foundation
import PacelliKit

/// Plan reads/writes. Parity with the Dart repository — `scratch_plans/{uuid}`
/// + `plan_entries/{uuid}` + `plan_checklist_items/{uuid}` flat docs,
/// encrypted title/label/description/template_name, date-only strings for
/// plan and entry dates, `household_id` denormalized for the rules.
///
/// v1 scope: plans CRUD + entries + plan checklist + status. Templates,
/// finalise, and attachments are deferred (Dart reference: getTemplates,
/// savePlanAsTemplate, createFromTemplate, finalisePlan, *Attachment*).
enum PlansRepository {
    private static var db: Firestore { Firestore.firestore() }
    private static var uid: String? { Auth.auth().currentUser?.uid }

    /// Non-template plans with children attached, newest first.
    /// (Dart uses orderBy + composite index; we sort client-side.)
    static func fetchPlans(householdId: String) async throws -> [Plan] {
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let snap = try await db.collection("scratch_plans")
            .whereField("household_id", isEqualTo: householdId)
            .whereField("is_template", isEqualTo: false)
            .getDocuments()

        var plans = snap.documents
            .compactMap { doc -> Plan? in
                var data = doc.data()
                if let t = data["title"] as? String {
                    data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
                }
                if let n = data["template_name"] as? String {
                    data["template_name"] = PacelliCrypto.decryptNullable(n, key: key)
                }
                return Plan(map: data)
            }
            .sorted { $0.createdAt > $1.createdAt }

        guard !plans.isEmpty else { return [] }

        // Household-wide child queries, grouped client-side (same pattern as
        // checklists; rules require the household_id filter).
        let entriesSnap = try await db.collection("plan_entries")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        var entriesByPlan: [String: [PlanEntry]] = [:]
        for doc in entriesSnap.documents {
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            if let l = data["label"] as? String {
                data["label"] = PacelliCrypto.decryptNullable(l, key: key)
            }
            if let d = data["description"] as? String {
                data["description"] = PacelliCrypto.decryptNullable(d, key: key)
            }
            guard let entry = PlanEntry(map: data), !entry.planId.isEmpty else { continue }
            entriesByPlan[entry.planId, default: []].append(entry)
        }

        let checklistSnap = try await db.collection("plan_checklist_items")
            .whereField("household_id", isEqualTo: householdId)
            .getDocuments()
        var checklistByPlan: [String: [PlanChecklistItem]] = [:]
        var legacy: [(id: String, plaintext: String)] = []
        for doc in checklistSnap.documents {
            var data = doc.data()
            if let t = data["title"] as? String {
                data["title"] = PacelliCrypto.decryptNullable(t, key: key) ?? t
            }
            // The REST API has always written this field encrypted while the
            // app wrote it raw, so this collection holds both forms for reasons
            // that predate the migration. See QuantityMigration.
            let qty = PacelliCrypto.readMigrating(data["quantity"] as? String, key: key)
            if let shown = qty.displayValue {
                data["quantity"] = shown
            } else {
                data["quantity"] = NSNull()
            }
            guard let item = PlanChecklistItem(map: data), !item.planId.isEmpty
            else { continue }
            if qty.needsMigration, let plaintext = qty.displayValue {
                legacy.append((item.id, plaintext))
            }
            checklistByPlan[item.planId, default: []].append(item)
        }
        QuantityMigration.backfill(
            collection: "plan_checklist_items", items: legacy, key: key)

        for i in plans.indices {
            plans[i].entries = (entriesByPlan[plans[i].id] ?? [])
                .sorted {
                    ($0.entryDate, $0.sortOrder, $0.createdAt ?? .distantPast)
                        < ($1.entryDate, $1.sortOrder, $1.createdAt ?? .distantPast)
                }
            plans[i].checklistItems = (checklistByPlan[plans[i].id] ?? [])
                .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        }
        return plans
    }

    /// Creates a draft plan (encrypted title). Mirrors Dart `createPlan`.
    static func createPlan(
        householdId: String, title: String, type: String = Plan.PlanType.weekly,
        startDate: Date, endDate: Date
    ) async throws -> Plan {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let now = Date()
        let plan = Plan(
            id: UUID().uuidString.lowercased(),
            householdId: householdId,
            title: title,
            type: type,
            startDate: startDate,
            endDate: endDate,
            createdBy: uid,
            createdAt: now,
            updatedAt: now)

        var map = plan.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)

        try await db.collection("scratch_plans").document(plan.id).setData(map)
        return plan
    }

    /// Deletes a plan and its entries + checklist items in one batch.
    /// Mirrors Dart `deletePlan`.
    static func deletePlan(_ plan: Plan) async throws {
        let batch = db.batch()

        let entries = try await db.collection("plan_entries")
            .whereField("household_id", isEqualTo: plan.householdId)
            .whereField("plan_id", isEqualTo: plan.id)
            .getDocuments()
        for doc in entries.documents {
            batch.deleteDocument(doc.reference)
        }

        let items = try await db.collection("plan_checklist_items")
            .whereField("household_id", isEqualTo: plan.householdId)
            .whereField("plan_id", isEqualTo: plan.id)
            .getDocuments()
        for doc in items.documents {
            batch.deleteDocument(doc.reference)
        }

        batch.deleteDocument(db.collection("scratch_plans").document(plan.id))
        try await batch.commit()
    }

    /// Mirrors Dart `updatePlanStatus` (draft ⇄ finalised).
    static func updateStatus(_ plan: Plan, status: String) async throws {
        try await db.collection("scratch_plans").document(plan.id).updateData([
            "status": status,
            "updated_at": DartISO8601.string(from: Date()),
        ])
    }

    // MARK: - Entries

    /// Adds an entry (encrypted title/label/description).
    /// Mirrors Dart `addEntry` doc shape.
    static func addEntry(
        planId: String, householdId: String, entryDate: Date, title: String,
        label: String? = nil, description: String? = nil, sortOrder: Int = 0
    ) async throws -> PlanEntry {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let entry = PlanEntry(
            id: UUID().uuidString.lowercased(),
            planId: planId,
            householdId: householdId,
            entryDate: entryDate,
            title: title,
            label: label,
            description: description,
            sortOrder: sortOrder,
            createdBy: uid,
            createdAt: Date())

        var map = entry.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)
        map["label"] = try PacelliCrypto.encryptNullable(label, key: key) ?? NSNull()
        map["description"] =
            try PacelliCrypto.encryptNullable(description, key: key) ?? NSNull()

        try await db.collection("plan_entries").document(entry.id).setData(map)
        return entry
    }

    /// Mirrors Dart `deleteEntry`.
    static func deleteEntry(_ entry: PlanEntry) async throws {
        try await db.collection("plan_entries").document(entry.id).delete()
    }

    // MARK: - Plan checklist

    /// Mirrors Dart `addPlanChecklistItem` doc shape.
    static func addChecklistItem(
        planId: String, householdId: String, entryId: String? = nil,
        title: String, quantity: String? = nil
    ) async throws -> PlanChecklistItem {
        guard let uid else { throw PacelliError.notSignedIn }
        guard let key = await KeyManager.shared.loadHouseholdKey(householdId) else {
            throw PacelliError.missingHouseholdKey
        }
        let item = PlanChecklistItem(
            id: UUID().uuidString.lowercased(),
            planId: planId,
            householdId: householdId,
            entryId: entryId,
            title: title,
            quantity: quantity,
            createdBy: uid,
            createdAt: Date())

        var map = item.toMap()
        map["title"] = try PacelliCrypto.encrypt(title, key: key)
        map["quantity"] = try PacelliCrypto.encryptNullable(quantity, key: key) ?? NSNull()

        try await db.collection("plan_checklist_items").document(item.id).setData(map)
        return item
    }

    /// Mirrors Dart `togglePlanChecklistItem`.
    static func setChecked(_ item: PlanChecklistItem, checked: Bool) async throws {
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
        try await db.collection("plan_checklist_items").document(item.id)
            .updateData(updates)
    }

    /// Mirrors Dart `deletePlanChecklistItem`.
    static func deleteChecklistItem(_ item: PlanChecklistItem) async throws {
        try await db.collection("plan_checklist_items").document(item.id).delete()
    }
}
