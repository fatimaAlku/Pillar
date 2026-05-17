import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
import '../../../academic_tasks/domain/entities/academic_task.dart';
import '../../../academic_tasks/presentation/screens/academic_tasks_screen.dart';
import '../../../focus/presentation/screens/focus_session_screen.dart';
import '../../../subjects/presentation/screens/subjects_manage_screen.dart';
import '../../../study_plan/domain/entities/study_personalization_models.dart';
import '../../../study_plan/domain/entities/study_session.dart';
import '../../../study_chat/presentation/screens/study_chat_screen.dart';
import '../../../study_plan/presentation/controllers/study_plan_firestore_providers.dart';
import '../../../study_plan/presentation/widgets/add_to_schedule_bottom_sheet.dart';
import '../../../study_plan/presentation/widgets/study_session_actions.dart';

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

List<AcademicTask> _upcomingAcademicTasks(List<AcademicTask> tasks) {
  final openTasks = tasks.where((task) => !task.isCompleted).toList()
    ..sort((a, b) {
      final aDue = a.dueDate ?? DateTime(9999);
      final bDue = b.dueDate ?? DateTime(9999);
      return aDue.compareTo(bDue);
    });
  return openTasks.take(4).toList(growable: false);
}

String _academicTaskDueLabel(
  BuildContext context,
  AppStrings strings,
  AcademicTask task,
) {
  final dueDate = task.dueDate;
  if (dueDate == null) return strings.academicTaskDueDate;
  final dateOnly = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final today = appTodayDateOnly();
  final days = dateOnly.difference(today).inDays;
  final formatted = DateFormat.yMMMd(
    Localizations.localeOf(context).languageCode,
  ).format(dateOnly);
  if (days == 0) return strings.academicTaskDueToday(formatted);
  if (days == 1) return strings.academicTaskDueTomorrow(formatted);
  if (days > 1) return strings.academicTaskDueInDays(days, formatted);
  return strings.academicTaskOverdue(days.abs(), formatted);
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

  void _openStudyChat() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const StudyChatScreen(),
      ),
    );
  }

  void _openAcademicTasks() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AcademicTasksScreen(),
      ),
    );
  }

  Future<void> _editSession({
    required String uid,
    required List<TopicPerformanceInput> topics,
    required StudySession session,
  }) async {
    await editStudySession(
      context: context,
      ref: ref,
      uid: uid,
      topics: topics,
      planId: session.planId,
      sessionId: session.id,
      topicId: session.topicId,
      durationMin: session.durationMin,
      startMinute: session.startMinute,
    );
  }

  Future<void> _deleteSession({
    required String uid,
    required StudySession session,
  }) async {
    await confirmAndDeleteStudySession(
      context: context,
      ref: ref,
      uid: uid,
      planId: session.planId,
      sessionId: session.id,
    );
  }

  void _openFocusSession({
    required String uid,
    required StudySession session,
    required String title,
  }) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FocusSessionScreen(
          uid: uid,
          session: session,
          topicTitle: title,
        ),
      ),
    );
  }

  Future<void> _toggleAcademicTask({
    required String uid,
    required AcademicTask task,
  }) async {
    final strings = AppStrings.of(context);
    try {
      await ref.read(academicTasksRepositoryProvider).setTaskCompleted(
            uid: uid,
            taskId: task.id,
            completed: !task.isCompleted,
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotToggleAcademicTask)),
      );
    }
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
    final scheduleDate = appTodayDateOnly();
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
      appTodayDateOnly(),
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
        final sessionsAsync = ref.watch(todaysSessionsStreamProvider(user.uid));
        final academicTasksAsync =
            ref.watch(academicTasksStreamProvider(user.uid));
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
                final academicTasks =
                    academicTasksAsync.valueOrNull ?? const <AcademicTask>[];
                final upcomingTasks = _upcomingAcademicTasks(academicTasks);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  children: [
                    _WelcomeHero(
                      dateLabel: dateStr,
                      onOpenStudyChat: _openStudyChat,
                    ),
                    const SizedBox(height: 22),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  colorScheme.primary,
                                  colorScheme.tertiary,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.focusToday,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.35,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  strings.smallStepsConsistentProgress,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ProgressCard(
                      progress: progress,
                      percentLabel: pct,
                      completed: completedCount,
                      total: sessions.length,
                    ),
                    const SizedBox(height: 14),
                    _UpcomingDeadlinesCard(
                      tasks: upcomingTasks,
                      onViewAll: _openAcademicTasks,
                      onToggle: (task) => _toggleAcademicTask(
                        uid: user.uid,
                        task: task,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _TodayPlanCard(
                      rows: rows,
                      emptyMessage: strings.noSessionsTodayHome,
                      onToggle: (index) => _toggleSession(
                        uid: user.uid,
                        session: rows[index].session,
                      ),
                      onStartFocus: (index) => _openFocusSession(
                        uid: user.uid,
                        session: rows[index].session,
                        title: rows[index].title,
                      ),
                      onEdit: (index) => _editSession(
                        uid: user.uid,
                        topics: topics,
                        session: rows[index].session,
                      ),
                      onDelete: (index) => _deleteSession(
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
                    const SizedBox(height: 22),
                    Text(
                      strings.quickActions,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _QuickActionsRow(
                      onAddTask: _openAcademicTasks,
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
  const _WelcomeHero({
    required this.dateLabel,
    required this.onOpenStudyChat,
  });

  final String dateLabel;
  final VoidCallback onOpenStudyChat;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onCont = colorScheme.onPrimaryContainer;

    return Tooltip(
      message: strings.studyChatTitle,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.primary.withValues(alpha: 0.08),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpenStudyChat,
              child: Stack(
                clipBehavior: Clip.antiAlias,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer,
                            Color.lerp(
                                  colorScheme.tertiaryContainer,
                                  colorScheme.primaryContainer,
                                  0.35,
                                )!
                                .withValues(alpha: 0.92),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -32,
                    top: -40,
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 112,
                      color: colorScheme.primary.withValues(alpha: 0.06),
                    ),
                  ),
                  Positioned(
                    left: -24,
                    bottom: -28,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.tertiary.withValues(alpha: 0.12),
                      ),
                      child: const SizedBox.square(dimension: 88),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.smartStudyAssistant,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                  height: 1.15,
                                  color: onCont,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: colorScheme.outline
                                        .withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Text(
                                  dateLabel,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: onCont.withValues(alpha: 0.88),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 72,
                          height: 72,
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
                                color: colorScheme.primary
                                    .withValues(alpha: 0.38),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 62,
                                height: 62,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.onPrimary
                                      .withValues(alpha: 0.14),
                                ),
                              ),
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 32,
                                color: colorScheme.onPrimary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardGradientFrame extends StatelessWidget {
  const _DashboardGradientFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.16),
            colorScheme.tertiary.withValues(alpha: 0.1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.1),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.5),
        child: Material(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(22.5),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    );
  }
}

class _DashboardHeaderIcon extends StatelessWidget {
  const _DashboardHeaderIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer.withValues(alpha: 0.65),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, color: colorScheme.primary, size: 22),
      ),
    );
  }
}

