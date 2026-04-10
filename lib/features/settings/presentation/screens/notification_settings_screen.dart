import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/notification_service.dart';
import '../../../../core/utils/extensions.dart';

/// Notification settings screen — toggle reminders and choose timing.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late bool _enabled;
  late ReminderTiming _timing;

  @override
  void initState() {
    super.initState();
    final service = ref.read(notificationServiceProvider);
    _enabled = service.isEnabled;
    _timing = service.timing;
  }

  Future<void> _onEnabledChanged(bool value) async {
    setState(() => _enabled = value);
    await ref.read(notificationServiceProvider).setEnabled(value);
  }

  Future<void> _onTimingChanged(ReminderTiming? value) async {
    if (value == null) return;
    setState(() => _timing = value);
    await ref.read(notificationServiceProvider).setTiming(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notifTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/disable toggle
          Card(
            child: SwitchListTile(
              secondary: Icon(
                Icons.notifications_outlined,
                color: context.colorScheme.primary,
              ),
              title: Text(
                context.l10n.notifEnable,
                style: context.textTheme.titleMedium,
              ),
              subtitle: Text(
                context.l10n.notifEnableSubtitle,
                style: context.textTheme.bodyMedium,
              ),
              value: _enabled,
              onChanged: _onEnabledChanged,
            ),
          ),

          const SizedBox(height: 16),

          // Reminder timing
          AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: !_enabled,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: context.colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            context.l10n.notifTimingTitle,
                            style: context.textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 36),
                        child: Text(
                          context.l10n.notifTimingSubtitle,
                          style: context.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Column(
                        children: [
                          RadioListTile<ReminderTiming>(
                            title: Text(context.l10n.notifTimingAtDue),
                            subtitle: Text(context.l10n.notifTimingAtDueDesc),
                            value: ReminderTiming.atDue,
                            groupValue: _timing,
                            onChanged: _onTimingChanged,
                          ),
                          RadioListTile<ReminderTiming>(
                            title: Text(context.l10n.notifTimingOneHour),
                            subtitle: Text(context.l10n.notifTimingOneHourDesc),
                            value: ReminderTiming.oneHourBefore,
                            groupValue: _timing,
                            onChanged: _onTimingChanged,
                          ),
                          RadioListTile<ReminderTiming>(
                            title: Text(context.l10n.notifTimingOneDay),
                            subtitle: Text(context.l10n.notifTimingOneDayDesc),
                            value: ReminderTiming.oneDayBefore,
                            groupValue: _timing,
                            onChanged: _onTimingChanged,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Info note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              context.l10n.notifInfoNote,
              style: context.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
