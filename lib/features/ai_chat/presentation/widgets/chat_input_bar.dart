import 'package:flutter/material.dart';

import '../../../../core/utils/extensions.dart';

/// Text input bar at the bottom of the AI chat screen.
///
/// Shows a text field with a send button. The send button is disabled
/// while a response is being generated. Pressing Enter (without Shift)
/// sends the message; Shift+Enter inserts a newline.
class ChatInputBar extends StatefulWidget {
  final bool isLoading;
  final ValueChanged<String> onSend;

  const ChatInputBar({
    super.key,
    required this.isLoading,
    required this.onSend,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool get _hasText => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_hasText || widget.isLoading) return;
    widget.onSend(_controller.text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ── Text field ──
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.newline,
              enabled: !widget.isLoading,
              decoration: InputDecoration(
                hintText: context.l10n.aiChatInputHint,
                hintStyle: TextStyle(
                  color: context.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.5),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                isDense: true,
              ),
              style: context.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 6),

          // ── Send button ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.colorScheme.primary,
                    ),
                  )
                : IconButton(
                    onPressed: _hasText ? _submit : null,
                    icon: Icon(
                      Icons.arrow_upward_rounded,
                      color: _hasText
                          ? context.colorScheme.onPrimary
                          : context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                      size: 20,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: _hasText
                          ? context.colorScheme.primary
                          : context.colorScheme.surfaceContainerHighest,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