class _DashboardGradientProgressBar extends StatelessWidget {
  const _DashboardGradientProgressBar({
    required this.progress,
    required this.colorScheme,
  });

  final double progress;
  final ColorScheme colorScheme;

  static const double _height = 11;

  @override
  Widget build(BuildContext context) {
    final track = Color.lerp(
      colorScheme.surfaceContainerHighest,
      colorScheme.surfaceContainerLow,
      0.45,
    )!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: _height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth * progress.clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: track),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: w,
                    height: _height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
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
    final safeProgress = total == 0 ? 0.0 : progress;

    return _DashboardGradientFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _DashboardHeaderIcon(icon: Icons.trending_up_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.todaysProgress,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DashboardGradientProgressBar(
              progress: safeProgress,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 14),
            if (total == 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 22,
                        color: colorScheme.primary.withValues(alpha: 0.75),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.todaysProgressNoSessions,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.completedTasks(completed, total),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    strings.percentComplete(percentLabel),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    strings.completedTasks(completed, total),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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

class _UpcomingDeadlinesCard extends StatelessWidget {
  const _UpcomingDeadlinesCard({
    required this.tasks,
    required this.onViewAll,
    required this.onToggle,
  });

  final List<AcademicTask> tasks;
  final VoidCallback onViewAll;
  final void Function(AcademicTask task) onToggle;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardGradientFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const _DashboardHeaderIcon(
                    icon: Icons.event_available_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.upcomingDeadlines,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onViewAll,
                    child: Text(strings.viewAllDeadlines),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 22,
                      color: colorScheme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.noUpcomingDeadlines,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ...tasks.map(
                (task) => Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onToggle(task),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Checkbox(
                              value: task.isCompleted,
                              onChanged: (_) => onToggle(task),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  [
                                    strings.academicTaskTypeLabel(
                                      task.type.name,
                                    ),
                                    _academicTaskDueLabel(
                                      context,
                                      strings,
                                      task,
                                    ),
                                  ].join(' • '),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
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
                ),
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
    required this.onStartFocus,
    required this.onEdit,
    required this.onDelete,
    this.onAddToSchedule,
  });

  final List<_SessionRow> rows;
  final String emptyMessage;
  final void Function(int index) onToggle;
  final void Function(int index) onStartFocus;
  final void Function(int index) onEdit;
  final void Function(int index) onDelete;
  final VoidCallback? onAddToSchedule;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DashboardGradientFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const _DashboardHeaderIcon(
                    icon: Icons.calendar_today_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.todaysStudyPlan,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.calendar_month_outlined,
                          size: 24,
                          color: colorScheme.primary.withValues(alpha: 0.72),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            emptyMessage,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (onAddToSchedule != null) ...[
                      const SizedBox(height: 16),
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
                        horizontal: 14,
                        vertical: 12,
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
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.title,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
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
                                  strings.minutesShort(
                                    row.session.durationMin,
                                  ),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => onEdit(index),
                            tooltip: strings.editScheduledSessionTooltip,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            onPressed: () => onDelete(index),
                            tooltip: strings.deleteScheduledSessionTooltip,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (!row.session.completed) ...[
                            IconButton.filledTonal(
                              onPressed: () => onStartFocus(index),
                              tooltip: strings.startFocusSessionTooltip,
                              icon: const Icon(
                                Icons.play_arrow_rounded,
                                size: 20,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: colorScheme.surface,
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer
                            .withValues(alpha: 0.85),
                        colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(icon, color: colorScheme.primary, size: 24),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
