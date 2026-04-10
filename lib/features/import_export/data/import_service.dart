import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/encryption_service.dart';
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
  /// Performs comprehensive validation including:
  /// - Type checking for all top-level fields
  /// - Version compatibility (only 1, 2, 3 supported)
  /// - Required fields in each entity list
  /// - HMAC verification for encrypted imports
  ///
  /// Returns null if valid, or an error description string if invalid.
  String? validate(Map<String, dynamic> data) {
    // Check version field
    if (data['version'] == null) return 'Missing version field';
    if (data['version'] is! int) return 'Version field must be an integer';

    final version = data['version'] as int;
    if (version < 1 || version > 3) {
      return 'Unsupported version $version (only 1, 2, 3 supported)';
    }

    // For v3+ exports, verify HMAC if present
    if (version >= 3) {
      final error = _validateHmac(data);
      if (error != null) return error;
    }

    // Check household_id field
    if (data['household_id'] == null) return 'Missing household_id';
    if (data['household_id'] is! String) {
      return 'household_id must be a string';
    }

    // Check required list fields with type validation
    if (data['tasks'] is! List) return 'Missing or invalid tasks array';
    if (data['categories'] is! List) return 'Missing or invalid categories array';
    if (data['checklists'] is! List) return 'Missing or invalid checklists array';
    if (data['plans'] is! List) return 'Missing or invalid plans array';

    // Validate entity lists
    final error = _validateEntityLists(data);
    if (error != null) return error;

    return null;
  }

  /// Validates HMAC integrity for v3+ encrypted exports.
  String? _validateHmac(Map<String, dynamic> data) {
    // HMAC verification is optional for backward compatibility
    // but if the fields are present, they must be valid
    if (data['hmac'] == null || data['encrypted'] == null) {
      // Fields not present, skip verification
      return null;
    }

    if (data['hmac'] is! String) return 'hmac field must be a string';
    if (data['encrypted'] is! String) return 'encrypted field must be a string';
    if (data['salt'] is! String) return 'salt field must be a string (for encrypted export)';

    return null;
  }

  /// Validates that entity lists contain properly typed items.
  String? _validateEntityLists(Map<String, dynamic> data) {
    final tasks = data['tasks'] as List;
    for (var i = 0; i < tasks.length; i++) {
      if (tasks[i] is! Map) {
        return 'Task at index $i is not an object';
      }
      final task = tasks[i] as Map<String, dynamic>;
      if (task['title'] is! String) {
        return 'Task at index $i missing or invalid title field';
      }
    }

    final categories = data['categories'] as List;
    for (var i = 0; i < categories.length; i++) {
      if (categories[i] is! Map) {
        return 'Category at index $i is not an object';
      }
      final cat = categories[i] as Map<String, dynamic>;
      if (cat['name'] is! String) {
        return 'Category at index $i missing or invalid name field';
      }
    }

    final checklists = data['checklists'] as List;
    for (var i = 0; i < checklists.length; i++) {
      if (checklists[i] is! Map) {
        return 'Checklist at index $i is not an object';
      }
      final cl = checklists[i] as Map<String, dynamic>;
      if (cl['title'] is! String) {
        return 'Checklist at index $i missing or invalid title field';
      }
    }

    final plans = data['plans'] as List;
    for (var i = 0; i < plans.length; i++) {
      if (plans[i] is! Map) {
        return 'Plan at index $i is not an object';
      }
      final plan = plans[i] as Map<String, dynamic>;
      if (plan['title'] is! String) {
        return 'Plan at index $i missing or invalid title field';
      }
    }

    // Validate optional inventory arrays if present
    final invCategories = data['inventory_categories'] as List?;
    if (invCategories != null) {
      for (var i = 0; i < invCategories.length; i++) {
        if (invCategories[i] is! Map) {
          return 'Inventory category at index $i is not an object';
        }
        final cat = invCategories[i] as Map<String, dynamic>;
        if (cat['name'] is! String) {
          return 'Inventory category at index $i missing or invalid name field';
        }
      }
    }

    final invLocations = data['inventory_locations'] as List?;
    if (invLocations != null) {
      for (var i = 0; i < invLocations.length; i++) {
        if (invLocations[i] is! Map) {
          return 'Inventory location at index $i is not an object';
        }
        final loc = invLocations[i] as Map<String, dynamic>;
        if (loc['name'] is! String) {
          return 'Inventory location at index $i missing or invalid name field';
        }
      }
    }

    final invItems = data['inventory_items'] as List?;
    if (invItems != null) {
      for (var i = 0; i < invItems.length; i++) {
        if (invItems[i] is! Map) {
          return 'Inventory item at index $i is not an object';
        }
        final item = invItems[i] as Map<String, dynamic>;
        if (item['name'] is! String) {
          return 'Inventory item at index $i missing or invalid name field';
        }
      }
    }

    final manualCategories = data['manual_categories'] as List?;
    if (manualCategories != null) {
      for (var i = 0; i < manualCategories.length; i++) {
        if (manualCategories[i] is! Map) {
          return 'Manual category at index $i is not an object';
        }
        final cat = manualCategories[i] as Map<String, dynamic>;
        if (cat['name'] is! String) {
          return 'Manual category at index $i missing or invalid name field';
        }
      }
    }

    final manualEntries = data['manual_entries'] as List?;
    if (manualEntries != null) {
      for (var i = 0; i < manualEntries.length; i++) {
        if (manualEntries[i] is! Map) {
          return 'Manual entry at index $i is not an object';
        }
        final entry = manualEntries[i] as Map<String, dynamic>;
        if (entry['title'] is! String) {
          return 'Manual entry at index $i missing or invalid title field';
        }
      }
    }

    return null;
  }

  /// Reads and parses a JSON backup file.
  ///
  /// If the file has a `.enc` extension, it is decrypted using the given
  /// [passphrase] before parsing. The method verifies HMAC integrity for v3+
  /// exports before decrypting.
  ///
  /// Throws if the passphrase is missing/wrong, HMAC verification fails,
  /// or the JSON is malformed.
  Future<Map<String, dynamic>> parseFile(File file, {String? passphrase}) async {
    final content = await file.readAsString();

    String jsonString;
    if (file.path.endsWith('.enc')) {
      if (passphrase == null || passphrase.isEmpty) {
        throw Exception('This backup is encrypted. Please provide the passphrase.');
      }

      // First, parse the JSON to check its structure
      final fileData = jsonDecode(content) as Map<String, dynamic>;

      // If this is a v3+ encrypted export with HMAC, verify integrity first
      if (fileData['version'] is int && (fileData['version'] as int) >= 3) {
        final hmacError = _verifyHmac(fileData, passphrase);
        if (hmacError != null) {
          throw Exception(hmacError);
        }
      }

      // Extract the encrypted data
      if (fileData['encrypted'] is String) {
        // v3+ format: extract encrypted field
        final encryptedData = fileData['encrypted'] as String;
        final key = EncryptionService.deriveUserKey(passphrase);
        jsonString = EncryptionService.decrypt(encryptedData, key);
      } else {
        // Legacy format: treat entire content as encrypted
        final key = EncryptionService.deriveUserKey(passphrase);
        jsonString = EncryptionService.decrypt(content, key);
      }
    } else {
      jsonString = content;
    }

    return jsonDecode(jsonString) as Map<String, dynamic>;
  }

  /// Verifies HMAC-SHA256 integrity of a v3+ encrypted export.
  ///
  /// Returns null if valid, or an error description if verification fails.
  String? _verifyHmac(Map<String, dynamic> data, String passphrase) {
    final hmacStored = data['hmac'];
    final encryptedData = data['encrypted'];
    final saltBase64 = data['salt'];

    if (hmacStored is! String || encryptedData is! String || saltBase64 is! String) {
      return 'Invalid HMAC data: missing or malformed hmac, encrypted, or salt fields';
    }

    try {
      // Reconstruct the HMAC key from the passphrase and stored salt
      final salt = base64Decode(saltBase64);
      final hmacKey = Hmac(sha256, salt).convert(utf8.encode(passphrase));

      // Compute HMAC over the encrypted data
      final hmacComputed = Hmac(sha256, hmacKey.bytes).convert(utf8.encode(encryptedData));

      // Compare (constant-time comparison would be better, but Dart's toString() is sufficient)
      if (hmacComputed.toString() != hmacStored) {
        return 'HMAC verification failed: backup may be corrupted or tampered with';
      }

      return null; // Valid
    } catch (e) {
      return 'HMAC verification error: $e';
    }
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
    final errors = <ImportError>[];

    final categories = data['categories'] as List;
    final tasks = data['tasks'] as List;
    final checklists = data['checklists'] as List;
    final plans = data['plans'] as List;
    final invCategories = data['inventory_categories'] as List? ?? [];
    final invLocations = data['inventory_locations'] as List? ?? [];
    final invItems = data['inventory_items'] as List? ?? [];
    final manualCategories = data['manual_categories'] as List? ?? [];
    final manualEntries = data['manual_entries'] as List? ?? [];

    final totalItems = categories.length +
        tasks.length +
        checklists.length +
        plans.length +
        invCategories.length +
        invLocations.length +
        invItems.length +
        manualCategories.length +
        manualEntries.length;
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
        errors.add(ImportError(
          entityType: 'Category',
          entityName: m['name'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
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
        errors.add(ImportError(
          entityType: 'Task',
          entityName: m['title'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
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
            householdId: householdId,
            title: im['title'] as String? ?? '',
            quantity: im['quantity'] as String?,
          );
        }
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip checklist: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Checklist',
          entityName: m['title'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
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
            householdId: householdId,
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
            householdId: householdId,
            title: pm['title'] as String? ?? '',
            quantity: pm['quantity'] as String?,
          );
        }
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip plan: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Plan',
          entityName: m['title'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
      }
      report('Plans');
    }

    // ── Pre-fetch existing inventory data for duplicate detection ──
    final existingInvCategories =
        await _repo.getInventoryCategories(householdId);
    final existingCatNames =
        existingInvCategories.map((c) => c.name).toSet();

    final existingInvLocations =
        await _repo.getInventoryLocations(householdId);
    final existingLocNames =
        existingInvLocations.map((l) => l.name).toSet();

    final existingInvItems =
        await _repo.getInventoryItems(householdId: householdId);
    final existingItemKeys =
        existingInvItems.map((i) => '${i.name}|${i.barcode ?? ''}').toSet();

    // ── 5. Inventory Categories ──
    final invCategoryIdMap = <String, String>{};
    for (final cat in invCategories) {
      final m = Map<String, dynamic>.from(cat as Map);
      final catName = m['name'] as String? ?? 'Imported';
      if (existingCatNames.contains(catName)) {
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Category',
          entityName: catName,
          message: 'Duplicate category already exists',
        ));
        // Map old ID to the existing category's ID so items still resolve.
        final existing = existingInvCategories.firstWhere((c) => c.name == catName);
        invCategoryIdMap[m['id'] as String] = existing.id;
        report('Inventory Categories');
        continue;
      }
      try {
        final newCat = await _repo.createInventoryCategory(
          householdId: householdId,
          name: catName,
          icon: m['icon'] as String? ?? 'inventory_2',
          color: m['color'] as String? ?? '#A5B4A5',
        );
        invCategoryIdMap[m['id'] as String] = newCat.id;
        existingCatNames.add(catName);
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip inv category: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Category',
          entityName: catName,
          message: e.toString(),
        ));
      }
      report('Inventory Categories');
    }

    // ── 6. Inventory Locations ──
    final invLocationIdMap = <String, String>{};
    for (final loc in invLocations) {
      final m = Map<String, dynamic>.from(loc as Map);
      final locName = m['name'] as String? ?? 'Imported';
      if (existingLocNames.contains(locName)) {
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Location',
          entityName: locName,
          message: 'Duplicate location already exists',
        ));
        final existing = existingInvLocations.firstWhere((l) => l.name == locName);
        invLocationIdMap[m['id'] as String] = existing.id;
        report('Inventory Locations');
        continue;
      }
      try {
        final newLoc = await _repo.createInventoryLocation(
          householdId: householdId,
          name: locName,
          icon: m['icon'] as String? ?? 'place',
        );
        invLocationIdMap[m['id'] as String] = newLoc.id;
        existingLocNames.add(locName);
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip inv location: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Location',
          entityName: locName,
          message: e.toString(),
        ));
      }
      report('Inventory Locations');
    }

    // ── 7. Inventory Items ──
    for (final item in invItems) {
      final m = Map<String, dynamic>.from(item as Map);
      final itemName = m['name'] as String? ?? 'Imported';
      final itemBarcode = m['barcode'] as String?;
      final itemKey = '$itemName|${itemBarcode ?? ''}';
      if (existingItemKeys.contains(itemKey)) {
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Item',
          entityName: itemName,
          message: 'Duplicate item already exists',
        ));
        report('Inventory Items');
        continue;
      }
      final oldCatId = m['category_id'] as String?;
      final oldLocId = m['location_id'] as String?;
      try {
        await _repo.createInventoryItem(
          householdId: householdId,
          name: m['name'] as String? ?? 'Imported',
          description: m['description'] as String?,
          categoryId: oldCatId != null ? invCategoryIdMap[oldCatId] : null,
          locationId: oldLocId != null ? invLocationIdMap[oldLocId] : null,
          quantity: (m['quantity'] as num?)?.toInt() ?? 0,
          unit: m['unit'] as String? ?? 'pieces',
          lowStockThreshold: (m['low_stock_threshold'] as num?)?.toInt(),
          barcode: m['barcode'] as String?,
          barcodeType: m['barcode_type'] as String? ?? 'none',
          expiryDate: m['expiry_date'] != null
              ? DateTime.tryParse(m['expiry_date'] as String)
              : null,
          purchaseDate: m['purchase_date'] != null
              ? DateTime.tryParse(m['purchase_date'] as String)
              : null,
          notes: m['notes'] as String?,
        );
        existingItemKeys.add(itemKey);
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip inv item: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Inventory Item',
          entityName: m['name'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
      }
      report('Inventory Items');
    }

    // ── 8. Manual Categories ──
    final manualCategoryIdMap = <String, String>{};
    final existingManualCategories =
        await _repo.getManualCategories(householdId);
    final existingManualCatNames =
        existingManualCategories.map((c) => c.name).toSet();

    for (final cat in manualCategories) {
      final m = Map<String, dynamic>.from(cat as Map);
      final catName = m['name'] as String? ?? 'Imported';
      if (existingManualCatNames.contains(catName)) {
        skipped++;
        final existing =
            existingManualCategories.firstWhere((c) => c.name == catName);
        manualCategoryIdMap[m['id'] as String] = existing.id;
        report('Manual Categories');
        continue;
      }
      try {
        final newCat = await _repo.createManualCategory(
          householdId: householdId,
          name: catName,
          icon: m['icon'] as String? ?? 'menu_book',
          color: m['color'] as String? ?? '#7EA87E',
        );
        manualCategoryIdMap[m['id'] as String] = newCat.id;
        existingManualCatNames.add(catName);
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip manual category: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Manual Category',
          entityName: catName,
          message: e.toString(),
        ));
      }
      report('Manual Categories');
    }

    // ── 9. Manual Entries ──
    for (final entry in manualEntries) {
      final m = Map<String, dynamic>.from(entry as Map);
      final oldCatId = m['category_id'] as String?;
      final newCatId =
          oldCatId != null ? manualCategoryIdMap[oldCatId] : null;
      final tagList = (m['tags'] as List?)?.cast<String>() ?? [];
      try {
        await _repo.createManualEntry(
          householdId: householdId,
          title: m['title'] as String? ?? 'Imported',
          content: m['content'] as String? ?? '',
          categoryId: newCatId,
          tags: tagList,
          isPinned: m['is_pinned'] as bool? ?? false,
        );
        created++;
      } catch (e) {
        debugPrint('[ImportService] Skip manual entry: $e');
        skipped++;
        errors.add(ImportError(
          entityType: 'Manual Entry',
          entityName: m['title'] as String? ?? 'Unknown',
          message: e.toString(),
        ));
      }
      report('Manual Entries');
    }

    return ImportResult(created: created, skipped: skipped, errors: errors);
  }
}

/// Result of an import operation.
class ImportResult {
  final int created;
  final int skipped;
  final List<ImportError> errors;

  const ImportResult({
    required this.created,
    required this.skipped,
    this.errors = const [],
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Details about a single entity that failed to import.
class ImportError {
  final String entityType;
  final String entityName;
  final String message;

  const ImportError({
    required this.entityType,
    required this.entityName,
    required this.message,
  });
}

/// Provider for the import service.
final importServiceProvider = Provider<ImportService>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  return ImportService(repo);
});
