import 'package:flutter/material.dart';

import '../../../../core/models/search_result.dart';
import '../../../../core/utils/extensions.dart';

/// A single search result row with icon, highlighted title, and subtitle.
class SearchResultTile extends StatelessWidget {
  final SearchResult result;
  final String query;
  final VoidCallback? onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.query,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(_iconFor(result.entityType), color: _colorFor(result.entityType, context)),
      title: _HighlightedText(text: result.title, query: query),
      subtitle: _buildSubtitle(context),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <Widget>[
      _TypeBadge(entityType: result.entityType, context: context),
    ];
    if (result.subtitle != null && result.subtitle!.isNotEmpty) {
      parts.add(const SizedBox(width: 8));
      parts.add(Flexible(
        child: Text(
          result.subtitle!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.textTheme.bodySmall,
        ),
      ));
    }
    return Row(children: parts);
  }

  static IconData _iconFor(String entityType) => switch (entityType) {
        'task' => Icons.check_circle_outline,
        'checklist' => Icons.checklist,
        'plan' => Icons.calendar_today,
        'attachment' => Icons.attach_file,
        'inventory' => Icons.inventory_2,
        _ => Icons.search,
      };

  static Color _colorFor(String entityType, BuildContext context) =>
      switch (entityType) {
        'task' => context.colorScheme.primary,
        'checklist' => Colors.teal,
        'plan' => Colors.deepPurple,
        'attachment' => Colors.orange,
        'inventory' => Colors.green,
        _ => context.colorScheme.onSurface,
      };
}

/// Displays a small coloured badge for the entity type.
class _TypeBadge extends StatelessWidget {
  final String entityType;
  final BuildContext context;

  const _TypeBadge({required this.entityType, required this.context});

  @override
  Widget build(BuildContext outerContext) {
    final l10n = outerContext.l10n;
    final label = switch (entityType) {
      'task' => l10n.searchResultTask,
      'checklist' => l10n.searchResultChecklist,
      'plan' => l10n.searchResultPlan,
      'attachment' => l10n.searchResultAttachment,
      'inventory' => l10n.searchResultInventory,
      _ => entityType,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: SearchResultTile._colorFor(entityType, outerContext)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: outerContext.textTheme.labelSmall?.copyWith(
          color: SearchResultTile._colorFor(entityType, outerContext),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Text widget that bolds the matching substring.
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final index = lowerText.indexOf(lowerQuery);

    if (index < 0) return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: context.textTheme.bodyLarge,
        children: [
          if (index > 0) TextSpan(text: text.substring(0, index)),
          TextSpan(
            text: text.substring(index, index + query.length),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (index + query.length < text.length)
            TextSpan(text: text.substring(index + query.length)),
        ],
      ),
    );
  }
}
