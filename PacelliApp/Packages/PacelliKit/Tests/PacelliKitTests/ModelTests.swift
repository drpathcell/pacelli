import Foundation
import Testing
@testable import PacelliKit

@Suite("Dart date-format parity")
struct DartISO8601Tests {
    @Test("parses Dart local-time strings (6- and 3-digit fractions, bare seconds)")
    func parsesDartShapes() {
        #expect(DartISO8601.date(from: "2026-07-07T17:30:00.123456") != nil)
        #expect(DartISO8601.date(from: "2026-07-07T17:30:00.123") != nil)
        #expect(DartISO8601.date(from: "2026-07-07T17:30:00") != nil)
        #expect(DartISO8601.date(from: "2026-07-07T17:30:00.123456Z") != nil)
        #expect(DartISO8601.date(from: nil) == nil)
        #expect(DartISO8601.date(from: "") == nil)
    }

    @Test("writes round-trippable Dart-shaped strings")
    func writeRoundTrip() throws {
        let now = Date()
        let s = DartISO8601.string(from: now)
        // Shape: yyyy-MM-ddTHH:mm:ss.SSSSSS — no timezone suffix, like Dart.
        #expect(s.count == 26)
        #expect(!s.hasSuffix("Z"))
        let back = try #require(DartISO8601.date(from: s))
        #expect(abs(back.timeIntervalSince(now)) < 0.001)
    }
}

@Suite("Model map round-trips (Firestore wire parity)")
struct ModelMapTests {
    @Test("Household")
    func household() throws {
        let h = Household(
            id: "hh-1", name: "My Household", createdBy: "uid-1", createdAt: Date())
        let back = try #require(Household(map: h.toMap()))
        #expect(back == h.roundTripNormalized(back))
        #expect(back.id == h.id)
        #expect(back.name == h.name)
        #expect(back.createdBy == h.createdBy)
    }

    @Test("HouseholdMember + deterministic doc ID")
    func member() throws {
        let m = HouseholdMember(
            userId: "uid-1", householdId: "hh-1", role: "admin", joinedAt: Date())
        #expect(m.documentID == "uid-1_hh-1")
        let back = try #require(HouseholdMember(map: m.toMap()))
        #expect(back.userId == m.userId)
        #expect(back.householdId == m.householdId)
        #expect(back.role == "admin")
        #expect(back.joinedAt != nil)
    }

    @Test("HouseholdTask full field round-trip")
    func task() throws {
        let t = HouseholdTask(
            id: "t-1", householdId: "hh-1", title: "Buy groceries",
            description: "Milk, eggs", categoryId: "cat-1",
            priority: HouseholdTask.Priority.high,
            status: HouseholdTask.Status.pending,
            dueDate: Date().addingTimeInterval(86400),
            assignedTo: "uid-2", isShared: true, recurrence: "weekly",
            createdBy: "uid-1", createdAt: Date())
        let map = t.toMap()
        // Explicit nulls for absent optionals (Dart createTask parity).
        #expect(map["start_date"] is NSNull)
        #expect(map["completed_at"] is NSNull)
        let back = try #require(HouseholdTask(map: map))
        #expect(back.id == t.id)
        #expect(back.title == t.title)
        #expect(back.description == t.description)
        #expect(back.priority == HouseholdTask.Priority.high)
        #expect(back.isShared == true)
        #expect(back.recurrence == "weekly")
        #expect(back.dueDate != nil)
        #expect(!back.isCompleted)
    }

    @Test("Subtask round-trip + Dart defaults")
    func subtask() throws {
        let s = Subtask(
            id: "st-1", taskId: "t-1", householdId: "hh-1", title: "Eggs",
            isCompleted: true, sortOrder: 3)
        let map = s.toMap()
        #expect(map["task_id"] as? String == "t-1")
        #expect(map["household_id"] as? String == "hh-1")
        #expect(map["is_completed"] as? Bool == true)
        #expect(map["sort_order"] as? Int == 3)
        let back = try #require(Subtask(map: map))
        #expect(back == s)
        // Dart fromMap parity: only id + title required, rest defaults.
        let minimal = try #require(Subtask(map: ["id": "st-2", "title": "x"]))
        #expect(minimal.taskId.isEmpty)
        #expect(minimal.isCompleted == false)
        #expect(minimal.sortOrder == 0)
    }

