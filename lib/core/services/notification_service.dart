import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ── SharedPreferences keys ──
const _kNotificationsEnabled = 'notifications_enabled';
const _kReminderTiming = 'reminder_timing'; // "at_due" | "1_hour" | "1_day"

/// Reminder timing options.
enum ReminderTiming {
  atDue, // at the exact due time
  oneHourBefore,
  oneDayBefore,
}

/// Service that manages local push notifications for task reminders.
///
/// Handles platform initialisation (iOS, Android, macOS), scheduling
/// notifications for task due dates, and cancelling them.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin;

  bool _initialised = false;
  bool _enabled = true;
  ReminderTiming _timing = ReminderTiming.oneHourBefore;

  NotificationService() : _plugin = FlutterLocalNotificationsPlugin();

  /// Whether notifications are enabled globally.
  bool get isEnabled => _enabled;

  /// The current reminder timing preference.
  ReminderTiming get timing => _timing;

  /// Initialises the notification plugin and loads preferences.
  ///
  /// Must be called once at app startup (from `main()` or a provider).
  Future<void> init() async {
    if (_initialised) return;

    // Initialise timezone data for scheduling.
    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const macosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );

    await _plugin.initialize(settings: initSettings);
    await _loadPreferences();
    _initialised = true;

    debugPrint('[NotificationService] ✓ Initialised (enabled=$_enabled, timing=$_timing)');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  PREFERENCES
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_kNotificationsEnabled) ?? true;
    _timing = _parseTiming(prefs.getString(_kReminderTiming));
  }

  /// Enables or disables notifications globally.
  ///
  /// When disabled, cancels all pending notifications.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotificationsEnabled, enabled);

    if (!enabled) {
      await cancelAll();
    }
  }

  /// Sets the reminder timing preference.
  Future<void> setTiming(ReminderTiming timing) async {
    _timing = timing;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kReminderTiming, _timingToString(timing));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  SCHEDULING
  // ═══════════════════════════════════════════════════════════════════

  /// Schedules a reminder notification for a task.
  ///
  /// Uses the task's [dueDate] and the user's [_timing] preference to
  /// calculate when to fire. The [taskId] is hashed to a stable int ID
  /// for the notification.
  ///
  /// Does nothing if notifications are disabled or [dueDate] is null.
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String taskTitle,
    DateTime? dueDate,
  }) async {
    if (!_enabled || dueDate == null) return;

    final scheduledDate = _applyTiming(dueDate);

    // Don't schedule if the time has already passed.
    if (scheduledDate.isBefore(DateTime.now())) return;

    final notificationId = _stableId(taskId);

    const androidDetails = AndroidNotificationDetails(
      'task_reminders',
      'Task Reminders',
      channelDescription: 'Reminders for upcoming task due dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Pacelli',
      // Generic body — avoids leaking task content to the lock screen.
      body: 'You have a task reminder',
      payload: taskId,
      scheduledDate: tzScheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    debugPrint('[NotificationService] Scheduled reminder for task $taskId at $scheduledDate');
  }

  /// Cancels the notification for a specific task.
  Future<void> cancelTaskReminder(String taskId) async {
    final notificationId = _stableId(taskId);
    await _plugin.cancel(id: notificationId);
    debugPrint('[NotificationService] Cancelled reminder for task $taskId');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  INVENTORY NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Schedules an expiry reminder for an inventory item.
  ///
  /// Uses the user's reminder timing preference (same as task reminders).
  Future<void> scheduleExpiryReminder({
    required String itemId,
    required String itemName,
    required DateTime expiryDate,
  }) async {
    if (!_enabled || expiryDate.isBefore(DateTime.now())) return;

    final scheduledDate = _applyTiming(expiryDate);
    if (scheduledDate.isBefore(DateTime.now())) return;

    final notificationId = _stableId('expiry_$itemId');

    const androidDetails = AndroidNotificationDetails(
      'inventory_reminders',
      'Inventory Reminders',
      channelDescription: 'Reminders for inventory expiry dates and low stock',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Pacelli',
      // Generic body — avoids leaking item names to the lock screen.
      body: 'An inventory item is expiring soon',
      payload: itemId,
      scheduledDate: tzScheduled,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );

    debugPrint('[NotificationService] Scheduled expiry reminder for item $itemId at $scheduledDate');
  }

  /// Cancels an expiry reminder for an inventory item.
  Future<void> cancelExpiryReminder(String itemId) async {
    await _plugin.cancel(id: _stableId('expiry_$itemId'));
    debugPrint('[NotificationService] Cancelled expiry reminder for item $itemId');
  }

  /// Sends an immediate low stock notification.
  ///
  /// Called when quantity drops below the threshold.
  Future<void> sendLowStockNotification({
    required String itemId,
    required String itemName,
    required int currentQuantity,
    required int threshold,
  }) async {
    if (!_enabled) return;

    final notificationId = _stableId('lowstock_$itemId');

    const androidDetails = AndroidNotificationDetails(
      'inventory_reminders',
      'Inventory Reminders',
      channelDescription: 'Reminders for inventory expiry dates and low stock',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await _plugin.show(
      id: notificationId,
      title: 'Pacelli',
      // Generic body — avoids leaking item names/quantities to the lock screen.
      body: 'An inventory item is running low',
      payload: itemId,
      notificationDetails: details,
    );

    debugPrint('[NotificationService] Sent low stock notification for item $itemId');
  }

  /// Cancels all pending notifications.
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled');
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════

  /// Applies the timing preference to the due date.
  DateTime _applyTiming(DateTime dueDate) {
    switch (_timing) {
      case ReminderTiming.atDue:
        return dueDate;
      case ReminderTiming.oneHourBefore:
        return dueDate.subtract(const Duration(hours: 1));
      case ReminderTiming.oneDayBefore:
        // Notify at 9 AM the day before.
        final dayBefore = dueDate.subtract(const Duration(days: 1));
        return DateTime(dayBefore.year, dayBefore.month, dayBefore.day, 9, 0);
    }
  }

  /// Generates a stable int ID from a string task ID.
  int _stableId(String taskId) => taskId.hashCode & 0x7FFFFFFF;

  static ReminderTiming _parseTiming(String? value) {
    switch (value) {
      case 'at_due':
        return ReminderTiming.atDue;
      case '1_day':
        return ReminderTiming.oneDayBefore;
      case '1_hour':
      default:
        return ReminderTiming.oneHourBefore;
    }
  }

  static String _timingToString(ReminderTiming timing) {
    switch (timing) {
      case ReminderTiming.atDue:
        return 'at_due';
      case ReminderTiming.oneHourBefore:
        return '1_hour';
      case ReminderTiming.oneDayBefore:
        return '1_day';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════
//  RIVERPOD PROVIDER
// ═══════════════════════════════════════════════════════════════════════

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
