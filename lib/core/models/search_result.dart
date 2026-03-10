import 'package:equatable/equatable.dart';

/// A single result from a global household search.
class SearchResult extends Equatable {
  final String id;

  /// One of: 'task', 'checklist', 'plan', 'attachment'.
  final String entityType;

  final String householdId;
  final String title;

  /// Optional context line (e.g. parent checklist name, task description snippet).
  final String? subtitle;

  /// Parent entity ID for nested items (checklist items → checklist, attachments → task/plan).
  final String? parentId;

  /// Arbitrary extra data for navigation or display.
  final Map<String, dynamic> metadata;

  /// Used for sorting results by relevance date (due date, created date, etc.).
  final DateTime? relevanceDate;

  const SearchResult({
    required this.id,
    required this.entityType,
    required this.householdId,
    required this.title,
    this.subtitle,
    this.parentId,
    this.metadata = const {},
    this.relevanceDate,
  });

  factory SearchResult.fromMap(Map<String, dynamic> map) => SearchResult(
        id: map['id'] as String,
        entityType: map['entity_type'] as String,
        householdId: map['household_id'] as String,
        title: map['title'] as String,
        subtitle: map['subtitle'] as String?,
        parentId: map['parent_id'] as String?,
        metadata: Map<String, dynamic>.from(
            map['metadata'] as Map<String, dynamic>? ?? {}),
        relevanceDate: map['relevance_date'] != null
            ? DateTime.tryParse(map['relevance_date'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'entity_type': entityType,
        'household_id': householdId,
        'title': title,
        'subtitle': subtitle,
        'parent_id': parentId,
        'metadata': metadata,
        'relevance_date': relevanceDate?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, entityType];
}
