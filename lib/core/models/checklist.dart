import 'package:equatable/equatable.dart';

/// A standalone checklist within a household.
class Checklist extends Equatable {
  final String id;
  final String householdId;
  final String title;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<ChecklistItem> items;

  const Checklist({
    required this.id,
    required this.householdId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Checklist.fromMap(Map<String, dynamic> map) {
    final itemList = map['checklist_items'] as List<dynamic>? ?? [];

    return Checklist(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      title: map['title'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      items: itemList
          .map((i) =>
              ChecklistItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'title': title,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  Map<String, dynamic> toDisplayMap() => {
        ...toMap(),
        'checklist_items': items.map((i) => i.toMap()).toList(),
      };

  Checklist copyWith({
    String? title,
    List<ChecklistItem>? items,
  }) {
    return Checklist(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [id, updatedAt];
}

/// A single item within a standalone checklist.
class ChecklistItem extends Equatable {
  final String id;
  final String checklistId;
  final String title;
  final String? quantity;
  final bool isChecked;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? checkedAt;
  final String? checkedBy;

  const ChecklistItem({
    required this.id,
    required this.checklistId,
    required this.title,
    this.quantity,
    this.isChecked = false,
    this.createdBy,
    this.createdAt,
    this.checkedAt,
    this.checkedBy,
  });

  factory ChecklistItem.fromMap(Map<String, dynamic> map) => ChecklistItem(
        id: map['id'] as String,
        checklistId: map['checklist_id'] as String? ?? '',
        title: map['title'] as String,
        quantity: map['quantity'] as String?,
        isChecked: map['is_checked'] as bool? ?? false,
        createdBy: map['created_by'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
        checkedAt: map['checked_at'] != null
            ? DateTime.tryParse(map['checked_at'] as String)
            : null,
        checkedBy: map['checked_by'] as String?,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'checklist_id': checklistId,
        'title': title,
        'quantity': quantity,
        'is_checked': isChecked,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
        'checked_at': checkedAt?.toIso8601String(),
        'checked_by': checkedBy,
      };

  @override
  List<Object?> get props => [id, isChecked];
}
