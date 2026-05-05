import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app.dart';
import 'core/data/data_repository_provider.dart';
import 'core/data/local_database.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

/// Entry point for the Pacelli app.
///
/// Initialises Firebase, checks the user's storage preference, and if they
/// previously chose "local" opens the SQLite database before launching.
void main() async {
  // Ensure Flutter bindings are initialised before async work.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Firebase (reads GoogleService-Info.plist / google-services.json).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Check if the user previously chose local storage — if so, open the DB
  // now so the provider is ready before the first frame.
  Database? localDb;
  final prefs = await SharedPreferences.getInstance();
  final backend = prefs.getString('storage_backend');
  if (backend == 'local') {
    localDb = await LocalDatabase.open();
  }

  // Initialise local notifications.
  final notificationService = NotificationService();
  await notificationService.init();

  // Clear orphaned notifications on first launch after install/reinstall.
  final isFirstLaunch = prefs.getBool('notifications_initialised') ?? true;
  if (isFirstLaunch) {
    await notificationService.cancelAll();
    await prefs.setBool('notifications_initialised', true);
  }

  // Create a provider container so we can seed the local DB provider.
  final container = ProviderContainer(
    overrides: [
      if (localDb != null)
        localDatabaseProvider.overrideWith((ref) => localDb),
      notificationServiceProvider.overrideWithValue(notificationService),
    ],
  );

  // ── Crashlytics breadcrumb wiring ──
  // When `firebase_crashlytics` lands (App Store route Phase 1.5), uncomment
  // the two lines below. Every diagnostics line written via
  // `_log()` / `ref.read(diagnosticsBufferProvider).log()` will then be
  // attached as a Crashlytics breadcrumb, so production crashes arrive
  // with the full burn / sync / migration trail already in the report.
  //
  // import 'core/diagnostics/diagnostics_buffer.dart';
  // import 'package:firebase_crashlytics/firebase_crashlytics.dart';
  // container
  //     .read(diagnosticsBufferProvider)
  //     .setCrashlyticsHook(FirebaseCrashlytics.instance.log);

  // Launch the app wrapped in Riverpod's UncontrolledProviderScope.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PacelliApp(),
    ),
  );
}
