import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../config/theme/app_colors.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/data/local_database.dart';
import '../../../../core/utils/extensions.dart';

/// Full-screen storage backend selection — presented before the app is usable.
///
/// The user MUST choose a backend before continuing. This is not optional.
/// Two options:
///   1. **On This Device** — Local SQLite, no cloud, full privacy.
///   2. **Cloud Sync** — Firebase/Firestore with end-to-end encryption.
class StorageSetupScreen extends ConsumerStatefulWidget {
  const StorageSetupScreen({super.key});

  @override
  ConsumerState<StorageSetupScreen> createState() =>
      _StorageSetupScreenState();
}

class _StorageSetupScreenState extends ConsumerState<StorageSetupScreen> {
  bool _isLoading = false;
  String? _selectedBackend;

  // ─── Local backend ──────────────────────────────────────────────

  Future<void> _selectLocal() async {
    setState(() {
      _isLoading = true;
      _selectedBackend = 'local';
    });

    try {
      final db = await LocalDatabase.open();
      ref.read(localDatabaseProvider.notifier).state = db;
      await saveStorageBackend('local');

      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.storageFailedLocal(e.toString()),
          isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Firebase/Cloud backend ───────────────────────────────────

  Future<void> _selectFirebase() async {
    setState(() {
      _isLoading = true;
      _selectedBackend = 'firebase';
    });

    try {
      await saveStorageBackend('firebase');

      // Clear the local DB provider so dataRepositoryProvider switches
      // to FirebaseDataRepository immediately.
      ref.read(localDatabaseProvider.notifier).state = null;

      if (!mounted) return;
      context.go(AppRoutes.home);
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.storageFailedCloud(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isConfigured = ref.watch(storageBackendProvider).valueOrNull != null;

    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isConfigured)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => context.pop(),
                        ),
                      )
                    else
                      const SizedBox(height: 32),

                    // Header
                    Center(
                      child: Icon(
                        Icons.storage_rounded,
                        size: 56,
                        color: context.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        context.l10n.storageWhereDataLive,
                        style: context.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        context.l10n.storageSubtitle,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Option 1: On This Device ──
                    _BackendOptionCard(
                      icon: Icons.phone_iphone_rounded,
                      title: context.l10n.storageOnDevice,
                      description:
                          context.l10n.storageOnDeviceDescription,
                      isSelected: _selectedBackend == 'local',
                      onTap: _selectLocal,
                    ),

                    const SizedBox(height: 12),

                    // ── Option 2: Cloud Sync (Firebase) ──
                    _BackendOptionCard(
                      icon: Icons.cloud_outlined,
                      title: context.l10n.storageCloudSync,
                      description:
                          context.l10n.storageCloudSyncDescription,
                      isSelected: _selectedBackend == 'firebase',
                      onTap: _selectFirebase,
                      badge: context.l10n.storageRecommended,
                    ),

                    const SizedBox(height: 32),

                    // Privacy note
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.shield_outlined,
                              size: 20, color: AppColors.info),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.storagePrivacyNote,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

/// A tappable card representing a backend option.
class _BackendOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;
  final String? badge;

  const _BackendOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.isSelected = false,
    this.isDisabled = false, // ignore: unused_element_parameter
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Opacity(
      opacity: isDisabled ? 0.45 : 1.0,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isSelected
              ? BorderSide(color: primaryColor, width: 2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: isDisabled ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: primaryColor.withValues(alpha: 0.1),
                  child: Icon(icon, color: primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: context.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge!,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isDisabled)
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: AppColors.textSecondaryLight),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
