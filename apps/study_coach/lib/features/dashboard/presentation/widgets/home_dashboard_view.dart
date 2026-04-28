import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../subjects/presentation/screens/subjects_manage_screen.dart';
import '../../../study_plan/domain/entities/study_personalization_models.dart';
import '../../../study_plan/domain/entities/study_session.dart';
import '../../../study_plan/presentation/controllers/study_plan_firestore_providers.dart';
import '../../../study_plan/presentation/widgets/add_to_schedule_bottom_sheet.dart';

String _formatTodayHeader(DateTime d, String locale) {
  return DateFormat('EEEE, MMMM d', locale).format(d);
}

String _topicTitle(
  StudySession session,
  List<TopicPerformanceInput> topics,
  AppStrings strings,
) {
  if (session.topicId.isEmpty) return strings.studySessionUntitled;
  for (final t in topics) {
    if (t.topicId == session.topicId) return t.topicTitle;
  }
  return session.topicId;
}

/// Home tab: today’s plan from Firestore sessions, progress, AI placeholder, and quick actions.
class HomeDashboardView extends ConsumerStatefulWidget {
  const HomeDashboardView({
    super.key,
    this.onGenerateQuizTap,
    this.onAddTopicTap,
  });

  final VoidCallback? onGenerateQuizTap;
  final VoidCallback? onAddTopicTap;

  @override
  ConsumerState<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends ConsumerState<HomeDashboardView> {
  Future<void> _toggleSession({
    required String uid,
    required StudySession session,
  }) async {
    final strings = AppStrings.of(context);
    try {
      await ref.read(studySessionsRepositoryProvider).setSessionCompleted(
            uid: uid,
            planId: session.planId,
            sessionId: session.id,
            completed: !session.completed,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotUpdateSession)),
      );
    }
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

  Future<void> _openAddToSchedule({
    required String uid,
    required List<TopicPerformanceInput> topics,
  }) async {
    final strings = AppStrings.of(context);
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noSubjectsForPersonalizedPlan)),
      );
      return;
    }
    final n = DateTime.now();
    final scheduleDate = DateTime(n.year, n.month, n.day);
    final dateIso = DateFormat('yyyy-MM-dd').format(scheduleDate);
    await showAddToScheduleBottomSheet(
      context,
      strings: strings,
      topics: topics,
      scheduleDate: scheduleDate,
      onSave: (topicId, durationMin, startMinute) async {
        await ref.read(studySessionsRepositoryProvider).addSession(
              uid: uid,
              topicId: topicId,
              dateIso: dateIso,
              durationMin: durationMin,
              startMinute: startMinute,
            );
      },
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
    final authAsync = ref.watch(currentAuthUserProvider);

    return authAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (user) {
        if (user == null) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              Text(
                strings.signInToSeeStudyPlan,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          );
        }
        final sessionsAsync =
            ref.watch(todaysSessionsStreamProvider(user.uid));
        final topicsAsync =
            ref.watch(topicPerformanceInputsStreamProvider(user.uid));

        return sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (sessions) {
            return topicsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (topics) {
                final rows = sessions
                    .map(
                      (s) => _SessionRow(
                        session: s,
                        title: _topicTitle(s, topics, strings),
                      ),
                    )
                    .toList();
                final completedCount =
                    sessions.where((s) => s.completed).length;
                final progress =
                    sessions.isEmpty ? 0.0 : completedCount / sessions.length;
                final pct = (progress * 100).round();

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
                    Text(
                      strings.smallStepsConsistentProgress,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _ProgressCard(
                      progress: progress,
                      percentLabel: pct,
                      completed: completedCount,
                      total: sessions.length,
                    ),
                    const SizedBox(height: 16),
                    _TodayPlanCard(
                      rows: rows,
                      emptyMessage: strings.noSessionsTodayHome,
                      onToggle: (index) => _toggleSession(
                        uid: user.uid,
                        session: rows[index].session,
                      ),
                      onAddToSchedule: topics.isEmpty
                          ? null
                          : () => _openAddToSchedule(
                                uid: user.uid,
                                topics: topics,
                              ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.quickActions,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _QuickActionsRow(
                      onAddTask: () => _openAddToSchedule(
                            uid: user.uid,
                            topics: topics,
                          ),
                      onGenerateQuiz: widget.onGenerateQuizTap ??
                          () => _onQuickAction(context, strings.generateQuiz),
                      onAddTopic: widget.onAddTopicTap ??
                          () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const SubjectsManageScreen(),
                              ),
                            );
                          },
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SessionRow {
  _SessionRow({required this.session, required this.title});

  final StudySession session;
  final String title;
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
                value: total == 0 ? 0 : progress,
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
                  total == 0
                      ? strings.todaysProgressNoSessions
                      : strings.percentComplete(percentLabel),
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
    required this.rows,
    required this.emptyMessage,
    required this.onToggle,
    this.onAddToSchedule,
  });

  final List<_SessionRow> rows;
  final String emptyMessage;
  final void Function(int index) onToggle;
  final VoidCallback? onAddToSchedule;

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
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      emptyMessage,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    if (onAddToSchedule != null) ...[
                      const SizedBox(height: 14),
                      FilledButton.tonalIcon(
                        onPressed: onAddToSchedule,
                        icon: const Icon(Icons.add, size: 20),
                        label: Text(strings.addSchedule),
                      ),
                    ],
                  ],
                ),
              )
            else
              ...List.generate(rows.length, (index) {
                final row = rows[index];
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
                                value: row.session.completed,
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
                                  row.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    decoration: row.session.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: row.session.completed
                                        ? colorScheme.onSurfaceVariant
                                        : colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  strings.minutesShort(row.session.durationMin),
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

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.onAddTask,
    required this.onGenerateQuiz,
    required this.onAddTopic,
  });

  final VoidCallback onAddTask;
  final VoidCallback onGenerateQuiz;
  final VoidCallback onAddTopic;

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
            icon: Icons.topic_outlined,
            label: strings.addCourse,
            onTap: onAddTopic,
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
