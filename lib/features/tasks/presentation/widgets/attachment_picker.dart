import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/data/data_repository.dart';
import '../../../../core/models/attachment.dart';
import '../../../../core/services/google_drive_service.dart';
import '../../../../core/utils/extensions.dart';

/// Bottom-sheet picker for attaching files to a task or plan entry.
///
/// Supports:
///   • Pick a file (any type via file_picker)
///   • Take a photo (camera via image_picker)
///   • Pick from gallery (images via image_picker)
///
/// On selection, uploads to the household's Google Drive folder,
/// creates the attachment record in Firestore, and returns `true`
/// on success (or `null` / `false` on cancel / failure).
class AttachmentPicker {
  AttachmentPicker._();

  /// Shows the source picker bottom sheet and returns the chosen file
  /// **without uploading** it. Useful when a task/plan does not yet exist
  /// (e.g. during task creation) and the upload must be deferred.
  ///
  /// Returns a [PickedFileInfo] on success, or `null` if cancelled.
  static Future<PickedFileInfo?> pickFileOnly(BuildContext context) async {
    final picked = await _pickFile(context);
    if (picked == null) return null;
    return PickedFileInfo(
      file: picked.file,
      fileName: picked.fileName,
      mimeType: picked.mimeType,
    );
  }

  /// Uploads a previously picked file and creates a **task** attachment record.
  ///
  /// Call this after the task has been created and you have a `taskId`.
  static Future<TaskAttachment?> uploadPickedFileForTask({
    required BuildContext context,
    required PickedFileInfo picked,
    required String taskId,
    required String householdId,
    required DataRepository repo,
    bool showOverlay = true,
  }) async {
    OverlayEntry? overlay;
    if (showOverlay && context.mounted) {
      overlay = OverlayEntry(builder: (_) => const _UploadingOverlay());
      Overlay.of(context).insert(overlay);
    }

    try {
      final internal = _PickedFile(
        file: picked.file,
        fileName: picked.fileName,
        mimeType: picked.mimeType,
      );
      final result = await _uploadToDrive(context, householdId, internal);

      final attachment = await repo.createAttachment(
        taskId: taskId,
        householdId: householdId,
        driveFileId: result.fileId,
        fileName: picked.fileName,
        mimeType: result.mimeType,
        fileSizeBytes: result.fileSizeBytes,
        thumbnailUrl: result.thumbnailLink,
        webViewLink: result.webViewLink,
      );

      overlay?.remove();
      return attachment;
    } catch (e) {
      overlay?.remove();
      if (context.mounted) {
        context.showSnackBar(
            context.l10n.attachUploadFailed(e.toString()),
            isError: true);
      }
      return null;
    }
  }

