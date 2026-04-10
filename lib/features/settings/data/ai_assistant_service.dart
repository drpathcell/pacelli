import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../presentation/screens/ai_assistant_screen.dart';

/// Manages the AI Assistant configuration.
///
/// Handles provider selection, API key storage (encrypted via FlutterSecureStorage),
/// Firebase ID token generation for the MCP server, and connection testing.
class AiAssistantService {
  static const _apiUrlKey = 'ai_assistant_api_url';
  static const _providerKey = 'ai_assistant_provider';
  static const _apiKeyStorageKey = 'ai_assistant_api_key';
  static const _hostedModeKey = 'ai_assistant_hosted_mode';

  /// Default Cloud Functions URL for Pacelli.
  static const defaultApiUrl =
      'https://us-central1-pacelli-app.cloudfunctions.net';

  static const _secureStorage = FlutterSecureStorage();

  // ── Provider Config ────────────────────────────────────────────

  /// Save the selected provider and API key.
  static Future<void> saveProviderConfig({
    required AiProvider provider,
    required String apiKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider.name);
    await _secureStorage.write(key: _apiKeyStorageKey, value: apiKey);
  }

  /// Get the currently saved provider, or null if none.
  static Future<AiProvider?> getSavedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_providerKey);
    if (name == null) return null;
    try {
      return AiProvider.values.byName(name);
    } catch (_) {
      return null;
    }
  }

  /// Check whether an API key is stored.
  static Future<bool> hasApiKey() async {
    final key = await _secureStorage.read(key: _apiKeyStorageKey);
    return key != null && key.isNotEmpty;
  }

  /// Read the stored API key (for making API calls).
  static Future<String?> getApiKey() async {
    return _secureStorage.read(key: _apiKeyStorageKey);
  }

  /// Clear the provider config and API key.
  static Future<void> clearProviderConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_providerKey);
    await _secureStorage.delete(key: _apiKeyStorageKey);
  }

  // ── Token ────────────────────────────────────────────────────

  /// Generate a fresh Firebase ID token for authenticating the MCP server.
  ///
  /// Returns `null` if the user is not signed in.
  static Future<String?> generateToken({bool forceRefresh = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return user.getIdToken(forceRefresh);
  }

  // ── Hosted Mode ──────────────────────────────────────────────

  /// Read whether hosted (Firebase token) mode is enabled.
  static Future<bool> getHostedMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hostedModeKey) ?? false;
  }

  /// Persist the hosted mode toggle.
  static Future<void> setHostedMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hostedModeKey, value);
  }

  // ── API URL ──────────────────────────────────────────────────

  /// Read the persisted Cloud Functions base URL.
  static Future<String> getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? defaultApiUrl;
  }

  /// Persist a custom Cloud Functions base URL.
  static Future<void> setApiUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiUrlKey, url);
  }

  // ── Connection Test ──────────────────────────────────────────

  /// Quick check: can we generate a valid token?
  static Future<AiConnectionStatus> testConnection() async {
    try {
      final token = await generateToken();
      if (token == null) return AiConnectionStatus.noUser;
      return AiConnectionStatus.ready;
    } catch (_) {
      return AiConnectionStatus.error;
    }
  }
}

/// Connection status for the AI assistant integration.
enum AiConnectionStatus {
  ready,
  noUser,
  error,
}
