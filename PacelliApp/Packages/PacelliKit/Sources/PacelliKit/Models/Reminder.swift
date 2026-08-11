import Foundation

/// A time of day as `HH:mm`.
///
/// Lives in PacelliKit rather than the app target so the scheduling rules are
/// unit-testable: `NotificationService` can only be exercised through
/// `UNUserNotificationCenter`, but *which* moment a reminder resolves to is
/// pure logic and is where the bugs actually are.
///
/// Stored unencrypted alongside `due_date` — structural metadata of the same
/// class, so encrypting it would be inconsistent and protect nothing the due
/// date does not already reveal.
public struct TimeOfDay: Equatable, Sendable {
    public let hour: Int
    public let minute: Int

    /// Clamps rather than failing: a nonsense component from a future client
    /// should degrade to a sane reminder, not crash or vanish silently.
    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public init?(raw: String) {
        let parts = raw.split(separator: ":")
        guard parts.count == 2,
            let h = Int(parts[0]), let m = Int(parts[1]),
            (0...23).contains(h), (0...59).contains(m)
        else { return nil }
        self.init(hour: h, minute: m)
    }

    public var raw: String { String(format: "%02d:%02d", hour, minute) }

    /// Today at this time — used to seed a `DatePicker`.
    public var date: Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
    }

    public static let noon = TimeOfDay(hour: 12, minute: 0)
}

extension HouseholdTask {
    /// The moment this task's reminder should fire, or nil if it shouldn't.
    ///
    /// Due dates are date-only, so the due *moment* is 00:00 — reminding then
    /// would buzz at midnight. The time of day is what makes the reminder
    /// useful: the task's own override if it has one, otherwise the device
    /// default.
    ///
    /// Returns nil for a task with no due date, and for a completed one — a
    /// finished task must never nag.
    public func reminderFireDate(
        defaultTime: TimeOfDay, calendar: Calendar = .current
    ) -> Date? {
        guard let due = dueDate, !isCompleted else { return nil }
        let time = reminderTime.flatMap(TimeOfDay.init(raw:)) ?? defaultTime
        var comps = calendar.dateComponents([.year, .month, .day], from: due)
        comps.hour = time.hour
        comps.minute = time.minute
        return calendar.date(from: comps)
    }
}