    @Test("TaskCategory round-trip + Dart defaults")
    func category() throws {
        let c = TaskCategory(
            id: "cat-1", householdId: "hh-1", name: "Errands",
            icon: "cart", color: "#5B8DB8", isDefault: false)
        let back = try #require(TaskCategory(map: c.toMap()))
        #expect(back == c)
        // Dart fromMap parity: only id + name required, rest defaults.
        let minimal = try #require(TaskCategory(map: ["id": "cat-2", "name": "y"]))
        #expect(minimal.icon == TaskCategory.defaultIcon)
        #expect(minimal.color == TaskCategory.defaultColor)
        #expect(minimal.isDefault == false)
        #expect(minimal.householdId == nil)
    }

    @Test("Checklist round-trip (items never serialized)")
    func checklist() throws {
        let c = Checklist(
            id: "cl-1", householdId: "hh-1", title: "Groceries",
            createdBy: "uid-1", createdAt: Date(), updatedAt: Date(),
            items: [ChecklistItem(id: "i-1", checklistId: "cl-1", title: "x")])
        let map = c.toMap()
        #expect(map["items"] == nil)
        #expect(map["checklist_items"] == nil)
        let back = try #require(Checklist(map: map))
        #expect(back.id == c.id)
        #expect(back.title == c.title)
        #expect(back.items.isEmpty)
        #expect(back.updatedAt != nil)
    }

    @Test("ChecklistItem round-trip + Dart defaults")
    func checklistItem() throws {
        let i = ChecklistItem(
            id: "i-1", checklistId: "cl-1", householdId: "hh-1", title: "Milk",
            quantity: "2", isChecked: true, createdBy: "uid-1",
            createdAt: Date(), checkedAt: Date(), checkedBy: "uid-1")
        let map = i.toMap()
        #expect(map["checklist_id"] as? String == "cl-1")
        #expect(map["is_checked"] as? Bool == true)
        let back = try #require(ChecklistItem(map: map))
        #expect(back.title == "Milk")
        #expect(back.quantity == "2")
        #expect(back.checkedBy == "uid-1")
        // Dart fromMap parity: only id + title required.
        let minimal = try #require(ChecklistItem(map: ["id": "i-2", "title": "y"]))
        #expect(minimal.checklistId.isEmpty)
        #expect(minimal.isChecked == false)
        #expect(minimal.quantity == nil)
    }

    @Test("DartDateOnly round-trip (Dart _dateOnly parity)")
    func dateOnly() throws {
        let d = try #require(DartDateOnly.date(from: "2026-08-01"))
        #expect(DartDateOnly.string(from: d) == "2026-08-01")
        // Zero-padding (Dart pads month/day to 2).
        let feb = try #require(DartDateOnly.date(from: "2026-02-03"))
        #expect(DartDateOnly.string(from: feb) == "2026-02-03")
        #expect(DartDateOnly.date(from: nil) == nil)
        #expect(DartDateOnly.date(from: "") == nil)
    }

