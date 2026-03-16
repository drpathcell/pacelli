import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/crypto/key_manager.dart';
import '../../../core/models/models.dart';
import '../../household/data/household_providers.dart';
import 'feedback_service.dart';

/// Provides the [FeedbackService], scoped to the current household.
final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final keyManager = ref.watch(keyManagerProvider);
  final household = ref.watch(currentHouseholdProvider).valueOrNull;
  final householdId = (household?['household'] as Map<String, dynamic>?)?['id'] as String?;
  return FeedbackService(keyManager: keyManager, householdId: householdId);
});

/// Fetches all feedback for the current household.
final feedbackListProvider =
    FutureProvider.autoDispose<List<FeedbackEntry>>((ref) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.getFeedback();
});

/// Fetches recent diagnostics for the current household.
final diagnosticsProvider =
    FutureProvider.autoDispose<List<AppDiagnostic>>((ref) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.getDiagnostics();
});

/// Fetches weekly digests for the current household.
final weeklyDigestsProvider =
    FutureProvider.autoDispose<List<WeeklyDigest>>((ref) async {
  final service = ref.watch(feedbackServiceProvider);
  return service.getDigests();
});
