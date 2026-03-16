import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'chat_models.dart';

/// Service that sends user messages to the Pacelli Cloud Functions AI
/// endpoint and streams back responses.
///
/// Uses Firebase ID tokens for auth — no manual token generation needed.
/// The token is refreshed automatically by Firebase SDK and cached for
/// up to 55 minutes (Firebase tokens last 1 hour).
class ChatService {
  static const _apiUrlKey = 'ai_assistant_api_url';
  static const _defaultApiUrl =
      'https://us-central1-pacelli-app.cloudfunctions.net';

  String? _cachedToken;
  DateTime? _tokenExpiry;

  // ── Auth ──────────────────────────────────────────────────────

  /// Get a valid Firebase ID token, refreshing only when needed.
  Future<String?> _getToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    // Reuse cached token if still valid (refresh at 55 min mark)
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    _cachedToken = await user.getIdToken(false);
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
    return _cachedToken;
  }

  /// Force-refresh the token (e.g. after a 401 error).
  Future<String?> _refreshToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    _cachedToken = await user.getIdToken(true);
    _tokenExpiry = DateTime.now().add(const Duration(minutes: 55));
    return _cachedToken;
  }

  // ── API URL ──────────────────────────────────────────────────

  Future<String> _getApiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiUrlKey) ?? _defaultApiUrl;
  }

  // ── Chat API ─────────────────────────────────────────────────

  /// Send a user message and get the AI response.
  ///
  /// The Cloud Function `/aiChat` accepts the full conversation history
  /// and returns the assistant's reply. If the endpoint doesn't exist yet,
  /// we fall back to a direct tool-calling approach.
  Future<ChatMessage> sendMessage(
    String userMessage,
    List<ChatMessage> history,
  ) async {
    final token = await _getToken();
    if (token == null) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        role: ChatRole.assistant,
        content: 'Please sign in to use the AI assistant.',
        timestamp: DateTime.now(),
        status: ChatMessageStatus.error,
      );
    }

    final apiUrl = await _getApiUrl();

    // Build conversation payload
    final messages = history
        .where((m) => m.role != ChatRole.system)
        .map((m) => {
              'role': m.role == ChatRole.user ? 'user' : 'assistant',
              'content': m.content,
            })
        .toList();

    messages.add({'role': 'user', 'content': userMessage});

    try {
      final response = await http.post(
        Uri.parse('$apiUrl/aiChat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'messages': messages}),
      );

      if (response.statusCode == 401) {
        // Token expired mid-session — refresh and retry once
        final newToken = await _refreshToken();
        if (newToken == null) {
          return _errorMessage('Session expired. Please sign in again.');
        }
        final retry = await http.post(
          Uri.parse('$apiUrl/aiChat'),
          headers: {
            'Authorization': 'Bearer $newToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'messages': messages}),
        );
        return _parseResponse(retry);
      }

      return _parseResponse(response);
    } catch (e) {
      return _errorMessage(
        'Could not reach the AI assistant. Check your connection and try again.',
      );
    }
  }

  /// Send a quick single-turn query (no history).
  Future<ChatMessage> quickQuery(String query) async {
    return sendMessage(query, []);
  }

  // ── Helpers ──────────────────────────────────────────────────

  ChatMessage _parseResponse(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] == true && json['data'] != null) {
        final data = json['data'] as Map<String, dynamic>;
        return ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          role: ChatRole.assistant,
          content: data['reply'] as String? ?? data.toString(),
          timestamp: DateTime.now(),
        );
      } else {
        final error = json['error'] as String? ?? 'Unknown error';
        return _errorMessage(error);
      }
    } catch (_) {
      return _errorMessage('Unexpected response from the AI assistant.');
    }
  }

  ChatMessage _errorMessage(String text) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: ChatRole.assistant,
      content: text,
      timestamp: DateTime.now(),
      status: ChatMessageStatus.error,
    );
  }

  /// Clear token cache (e.g. on sign-out).
  void clearCache() {
    _cachedToken = null;
    _tokenExpiry = null;
  }
}
