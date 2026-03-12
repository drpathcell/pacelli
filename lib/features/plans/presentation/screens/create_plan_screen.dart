import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../config/theme/app_colors.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/plan_providers.dart';
import '../../../../core/data/data_repository_provider.dart';

/// Screen for creating a new scratch plan — from scratch or from a template.
class CreatePlanScreen extends ConsumerStatefulWidget {
  final String householdId;
  const CreatePlanScreen({super.key, required this.householdId});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  String _type = 'weekly'; // weekly, monthly, custom
  DateTime _startDate = _nextMonday();
  DateTime? _endDate;
  bool _isLoading = false;


  static DateTime _nextMonday() {
    final now = DateTime.now();
    final daysUntilMonday = (DateTime.monday - now.weekday + 7) % 7;
    return DateTime(
        now.year, now.month, now.day + (daysUntilMonday == 0 ? 7 : daysUntilMonday));
  }

  DateTime get _computedEndDate {
    if (_endDate != null) return _endDate!;
    switch (_type) {
      case 'weekly':
        return _startDate.add(const Duration(days: 6));
      case 'monthly':
        return DateTime(_startDate.year, _startDate.month + 1, _startDate.day - 1);
      default:
        return _startDate.add(const Duration(days: 6));
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  /// For custom plans — calendar-style range selection.
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate ?? _computedEndDate,
      ),
      helpText: context.l10n.planSelectDates,
      saveText: context.l10n.planConfirm,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _createPlan() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(dataRepositoryProvider);
      final plan = await repo.createPlan(
        householdId: widget.householdId,
        title: _titleController.text.trim(),
        type: _type,
        startDate: _startDate,
        endDate: _computedEndDate,
      );
      if (!mounted) return;

      ref.invalidate(householdPlansProvider(widget.householdId));
      context.pushReplacement('/plans/${plan.id}');
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToCreate(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createFromBuiltInTemplate(
      Map<String, dynamic> template) async {
    setState(() => _isLoading = true);
    final dinnerLabel = context.l10n.planLabelDinner;
    try {
      final start = _nextMonday();
      final end = start.add(const Duration(days: 6));
      final repo = ref.read(dataRepositoryProvider);
      final plan = await repo.createPlan(
        householdId: widget.householdId,
        title: template['title'] as String,
        type: 'weekly',
        startDate: start,
        endDate: end,
      );

      // Pre-populate with dinner slots for each day
      for (int i = 0; i < 7; i++) {
        final day = start.add(Duration(days: i));
        await repo.addEntry(
          planId: plan.id,
          householdId: widget.householdId,
          entryDate: day,
          title: '',
          label: dinnerLabel,
          sortOrder: 0,
        );
      }

      if (!mounted) return;
      ref.invalidate(householdPlansProvider(widget.householdId));
      context.pushReplacement('/plans/${plan.id}');
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToCreate(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createFromUserTemplate(
      Map<String, dynamic> template) async {
    setState(() => _isLoading = true);
    try {
      final start = _nextMonday();
      final templateType = template['type'] as String;
      final end = templateType == 'monthly'
          ? DateTime(start.year, start.month + 1, start.day - 1)
          : start.add(const Duration(days: 6));

      final plan = await ref.read(dataRepositoryProvider).createFromTemplate(
        templateId: template['id'] as String,
        householdId: widget.householdId,
        title: '${template['template_name'] ?? template['title']}',
        startDate: start,
        endDate: end,
      );

      if (!mounted) return;
      ref.invalidate(householdPlansProvider(widget.householdId));
      context.pushReplacement('/plans/${plan.id}');
    } catch (e) {
      if (!mounted) return;
      context.showSnackBar(context.l10n.planFailedToCreate(e.toString()), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync =
        ref.watch(planTemplatesProvider(widget.householdId));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.planNewPlan)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Templates section ───────────────────────
                  Text(
                    context.l10n.planStartFromTemplate,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Built-in templates
                  ...[
                    _TemplateCard(
                      title: context.l10n.planWeeklyDinnerPlanner,
                      description: context.l10n.planWeeklyDinnerDescription,
                      icon: Icons.restaurant_rounded,
                      onTap: () => _createFromBuiltInTemplate({
                        'id': 'built-in-weekly-dinner',
                        'title': context.l10n.planWeeklyDinnerPlanner,
                        'type': 'weekly',
                      }),
                    ),
                  ],

                  // User templates
                  templatesAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (templates) {
                      if (templates.isEmpty) return const SizedBox.shrink();
                      return Column(
                        children: templates
                            .map((t) => _TemplateCard(
                                  title: (t['template_name'] ??
                                      t['title']) as String,
                                  description:
                                      '${t['type']} plan • ${(t['plan_entries'] as List?)?.length ?? 0} entries',
                                  icon: Icons.bookmark_rounded,
                                  onTap: () => _createFromUserTemplate(t),
                                ))
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // ── From scratch section ────────────────────
                  Text(
                    context.l10n.planOrStartFromScratch,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Title
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: context.l10n.planTitle,
                            hintText: context.l10n.planTitleHint,
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                          ),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? context.l10n.planGiveItAName : null,
                        ),
                        const SizedBox(height: 16),

                        // Type selector
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'weekly',
                                label: Text(context.l10n.planTypeWeek),
                                icon: const Icon(Icons.view_week_rounded)),
                            ButtonSegment(
                                value: 'monthly',
                                label: Text(context.l10n.planTypeMonth),
                                icon: const Icon(Icons.calendar_month_rounded)),
                            ButtonSegment(
                                value: 'custom',
                                label: Text(context.l10n.planTypeCustom),
                                icon: const Icon(Icons.tune_rounded)),
                          ],
                          selected: {_type},
                          onSelectionChanged: (v) {
                            setState(() {
                              _type = v.first;
                              _endDate = null; // recalculate
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Date selection — differs by type
                        if (_type == 'custom') ...[
                          // Custom: tap to open range picker
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.date_range_rounded),
                            title: Text(
                              '${DateFormat('EEE d MMM').format(_startDate)} – '
                              '${DateFormat('EEE d MMM').format(_computedEndDate)}',
                            ),
                            subtitle: Text(
                              context.l10n.planDaysCount(_computedEndDate.difference(_startDate).inDays + 1),
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                            trailing: const Icon(Icons.edit_calendar_rounded, size: 20),
                            onTap: _pickDateRange,
                          ),
                        ] else ...[
                          // Week / Month: single start date picker
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.today_rounded),
                            title: Text(
                                context.l10n.planStartsDate(DateFormat('EEE d MMM').format(_startDate))),
                            onTap: _pickStartDate,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_computedEndDate.difference(_startDate).inDays + 1} days • '
                              '${DateFormat('d MMM').format(_startDate)} – ${DateFormat('d MMM').format(_computedEndDate)}',
                              style: context.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Create button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _createPlan,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(context.l10n.planCreatePlan),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A tappable template card.
class _TemplateCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _TemplateCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accentLight.withValues(alpha: 0.15),
          child: Icon(icon, color: AppColors.accentLight),
        ),
        title: Text(title),
        subtitle: Text(
          description,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
        onTap: onTap,
      ),
    );
  }
}
