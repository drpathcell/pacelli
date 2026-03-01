import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/extensions.dart';

/// Settings screen — app preferences, account management, logout.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      // Also sign out from Google if they used Google Sign-In
      try {
        await GoogleSignIn().signOut();
      } catch (_) {
        // Ignore — user might not have signed in with Google
      }

      await supabase.auth.signOut();

      if (context.mounted) {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      if (context.mounted) {
        context.showSnackBar('Failed to log out. Please try again.',
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
                      (user?.userMetadata?['full_name'] as String?)
                              ?.substring(0, 1)
                              .toUpperCase() ??
                          '?',
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
                          user?.userMetadata?['full_name'] ?? 'User',
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
            title: 'Household',
            subtitle: 'Manage household & members',
            onTap: () => context.push(AppRoutes.household),
          ),
          _SettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Reminders & alerts',
            onTap: () {
              context.showSnackBar('Coming soon!');
            },
          ),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Theme & display',
            onTap: () {
              context.showSnackBar('Coming soon!');
            },
          ),
          _SettingsTile(
            icon: Icons.info_outlined,
            title: 'About Pacelli',
            subtitle: 'Version 0.1.0',
            onTap: () {},
          ),
          const SizedBox(height: 24),

          // Logout button
          OutlinedButton.icon(
            onPressed: () => _handleLogout(context),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colorScheme.error,
              side: BorderSide(color: context.colorScheme.error),
            ),
          ),
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
