import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/crypto/encryption_service.dart';
import '../../../core/crypto/key_manager.dart';
import '../../../core/models/models.dart';

const _uuid = Uuid();

/// Service for submitting feedback, logging diagnostics, and fetching
/// weekly digests. Uses Firestore directly (like HouseholdService) because
/// feedback/diagnostics are infrastructure concerns, not household data
/// stored through the DataRepository abstraction.
class FeedbackService {
  final FirebaseFirestore _db;
  final KeyManager _keyManager;
  final String? _householdId;

  FeedbackService({
    FirebaseFirestore? firestore,
    required KeyManager keyManager,
    String? householdId,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _keyManager = keyManager,
        _householdId = householdId;

  // ═══════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  String? _getHouseholdId() => _householdId;

  Future<String?> _getKey(String householdId) async {
    try {
      return await _keyManager.loadHouseholdKey(householdId);
    } catch (_) {
      return null;
    }
  }

  String _enc(String plaintext, String key) =>
      EncryptionService.encrypt(plaintext, key);

  String _dec(String ciphertext, String key) =>
      EncryptionService.decrypt(ciphertext, key);

  String? _decN(String? ciphertext, String key) =>
      ciphertext != null ? EncryptionService.decrypt(ciphertext, key) : null;

  // ═══════════════════════════════════════════════════════════════════
  //  FEEDBACK
  // ═══════════════════════════════════════════════════════════════════

  /// Submits user feedback. Encrypts message and context.
  Future<FeedbackEntry> submitFeedback({
    required FeedbackType type,
    required FeedbackRating rating,
    required String message,
    String? context,
  }) async {
    final uid = _uid;
    final householdId = _getHouseholdId();
    if (uid == null || householdId == null) {
      throw Exception('User or household not available');
    }

    final key = await _getKey(householdId);
    final id = _uuid.v4();
    final now = DateTime.now();

    final doc = {
      'id': id,
      'household_id': householdId,
      'type': type.name,
      'rating': rating.name,
      'message': key != null ? _enc(message, key) : message,
      'context': context != null && key != null ? _enc(context, key) : context,
      'created_by': uid,
      'created_at': now.toIso8601String(),
    };

    await _db.collection('feedback').doc(id).set(doc);
    debugPrint('[FeedbackService] Submitted feedback $id');

    return FeedbackEntry(
      id: id,
      householdId: householdId,
      type: type,
      rating: rating,
      message: message,
      context: context,
      createdBy: uid,
      createdAt: now,
    );
  }

  /// Fetches all feedback for the current household.
  Future<List<FeedbackEntry>> getFeedback({int limit = 50}) async {
    final householdId = _getHouseholdId();
    if (householdId == null) return [];

    final key = await _getKey(householdId);
    final snap = await _db
        .collection('feedback')
        .where('household_id', isEqualTo: householdId)
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return FeedbackEntry(
        id: data['id'] as String,
        householdId: data['household_id'] as String,
        type: FeedbackType.values.firstWhere(
          (e) => e.name == (data['type'] as String? ?? 'general'),
          orElse: () => FeedbackType.general,
        ),
        rating: FeedbackRating.values.firstWhere(
          (e) => e.name == (data['rating'] as String? ?? 'neutral'),
          orElse: () => FeedbackRating.neutral,
        ),
        message:
            key != null ? _dec(data['message'] as String, key) : data['message'] as String? ?? '',
        context:
            key != null ? _decN(data['context'] as String?, key) : data['context'] as String?,
        createdBy: data['created_by'] as String,
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DIAGNOSTICS
  // ═══════════════════════════════════════════════════════════════════

  /// Logs a diagnostic event (error, warning, performance metric, etc.).
  /// This is fire-and-forget — it silently swallows errors.
  Future<void> logDiagnostic({
    required String kind,
    required String summary,
    String? detail,
    String? source,
  }) async {
    try {
      final uid = _uid;
      final householdId = _getHouseholdId();
      if (householdId == null) return;

      final key = await _getKey(householdId);
      final id = _uuid.v4();
      final now = DateTime.now();

      final doc = {
        'id': id,
        'household_id': householdId,
        'kind': kind,
        'summary': key != null ? _enc(summary, key) : summary,
        'detail': detail != null && key != null ? _enc(detail, key) : detail,
        'source': source,
        'user_id': uid,
        'created_at': now.toIso8601String(),
      };

      await _db.collection('diagnostics').doc(id).set(doc);
    } catch (e) {
      debugPrint('[FeedbackService] Failed to log diagnostic: $e');
    }
  }

  /// Fetches recent diagnostics for the household.
  Future<List<AppDiagnostic>> getDiagnostics({
    int limit = 100,
    String? kind,
  }) async {
    final householdId = _getHouseholdId();
    if (householdId == null) return [];

    final key = await _getKey(householdId);
    Query<Map<String, dynamic>> query = _db
        .collection('diagnostics')
        .where('household_id', isEqualTo: householdId);

    if (kind != null) {
      query = query.where('kind', isEqualTo: kind);
    }

    final snap = await query
        .orderBy('created_at', descending: true)
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return AppDiagnostic(
        id: data['id'] as String,
        householdId: data['household_id'] as String,
        kind: data['kind'] as String? ?? 'error',
        summary: key != null
            ? _dec(data['summary'] as String, key)
            : data['summary'] as String? ?? '',
        detail: key != null
            ? _decN(data['detail'] as String?, key)
            : data['detail'] as String?,
        source: data['source'] as String?,
        userId: data['user_id'] as String?,
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  WEEKLY DIGESTS
  // ═══════════════════════════════════════════════════════════════════

  /// Fetches all weekly digests for the household, most recent first.
  Future<List<WeeklyDigest>> getDigests({int limit = 12}) async {
    final householdId = _getHouseholdId();
    if (householdId == null) return [];

    final snap = await _db
        .collection('weekly_digests')
        .where('household_id', isEqualTo: householdId)
        .orderBy('week_starting', descending: true)
        .limit(limit)
        .get();

    final key = await _getKey(householdId);

    return snap.docs.map((doc) {
      final data = doc.data();
      return WeeklyDigest(
        id: data['id'] as String,
        householdId: data['household_id'] as String,
        weekStarting: DateTime.parse(data['week_starting'] as String),
        weekEnding: DateTime.parse(data['week_ending'] as String),
        tasksCreated: (data['tasks_created'] as num?)?.toInt() ?? 0,
        tasksCompleted: (data['tasks_completed'] as num?)?.toInt() ?? 0,
        checklistItemsChecked:
            (data['checklist_items_checked'] as num?)?.toInt() ?? 0,
        plansCreated: (data['plans_created'] as num?)?.toInt() ?? 0,
        inventoryItemsAdded:
            (data['inventory_items_added'] as num?)?.toInt() ?? 0,
        manualEntriesCreated:
            (data['manual_entries_created'] as num?)?.toInt() ?? 0,
        aiChatMessages: (data['ai_chat_messages'] as num?)?.toInt() ?? 0,
        feedbackSubmitted:
            (data['feedback_submitted'] as num?)?.toInt() ?? 0,
        errorsLogged: (data['errors_logged'] as num?)?.toInt() ?? 0,
        summary: key != null
            ? _decN(data['summary'] as String?, key)
            : data['summary'] as String?,
        createdAt: DateTime.parse(data['created_at'] as String),
      );
    }).toList();
  }
}
