import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/models/attachment.dart';
import '../../../../core/utils/attachment_helpers.dart';
import '../../../../core/utils/extensions.dart';

/// Lightweight value object that both [TaskAttachment] and [PlanAttachment]
/// can be converted into, so a single list widget handles both.
class AttachmentDisplayItem {
  final String id;
  final String fileName;
  final String mimeType;
  final int fileSizeBytes;
  final String webViewLink;

  const AttachmentDisplayItem({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    required this.webViewLink,
  });

  factory AttachmentDisplayItem.fromTask(TaskAttachment att) {
    return AttachmentDisplayItem(
      id: att.id,
      fileName: att.fileName,
      mimeType: att.mimeType,
      fileSizeBytes: att.fileSizeBytes,
      webViewLink: att.webViewLink,
    );
  }

  factory AttachmentDisplayItem.fromPlan(PlanAttachment att) {
    return AttachmentDisplayItem(
      id: att.id,
      fileName: att.fileName,
      mimeType: att.mimeType,
      fileSizeBytes: att.fileSizeBytes,
      webViewLink: att.webViewLink,
    );
  }
}

/// Displays a list of file attachments.
///
/// Works with both task and plan attachments via [AttachmentDisplayItem].
/// Each item shows the file icon, name, size, and type. Tapping opens
/// the file in the browser via the Google Drive shareable link.
/// The [onDelete] callback is only shown if non-null (owner/admin only).
class AttachmentList extends StatelessWidget {
  final List<AttachmentDisplayItem> attachments;
  final void Function(AttachmentDisplayItem)? onDelete;

  const AttachmentList({
    super.key,
    required this.attachments,
    this.onDelete,
  });

  Future<void> _openAttachment(
      BuildContext context, AttachmentDisplayItem att) async {
    final uri = Uri.tryParse(att.webViewLink);
    if (uri == null) {
      context.showSnackBar(context.l10n.attachInvalidLink, isError: true);
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        context.showSnackBar(context.l10n.attachCouldNotOpen, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file_rounded,
                size: 18, color: AppColors.textSecondaryLight),
            const SizedBox(width: 6),
            Text(
              context.l10n.attachCount(attachments.length),
              style: context.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...attachments.map((att) => _AttachmentTile(
              attachment: att,
              onTap: () => _openAttachment(context, att),
              onDelete: onDelete != null ? () => onDelete!(att) : null,
            )),
      ],
    );
  }
}

class _AttachmentTile extends StatelessWidget {
  final AttachmentDisplayItem attachment;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _AttachmentTile({
    required this.attachment,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AttachmentHelpers.iconForMimeType(attachment.mimeType);
    final color = AttachmentHelpers.colorForMimeType(attachment.mimeType);
    final sizeLabel = AttachmentHelpers.formatFileSize(attachment.fileSizeBytes);
    final typeLabel = AttachmentHelpers.fileTypeLabel(attachment.mimeType);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // File icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),

              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$typeLabel · $sizeLabel',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),

              // Delete button (if allowed)
              if (onDelete != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.textSecondaryLight,
                  onPressed: onDelete,
                  tooltip: context.l10n.attachRemoveTooltip,
                ),

              // Open indicator
              Icon(Icons.open_in_new_rounded,
                  size: 16, color: AppColors.textSecondaryLight),
            ],
          ),
        ),
      ),
    );
  }
}
