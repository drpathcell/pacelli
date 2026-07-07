import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes/app_router.dart';
import '../../../../core/data/data_repository_provider.dart';
import '../../../../core/utils/extensions.dart';
import '../../../household/data/household_service.dart';

/// Enters guest mode with zero setup — App Store Guideline 5.1.1(v).
///
/// Builds 24 and 25 were rejected because reaching any feature required
/// registration or household setup. Guests must be able to use core features
/// (tasks, inventory, plans, manual) without entering personal information.
///
/// Signs in anonymously, then lands the user straight on Home with a ready
/// household — no storage-setup screen, no "create a household" wall:
///   1. Anonymous auth (no personal data collected).
///   2. Silently selects the cloud backend for the session. Anonymous data
///      lives under the anonymous uid and upgrades in place if the guest later
///      creates a real account (Apple/Google/email) via linkWithCredential.
///   3. Auto-provisions a default household when the user has none, so every
///      feature is immediately usable.
///
/// Throws on failure (anonymous auth disabled, offline, etc.); callers show a
/// friendly message and keep the user on the auth screen.
Future<void> enterGuestMode(BuildContext context) async {
  // Capture the localized default name before the first async gap.
  final defaultHouseholdName = context.l10n.homeMyHousehold;

  // 1. Anonymous auth — no registration, no personal info.
  await FirebaseAuth.instance.signInAnonymously();

  // 2. Select the cloud backend for this guest session.
  await saveStorageBackend('firebase');

  // 3. Ensure a usable household exists so the app is never gated behind setup.
  final existing = await HouseholdService.getCurrentHousehold();
  if (existing == null) {
    await HouseholdService.createHousehold(defaultHouseholdName);
  }

  if (!context.mounted) return;
  context.go(AppRoutes.home);
}
