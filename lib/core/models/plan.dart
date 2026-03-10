import 'package:equatable/equatable.dart';

/// A scratch plan within a household.
class Plan extends Equatable {
  final String id;
  final String householdId;
  final String title;
  final String type; // 'weekly', 'daily', 'custom'
  final String status; // 'draft', 'finalised'
  final DateTime startDate;
  final DateTime endDate;
  final bool isTemplate;
  final String? templateName;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<PlanEntry> entries;
  final List<PlanChecklistItem> checklistItems;

  const Plan({
    required this.id,
    required this.householdId,
    required this.title,
    this.type = 'weekly',
    this.status = 'draft',
    required this.startDate,
    required this.endDate,
    this.isTemplate = false,
    this.templateName,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
    this.entries = const [],
    this.checklistItems = const [],
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    final entryList = map['plan_entries'] as List<dynamic>? ?? [];
    final checklistList = map['plan_checklist_items'] as List<dynamic>? ?? [];

    return Plan(
      id: map['id'] as String,
      householdId: map['household_id'] as String,
      title: map['title'] as String,
      type: map['type'] as String? ?? 'weekly',
      status: map['status'] as String? ?? 'draft',
      startDate: DateTime.parse(map['start_date'] as String),
      endDate: DateTime.parse(map['end_date'] as String),
      isTemplate: map['is_template'] as bool? ?? false,
      templateName: map['template_name'] as String?,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'] as String)
          : null,
      entries: entryList
          .map((e) => PlanEntry.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      checklistItems: checklistList
          .map((c) =>
              PlanChecklistItem.fromMap(Map<String, dynamic>.from(c as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'household_id': householdId,
        'title': title,
        'type': type,
        'status': status,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'is_template': isTemplate,
        'template_name': templateName,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  /// Full map including nested entries/checklist for display.
  Map<String, dynamic> toDisplayMap() => {
        ...toMap(),
        'plan_entries': entries.map((e) => e.toMap()).toList(),
        'plan_checklist_items':
            checklistItems.map((c) => c.toMap()).toList(),
      };

  Plan copyWith({
    String? title,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    List<PlanEntry>? entries,
    List<PlanChecklistItem>? checklistItems,
  }) {
    return Plan(
      id: id,
      householdId: householdId,
      title: title ?? this.title,
      type: type,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isTemplate: isTemplate,
      templateName: templateName,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      entries: entries ?? this.entries,
      checklistItems: checklistItems ?? this.checklistItems,
    );
  }

  @override
  List<Object?> get props => [id, status, updatedAt];

  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// A single entry/row within a plan day.
class PlanEntry extends Equatable {
  final String id;
  final String planId;
  final DateTime entryDate;
  final String title;
  final String? label;
  final String? description;
  final int sortOrder;
  final String? createdBy;
  final DateTime? createdAt;

  const PlanEntry({
    required this.id,
    required this.planId,
    required this.entryDate,
    required this.title,
    this.label,
    this.description,
    this.sortOrder = 0,
    this.createdBy,
    this.createdAt,
  });

  factory PlanEntry.fromMap(Map<String, dynamic> map) => PlanEntry(
        id: map['id'] as String,
        planId: map['plan_id'] as String? ?? '',
        entryDate: DateTime.parse(map['entry_date'] as String),
        title: map['title'] as String,
        label: map['label'] as String?,
        description: map['description'] as String?,
        sortOrder: map['sort_order'] as int? ?? 0,
        createdBy: map['created_by'] as String?,
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'plan_id': planId,
        'entry_date': Plan._dateOnly(entryDate),
        'title': title,
        'label': label,
        'description': description,
        'sort_order': sortOrder,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };

  @override
  List<Object?> get props => [id];
}

/// A checklist item belonging to a plan (optionally linked to an entry).
class PlanChecklistItem extends Equatable {
  final String id;
  final String planId;
  final String? entryId;
  final String title;
  final String? quantity;
  final bool isChecked;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? checkedAt;
  final String? checkedBy;

  const PlanChecklistItem({
    required this.id,
    required this.planId,
    this.entryId,
    required this.title,
    this.quantity,
    this.isChecked = false,
    this.createdBy,
    this.createdAt,
    this.checkedAt,
    this.checkedBy,
  });

  factory PlanChecklistItem.fromMap(Map<String, dynamic> map) =>
      PlanChecklistItem(
        id: map['id'] as String,
        planId: map['plan_id'] as String? ?? '',
        entryId: map['entry_id'] as String?,
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
        'plan_id': planId,
        'entry_id': entryId,
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
