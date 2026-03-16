import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/pacelli_ai_icon.dart';
import '../../data/capability_data.dart';

/// "What can Pacelli do?" discovery screen.
///
/// Shows all app capabilities organised by domain with expandable
/// groups. Each capability shows whether it's also available through
/// the AI assistant. Accessible from Settings and from the Home screen.
class CapabilitiesScreen extends StatelessWidget {
  const CapabilitiesScreen({super.key});

  /// Resolve a l10n key to the translated string.
  ///
  /// This maps the static titleKey/descKey strings from [capability_data]
  /// to actual localisations. It's done via a switch rather than
  /// reflection to keep AOT compatibility.
  String _resolve(BuildContext context, String key) {
    final l = context.l10n;
    switch (key) {
      // Group titles
      case 'capGroupTasks':
        return l.capGroupTasks;
      case 'capGroupTasksDesc':
        return l.capGroupTasksDesc;
      case 'capGroupChecklists':
        return l.capGroupChecklists;
      case 'capGroupChecklistsDesc':
        return l.capGroupChecklistsDesc;
      case 'capGroupPlans':
        return l.capGroupPlans;
      case 'capGroupPlansDesc':
        return l.capGroupPlansDesc;
      case 'capGroupInventory':
        return l.capGroupInventory;
      case 'capGroupInventoryDesc':
        return l.capGroupInventoryDesc;
      case 'capGroupCalendar':
        return l.capGroupCalendar;
      case 'capGroupCalendarDesc':
        return l.capGroupCalendarDesc;
      case 'capGroupAi':
        return l.capGroupAi;
      case 'capGroupAiDesc':
        return l.capGroupAiDesc;
      case 'capGroupSecurity':
        return l.capGroupSecurity;
      case 'capGroupSecurityDesc':
        return l.capGroupSecurityDesc;

      // Capability titles
      case 'capCreateTasks':
        return l.capCreateTasks;
      case 'capCreateTasksDesc':
        return l.capCreateTasksDesc;
      case 'capRecurringTasks':
        return l.capRecurringTasks;
      case 'capRecurringTasksDesc':
        return l.capRecurringTasksDesc;
      case 'capTaskPriority':
        return l.capTaskPriority;
      case 'capTaskPriorityDesc':
        return l.capTaskPriorityDesc;
      case 'capSharedTasks':
        return l.capSharedTasks;
      case 'capSharedTasksDesc':
        return l.capSharedTasksDesc;
      case 'capSubtasks':
        return l.capSubtasks;
      case 'capSubtasksDesc':
        return l.capSubtasksDesc;
      case 'capShoppingLists':
        return l.capShoppingLists;
      case 'capShoppingListsDesc':
        return l.capShoppingListsDesc;
      case 'capPushAsTask':
        return l.capPushAsTask;
      case 'capPushAsTaskDesc':
        return l.capPushAsTaskDesc;
      case 'capTripPlans':
        return l.capTripPlans;
      case 'capTripPlansDesc':
        return l.capTripPlansDesc;
      case 'capPlanTemplates':
        return l.capPlanTemplates;
      case 'capPlanTemplatesDesc':
        return l.capPlanTemplatesDesc;
      case 'capFinalisePlan':
        return l.capFinalisePlan;
      case 'capFinalisePlanDesc':
        return l.capFinalisePlanDesc;
      case 'capTrackItems':
        return l.capTrackItems;
      case 'capTrackItemsDesc':
        return l.capTrackItemsDesc;
      case 'capExpiryAlerts':
        return l.capExpiryAlerts;
      case 'capExpiryAlertsDesc':
        return l.capExpiryAlertsDesc;
      case 'capBarcodeScanning':
        return l.capBarcodeScanning;
      case 'capBarcodeScanningDesc':
        return l.capBarcodeScanningDesc;
      case 'capLocations':
        return l.capLocations;
      case 'capLocationsDesc':
        return l.capLocationsDesc;
      case 'capCalendarView':
        return l.capCalendarView;
      case 'capCalendarViewDesc':
        return l.capCalendarViewDesc;
      case 'capReminders':
        return l.capReminders;
      case 'capRemindersDesc':
        return l.capRemindersDesc;
      case 'capNaturalLanguage':
        return l.capNaturalLanguage;
      case 'capNaturalLanguageDesc':
        return l.capNaturalLanguageDesc;
      case 'capMcpIntegration':
        return l.capMcpIntegration;
      case 'capMcpIntegrationDesc':
        return l.capMcpIntegrationDesc;
      case 'capEncryption':
        return l.capEncryption;
      case 'capEncryptionDesc':
        return l.capEncryptionDesc;
      case 'capBurnData':
        return l.capBurnData;
      case 'capBurnDataDesc':
        return l.capBurnDataDesc;
      case 'capBackupRestore':
        return l.capBackupRestore;
      case 'capBackupRestoreDesc':
        return l.capBackupRestoreDesc;

      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.capScreenTitle),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: capabilityGroups.length,
        itemBuilder: (context, index) {
          final group = capabilityGroups[index];
          return _CapabilityGroupCard(
            group: group,
            resolve: (key) => _resolve(context, key),
          );
        },
      ),
    );
  }
}

class _CapabilityGroupCard extends StatelessWidget {
  final CapabilityGroup group;
  final String Function(String key) resolve;

  const _CapabilityGroupCard({
    required this.group,
    required this.resolve,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(group.icon, style: const TextStyle(fontSize: 24)),
          title: Text(
            resolve(group.titleKey),
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              resolve(group.descKey),
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          initiallyExpanded: false,
          childrenPadding:
              const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          children: group.capabilities.map((cap) {
            return _CapabilityTile(
              capability: cap,
              resolve: resolve,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _CapabilityTile extends StatelessWidget {
  final Capability capability;
  final String Function(String key) resolve;

  const _CapabilityTile({
    required this.capability,
    required this.resolve,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(capability.icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        resolve(capability.titleKey),
                        style: context.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (capability.aiSupported)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PacelliAiIcon(
                              size: 12,
                              color: context.colorScheme.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'AI',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  resolve(capability.descKey),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
