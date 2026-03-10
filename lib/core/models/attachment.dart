import 'package:equatable/equatable.dart';

/// A file attachment associated with a task.
///
/// The actual file lives in the household owner's Google Drive.
/// Metadata (file name, description) is E2E encrypted in Firestore.
class TaskAttachment extends Equatable {
  final String id;
  final String taskId;
  final String householdId;
  final String driveFileId;
  final String fileName; // encrypted in Firestore
  final String mimeType;
  final int fileSizeBytes;
  final String? thumbnailUrl;
  final String webViewLink;
  final String uploadedBy; // user ID
  final DateTime uploadedAt;
  final String? description; // encrypted in Firestore

  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.householdId,
    required this.driveFileId,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.thumbnailUrl,
    required this.webViewLink,
    required this.uploadedBy,
    required this.uploadedAt,
    this.description,
  });

  /// Creates a TaskAttachment from a data map.
  factory TaskAttachment.fromMap(Map<String, dynamic> map) {
    return TaskAttachment(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      householdId: map['household_id'] as String,
      driveFileId: map['drive_file_id'] as String,
      fileName: map['file_name'] as String,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnail_url'] as String?,
      webViewLink: map['web_view_link'] as String,
      uploadedBy: map['uploaded_by'] as String,
      uploadedAt: map['uploaded_at'] is DateTime
          ? map['uploaded_at'] as DateTime
          : DateTime.parse(map['uploaded_at'] as String),
      description: map['description'] as String?,
    );
  }

  /// Converts to a map for Firestore / SQLite storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'task_id': taskId,
        'household_id': householdId,
        'drive_file_id': driveFileId,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'thumbnail_url': thumbnailUrl,
        'web_view_link': webViewLink,
        'uploaded_by': uploadedBy,
        'uploaded_at': uploadedAt.toIso8601String(),
        'description': description,
      };

  TaskAttachment copyWith({
    String? id,
    String? taskId,
    String? householdId,
    String? driveFileId,
    String? fileName,
    String? mimeType,
    int? fileSizeBytes,
    String? thumbnailUrl,
    String? webViewLink,
    String? uploadedBy,
    DateTime? uploadedAt,
    String? description,
  }) {
    return TaskAttachment(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      householdId: householdId ?? this.householdId,
      driveFileId: driveFileId ?? this.driveFileId,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      webViewLink: webViewLink ?? this.webViewLink,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        householdId,
        driveFileId,
        fileName,
        mimeType,
        fileSizeBytes,
        thumbnailUrl,
        webViewLink,
        uploadedBy,
        uploadedAt,
        description,
      ];
}

/// A file attachment associated with a plan entry.
///
/// Same storage model as [TaskAttachment] (file in Drive, metadata encrypted
/// in Firestore) but keyed on `planId` + `entryId` instead of `taskId`.
class PlanAttachment extends Equatable {
  final String id;
  final String planId;
  final String entryId;
  final String householdId;
  final String driveFileId;
  final String fileName; // encrypted in Firestore
  final String mimeType;
  final int fileSizeBytes;
  final String? thumbnailUrl;
  final String webViewLink;
  final String uploadedBy; // user ID
  final DateTime uploadedAt;
  final String? description; // encrypted in Firestore

  const PlanAttachment({
    required this.id,
    required this.planId,
    required this.entryId,
    required this.householdId,
    required this.driveFileId,
    required this.fileName,
    required this.mimeType,
    required this.fileSizeBytes,
    this.thumbnailUrl,
    required this.webViewLink,
    required this.uploadedBy,
    required this.uploadedAt,
    this.description,
  });

  factory PlanAttachment.fromMap(Map<String, dynamic> map) {
    return PlanAttachment(
      id: map['id'] as String,
      planId: map['plan_id'] as String,
      entryId: map['entry_id'] as String,
      householdId: map['household_id'] as String,
      driveFileId: map['drive_file_id'] as String,
      fileName: map['file_name'] as String,
      mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      thumbnailUrl: map['thumbnail_url'] as String?,
      webViewLink: map['web_view_link'] as String,
      uploadedBy: map['uploaded_by'] as String,
      uploadedAt: map['uploaded_at'] is DateTime
          ? map['uploaded_at'] as DateTime
          : DateTime.parse(map['uploaded_at'] as String),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'plan_id': planId,
        'entry_id': entryId,
        'household_id': householdId,
        'drive_file_id': driveFileId,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size_bytes': fileSizeBytes,
        'thumbnail_url': thumbnailUrl,
        'web_view_link': webViewLink,
        'uploaded_by': uploadedBy,
        'uploaded_at': uploadedAt.toIso8601String(),
        'description': description,
      };

  @override
  List<Object?> get props => [
        id,
        planId,
        entryId,
        householdId,
        driveFileId,
        fileName,
        mimeType,
        fileSizeBytes,
        thumbnailUrl,
        webViewLink,
        uploadedBy,
        uploadedAt,
        description,
      ];
}

/// Configuration for a household's Google Drive integration.
class HouseholdDriveConfig extends Equatable {
  final String householdId;
  final String ownerId;
  final String driveFolderId;
  final bool isEnabled;
  final DateTime createdAt;

  const HouseholdDriveConfig({
    required this.householdId,
    required this.ownerId,
    required this.driveFolderId,
    required this.isEnabled,
    required this.createdAt,
  });

  factory HouseholdDriveConfig.fromMap(Map<String, dynamic> map) {
    return HouseholdDriveConfig(
      householdId: map['household_id'] as String,
      ownerId: map['owner_id'] as String,
      driveFolderId: map['drive_folder_id'] as String,
      isEnabled: map['is_enabled'] as bool? ?? false,
      createdAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'household_id': householdId,
        'owner_id': ownerId,
        'drive_folder_id': driveFolderId,
        'is_enabled': isEnabled,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [householdId, ownerId, driveFolderId, isEnabled, createdAt];
}
