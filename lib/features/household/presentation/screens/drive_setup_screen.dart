import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/attachment.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/household_providers.dart';

/// Screen for the household owner to connect Google Drive storage.
///
/// This sets up a dedicated "Pacelli/{householdName}" folder in the owner's
/// Google Drive where all household file attachments will be stored.
/// Household members access files via shareable links — no Drive API auth
/// needed on their end.
class DriveSetupScreen extends ConsumerStatefulWidget {
  final String householdId;

  const DriveSetupScreen({super.key, required this.householdId});

  @override
  ConsumerState<DriveSetupScreen> createState() => _DriveSetupScreenState();
}

class _DriveSetupScreenState extends ConsumerState<DriveSetupScreen> {
  final _driveService = GoogleDriveService();
  bool _isLoading = false;
  bool _isConnected = false;
  String? _folderId;

  @override
  void initState() {
    super.initState();
    _checkExistingConfig();
  }

  /// Check if Drive is already configured for this household.
  Future<void> _checkExistingConfig() async {
    setState(() => _isLoading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('household_drive_config')
          .doc(widget.householdId)
          .get();

      if (doc.exists) {
        final config = HouseholdDriveConfig.fromMap(doc.data()!);
        if (config.isEnabled) {
          setState(() {
            _isConnected = true;
            _folderId = config.driveFolderId;
          });
        }
      }
    } catch (e) {
      debugPrint('DriveSetupScreen: Failed to check config: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Connect Google Drive: request scope, create folder, save config.
  Future<void> _connectDrive() async {
    setState(() => _isLoading = true);

    try {
      // 1. Request Drive file scope
      final granted = await _driveService.requestDriveScope();
      if (!granted) {
        if (mounted) {
          context.showSnackBar(
            context.l10n.driveAccessNotGranted,
            isError: true,
          );
        }
        return;
      }

      // 2. Get household name for the folder
      final householdAsync = ref.read(currentHouseholdProvider);
      final householdName = householdAsync.valueOrNull?['household']?['name']
              as String? ??
          'My Household';

      // 3. Create "Pacelli/{householdName}" folder in Drive
      final folderId = await _driveService.ensurePacelliFolder(householdName);

      // 4. Save the config to Firestore
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final config = HouseholdDriveConfig(
        householdId: widget.householdId,
        ownerId: uid,
        driveFolderId: folderId,
        isEnabled: true,
        createdAt: DateTime.now(),
      );

      await FirebaseFirestore.instance
          .collection('household_drive_config')
          .doc(widget.householdId)
          .set(config.toMap());

      if (mounted) {
        setState(() {
          _isConnected = true;
          _folderId = folderId;
        });
        context.showSnackBar(context.l10n.driveConnectedSuccess);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          context.l10n.driveConnectFailed(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Disconnect Drive: disable config in Firestore.
  Future<void> _disconnectDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.driveDisconnectTitle),
        content: Text(context.l10n.driveDisconnectMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.driveDisconnect),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('household_drive_config')
          .doc(widget.householdId)
          .update({'is_enabled': false});

      if (mounted) {
        setState(() {
          _isConnected = false;
          _folderId = null;
        });
        context.showSnackBar(context.l10n.driveDisconnected);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(context.l10n.driveDisconnectFailed(e.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _isCurrentUserOwner();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.driveTitle),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero icon
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _isConnected
                            ? AppColors.success.withValues(alpha: 0.1)
                            : context.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isConnected
                            ? Icons.cloud_done_rounded
                            : Icons.cloud_upload_outlined,
                        size: 40,
                        color: _isConnected
                            ? AppColors.success
                            : context.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Center(
                    child: Text(
                      _isConnected
                          ? context.l10n.driveConnected
                          : context.l10n.driveConnect,
                      style: context.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _isConnected
                          ? context.l10n.driveConnectedSubtitle
                          : context.l10n.driveConnectSubtitle,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── How it works ──
                  if (!_isConnected) ...[
                    _SectionHeader(title: context.l10n.driveHowItWorks),
                    const SizedBox(height: 12),

                    _InfoRow(
                      icon: Icons.folder_outlined,
                      text: context.l10n.driveInfoFolder,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.attach_file_rounded,
                      text: context.l10n.driveInfoAttach,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.people_outline_rounded,
                      text: context.l10n.driveInfoMembers,
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.storage_rounded,
                      text: context.l10n.driveInfoQuota,
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
                              context.l10n.drivePrivacyNote,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.info,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  // ── Connected status ──
                  if (_isConnected) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context.l10n.driveStorageActive,
                                        style: context.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        context.l10n.driveCanAttachNow,
                                        style: context.textTheme.bodySmall
                                            ?.copyWith(
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_folderId != null) ...[
                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.folder_rounded,
                                      size: 20,
                                      color: AppColors.textSecondaryLight),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.l10n.drivePacelliFolder,
                                      style: context.textTheme.bodySmall
                                          ?.copyWith(
                                        color: AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Action button ──
                  if (isOwner)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : (_isConnected ? _disconnectDrive : _connectDrive),
                        icon: Icon(_isConnected
                            ? Icons.link_off_rounded
                            : Icons.add_link_rounded),
                        label: Text(
                          _isConnected
                              ? context.l10n.driveDisconnectButton
                              : context.l10n.driveConnectButton,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isConnected
                              ? AppColors.error.withValues(alpha: 0.9)
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: AppColors.warning),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              context.l10n.driveAdminOnly,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Check if the current user is the household admin/owner.
  bool _isCurrentUserOwner() {
    final householdAsync = ref.read(currentHouseholdProvider);
    final role = householdAsync.valueOrNull?['role'] as String?;
    return role == 'admin';
  }
}

/// Bold section header label.
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: context.textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppColors.textSecondaryLight,
      ),
    );
  }
}

/// A row with an icon and text, used for the "how it works" section.
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: context.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: context.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