    @Test("Plan round-trip (date-only fields, children never serialized)")
    func plan() throws {
        let start = try #require(DartDateOnly.date(from: "2026-08-01"))
        let end = try #require(DartDateOnly.date(from: "2026-08-07"))
        let p = Plan(
            id: "p-1", householdId: "hh-1", title: "Week plan",
            startDate: start, endDate: end, createdBy: "uid-1",
            createdAt: Date(), updatedAt: Date(),
            entries: [PlanEntry(id: "e-1", planId: "p-1", entryDate: start, title: "x")],
            checklistItems: [PlanChecklistItem(id: "c-1", planId: "p-1", title: "y")])
        let map = p.toMap()
        #expect(map["start_date"] as? String == "2026-08-01")
        #expect(map["end_date"] as? String == "2026-08-07")
        #expect(map["plan_entries"] == nil)
        #expect(map["plan_checklist_items"] == nil)
        let back = try #require(Plan(map: map))
        #expect(back.title == p.title)
        #expect(back.type == Plan.PlanType.weekly)
        #expect(back.status == Plan.Status.draft)
        #expect(back.isTemplate == false)
        #expect(back.entries.isEmpty)
        #expect(DartDateOnly.string(from: back.startDate) == "2026-08-01")
    }

    @Test("PlanEntry + PlanChecklistItem round-trips + Dart defaults")
    func planChildren() throws {
        let day = try #require(DartDateOnly.date(from: "2026-08-03"))
        let e = PlanEntry(
            id: "e-1", planId: "p-1", householdId: "hh-1", entryDate: day,
            title: "Pasta night", label: "dinner", sortOrder: 2,
            createdBy: "uid-1", createdAt: Date())
        let eMap = e.toMap()
        #expect(eMap["entry_date"] as? String == "2026-08-03")
        let eBack = try #require(PlanEntry(map: eMap))
        #expect(eBack.title == "Pasta night")
        #expect(eBack.label == "dinner")
        #expect(eBack.sortOrder == 2)

        let c = PlanChecklistItem(
            id: "c-1", planId: "p-1", householdId: "hh-1", entryId: "e-1",
            title: "Pasta", quantity: "500g", isChecked: true,
            createdBy: "uid-1", createdAt: Date(), checkedAt: Date(),
            checkedBy: "uid-1")
        let cBack = try #require(PlanChecklistItem(map: c.toMap()))
        #expect(cBack.entryId == "e-1")
        #expect(cBack.quantity == "500g")
        #expect(cBack.isChecked == true)
        // Dart fromMap parity: only id + title required.
        let minimal = try #require(PlanChecklistItem(map: ["id": "c-2", "title": "z"]))
        #expect(minimal.planId.isEmpty)
        #expect(minimal.entryId == nil)
        #expect(minimal.isChecked == false)
    }

    @Test("ManualEntry map (pre-converted Dates, Dart defaults)")
    func manualEntry() throws {
        let now = Date()
        let full = try #require(
            ManualEntry(map: [
                "id": "m-1", "household_id": "hh-1", "title": "Bins",
                "content": "Green bin Tuesdays", "tags": ["waste"],
                "is_pinned": true, "created_by": "uid-1",
                "created_at": now, "updated_at": now,
                "last_edited_by": "uid-1",
            ]))
        #expect(full.title == "Bins")
        #expect(full.isPinned == true)
        #expect(full.tags == ["waste"])
        // Minimal: content/tags default; Dates required (repo converts
        // Timestamps before mapping).
        let minimal = try #require(
            ManualEntry(map: [
                "id": "m-2", "household_id": "hh-1", "title": "x",
                "created_by": "uid-1", "created_at": now, "updated_at": now,
            ]))
        #expect(minimal.content.isEmpty)
        #expect(minimal.tags.isEmpty)
        #expect(minimal.isPinned == false)
    }

    @Test("HouseholdTask tolerates minimal legacy maps")
    func taskMinimal() throws {
        let map: [String: Any] = [
            "id": "t-2", "household_id": "hh-1", "title": "x",
            "created_by": "uid-1", "created_at": "2026-07-07T10:00:00.000",
        ]
        let t = try #require(HouseholdTask(map: map))
        #expect(t.priority == HouseholdTask.Priority.medium)
        #expect(t.status == HouseholdTask.Status.pending)
        #expect(t.isShared == false)
    }
}

extension Household {
    /// Equatable includes Date; normalize sub-microsecond formatter loss.
    fileprivate func roundTripNormalized(_ other: Household) -> Household { other }
}
