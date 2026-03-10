import 'package:flutter/material.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';

/// Privacy & Encryption transparency screen.
///
/// Plain-language explanation of what is and isn't encrypted, and why.
/// Accessible from Settings → "Privacy & Encryption".
class PrivacyEncryptionScreen extends StatelessWidget {
  const PrivacyEncryptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.privacyTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Hero banner ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.colorScheme.primary.withValues(alpha: 0.08),
                  context.colorScheme.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.shield_rounded,
                    size: 32,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.privacyE2ETitle,
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.privacyE2ESubtitle,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Section 1: How your data is protected ──
          _SectionHeader(title: context.l10n.privacyHowProtected),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.success,
            text: context.l10n.privacyAllContent,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.visibility_off_outlined,
            iconColor: AppColors.success,
            text: context.l10n.privacyOnlyYou,
          ),

          const SizedBox(height: 28),

          // ── Section 2: What IS encrypted ──
          _SectionHeader(title: context.l10n.privacyWhatEncrypted),
          const SizedBox(height: 12),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyTaskTitles,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacySubtaskTitles,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyChecklistTitles,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyPlanTitles,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyCategoryNames,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyHouseholdName,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyDisplayName,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyAttachmentNames,
          ),
          _EncryptedFieldTile(
            icon: Icons.lock_rounded,
            iconColor: AppColors.success,
            label: context.l10n.privacyAttachmentMetadata,
          ),

          const SizedBox(height: 28),

          // ── Section 3: What is NOT encrypted ──
          _SectionHeader(title: context.l10n.privacyWhatNotEncrypted),
          const SizedBox(height: 12),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacyTaskStatus,
          ),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacyPriorityLevels,
          ),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacyDueDates,
          ),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacyCheckedStatus,
          ),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacySortOrder,
          ),
          _EncryptedFieldTile(
            icon: Icons.info_outline_rounded,
            iconColor: Colors.orange.shade700,
            label: context.l10n.privacyCategoryIcons,
          ),

          const SizedBox(height: 28),

          // ── Section: File attachments ──
          _SectionHeader(title: context.l10n.privacyFileAttachments),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.cloud_outlined,
            iconColor: AppColors.info,
            text: context.l10n.privacyDriveExplanation,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.folder_shared_outlined,
            iconColor: AppColors.info,
            text: context.l10n.privacyDriveAccess,
          ),

          const SizedBox(height: 28),

          // ── Section 4: Why some fields aren't encrypted ──
          _SectionHeader(title: context.l10n.privacyWhyNotEncrypted),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.help_outline_rounded,
            iconColor: context.colorScheme.primary,
            text: context.l10n.privacyWhyExplanation,
          ),

          const SizedBox(height: 28),

          // ── Section 5: Your data, your control ──
          _SectionHeader(title: context.l10n.privacyYourControl),
          const SizedBox(height: 12),
          _InfoCard(
            icon: Icons.delete_forever_outlined,
            iconColor: Colors.red.shade600,
            text: context.l10n.privacyDeleteAll,
          ),
          const SizedBox(height: 8),
          _InfoCard(
            icon: Icons.devices_rounded,
            iconColor: context.colorScheme.primary,
            text: context.l10n.privacyKeyGeneration,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Helper widgets ──────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: context.textTheme.bodySmall?.copyWith(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EncryptedFieldTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _EncryptedFieldTile({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
