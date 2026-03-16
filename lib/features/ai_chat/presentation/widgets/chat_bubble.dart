import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/pacelli_ai_icon.dart';
import '../../data/chat_models.dart';

/// Callback for rating an AI response.
typedef OnRateResponse = void Function(String messageId, bool isPositive);

/// A single chat message bubble.
///
/// User messages align right with the primary colour. Assistant messages
/// align left with a surface container background. Shows a typing
/// indicator when status is [ChatMessageStatus.sending].
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  /// Optional callback for thumbs up/down on assistant messages.
  final OnRateResponse? onRate;

  /// Set of message IDs that have already been rated.
  final Set<String> ratedMessageIds;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRate,
    this.ratedMessageIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final isError = message.status == ChatMessageStatus.error;
    final isSending = message.status == ChatMessageStatus.sending;

    final bubble = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  context.colorScheme.primary.withValues(alpha: 0.12),
              child: PacelliAiIcon(
                size: 16,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? context.colorScheme.primary
                    : isError
                        ? Colors.red.shade50
                        : context.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: isSending
                  ? _TypingIndicator(context: context)
                  : Text(
                      message.content,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: isUser
                            ? Colors.white
                            : isError
                                ? Colors.red.shade900
                                : context.colorScheme.onSurface,
                        height: 1.4,
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );

    // Wrap with feedback buttons for assistant messages.
    final isAssistant = message.role == ChatRole.assistant;
    final hasBeenRated = ratedMessageIds.contains(message.id);
    if (!isAssistant || isSending || onRate == null) return bubble;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        bubble,
        if (!hasBeenRated)
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _FeedbackButton(
                  icon: Icons.thumb_up_outlined,
                  onTap: () => onRate!(message.id, true),
                ),
                const SizedBox(width: 4),
                _FeedbackButton(
                  icon: Icons.thumb_down_outlined,
                  onTap: () => onRate!(message.id, false),
                ),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(left: 36, bottom: 8),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: context.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FeedbackButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: context.colorScheme.outline.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

/// Animated typing dots shown while waiting for the AI response.
class _TypingIndicator extends StatefulWidget {
  final BuildContext context;
  const _TypingIndicator({required this.context});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            final scale = 0.5 + 0.5 * (1 - (2 * t - 1).abs());
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: context.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
