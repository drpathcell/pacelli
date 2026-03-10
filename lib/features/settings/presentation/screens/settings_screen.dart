import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Settings screen — app preferences, account management, logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.construction_rounded, size: 40),
        title: Text('$feature'),
        content: Text(
          context.l10n.settingsComingSoon(feature),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonOK),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Pacelli',
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 28),
      ),
      children: [
        const SizedBox(height: 8),
        Text(context.l10n.settingsAboutDescription),
      ],
    );
  }

  void _showBurnConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          size: 48,
          color: Colors.red.shade600,
        ),
        title: Text(context.l10n.settingsBurnTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.settingsBurnWillDelete,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            _BurnListItem(context.l10n.settingsBurnTasks),
            _BurnListItem(context.l10n.settingsBurnCategories),
            _BurnListItem(context.l10n.settingsBurnLocalDb),
            _BurnListItem(context.l10n.settingsBurnCloudData),
            _BurnListItem(context.l10n.settingsBurnKeys),
            _BurnListItem(context.l10n.settingsBurnCredentials),
            _BurnListItem(context.l10n.settingsBurnSession),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline,
                      size: 18, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.settingsBurnIrreversible,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.settingsBurnDriveWarningShort,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.go(AppRoutes.burnData);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 18),
                const SizedBox(width: 6),
                Text(context.l10n.settingsBurnEverything),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Also sign out from Google if they used Google Sign-In.
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Ignore — user might not have signed in with Google.
      }

      await FirebaseAuth.instance.signOut();

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar(context.l10n.settingsSignOutFailed,
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        context.colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      (user?.displayName ?? '?').substring(0, 1).toUpperCase(),
                      style: context.textTheme.titleLarge?.copyWith(
                        color: context.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'User',
                          style: context.textTheme.titleMedium,
                        ),
                        Text(
                          user?.email ?? '',
                          style: context.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings options
          _SettingsTile(
            icon: Icons.home_outlined,
            title: context.l10n.settingsHousehold,
            subtitle: context.l10n.settingsHouseholdSubtitle,
            onTap: () => context.push(AppRoutes.household),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: context.l10n.settingsNotifications,
            subtitle: context.l10n.settingsNotificationsSubtitle,
            onTap: () => _showComingSoon(context, context.l10n.settingsNotifications),
          ),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: context.l10n.settingsPrivacy,
            subtitle: context.l10n.settingsPrivacySubtitle,
            onTap: () => context.push(AppRoutes.privacyEncryption),
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: context.l10n.settingsAppearance,
            subtitle: context.l10n.settingsAppearanceSubtitle,
            onTap: () => context.push(AppRoutes.appearance),
          ),
          _SettingsTile(
            icon: Icons.info_outlined,
            title: context.l10n.settingsAbout,
            subtitle: context.l10n.settingsAboutVersion,
            onTap: () => _showAbout(context),
          ),
          const SizedBox(height: 24),

          // Logout button
          OutlinedButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.l10n.settingsSignOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colorScheme.error,
              side: BorderSide(color: context.colorScheme.error),
            ),
          ),

          const SizedBox(height: 32),

          // Divider with "Danger Zone" label
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  context.l10n.settingsDangerZone,
                  style: context.textTheme.labelSmall?.copyWith(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 16),

          // Burn All Data button — prominent, can't be missed.
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade700,
                  Colors.orange.shade800,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _showBurnConfirmation(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.settingsBurnAllData,
                        style: context.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Explanation text
          Text(
            context.l10n.settingsBurnExplanation,
            style: context.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// A reusable settings list tile.
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: context.colorScheme.primary),
        title: Text(title, style: context.textTheme.titleMedium),
        subtitle: Text(subtitle, style: context.textTheme.bodyMedium),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

/// A single item in the burn confirmation list.
class _BurnListItem extends StatelessWidget {
  final String text;
  const _BurnListItem(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.local_fire_department_rounded,
              size: 14, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
