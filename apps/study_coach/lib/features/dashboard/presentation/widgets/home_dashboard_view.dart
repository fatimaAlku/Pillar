import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';

String _formatTodayHeader(DateTime d, String locale) {
  return DateFormat('EEEE, MMMM d', locale).format(d);
}

/// Home tab: today’s plan, progress, AI placeholder, and quick actions.
class HomeDashboardView extends StatefulWidget {
  const HomeDashboardView({super.key});

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  late List<_TodayTask> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = [
      _TodayTask(
        titleKey: _TodayTaskKey.reviewCellularRespiration,
        durationMin: 30,
      ),
      _TodayTask(
        titleKey: _TodayTaskKey.practiceQuizThermodynamics,
        durationMin: 15,
        done: true,
      ),
      _TodayTask(titleKey: _TodayTaskKey.readNotesChapterSeven, durationMin: 20),
    ];
  }

  int get _completedCount => _tasks.where((t) => t.done).length;

  double get _progress =>
      _tasks.isEmpty ? 0 : _completedCount / _tasks.length;

  void _toggleTask(int index) {
    setState(() {
      _tasks[index].done = !_tasks[index].done;
    });
  }

  void _onQuickAction(BuildContext context, String label) {
    final strings = AppStrings.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(strings.comingSoonFor(label)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateStr = _formatTodayHeader(
      DateTime.now(),
      Localizations.localeOf(context).languageCode,
    );
    final pct = (_progress * 100).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _WelcomeHero(dateLabel: dateStr),
        const SizedBox(height: 18),
        Text(
          strings.focusToday,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(strings.smallStepsConsistentProgress,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            )),
        const SizedBox(height: 24),
        _ProgressCard(
          progress: _progress,
          percentLabel: pct,
          completed: _completedCount,
          total: _tasks.length,
        ),
        const SizedBox(height: 16),
        _TodayPlanCard(
          tasks: _tasks,
          onToggle: _toggleTask,
        ),
        const SizedBox(height: 16),
        const _AiSuggestionCard(),
        const SizedBox(height: 16),
        Text(
          strings.quickActions,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _QuickActionsRow(
          onAddTask: () => _onQuickAction(context, strings.addTask),
          onGenerateQuiz: () => _onQuickAction(context, strings.generateQuiz),
          onUploadNotes: () => _onQuickAction(context, strings.uploadNotes),
        ),
      ],
    );
  }
}

class _TodayTask {
  _TodayTask({
    required this.titleKey,
    required this.durationMin,
    this.done = false,
  });

  final _TodayTaskKey titleKey;
  final int durationMin;
  bool done;

  String title(AppStrings strings) {
    return switch (titleKey) {
      _TodayTaskKey.reviewCellularRespiration =>
        strings.todayTaskReviewCellularRespiration(),
      _TodayTaskKey.practiceQuizThermodynamics =>
        strings.todayTaskPracticeQuizThermodynamics(),
      _TodayTaskKey.readNotesChapterSeven => strings.todayTaskReadNotesChapterSeven(),
    };
  }
}

enum _TodayTaskKey {
  reviewCellularRespiration,
  practiceQuizThermodynamics,
  readNotesChapterSeven,
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.dateLabel});

  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer,
              colorScheme.tertiaryContainer.withValues(alpha: 0.95),
            ],
          ),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.smartStudyAssistant,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.78,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.tertiary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.progress,
    required this.percentLabel,
    required this.completed,
    required this.total,
  });

  final double progress;
  final int percentLabel;
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.trending_up_rounded, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  strings.todaysProgress,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor:
                    colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  strings.percentComplete(percentLabel),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  strings.completedTasks(completed, total),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard({
    required this.tasks,
    required this.onToggle,
  });

  final List<_TodayTask> tasks;
  final void Function(int index) onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    strings.todaysStudyPlan,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...List.generate(tasks.length, (index) {
              final t = tasks[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onToggle(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: t.done,
                              onChanged: (_) => onToggle(index),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.title(strings),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: t.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: t.done
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                strings.minutesShort(t.durationMin),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AiSuggestionCard extends StatelessWidget {
  const _AiSuggestionCard();

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.85),
              colorScheme.tertiaryContainer.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.aiSuggestion,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.aiSuggestionBody,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.92,
                        ),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAddTask,
    required this.onGenerateQuiz,
    required this.onUploadNotes,
  });

  final VoidCallback onAddTask;
  final VoidCallback onGenerateQuiz;
  final VoidCallback onUploadNotes;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.add_task_rounded,
            label: strings.addTask,
            onTap: onAddTask,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.quiz_rounded,
            label: strings.generateQuiz,
            onTap: onGenerateQuiz,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionCard(
            icon: Icons.upload_file_rounded,
            label: strings.uploadNotes,
            onTap: onUploadNotes,
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: colorScheme.primary, size: 26),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
