import 'package:equatable/equatable.dart';

import 'task.dart'; // for ProfileRef

/// A category/section in the household manual (e.g. "Recipes", "Appliances").
class ManualCategory extends Equatable {
  final String id;
  final String householdId;
  final String name;
  final String icon;
  final String color;
  final int sortOrder;
  final String createdBy;
  final DateTime createdAt;

  const ManualCategory({
    required this.id,
    required this.householdId,
    required this.name,
    this.icon = 'menu_book',
    this.color = '#7EA87E',
    this.sortOrder = 0,
    required this.createdBy,
    required this.createdAt,
  });

  factory ManualCategory.fromMap(Map<String, dynamic> map) {
    return ManualCategory(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      name: map['name'] as String,
      icon: map['icon'] as String? ?? 'menu_book',
      color: map['color'] as String? ?? '#7EA87E',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'name': name,
        'icon': icon,
        'color': color,
        'sort_order': sortOrder,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [id, householdId, name, icon, color, sortOrder];
}

/// A single entry/page in the household manual.
///
/// Content is stored as Markdown for rich formatting (headings, lists,
/// bold/italic, links, images). The app renders it with a Markdown widget.
class ManualEntry extends Equatable {
  final String id;
  final String householdId;
  final String title;
  final String content; // Markdown
  final String? categoryId;
  final List<String> tags;
  final bool isPinned;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastEditedBy;

  // Joined / denormalized fields
  final ManualCategory? category;
  final ProfileRef? creatorProfile;
  final ProfileRef? editorProfile;

  const ManualEntry({
    required this.id,
    required this.householdId,
    required this.title,
    this.content = '',
    this.categoryId,
    this.tags = const [],
    this.isPinned = false,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastEditedBy,
    this.category,
    this.creatorProfile,
    this.editorProfile,
  });

  factory ManualEntry.fromMap(Map<String, dynamic> map) {
    final categoryMap =
        map['manual_categories'] as Map<String, dynamic>?;
    final creatorMap = map['creator'] as Map<String, dynamic>?;
    final editorMap = map['editor'] as Map<String, dynamic>?;
    final tagList = map['tags'] as List<dynamic>? ?? [];

    return ManualEntry(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      title: map['title'] as String,
      content: map['content'] as String? ?? '',
      categoryId: map['category_id'] as String?,
      tags: tagList.cast<String>(),
      isPinned: map['is_pinned'] as bool? ?? false,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastEditedBy: map['last_edited_by'] as String?,
      category: categoryMap != null
          ? ManualCategory.fromMap(categoryMap)
          : null,
      creatorProfile: creatorMap != null
          ? ProfileRef(
              id: creatorMap['uid'] as String? ?? creatorMap['id'] as String? ?? '',
              fullName: creatorMap['display_name'] as String? ?? creatorMap['full_name'] as String?,
            )
          : null,
      editorProfile: editorMap != null
          ? ProfileRef(
              id: editorMap['uid'] as String? ?? editorMap['id'] as String? ?? '',
              fullName: editorMap['display_name'] as String? ?? editorMap['full_name'] as String?,
            )
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'title': title,
        'content': content,
        'category_id': categoryId,
        'tags': tags,
        'is_pinned': isPinned,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_edited_by': lastEditedBy,
      };

  ManualEntry copyWith({
    String? title,
    String? content,
    String? categoryId,
    List<String>? tags,
    bool? isPinned,
    DateTime? updatedAt,
    String? lastEditedBy,
    ManualCategory? category,
  }) {
    return ManualEntry(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      content: content ?? this.content,
      categoryId: categoryId ?? this.categoryId,
      tags: tags ?? this.tags,
      isPinned: isPinned ?? this.isPinned,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastEditedBy: lastEditedBy ?? this.lastEditedBy,
      category: category ?? this.category,
      creatorProfile: creatorProfile,
      editorProfile: editorProfile,
    );
  }

  @override
  List<Object?> get props => [id, householdId, title, content, categoryId,
      tags, isPinned, createdAt, updatedAt];
}
