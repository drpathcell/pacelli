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

    /// `quantity` is CIPHERTEXT at rest as of 1.7.0, in both writers.
    ///
    /// This test cannot see that, and saying so is the point. `toMap()` still
    /// emits the raw quantity — it is the in-memory shape — and the
    /// repositories replace it with ciphertext immediately before the write,
    /// exactly as they already do for `title`. The storage contract therefore
    /// lives in four files, none of them this one:
    ///
    ///   - `ChecklistsRepository` / `PlansRepository`  (the app's writes)
    ///   - `checklists.ts` / `plans.ts`                (the API's writes)
    ///
    /// and is enforced by `scripts/verify_api_wire.py`, which greps all four
    /// per write site. The earlier version of this test asserted the opposite —
    /// that `toMap()` must emit plaintext — which was true of storage until the
    /// migration and is now merely true of the struct.
    ///
    /// What IS testable here is that the model layer stays neutral about the
    /// form: it must carry a ciphertext quantity through a round trip without
    /// inspecting, validating or rejecting it. If it ever started caring, the
    /// repositories' override would not survive parsing.
    @Test("the model layer carries a ciphertext quantity untouched")
    func modelIsNeutralAboutQuantityForm() throws {
        let key = "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
        let ciphertext = try PacelliCrypto.encrypt("2", key: key)

        let map: [String: Any] = [
            "id": "i-1",
            "checklist_id": "cl-1",
            "household_id": "hh-1",
            "title": try PacelliCrypto.encrypt("White pepper", key: key),
            "quantity": ciphertext,
            "is_checked": false,
            "created_at": "2026-08-14T07:30:00.000Z",
        ]

        let item = try #require(
            ChecklistItem(map: map),
            "The app cannot parse an item whose quantity is encrypted.")
        #expect(
            item.quantity == ciphertext,
            "init?(map:) altered the stored quantity instead of carrying it.")

        // And back out again, unchanged.
        #expect(item.toMap()["quantity"] as? String == ciphertext)
    }
}
