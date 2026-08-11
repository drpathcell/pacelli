import Foundation
import Testing

@testable import PacelliKit

/// The scheduling rules. `NotificationService` itself can only be exercised
/// through `UNUserNotificationCenter`, but *which moment* a reminder resolves
/// to is pure logic — and it is where the bugs are.
@Suite("Reminder scheduling")
struct ReminderTests {

    /// Fixed calendar so a test can't pass or fail depending on where it runs.
    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Dublin")!
        return c
    }

    private func task(
        due: Date?, reminder: String? = nil, completed: Bool = false
    ) -> HouseholdTask {
        HouseholdTask(
            id: "t1", householdId: "hh", title: "Buy milk",
            status: completed ? HouseholdTask.Status.completed : HouseholdTask.Status.pending,
            dueDate: due, reminderTime: reminder,
            createdBy: "uid", createdAt: Date())
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - TimeOfDay

    @Test("parses and round-trips HH:mm")
    func timeRoundTrip() throws {
        let t = try #require(TimeOfDay(raw: "09:05"))
        #expect(t.hour == 9)
        #expect(t.minute == 5)
        #expect(t.raw == "09:05")
        // Zero-padding matters: the raw form is what lands in Firestore.
        #expect(TimeOfDay(hour: 9, minute: 5).raw == "09:05")
    }

    @Test("rejects malformed times rather than guessing")
    func timeRejects() {
        #expect(TimeOfDay(raw: "") == nil)
        #expect(TimeOfDay(raw: "9") == nil)
        #expect(TimeOfDay(raw: "24:00") == nil)
        #expect(TimeOfDay(raw: "12:60") == nil)
        #expect(TimeOfDay(raw: "noon") == nil)
        #expect(TimeOfDay(raw: "12:00:00") == nil)
    }

    @Test("clamps out-of-range components instead of crashing")
    func timeClamps() {
        // A future client writing something odd should degrade to a sane
        // reminder, not take the app down.
        #expect(TimeOfDay(hour: 99, minute: 99).raw == "23:59")
        #expect(TimeOfDay(hour: -5, minute: -5).raw == "00:00")
    }

    // MARK: - Fire date resolution

    @Test("uses the device default when the task has no override")
    func usesDefault() throws {
        let t = task(due: day(2026, 8, 12))
        let fire = try #require(t.reminderFireDate(defaultTime: .noon, calendar: cal))
        let c = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        #expect(c.year == 2026 && c.month == 8 && c.day == 12)
        #expect(c.hour == 12 && c.minute == 0)
    }

    @Test("a per-task time overrides the default")
    func overrideWins() throws {
        let t = task(due: day(2026, 8, 12), reminder: "19:30")
        let fire = try #require(t.reminderFireDate(defaultTime: .noon, calendar: cal))
        let c = cal.dateComponents([.hour, .minute], from: fire)
        #expect(c.hour == 19 && c.minute == 30)
    }

    @Test("falls back to the default when the override is malformed")
    func malformedOverrideFallsBack() throws {
        let t = task(due: day(2026, 8, 12), reminder: "not-a-time")
        let fire = try #require(t.reminderFireDate(defaultTime: .noon, calendar: cal))
        #expect(cal.dateComponents([.hour], from: fire).hour == 12)
    }

    @Test("never fires at midnight — the whole point of the time of day")
    func neverMidnight() throws {
        // due_date is date-only, so the due MOMENT is 00:00. Reminding then
        // would buzz in the middle of the night; this is the regression guard.
        let t = task(due: day(2026, 8, 12))
        let fire = try #require(t.reminderFireDate(defaultTime: .noon, calendar: cal))
        #expect(fire != day(2026, 8, 12))
        #expect(cal.dateComponents([.hour], from: fire).hour != 0)
    }

    @Test("a task with no due date has no reminder")
    func noDueNoReminder() {
        #expect(task(due: nil).reminderFireDate(defaultTime: .noon, calendar: cal) == nil)
    }

    @Test("a completed task never nags")
    func completedNoReminder() {
        let t = task(due: day(2026, 8, 12), completed: true)
        #expect(t.reminderFireDate(defaultTime: .noon, calendar: cal) == nil)
    }

    @Test("an override survives the Firestore round trip")
    func wireRoundTrip() throws {
        let t = task(due: day(2026, 8, 12), reminder: "07:15")
        let back = try #require(HouseholdTask(map: t.toMap()))
        #expect(back.reminderTime == "07:15")
        // And absence stays absence rather than becoming a bogus time.
        let plain = task(due: day(2026, 8, 12))
        let plainBack = try #require(HouseholdTask(map: plain.toMap()))
        #expect(plainBack.reminderTime == nil)
    }
}
