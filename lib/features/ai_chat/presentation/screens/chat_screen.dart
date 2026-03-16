import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/pacelli_ai_icon.dart';
import '../../../feedback/data/feedback_providers.dart';
import '../../data/chat_models.dart';
import '../../data/chat_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_input_bar.dart';

/// Full-screen AI chat interface.
///
/// Opened by tapping the central AI FAB in the bottom nav. Shows a
/// scrollable conversation with an input bar at the bottom.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  final _ratedMessageIds = <String>{};

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onRateResponse(String messageId, bool isPositive) {
    setState(() => _ratedMessageIds.add(messageId));

    // Find the assistant message to include its content as context.
    final messages = ref.read(chatMessagesProvider);
    final msg = messages.where((m) => m.id == messageId).firstOrNull;
    final contextPreview = (msg?.content.length ?? 0) > 120
        ? '${msg!.content.substring(0, 120)}...'
        : msg?.content ?? '';

    final service = ref.read(feedbackServiceProvider);
    service.submitFeedback(
      type: FeedbackType.aiResponse,
      rating: isPositive ? FeedbackRating.positive : FeedbackRating.negative,
      message: isPositive ? 'Helpful AI response' : 'Unhelpful AI response',
      context: 'chat_message:$messageId | $contextPreview',
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider);
    final isLoading = messages.isNotEmpty &&
        messages.last.status == ChatMessageStatus.sending;

    // Auto-scroll when new messages arrive
    ref.listen(chatMessagesProvider, (_, __) => _scrollToBottom());

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiAssistantTitle),
        actions: [
          if (messages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 22),
              tooltip: context.l10n.commonClear,
              onPressed: () {
                ref.read(chatMessagesProvider.notifier).clear();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Messages ──
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(context: context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(
                        message: messages[index],
                        onRate: _onRateResponse,
                        ratedMessageIds: _ratedMessageIds,
                      );
                    },
                  ),
          ),

          // ── Input ──
          ChatInputBar(
            isLoading: isLoading,
            onSend: (text) {
              ref.read(chatMessagesProvider.notifier).send(text);
            },
          ),
        ],
      ),
    );
  }
}

/// Shown when the conversation is empty.
class _EmptyState extends StatelessWidget {
  final BuildContext context;
  const _EmptyState({required this.context});

  @override
  Widget build(BuildContext _) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: PacelliAiIcon(
                size: 48,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.aiChatWelcomeTitle,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.aiChatWelcomeSubtitle,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Suggestion chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  label: context.l10n.aiChatSuggestion1,
                  context: context,
                ),
                _SuggestionChip(
                  label: context.l10n.aiChatSuggestion2,
                  context: context,
                ),
                _SuggestionChip(
                  label: context.l10n.aiChatSuggestion3,
                  context: context,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final BuildContext context;
  const _SuggestionChip({required this.label, required this.context});

  @override
  Widget build(BuildContext _) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: context.colorScheme.primary,
        ),
      ),
      side: BorderSide(
        color: context.colorScheme.primary.withValues(alpha: 0.3),
      ),
      backgroundColor: context.colorScheme.primary.withValues(alpha: 0.04),
      onPressed: () {
        // Find the ChatScreen's consumer state via the ProviderScope
        final container = ProviderScope.containerOf(context);
        container.read(chatMessagesProvider.notifier).send(label);
      },
    );
  }
}
