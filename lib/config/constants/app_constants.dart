/// App-wide constants.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── Google OAuth (Firebase project: pacelli-35621) ─────────
  /// Web client ID — needed as `serverClientId` for Firebase Auth token
  /// exchange. This is NOT a secret (it's embedded in every Google Sign-In
  /// flow and visible in the browser).
  static const String googleWebClientId =
      '506154778945-3iuom6m8sgd6aqj8pcum9v9744tnojt3.apps.googleusercontent.com';

  // iOS client ID is auto-read from GoogleService-Info.plist by the
  // google_sign_in plugin — no need to duplicate it here.

  // ── App Info ──────────────────────────────────────────────
  static const String appName = 'Pacelli';
  static const String appVersion = '0.1.0';
  static const String appTagline = 'A peaceful home, organised with love.';

  // ── Household Limits ──────────────────────────────────────
  static const int maxHouseholdMembersFree = 2;
  static const int maxHouseholdMembersPaid = 12;

  // ── Task Defaults ─────────────────────────────────────────
  static const int defaultReminderMinutesBefore = 30;
}
