import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/models.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../shared/widgets/pacelli_ai_icon.dart';
import '../../data/feedback_providers.dart';

/// Main feedback & insights screen with tabs: Submit, History, Digests.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedbackTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.feedbackTabSubmit),
            Tab(text: l10n.feedbackTabHistory),
            Tab(text: l10n.feedbackTabDigests),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SubmitFeedbackTab(),
          _FeedbackHistoryTab(),
          _WeeklyDigestsTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 1: Submit Feedback
// ═══════════════════════════════════════════════════════════════════

class _SubmitFeedbackTab extends ConsumerStatefulWidget {
  const _SubmitFeedbackTab();

  @override
  ConsumerState<_SubmitFeedbackTab> createState() => _SubmitFeedbackTabState();
}

class _SubmitFeedbackTabState extends ConsumerState<_SubmitFeedbackTab> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  FeedbackType _type = FeedbackType.general;
  FeedbackRating _rating = FeedbackRating.neutral;
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final service = ref.read(feedbackServiceProvider);
      await service.submitFeedback(
        type: _type,
        rating: _rating,
        message: _messageController.text.trim(),
      );

      if (!mounted) return;
      _messageController.clear();
      ref.invalidate(feedbackListProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.feedbackSubmitted)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.feedbackError}: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type selector
            Text(l10n.feedbackType,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<FeedbackType>(
              segments: [
                ButtonSegment(
                  value: FeedbackType.general,
                  label: Text(l10n.feedbackTypeGeneral),
                  icon: const Icon(Icons.chat_bubble_outline, size: 18),
                ),
                ButtonSegment(
                  value: FeedbackType.bug,
                  label: Text(l10n.feedbackTypeBug),
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                ),
                ButtonSegment(
                  value: FeedbackType.featureRequest,
                  label: Text(l10n.feedbackTypeFeature),
                  icon: const Icon(Icons.lightbulb_outline, size: 18),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),

            const SizedBox(height: 20),

            // Rating
            Text(l10n.feedbackRating,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RatingChip(
                  icon: Icons.thumb_up_rounded,
                  label: l10n.feedbackPositive,
                  selected: _rating == FeedbackRating.positive,
                  color: cs.primary,
                  onTap: () =>
                      setState(() => _rating = FeedbackRating.positive),
                ),
                const SizedBox(width: 12),
                _RatingChip(
                  icon: Icons.thumbs_up_down_rounded,
                  label: l10n.feedbackNeutral,
                  selected: _rating == FeedbackRating.neutral,
                  color: cs.outline,
                  onTap: () =>
                      setState(() => _rating = FeedbackRating.neutral),
                ),
                const SizedBox(width: 12),
                _RatingChip(
                  icon: Icons.thumb_down_rounded,
                  label: l10n.feedbackNegative,
                  selected: _rating == FeedbackRating.negative,
                  color: cs.error,
                  onTap: () =>
                      setState(() => _rating = FeedbackRating.negative),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Message
            TextFormField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.feedbackMessage,
                hintText: l10n.feedbackMessageHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.feedbackMessageRequired : null,
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(l10n.feedbackSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _RatingChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      avatar: Icon(icon, size: 18, color: selected ? color : null),
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.15),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 2: Feedback History
// ═══════════════════════════════════════════════════════════════════

class _FeedbackHistoryTab extends ConsumerWidget {
  const _FeedbackHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(feedbackListProvider);
    final l10n = context.l10n;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.feedback_outlined,
                    size: 64,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(l10n.feedbackNoHistory,
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(feedbackListProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final entry = entries[i];
              return _FeedbackCard(entry: entry);
            },
          ),
        );
      },
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final FeedbackEntry entry;
  const _FeedbackCard({required this.entry});

  Widget _typeIconWidget(Color color) {
    switch (entry.type) {
      case FeedbackType.bug:
        return Icon(Icons.bug_report_rounded, size: 20, color: color);
      case FeedbackType.featureRequest:
        return Icon(Icons.lightbulb_rounded, size: 20, color: color);
      case FeedbackType.aiResponse:
        return PacelliAiIcon(size: 20, color: color);
      case FeedbackType.general:
        return Icon(Icons.chat_bubble_rounded, size: 20, color: color);
    }
  }

  IconData get _ratingIcon {
    switch (entry.rating) {
      case FeedbackRating.positive:
        return Icons.thumb_up_rounded;
      case FeedbackRating.negative:
        return Icons.thumb_down_rounded;
      case FeedbackRating.neutral:
        return Icons.thumbs_up_down_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _typeIconWidget(cs.primary),
                const SizedBox(width: 8),
                Text(
                  entry.type.name.toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.primary),
                ),
                const Spacer(),
                Icon(_ratingIcon, size: 18, color: cs.outline),
                const SizedBox(width: 8),
                Text(
                  _formatDate(entry.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(entry.message),
            if (entry.context != null) ...[
              const SizedBox(height: 4),
              Text(
                entry.context!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.outline),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ═══════════════════════════════════════════════════════════════════
//  TAB 3: Weekly Digests
// ═══════════════════════════════════════════════════════════════════

class _WeeklyDigestsTab extends ConsumerWidget {
  const _WeeklyDigestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyDigestsProvider);
    final l10n = context.l10n;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (digests) {
        if (digests.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded,
                    size: 56,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(l10n.feedbackNoDigests,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 4),
                Text(l10n.feedbackNoDigestsHint,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(weeklyDigestsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: digests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _DigestCard(digest: digests[i]),
          ),
        );
      },
    );
  }
}

class _DigestCard extends StatelessWidget {
  final WeeklyDigest digest;
  const _DigestCard({required this.digest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final dateRange =
        '${_fmtDate(digest.weekStarting)} – ${_fmtDate(digest.weekEnding)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    size: 20, color: cs.primary),
                const SizedBox(width: 8),
                Text(dateRange,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),

            // Stats grid
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _StatChip(Icons.task_alt_rounded, l10n.feedbackDigestTasks,
                    '${digest.tasksCompleted}/${digest.tasksCreated}'),
                _StatChip(Icons.checklist_rounded, l10n.feedbackDigestChecklists,
                    '${digest.checklistItemsChecked}'),
                _StatChip(Icons.map_rounded, l10n.feedbackDigestPlans,
                    '${digest.plansCreated}'),
                _StatChip(Icons.inventory_2_rounded, l10n.feedbackDigestInventory,
                    '${digest.inventoryItemsAdded}'),
                _StatChip(Icons.menu_book_rounded, l10n.feedbackDigestManual,
                    '${digest.manualEntriesCreated}'),
                _StatChipWidget(PacelliAiIcon(size: 16, color: Theme.of(context).colorScheme.outline), l10n.feedbackDigestAI,
                    '${digest.aiChatMessages}'),
              ],
            ),

            if (digest.summary != null && digest.summary!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(digest.summary!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}';
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatChip(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return _StatChipWidget(
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.outline),
      label,
      value,
    );
  }
}

class _StatChipWidget extends StatelessWidget {
  final Widget iconWidget;
  final String label;
  final String value;

  const _StatChipWidget(this.iconWidget, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 4),
        Text('$label: ',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
