// Chat message and conversation models for the in-app AI assistant.

enum ChatRole { user, assistant, system }

enum ChatMessageStatus { sending, sent, error }

/// Represents a confirmation prompt for a write operation.
class ActionConfirmation {
  final String description;
  final String endpoint;
  final Map<String, dynamic> payload;
  final void Function() onConfirm;
  final void Function() onDeny;
  bool responded;

  ActionConfirmation({
    required this.description,
    required this.endpoint,
    required this.payload,
    required this.onConfirm,
    required this.onDeny,
    this.responded = false,
  });
}

/// A single chat message.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final ChatMessageStatus status;
  final ActionConfirmation? confirmation;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.status = ChatMessageStatus.sent,
    this.confirmation,
  });

  ChatMessage copyWith({
    String? content,
    ChatMessageStatus? status,
    ActionConfirmation? confirmation,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      status: status ?? this.status,
      confirmation: confirmation ?? this.confirmation,
    );
  }
}
