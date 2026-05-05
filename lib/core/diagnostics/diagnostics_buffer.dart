import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory rolling diagnostics buffer for failure flows.
///
/// Any flow that may fail in a way the user benefits from being able to
/// copy-paste into a support email writes breadcrumbs here via [log].
/// The failure UI then surfaces the buffer contents.
///
/// The first consumer is the burn-all-data flow; future consumers
/// (export, key migration, sync) should reuse this rather than rolling
/// their own buffer.
///
/// Extends [ChangeNotifier] so widgets watching it via Riverpod's
/// [ChangeNotifierProvider] rebuild whenever a new line is logged.
class DiagnosticsBuffer extends ChangeNotifier {
  final StringBuffer _buffer = StringBuffer();
  void Function(String line)? _crashlyticsHook;

  /// The full log text, oldest line first.
  String get text => _buffer.toString();

  /// Whether anything has been logged yet.
  bool get isNotEmpty => _buffer.isNotEmpty;

  /// Logs a tagged line. Mirrors to [debugPrint] so `flutter logs` still
  /// surfaces the trace, forwards to the Crashlytics hook if installed,
  /// then notifies UI listeners.
  void log(String tag, Object msg) {
    final line = '[$tag] $msg';
    _buffer.writeln(line);
    // Legacy prefix preserved so existing log greps keep working.
    debugPrint('[BURN] $line');
    _crashlyticsHook?.call(line);
    notifyListeners();
  }

  /// Clears the buffer. Call before retrying a flow so old breadcrumbs
  /// don't muddle the new attempt.
  void clear() {
    if (_buffer.isEmpty) return;
    _buffer.clear();
    notifyListeners();
  }

  /// Plug in a Crashlytics-style breadcrumb sink. Once
  /// `firebase_crashlytics` is added (Phase 1.5 of the App Store route),
  /// wire it from `main.dart` like:
  ///
  /// ```dart
  /// container.read(diagnosticsBufferProvider.notifier)
  ///     .setCrashlyticsHook(FirebaseCrashlytics.instance.log);
  /// ```
  ///
  /// Production crashes will then arrive with the full breadcrumb trail
  /// already attached — zero ask of the user.
  void setCrashlyticsHook(void Function(String line)? hook) {
    _crashlyticsHook = hook;
  }
}

/// Singleton diagnostics buffer for the app.
final diagnosticsBufferProvider =
    ChangeNotifierProvider<DiagnosticsBuffer>((ref) {
  return DiagnosticsBuffer();
});
