import 'package:equatable/equatable.dart';

/// The type of feedback submitted by the user.
enum FeedbackType {
  /// General feedback about the app.
  general,

  /// Feedback on a specific AI chat response.
  aiResponse,

  /// A bug report.
  bug,

  /// A feature request.
  featureRequest,
}

/// Rating given with feedback (optional).
enum FeedbackRating {
  positive,
  negative,
  neutral,
}

/// A single feedback entry from a user.
class FeedbackEntry extends Equatable {
  final String id;
  final String householdId;
  final FeedbackType type;
  final FeedbackRating rating;
  final String message;

  /// Optional context: screen name, chat message ID, feature name, etc.
  final String? context;
  final String createdBy;
  final DateTime createdAt;

  const FeedbackEntry({
    required this.id,
    required this.householdId,
    required this.type,
    required this.rating,
    required this.message,
    this.context,
    required this.createdBy,
    required this.createdAt,
  });

  factory FeedbackEntry.fromMap(Map<String, dynamic> map) {
    return FeedbackEntry(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      type: FeedbackType.values.firstWhere(
        (e) => e.name == (map['type'] as String? ?? 'general'),
        orElse: () => FeedbackType.general,
      ),
      rating: FeedbackRating.values.firstWhere(
        (e) => e.name == (map['rating'] as String? ?? 'neutral'),
        orElse: () => FeedbackRating.neutral,
      ),
      message: map['message'] as String? ?? '',
      context: map['context'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'type': type.name,
        'rating': rating.name,
        'message': message,
        'context': context,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, householdId, type, rating, message, context, createdAt];
}

/// An automatically captured diagnostic event (error, crash, perf metric).
class AppDiagnostic extends Equatable {
  final String id;
  final String householdId;

  /// Type of diagnostic: 'error', 'warning', 'performance', 'usage'.
  final String kind;

  /// Short summary (e.g., exception type, metric name).
  final String summary;

  /// Detailed info (stack trace, metric value, etc.).
  final String? detail;

  /// Where it happened (screen, service, function name).
  final String? source;
  final String? userId;
  final DateTime createdAt;

  const AppDiagnostic({
    required this.id,
    required this.householdId,
    required this.kind,
    required this.summary,
    this.detail,
    this.source,
    this.userId,
    required this.createdAt,
  });

  factory AppDiagnostic.fromMap(Map<String, dynamic> map) {
    return AppDiagnostic(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      kind: map['kind'] as String? ?? 'error',
      summary: map['summary'] as String? ?? '',
      detail: map['detail'] as String?,
      source: map['source'] as String?,
      userId: map['user_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'kind': kind,
        'summary': summary,
        'detail': detail,
        'source': source,
        'user_id': userId,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, householdId, kind, summary, source, createdAt];
}

/// Aggregated weekly digest summary for a household.
class WeeklyDigest extends Equatable {
  final String id;
  final String householdId;
  final DateTime weekStarting;
  final DateTime weekEnding;

  /// Stats snapshot.
  final int tasksCreated;
  final int tasksCompleted;
  final int checklistItemsChecked;
  final int plansCreated;
  final int inventoryItemsAdded;
  final int manualEntriesCreated;

  /// AI usage stats.
  final int aiChatMessages;
  final int feedbackSubmitted;
  final int errorsLogged;

  /// Optional AI-generated summary text.
  final String? summary;

  final DateTime createdAt;

  const WeeklyDigest({
    required this.id,
    required this.householdId,
    required this.weekStarting,
    required this.weekEnding,
    this.tasksCreated = 0,
    this.tasksCompleted = 0,
    this.checklistItemsChecked = 0,
    this.plansCreated = 0,
    this.inventoryItemsAdded = 0,
    this.manualEntriesCreated = 0,
    this.aiChatMessages = 0,
    this.feedbackSubmitted = 0,
    this.errorsLogged = 0,
    this.summary,
    required this.createdAt,
  });

  factory WeeklyDigest.fromMap(Map<String, dynamic> map) {
    return WeeklyDigest(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      weekStarting: DateTime.parse(map['week_starting'] as String),
      weekEnding: DateTime.parse(map['week_ending'] as String),
      tasksCreated: (map['tasks_created'] as num?)?.toInt() ?? 0,
      tasksCompleted: (map['tasks_completed'] as num?)?.toInt() ?? 0,
      checklistItemsChecked:
          (map['checklist_items_checked'] as num?)?.toInt() ?? 0,
      plansCreated: (map['plans_created'] as num?)?.toInt() ?? 0,
      inventoryItemsAdded:
          (map['inventory_items_added'] as num?)?.toInt() ?? 0,
      manualEntriesCreated:
          (map['manual_entries_created'] as num?)?.toInt() ?? 0,
      aiChatMessages: (map['ai_chat_messages'] as num?)?.toInt() ?? 0,
      feedbackSubmitted: (map['feedback_submitted'] as num?)?.toInt() ?? 0,
      errorsLogged: (map['errors_logged'] as num?)?.toInt() ?? 0,
      summary: map['summary'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'week_starting': weekStarting.toIso8601String(),
        'week_ending': weekEnding.toIso8601String(),
        'tasks_created': tasksCreated,
        'tasks_completed': tasksCompleted,
        'checklist_items_checked': checklistItemsChecked,
        'plans_created': plansCreated,
        'inventory_items_added': inventoryItemsAdded,
        'manual_entries_created': manualEntriesCreated,
        'ai_chat_messages': aiChatMessages,
        'feedback_submitted': feedbackSubmitted,
        'errors_logged': errorsLogged,
        'summary': summary,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, householdId, weekStarting, weekEnding, createdAt];
}
