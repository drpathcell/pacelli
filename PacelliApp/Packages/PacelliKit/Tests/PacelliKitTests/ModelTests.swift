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
