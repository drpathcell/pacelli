import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/crypto/encryption_service.dart';
import '../../../core/data/data_repository.dart';
import '../../../core/data/data_repository_provider.dart';

const _kLastExportDate = 'last_export_date';

/// Service that exports household data as JSON (full backup) or CSV (tasks only).
class ExportService {
  final DataRepository _repo;

  ExportService(this._repo);

  /// Exports all household data as an encrypted JSON file and opens the share sheet.
  ///
  /// The JSON includes tasks (with subtasks), categories, checklists (with
  /// items), and plans (with entries and checklist items).
  ///
  /// The [passphrase] parameter is required and must not be empty. The export
  /// is encrypted with AES-256-CBC and includes an HMAC-SHA256 integrity tag.
  ///
  /// Data from the repository is already decrypted by the time it reaches
  /// the model layer, so no extra decryption step is needed here.
  Future<File> exportAsJson(String householdId, {required String passphrase}) async {
    // Validate passphrase is not empty
    if (passphrase.isEmpty) {
      throw ArgumentError('Passphrase cannot be empty');
    }
    final tasks = await _repo.getTasks(householdId: householdId);
    final categories = await _repo.getCategories(householdId);
    final checklists = await _repo.getChecklists(householdId);
    final plans = await _repo.getPlans(householdId);

    // Inventory data.
    final invItems = await _repo.getInventoryItems(householdId: householdId);
    final invCategories = await _repo.getInventoryCategories(householdId);
    final invLocations = await _repo.getInventoryLocations(householdId);

    // Fetch logs per item.
    final invLogs = <Map<String, dynamic>>[];
    for (final item in invItems) {
      final logs = await _repo.getInventoryLogs(itemId: item.id, householdId: householdId, limit: 500);
      invLogs.addAll(logs.map((l) => l.toMap()));
    }

    // Manual data.
    final manualEntries = await _repo.getManualEntries(householdId: householdId);
    final manualCategories = await _repo.getManualCategories(householdId);

    final export = {
      'version': 3,
      'exported_at': DateTime.now().toIso8601String(),
      'household_id': householdId,
      'tasks': tasks.map((t) => {
            ...t.toMap(),
            'subtasks': t.subtasks.map((s) => s.toMap()).toList(),
          }).toList(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'checklists': checklists.map((cl) => cl.toDisplayMap()).toList(),
      'plans': plans.map((p) => p.toDisplayMap()).toList(),
      'inventory_items': invItems.map((i) => i.toMap()).toList(),
      'inventory_categories': invCategories.map((c) => c.toMap()).toList(),
      'inventory_locations': invLocations.map((l) => l.toMap()).toList(),
      'inventory_logs': invLogs,
      'manual_entries': manualEntries.map((e) => e.toMap()).toList(),
      'manual_categories': manualCategories.map((c) => c.toMap()).toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(export);

    // Encrypt the JSON with AES-256-CBC using the passphrase
    final key = EncryptionService.deriveUserKey(passphrase);
    final encryptedData = EncryptionService.encrypt(json, key);

    // Derive a separate HMAC key from the passphrase using a different salt
    final hmacSalt = utf8.encode('pacelli_export_hmac_salt_v1');
    final hmacKey = Hmac(sha256, hmacSalt).convert(utf8.encode(passphrase));

    // Compute HMAC-SHA256 over the encrypted data
    final hmac = Hmac(sha256, hmacKey.bytes).convert(utf8.encode(encryptedData));

    // Build the export format with version, encrypted data, HMAC, and salt
    final exportedFile = {
      'version': 3,
      'encrypted': encryptedData,
      'hmac': hmac.toString(), // hex string
      'salt': base64Encode(hmacSalt),
    };

    final fileContent = const JsonEncoder.withIndent('  ').convert(exportedFile);

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/pacelli_backup_$timestamp.json.enc');
    await file.writeAsString(fileContent);

    await _saveLastExportDate();
    debugPrint('[ExportService] JSON backup saved to ${file.path}');
    return file;
  }

  /// Exports tasks as a simplified CSV file and opens the share sheet.
  ///
  /// Columns: Title, Status, Priority, Due Date, Category, Assigned To.
  Future<File> exportTasksCsv(String householdId) async {
    final tasks = await _repo.getTasks(householdId: householdId);

    final buffer = StringBuffer();
    buffer.writeln('Title,Status,Priority,Due Date,Category,Assigned To');

    for (final task in tasks) {
      buffer.writeln([
        _csvEscape(task.title),
        _csvEscape(task.status),
        _csvEscape(task.priority),
        _csvEscape(task.dueDate?.toIso8601String() ?? ''),
        _csvEscape(task.category?.name ?? ''),
        _csvEscape(task.assignedProfile?.fullName ?? task.assignedTo ?? ''),
      ].join(','));
    }

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HHmmss').format(DateTime.now());
    final file = File('${dir.path}/pacelli_tasks_$timestamp.csv');
    await file.writeAsString(buffer.toString());

    await _saveLastExportDate();
    debugPrint('[ExportService] CSV export saved to ${file.path}');
    return file;
  }

  /// Opens the native share sheet for the given file.
  Future<void> shareFile(File file) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)]),
    );
  }

  /// Returns the last export date, or null if never exported.
  static Future<DateTime?> getLastExportDate() async {
    final prefs = await SharedPreferences.getInstance();
    final iso = prefs.getString(_kLastExportDate);
    return iso != null ? DateTime.tryParse(iso) : null;
  }

  Future<void> _saveLastExportDate() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastExportDate, DateTime.now().toIso8601String());
  }

  /// Escapes a value for CSV (wraps in quotes if it contains commas/quotes/newlines).
  static String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

/// Provider for the export service.
final exportServiceProvider = Provider<ExportService>((ref) {
  final repo = ref.watch(dataRepositoryProvider);
  return ExportService(repo);
});
