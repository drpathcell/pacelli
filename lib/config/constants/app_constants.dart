/// App-wide constants.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── Google OAuth (Firebase project: pacelli-35621) ─────────
  /// Web client ID — required as `serverClientId` for GoogleSignIn.
  /// Find in Firebase Console → Authentication → Sign-in method →
  /// Google → Web SDK configuration → Web client ID.
  static const String googleWebClientId =
      '506154778945-3iuom6m8sgd6aqj8pcum9v9744tnojt3.apps.googleusercontent.com';

  /// iOS client ID — from GoogleService-Info.plist CLIENT_ID field.
  static const String googleiOSClientId =
      '506154778945-68ta2sjllehr81l6ubl34e8htfcgtfig.apps.googleusercontent.com';

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
