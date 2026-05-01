import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/routes/app_router.dart';

/// Shared post-auth navigation helper.
///
/// All sign-in / sign-up flows (email, Google, Apple) must call this instead
/// of `context.go(AppRoutes.home)` directly. It checks whether the user has
/// already chosen a storage backend and routes to either the
/// [StorageSetupScreen] (first-time, before any data has been written) or
/// straight to home (returning user).
///
/// Why this matters: bypassing the picker silently defaults the user to
/// Cloud Sync, hiding the On-Device backend option entirely. That's a
/// regression from the dual-backend architecture documented in CLAUDE.md.
/// Build 11 audit (2026-05-01) caught this — A1 finding.
Future<void> goAfterAuth(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final backend = prefs.getString('storage_backend');
  if (!context.mounted) return;
  if (backend == null) {
    context.go(AppRoutes.storageSetup);
  } else {
    context.go(AppRoutes.home);
  }
}
