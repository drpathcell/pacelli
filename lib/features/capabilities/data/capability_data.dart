// Static capability catalogue for the "What can Pacelli do?" screen.
//
// Each [CapabilityGroup] represents a feature domain with individual
// capabilities. These are shown on the human-facing discovery screen
// and also served via the `pacelli://capabilities` MCP resource so
// AI agents can discover what the app supports.

class Capability {
  final String icon;
  final String titleKey;
  final String descKey;

  const Capability({
    required this.icon,
    required this.titleKey,
    required this.descKey,
  });
}

class CapabilityGroup {
  final String icon;
  final String titleKey;
  final String descKey;
  final List<Capability> capabilities;

  const CapabilityGroup({
    required this.icon,
    required this.titleKey,
    required this.descKey,
    required this.capabilities,
  });
}

/// The full catalogue of app capabilities grouped by domain.
const capabilityGroups = [
  // ── Tasks ──
  CapabilityGroup(
    icon: '✅',
    titleKey: 'capGroupTasks',
    descKey: 'capGroupTasksDesc',
    capabilities: [
      Capability(
        icon: '📋',
        titleKey: 'capCreateTasks',
        descKey: 'capCreateTasksDesc',
      ),
      Capability(
        icon: '🔁',
        titleKey: 'capRecurringTasks',
        descKey: 'capRecurringTasksDesc',
      ),
      Capability(
        icon: '📊',
        titleKey: 'capTaskPriority',
        descKey: 'capTaskPriorityDesc',
      ),
      Capability(
        icon: '👥',
        titleKey: 'capSharedTasks',
        descKey: 'capSharedTasksDesc',
      ),
      Capability(
        icon: '✂️',
        titleKey: 'capSubtasks',
        descKey: 'capSubtasksDesc',
      ),
    ],
  ),

  // ── Checklists ──
  CapabilityGroup(
    icon: '📝',
    titleKey: 'capGroupChecklists',
    descKey: 'capGroupChecklistsDesc',
    capabilities: [
      Capability(
        icon: '🛒',
        titleKey: 'capShoppingLists',
        descKey: 'capShoppingListsDesc',
      ),
      Capability(
        icon: '➡️',
        titleKey: 'capPushAsTask',
        descKey: 'capPushAsTaskDesc',
      ),
    ],
  ),

  // ── Plans ──
  CapabilityGroup(
    icon: '🗓️',
    titleKey: 'capGroupPlans',
    descKey: 'capGroupPlansDesc',
    capabilities: [
      Capability(
        icon: '✈️',
        titleKey: 'capTripPlans',
        descKey: 'capTripPlansDesc',
      ),
      Capability(
        icon: '📑',
        titleKey: 'capPlanTemplates',
        descKey: 'capPlanTemplatesDesc',
      ),
      Capability(
        icon: '🔀',
        titleKey: 'capFinalisePlan',
        descKey: 'capFinalisePlanDesc',
      ),
    ],
  ),

  // ── Inventory ──
  CapabilityGroup(
    icon: '📦',
    titleKey: 'capGroupInventory',
    descKey: 'capGroupInventoryDesc',
    capabilities: [
      Capability(
        icon: '🏷️',
        titleKey: 'capTrackItems',
        descKey: 'capTrackItemsDesc',
      ),
      Capability(
        icon: '⚠️',
        titleKey: 'capExpiryAlerts',
        descKey: 'capExpiryAlertsDesc',
      ),
      Capability(
        icon: '📷',
        titleKey: 'capBarcodeScanning',
        descKey: 'capBarcodeScanningDesc',
      ),
      Capability(
        icon: '📍',
        titleKey: 'capLocations',
        descKey: 'capLocationsDesc',
      ),
    ],
  ),

  // ── Calendar ──
  CapabilityGroup(
    icon: '📅',
    titleKey: 'capGroupCalendar',
    descKey: 'capGroupCalendarDesc',
    capabilities: [
      Capability(
        icon: '👁️',
        titleKey: 'capCalendarView',
        descKey: 'capCalendarViewDesc',
      ),
      Capability(
        icon: '🔔',
        titleKey: 'capReminders',
        descKey: 'capRemindersDesc',
      ),
    ],
  ),

  // ── Feedback & Insights ──
  CapabilityGroup(
    icon: '📊',
    titleKey: 'capGroupFeedback',
    descKey: 'capGroupFeedbackDesc',
    capabilities: [
      Capability(
        icon: '💬',
        titleKey: 'capSubmitFeedback',
        descKey: 'capSubmitFeedbackDesc',
      ),
      Capability(
        icon: '📈',
        titleKey: 'capWeeklyDigest',
        descKey: 'capWeeklyDigestDesc',
      ),
    ],
  ),

  // ── Security & Privacy ──
  CapabilityGroup(
    icon: '🔒',
    titleKey: 'capGroupSecurity',
    descKey: 'capGroupSecurityDesc',
    capabilities: [
      Capability(
        icon: '🔐',
        titleKey: 'capEncryption',
        descKey: 'capEncryptionDesc',
      ),
      Capability(
        icon: '🔥',
        titleKey: 'capBurnData',
        descKey: 'capBurnDataDesc',
      ),
      Capability(
        icon: '💾',
        titleKey: 'capBackupRestore',
        descKey: 'capBackupRestoreDesc',
      ),
    ],
  ),
];

/// Converts the capability catalogue to a JSON-friendly map for the
/// MCP `pacelli://capabilities` resource.
List<Map<String, dynamic>> capabilitiesToJson() {
  return capabilityGroups.map((g) => {
    'group': g.titleKey,
    'icon': g.icon,
    'capabilities': g.capabilities.map((c) => {
      'name': c.titleKey,
      'icon': c.icon,
    }).toList(),
  }).toList();
}
