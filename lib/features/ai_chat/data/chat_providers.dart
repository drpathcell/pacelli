import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'chat_models.dart';
import 'chat_service.dart';

/// Singleton chat service instance.
final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

/// The conversation state — list of messages.
final chatMessagesProvider =
    StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>(
  (ref) => ChatMessagesNotifier(ref.read(chatServiceProvider)),
);

/// Whether the AI is currently processing a response.
final chatLoadingProvider = StateProvider<bool>((ref) => false);

/// Manages the in-app chat conversation.
class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatService _service;

  ChatMessagesNotifier(this._service) : super([]);

  /// Send a user message and get the AI response.
  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;

    // Add the user message
    final userMsg = ChatMessage(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      role: ChatRole.user,
      content: text.trim(),
      timestamp: DateTime.now(),
    );
    state = [...state, userMsg];

    // Add a placeholder for the AI response
    final placeholderId = 'a_${DateTime.now().millisecondsSinceEpoch}';
    final placeholder = ChatMessage(
      id: placeholderId,
      role: ChatRole.assistant,
      content: '',
      timestamp: DateTime.now(),
      status: ChatMessageStatus.sending,
    );
    state = [...state, placeholder];

    // Call the API
    final reply = await _service.sendMessage(text.trim(), state);

    // Replace placeholder with actual response
    state = state
        .map((m) => m.id == placeholderId
            ? reply.copyWith(
                status: reply.status == ChatMessageStatus.error
                    ? ChatMessageStatus.error
                    : ChatMessageStatus.sent,
              )
            : m)
        .toList();
  }

  /// Clear the conversation.
  void clear() => state = [];
}
