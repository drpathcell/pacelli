import Foundation
import Testing

@testable import PacelliKit

/// Can the app read what the REST API writes?
///
/// There are two writers into the same Firestore collections: the native app
/// (`toMap()` + `PacelliCrypto`) and 71 deployed Cloud Functions
/// (`functions/src/functions/*.ts`, built for the Flutter app). Nothing has ever
/// checked that the second produces documents the first can parse — and an AI
/// given write access would go through the second.
///
/// These tests use the field shapes taken verbatim from the API handlers. A
/// failure here means a document the API writes is invisible or wrong in the
/// app, which the API cannot detect: it returns 200 either way.
@Suite("REST API wire contract")
struct ApiWireContractTests {

    /// Exactly what `addChecklistItem` writes today
    /// (functions/src/functions/checklists.ts) — note the absence of `id`.
    private var apiChecklistItemMap: [String: Any] {
        [
            "id": "i-1",  // added by the 2026-08-14 fix; absent before it
            "checklist_id": "cl-1",
            "household_id": "hh-1",
            "title": "Buy milk",  // decrypted by the caller before parsing
            "quantity": "2",
            "is_checked": false,
            "created_by": "uid-1",
            "created_at": "2026-08-14T07:30:00.000Z",  // JS new Date().toISOString()
            "checked_at": NSNull(),
            "checked_by": NSNull(),
        ]
    }

    @Test("DartISO8601 parses the JS toISOString() shape the API writes")
    func parsesJavaScriptTimestamps() {
        // 3-digit fraction + Z. The existing suite covers .123456Z and .123 but
        // never this exact combination, which is the only one JS produces.
        #expect(DartISO8601.date(from: "2026-08-14T07:30:00.000Z") != nil)
        #expect(DartISO8601.date(from: "2026-08-14T07:30:00.123Z") != nil)
    }

    @Test("A checklist item written by the API is parseable by the app")
    func apiChecklistItemIsReadable() throws {
        let item = try #require(
            ChecklistItem(map: apiChecklistItemMap),
            """
            The app dropped an item the API wrote. fetchChecklists() does
            `guard let item = ChecklistItem(map: data) else { continue }`, so the
            item is silently invisible — no error, no empty state, just absent.
            """)
        #expect(item.title == "Buy milk")
        #expect(item.quantity == "2")
    }

    /// Exactly what `createChecklist` writes.
    @Test("A checklist written by the API is parseable by the app")
    func apiChecklistIsReadable() throws {
        let map: [String: Any] = [
            "id": "x-1",
            "household_id": "hh-1",
            "title": "Dunnes shop",
            "created_by": "uid-1",
            "created_at": "2026-08-14T07:30:00.000Z",
            "updated_at": NSNull(),
        ]
        _ = try #require(
            Checklist(map: map),
            "The app cannot parse a checklist the API created.")
    }

    /// `createTask` (functions/src/functions/tasks.ts:226). Tasks are the
    /// primary entity, so this is the one that matters most.
    @Test("A task written by the API is parseable by the app")
    func apiTaskIsReadable() throws {
        let map: [String: Any] = [
            "id": "x-1",
            "household_id": "hh-1",
            "title": "Water the plants",
            "description": NSNull(),
            "category_id": NSNull(),
            "priority": "medium",
            "status": "pending",
            "created_by": "uid-1",
            "created_at": "2026-08-14T07:30:00.000Z",
            "updated_at": NSNull(),
        ]
        _ = try #require(
            HouseholdTask(map: map),
            "The app cannot parse a task the API created — the whole Tasks tab misses it.")
    }

    /// `addSubtask` (tasks.ts:251).
    @Test("A subtask written by the API is parseable by the app")
    func apiSubtaskIsReadable() throws {
        let map: [String: Any] = [
            "id": "s-1",
            "task_id": "t-1",
            "household_id": "hh-1",
            "title": "Fetch the watering can",
            "is_completed": false,
            "created_at": "2026-08-14T07:30:00.000Z",
        ]
        _ = try #require(
            Subtask(map: map), "The app cannot parse a subtask the API created.")
    }

    /// `createCategory` (categories.ts:40).
    @Test("A category written by the API is parseable by the app")
    func apiCategoryIsReadable() throws {
        let map: [String: Any] = [
            "id": "c-1",
            "household_id": "hh-1",
            "name": "Kitchen",
            "colour": "#FF0000",
            "created_at": "2026-08-14T07:30:00.000Z",
        ]
        _ = try #require(
            TaskCategory(map: map), "The app cannot parse a category the API created.")
    }

    /// Both writers must store `quantity` as PLAINTEXT.
    ///
    /// The API used to encrypt it (`encN`) while the app writes and reads it
    /// raw, so an API-created item showed a base64 blob in the Qty field and an
    /// app-created one came back from the API as null. The app won that argument
    /// because it is the live writer with existing plaintext data on real
    /// devices; encrypting it properly is a migration, not a patch.
    ///
    /// This asserts the app side of the contract. The API side is pinned by the
    /// grep in `scripts/verify_api_wire.py`, because a Swift test cannot see
    /// TypeScript.
    @Test("the app stores checklist quantity as plaintext, matching the API")
    func quantityIsPlaintextBothSides() throws {
        let item = ChecklistItem(
            id: "i-1", checklistId: "cl-1", householdId: "hh-1",
            title: "White pepper", quantity: "2")
        let map = item.toMap()
        #expect(
            map["quantity"] as? String == "2",
            """
            toMap() no longer emits a plaintext quantity. If the app has started
            encrypting it, functions/src/functions/checklists.ts must change in
            the same commit or the two writers disagree again.
            """)
    }
}
