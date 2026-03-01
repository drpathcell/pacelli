import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/constants/app_constants.dart';

/// Entry point for the Pacelli app.
///
/// Initialises Supabase and wraps the app in a Riverpod [ProviderScope]
/// so that state management is available throughout the widget tree.
void main() async {
  // Ensure Flutter bindings are initialised before async work.
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Supabase with your project credentials.
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  // Launch the app wrapped in Riverpod's ProviderScope.
  runApp(
    const ProviderScope(
      child: PacelliApp(),
    ),
  );
}
