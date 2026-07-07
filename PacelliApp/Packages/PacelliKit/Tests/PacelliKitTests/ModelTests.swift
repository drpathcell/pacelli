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
