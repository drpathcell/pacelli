import Foundation
import PacelliKit
import UserNotifications

/// Local task reminders.
///
/// Everything here happens on device against already-decrypted data, so a
/// reminder can show the real task title ("Buy milk") rather than a placeholder.
/// Nothing is sent to a server and no push infrastructure is involved — that is
/// only needed for telling the OTHER member something happened.
///
/// Lock-screen privacy is left to iOS: the per-app "Show Previews" setting
/// defaults to *When Unlocked*, so the title is hidden behind Face ID without
/// us degrading the notification to generic text.
enum NotificationService {

    /// iOS keeps at most 64 pending local notifications per app and silently
    /// drops the rest. We schedule the nearest ones and top up on every
    /// mutation and every foreground, so a long backlog can't push the
    /// imminent reminders out.
    static let maxPending = 60  // headroom under the 64 limit

    // Computed, not stored: under Swift 6 strict concurrency a stored static
    // of a non-Sendable type is a shared-mutable-state error. Same pattern as
    // `db` in the repositories.
    private static var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    // MARK: - Identifiers

    /// Two reminders per task: the day itself and the optional day-before
    /// nudge. Deterministic IDs so rescheduling replaces rather than
    /// duplicates.
    private static func onDayId(_ taskId: String) -> String { "task_\(taskId)_day" }
    private static func dayBeforeId(_ taskId: String) -> String { "task_\(taskId)_prev" }

    // MARK: - Permission

    /// Ask only at the moment a reminder would first be useful — never at
    /// launch. Guest-first: the app must stay fully usable if this is refused.
    @discardableResult
    static func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge]))
                ?? false
        case .denied:
            return false
        default:
            return true
        }
    }

    static func isAuthorized() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
    }

    // MARK: - Scheduling

    /// Delegates to `HouseholdTask.reminderFireDate` in PacelliKit, which is
    /// where the resolution rules are unit-tested.
    static func fireDate(for task: HouseholdTask, prefs: ReminderPrefs) -> Date? {
        task.reminderFireDate(defaultTime: prefs.defaultTime)
    }

    /// Replaces any existing reminders for this task.
    static func schedule(_ task: HouseholdTask, prefs: ReminderPrefs) async {
        cancel(task.id)
        guard prefs.enabled, let fire = fireDate(for: task, prefs: prefs) else { return }

        if fire > Date() {
            await add(
                id: onDayId(task.id), title: task.title,
                body: String(localized: "Due today"), at: fire, taskId: task.id)
        }
        if prefs.dayBefore,
            let prev = Calendar.current.date(byAdding: .day, value: -1, to: fire),
            prev > Date()
        {
            await add(
                id: dayBeforeId(task.id), title: task.title,
                body: String(localized: "Due tomorrow"), at: prev, taskId: task.id)
        }
    }

    private static func add(
        id: String, title: String, body: String, at date: Date, taskId: String
    ) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["task_id": taskId]  // for deep linking
        content.threadIdentifier = "pacelli_tasks"

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        try? await center.add(
            UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    static func cancel(_ taskId: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: [onDayId(taskId), dayBeforeId(taskId)])
    }

    static func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Reconciliation

    /// Rebuild the whole pending set from the current tasks.
    ///
    /// This is what stops a reminder firing for something the other person
    /// already ticked off: local notifications don't sync, so the schedule is
    /// only as fresh as the last reconcile. Call on foreground and after any
    /// change. Sorting by fire date before the cap means the soonest reminders
    /// always win the 64 slots.
    static func reconcile(tasks: [HouseholdTask], prefs: ReminderPrefs) async {
        cancelAll()
        guard prefs.enabled, await isAuthorized() else { return }

        let upcoming =
            tasks
            .compactMap { task -> (HouseholdTask, Date)? in
                guard let fire = fireDate(for: task, prefs: prefs) else { return nil }
                return (task, fire)
            }
            // Only the on-day time is tested: the day-before nudge is always
            // earlier, so a task whose on-day fire has passed has nothing
            // left to schedule either.
            .filter { $0.1 > Date() }
            .sorted { $0.1 < $1.1 }

        // Each task can occupy two slots when the day-before nudge is on.
        let slotsPerTask = prefs.dayBefore ? 2 : 1
        for (task, _) in upcoming.prefix(maxPending / slotsPerTask) {
            await schedule(task, prefs: prefs)
        }
    }

    static func pendingCount() async -> Int {
        await center.pendingNotificationRequests().count
    }
}

// MARK: - Preferences

/// Reminder settings, local to the device (SharedPreferences parity — these
/// are a per-device preference, not household state).
struct ReminderPrefs: Equatable, Sendable {
    var enabled: Bool
    var defaultTime: TimeOfDay
    var dayBefore: Bool

    static let storageEnabled = "reminders_enabled"
    static let storageTime = "reminders_default_time"
    static let storageDayBefore = "reminders_day_before"

    static var current: ReminderPrefs {
        let d = UserDefaults.standard
        return ReminderPrefs(
            enabled: d.object(forKey: storageEnabled) as? Bool ?? false,
            defaultTime: (d.string(forKey: storageTime)).flatMap(TimeOfDay.init(raw:)) ?? .noon,
            dayBefore: d.bool(forKey: storageDayBefore))
    }

    func save() {
        let d = UserDefaults.standard
        d.set(enabled, forKey: Self.storageEnabled)
        d.set(defaultTime.raw, forKey: Self.storageTime)
        d.set(dayBefore, forKey: Self.storageDayBefore)
    }
}
