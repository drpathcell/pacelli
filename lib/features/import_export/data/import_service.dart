import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/data_repository.dart';
import '../../../core/data/data_repository_provider.dart';

/// Callback for reporting import progress (0.0 – 1.0).
typedef ImportProgressCallback = void Function(double progress, String status);

/// Service that imports household data from a Pacelli JSON backup file.
///
/// When importing into the Firebase backend, the repository's `create*`
/// methods handle encryption automatically — the imported plaintext is
/// re-encrypted before writing to Firestore.
class ImportService {
  final DataRepository _repo;

  ImportService(this._repo);

  /// Validates that the JSON file has the expected Pacelli backup structure.
  ///
  /// Returns null if valid, or an error description string if invalid.
  String? validate(Map<String, dynamic> data) {
    if (data['version'] == null) return 'Missing version field';
    if (data['household_id'] == null) return 'Missing household_id';
    if (data['tasks'] is! List) return 'Missing or invalid tasks array';
    if (data['categories'] is! List) return 'Missing or invalid categories array';
    if (data['checklists'] is! List) return 'Missing or invalid checklists array';
    if (data['plans'] is! List) return 'Missing or invalid plans array';
    return null;
  }

  /// Reads and parses a JSON backup file.
  ///
  /// Returns the parsed map, or throws if the file can't be read or parsed.
  Future<Map<String, dynamic>> parseFile(File file) async {
    final content = await file.readAsString();
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// Imports all data from a validated backup into the given household.
  ///
  /// Re-creates categories, tasks (with subtasks), checklists (with items),
  /// and plans (with entries and checklist items) via the DataRepository.
  ///
  /// The [onProgress] callback reports incremental progress.
  Future<ImportResult> importData({
    required String householdId,
    required Map<String, dynamic> data,
    ImportProgressCallback? onProgress,
  }) async {
    int created = 0;
    int skipped = 0;

    final categories = data['categories'] as List;
    final tasks = data['tasks'] as List;
    final checklists = data['checklists'] as List;
    final plans = data['plans'] as List;

    final totalItems =
        categories.length + tasks.length + checklists.length + plans.length;
    int processed = 0;

    void report(String status) {
      processed++;
      onProgress?.call(
        totalItems > 0 ? processed / totalItems : 1.0,
        status,
      );
    }

    // ── 1. Categories ──
    // Build a map of old ID → new ID so tasks can reference them.
    final categoryIdMap = <String, String>{};
    for (final cat in categories) {
      final m = Map<String, dynamic>.from(cat as Map);
      try {
        final newCat = await _repo.createCategory(
          householdId: householdId,
          name: m['name'] as String? ?? 'Imported',
          icon: m['icon'] as String? ?? 'category',
          color: m['color'] as String? ?? '#7EA87E',
        );
        categoryIdMap[m['id'] as String] = newCat.id;
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip category: $e');
        skipped++;
      }
      report('Categories');
    }

    // ── 2. Tasks ──
    for (final task in tasks) {
      final m = Map<String, dynamic>.from(task as Map);
      final subtasks = (m['subtasks'] as List?)
              ?.map((s) => (s as Map)['title'] as String)
              .toList() ??
          [];

      final oldCatId = m['category_id'] as String?;
      final newCatId = oldCatId != null ? categoryIdMap[oldCatId] : null;

      try {
        await _repo.createTask(
          householdId: householdId,
          title: m['title'] as String,
          description: m['description'] as String?,
          categoryId: newCatId,
          priority: m['priority'] as String? ?? 'medium',
          dueDate: m['due_date'] != null
              ? DateTime.tryParse(m['due_date'] as String)
              : null,
          startDate: m['start_date'] != null
              ? DateTime.tryParse(m['start_date'] as String)
              : null,
          assignedTo: m['assigned_to'] as String?,
          isShared: m['is_shared'] as bool? ?? false,
          recurrence: m['recurrence'] as String? ?? 'none',
          subtaskTitles: subtasks.isNotEmpty ? subtasks : null,
        );
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip task: $e');
        skipped++;
      }
      report('Tasks');
    }

    // ── 3. Checklists ──
    for (final cl in checklists) {
      final m = Map<String, dynamic>.from(cl as Map);
      try {
        final newChecklist = await _repo.createChecklist(
          householdId: householdId,
          title: m['title'] as String? ?? 'Imported',
        );

        final items = m['checklist_items'] as List? ?? [];
        for (final item in items) {
          final im = Map<String, dynamic>.from(item as Map);
          await _repo.addChecklistItem(
            checklistId: newChecklist.id,
            title: im['title'] as String? ?? '',
            quantity: im['quantity'] as String?,
          );
        }
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip checklist: $e');
        skipped++;
      }
      report('Checklists');
    }

    // ── 4. Plans ──
    for (final plan in plans) {
      final m = Map<String, dynamic>.from(plan as Map);
      try {
        final newPlan = await _repo.createPlan(
          householdId: householdId,
          title: m['title'] as String? ?? 'Imported Plan',
          type: m['type'] as String? ?? 'weekly',
          startDate: DateTime.parse(m['start_date'] as String),
          endDate: DateTime.parse(m['end_date'] as String),
        );

        // Plan entries
        final entries = m['plan_entries'] as List? ?? [];
        for (final entry in entries) {
          final em = Map<String, dynamic>.from(entry as Map);
          await _repo.addEntry(
            planId: newPlan.id,
            entryDate: DateTime.parse(em['entry_date'] as String),
            title: em['title'] as String? ?? '',
            label: em['label'] as String?,
            description: em['description'] as String?,
            sortOrder: em['sort_order'] as int? ?? 0,
          );
        }

        // Plan checklist items
        final planItems = m['plan_checklist_items'] as List? ?? [];
        for (final pi in planItems) {
          final pm = Map<String, dynamic>.from(pi as Map);
          await _repo.addPlanChecklistItem(
            planId: newPlan.id,
            title: pm['title'] as String? ?? '',
            quantity: pm['quantity'] as String?,
          );
        }
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip plan: $e');
        skipped++;
      }
      report('Plans');
    }

    return ImportResult(created: created, skipped: skipped);
  }
}

/// Result of an import operation.
class ImportResult {
  final int created;
  final int skipped;

  const ImportResult({required this.created, required this.skipped});
}

/// Provider for the import service.
final importServiceProvider = Provider<ImportService>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  return ImportService(repo);
});
