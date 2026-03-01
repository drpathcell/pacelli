/// App-wide constants.
///
/// IMPORTANT: Replace the Supabase values below with your actual
/// project credentials from Settings → API in your Supabase dashboard.
class AppConstants {
  AppConstants._(); // Prevent instantiation

  // ── Supabase ──────────────────────────────────────────────
  static const String supabaseUrl = 'https://cgctdslvswicttaqnkea.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_mYnrzNBfNw-EIpCx8ATmfw_IjH6o324';

  // ── Google OAuth ────────────────────────────────────────────
  static const String googleWebClientId =
      '385951935537-ifsoc4s8hoe748uqpcu8fnhbatup84cv.apps.googleusercontent.com';
  static const String googleiOSClientId =
      '385951935537-ihda7pim8nn73vdlhj3eehb35doa4nrf.apps.googleusercontent.com';

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