  /// Shows a bottom sheet with pick options and handles the upload flow
  /// for a **task** attachment.
  ///
  /// Returns the created [TaskAttachment] on success, or `null` if cancelled.
  static Future<TaskAttachment?> show({
    required BuildContext context,
    required String taskId,
    required String householdId,
    required DataRepository repo,
  }) async {
    final picked = await _pickFile(context);
    if (picked == null) return null;
    if (!context.mounted) return null;

    final overlay = OverlayEntry(builder: (_) => const _UploadingOverlay());
    Overlay.of(context).insert(overlay);

    try {
      final result = await _uploadToDrive(context, householdId, picked);

      final attachment = await repo.createAttachment(
        taskId: taskId,
        householdId: householdId,
        driveFileId: result.fileId,
        fileName: picked.fileName,
        mimeType: result.mimeType,
        fileSizeBytes: result.fileSizeBytes,
        thumbnailUrl: result.thumbnailLink,
        webViewLink: result.webViewLink,
      );

      overlay.remove();
      if (context.mounted) {
        context.showSnackBar(context.l10n.attachSuccess);
      }
      return attachment;
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        context.showSnackBar(
            context.l10n.attachUploadFailed(e.toString()),
            isError: true);
      }
      return null;
    }
  }

  /// Shows a bottom sheet with pick options and handles the upload flow
  /// for a **plan entry** attachment.
  ///
  /// Returns the created [PlanAttachment] on success, or `null` if cancelled.
  static Future<PlanAttachment?> showForPlanEntry({
    required BuildContext context,
    required String planId,
    required String entryId,
    required String householdId,
    required DataRepository repo,
  }) async {
    final picked = await _pickFile(context);
    if (picked == null) return null;
    if (!context.mounted) return null;

    final overlay = OverlayEntry(builder: (_) => const _UploadingOverlay());
    Overlay.of(context).insert(overlay);

    try {
      final result = await _uploadToDrive(context, householdId, picked);

      final attachment = await repo.createPlanAttachment(
        planId: planId,
        entryId: entryId,
        householdId: householdId,
        driveFileId: result.fileId,
        fileName: picked.fileName,
        mimeType: result.mimeType,
        fileSizeBytes: result.fileSizeBytes,
        thumbnailUrl: result.thumbnailLink,
        webViewLink: result.webViewLink,
      );

      overlay.remove();
      if (context.mounted) {
        context.showSnackBar(context.l10n.attachSuccess);
      }
      return attachment;
    } catch (e) {
      overlay.remove();
      if (context.mounted) {
        context.showSnackBar(
            context.l10n.attachUploadFailed(e.toString()),
            isError: true);
      }
      return null;
    }
  }

  // ── Shared helpers ──────────────────────────────────────────────

  /// Shows the source picker bottom sheet, then picks the file.
  static Future<_PickedFile?> _pickFile(BuildContext context) async {
    final source = await showModalBottomSheet<_PickSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondaryLight.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              ctx.l10n.attachTitle,
              style: ctx.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder_open_rounded),
              title: Text(ctx.l10n.attachPickFile),
              subtitle: Text(ctx.l10n.attachPickFileSubtitle),
              onTap: () => Navigator.of(ctx).pop(_PickSource.file),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: Text(ctx.l10n.attachTakePhoto),
              subtitle: Text(ctx.l10n.attachTakePhotoSubtitle),
              onTap: () => Navigator.of(ctx).pop(_PickSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(ctx.l10n.attachPickGallery),
              subtitle: Text(ctx.l10n.attachPickGallerySubtitle),
              onTap: () => Navigator.of(ctx).pop(_PickSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return null;

    File? file;
    String? fileName;
    String? mimeType;

    switch (source) {
      case _PickSource.file:
        final result = await FilePicker.platform.pickFiles();
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
          fileName = result.files.single.name;
          mimeType = lookupMimeType(fileName) ?? 'application/octet-stream';
        }
        break;

      case _PickSource.camera:
        final xFile =
            await ImagePicker().pickImage(source: ImageSource.camera);
        if (xFile != null) {
          file = File(xFile.path);
          fileName = xFile.name;
          mimeType = lookupMimeType(xFile.name) ?? 'image/jpeg';
        }
        break;

      case _PickSource.gallery:
        final xFile =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (xFile != null) {
          file = File(xFile.path);
          fileName = xFile.name;
          mimeType = lookupMimeType(xFile.name) ?? 'image/jpeg';
        }
        break;
    }

    if (file == null || fileName == null) return null;
    return _PickedFile(file: file, fileName: fileName, mimeType: mimeType!);
  }

  /// Uploads a picked file to the household's Google Drive folder.
  static Future<DriveFileResult> _uploadToDrive(
    BuildContext context,
    String householdId,
    _PickedFile picked,
  ) async {
    final configDoc = await FirebaseFirestore.instance
        .collection('household_drive_config')
        .doc(householdId)
        .get();

    if (!configDoc.exists) {
      throw Exception(context.l10n.attachDriveNotSetUp);
    }

    final config = HouseholdDriveConfig.fromMap(configDoc.data()!);
    if (!config.isEnabled || config.driveFolderId == null) {
      throw Exception(context.l10n.attachDriveDisabled);
    }

    final driveService = GoogleDriveService();
    return driveService.uploadFile(
      folderId: config.driveFolderId!,
      file: picked.file,
      fileName: picked.fileName,
      mimeType: picked.mimeType,
    );
  }
}

enum _PickSource { file, camera, gallery }

/// Public value object representing a file the user has picked but not yet
/// uploaded. Returned by [AttachmentPicker.pickFileOnly].
class PickedFileInfo {
  final File file;
  final String fileName;
  final String mimeType;

  const PickedFileInfo({
    required this.file,
    required this.fileName,
    required this.mimeType,
  });
}

class _PickedFile {
  final File file;
  final String fileName;
  final String mimeType;

  const _PickedFile({
    required this.file,
    required this.fileName,
    required this.mimeType,
  });
}

/// Semi-transparent overlay shown during file upload.
class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Center(
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  context.l10n.attachUploading,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
