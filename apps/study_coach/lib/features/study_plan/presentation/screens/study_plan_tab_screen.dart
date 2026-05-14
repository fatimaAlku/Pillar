import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/theme/pillar_theme.dart';
import '../../../../core/state/app_providers.dart';
import '../../../focus/presentation/screens/focus_session_screen.dart';
import '../../../profile/domain/entities/user_profile_data.dart';
import '../../../quizzes/domain/entities/quiz_history_entry.dart';
import '../../../recommendations/domain/entities/recommendation.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../../domain/entities/study_session.dart';
import '../controllers/study_plan_controller.dart';
import '../controllers/study_plan_firestore_providers.dart';
import '../widgets/add_to_schedule_bottom_sheet.dart';

class StudyPlanTabScreen extends ConsumerStatefulWidget {
  const StudyPlanTabScreen({super.key});

  @override
  ConsumerState<StudyPlanTabScreen> createState() => _StudyPlanTabScreenState();
}

class _StudyPlanTabScreenState extends ConsumerState<StudyPlanTabScreen> {
  late DateTime _selectedDate;

  /// Local override of the day's study budget. `null` follows the user's
  /// profile preference; otherwise the planner uses [_dayBudgetOverride].
  int? _dayBudgetOverride;

  @override
  void initState() {
    super.initState();
    _selectedDate = appTodayDateOnly();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
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
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
        }
        final topicsAsync =
            ref.watch(topicPerformanceInputsStreamProvider(user.uid));
        return topicsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (topics) =>
              _buildPlanScrollView(context, strings, user.uid, topics),
        );
      },
    );
  }

  Future<void> _confirmDeleteScheduledSession({
    required String uid,
    required _ScheduleItem item,
  }) async {
    final strings = AppStrings.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.deleteSessionTitle),
        content: Text(strings.deleteSessionConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(strings.deleteSessionAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(studySessionsRepositoryProvider).deleteSession(
            uid: uid,
            planId: item.planId,
            sessionId: item.sessionId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.sessionDeleted)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotDeleteSession)),
      );
    }
  }

  Future<void> _editScheduledSession({
    required String uid,
    required List<TopicPerformanceInput> topics,
    required _ScheduleItem item,
  }) async {
    if (topics.isEmpty || item.sessionId.isEmpty || item.planId.isEmpty) {
      return;
    }
    final strings = AppStrings.of(context);
    final idx = topics.indexWhere((t) => t.topicId == item.topicId);
    var topicSel = idx >= 0 ? topics[idx] : topics.first;
    double duration = item.durationMin.toDouble().clamp(15.0, 120.0);
    var sessionTime = TimeOfDay(
      hour: (item.startMinute ?? (17 * 60)) ~/ 60,
      minute: (item.startMinute ?? (17 * 60)) % 60,
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text(strings.editSessionTitle),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.topicForSession,
                        border: const OutlineInputBorder(),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<TopicPerformanceInput>(
                          isExpanded: true,
                          value: topicSel,
                          items: topics
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t.topicTitle == t.subjectTitle
                                        ? t.topicTitle
                                        : '${t.subjectTitle} — ${t.topicTitle}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setLocal(() => topicSel = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.studyTime,
                        border: const OutlineInputBorder(),
                      ),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: sessionTime,
                            );
                            if (picked == null) return;
                            setLocal(() => sessionTime = picked);
                          },
                          icon: const Icon(Icons.schedule_outlined, size: 18),
                          label: Text(
                            MaterialLocalizations.of(context)
                                .formatTimeOfDay(sessionTime),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: strings.sessionDuration,
                        border: const OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Slider(
                              min: 15,
                              max: 120,
                              divisions: 21,
                              value: duration,
                              label: '${duration.round()}',
                              onChanged: (v) => setLocal(() => duration = v),
                            ),
                          ),
                          Text('${duration.round()}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(strings.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(strings.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true || !mounted) return;
    final newTopicId = topicSel.topicId;
    final newDuration = duration.round();
    final newStartMinute = (sessionTime.hour * 60) + sessionTime.minute;
    if (newTopicId == item.topicId &&
        newDuration == item.durationMin &&
        newStartMinute == item.startMinute) {
      return;
    }
    try {
      await ref.read(studySessionsRepositoryProvider).updateSession(
            uid: uid,
            planId: item.planId,
            sessionId: item.sessionId,
            topicId: newTopicId != item.topicId ? newTopicId : null,
            durationMin: newDuration != item.durationMin ? newDuration : null,
            startMinute:
                newStartMinute != item.startMinute ? newStartMinute : null,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.sessionUpdated)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.couldNotUpdateSession)),
      );
    }
  }

  Future<void> _openAddToSchedule({
    required String uid,
    required List<TopicPerformanceInput> topics,
    required DateTime scheduleDate,
    String? initialTopicId,
    int? initialDurationMin,
    int? initialStartMinute,
  }) async {
    final strings = AppStrings.of(context);
    if (topics.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.noSubjectsForPersonalizedPlan)),
      );
      return;
    }
    final dateIso = DateFormat('yyyy-MM-dd').format(scheduleDate);
    await showAddToScheduleBottomSheet(
      context,
      strings: strings,
      topics: topics,
      scheduleDate: scheduleDate,
      initialTopicId: initialTopicId,
      initialDurationMin: initialDurationMin,
      initialStartMinute: initialStartMinute,
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

  void _openFocusSession({
    required String uid,
    required _ScheduleItem item,
    required DateTime scheduleDate,
  }) {
    if (item.planId.isEmpty || item.sessionId.isEmpty) return;
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FocusSessionScreen(
          uid: uid,
          topicTitle: item.title,
          session: StudySession(
            id: item.sessionId,
            planId: item.planId,
            topicId: item.topicId,
            date: DateFormat('yyyy-MM-dd').format(scheduleDate),
            durationMin: item.durationMin,
            startMinute: item.startMinute,
            completed: item.completed,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanScrollView(
    BuildContext context,
    AppStrings strings,
    String uid,
    List<TopicPerformanceInput> topics,
  ) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final days = _buildWeekDays(anchor: _selectedDate);
    final quizHistory =
        ref.watch(quizHistoryStreamProvider(uid)).valueOrNull ?? const [];
    final latestRecommendation =
        ref.watch(latestRecommendationProvider(uid)).valueOrNull;
    final enrichedTopics =
        ref.watch(enrichedTopicPerformanceInputsProvider(uid));
    final baseTopicsForPlanning = enrichedTopics.isEmpty
        ? _applyPerformanceSignals(topics, quizHistory)
        : enrichedTopics;
    final topicsForPlanning = _applyRecommendationSignals(
      baseTopicsForPlanning,
      latestRecommendation,
    );
    final preferredMinutes = ref
            .watch(userProfileStreamProvider(uid))
            .valueOrNull
            ?.dailyStudyMinutes ??
        UserProfileData.defaultDailyStudyMinutes;
    final dayBudget = _dayBudgetOverride ?? preferredMinutes;
    final input = StudyPlanPersonalizationInput(
      topics: topicsForPlanning,
      availableStudyMinutes: dayBudget,
      now: appNowInstant(),
    );
    final dynamicResult = ref.watch(studyPlanDynamicResultProvider(input));
    final tasks = dynamicResult.updatedPlan;
    final dateIso = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final sessionsAsync = ref
        .watch(sessionsForDateStreamProvider(SessionsForDateKey(uid, dateIso)));

    final allocatedMinutes = tasks.fold<int>(
      0,
      (acc, task) => acc + task.recommendedMinutes,
    );
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _CalendarHeader(
          selectedDate: _selectedDate,
          days: days,
          onDayTap: (d) => setState(() => _selectedDate = d),
          onPickDate: _pickDate,
        ),
        const SizedBox(height: 18),
        _PlanPrimaryCta(
          onPressed: topics.isEmpty
              ? null
              : () => _openAddToSchedule(
                    uid: uid,
                    topics: topics,
                    scheduleDate: _selectedDate,
                  ),
          icon: const Icon(Icons.add_rounded),
          label: Text(strings.addSchedule),
        ),
        const SizedBox(height: 14),
        if (topics.isNotEmpty)
          _DayBudgetPill(
            selectedDate: _selectedDate,
            currentMinutes: dayBudget,
            preferredMinutes: preferredMinutes,
            allocatedMinutes: allocatedMinutes,
            onChanged: (minutes) =>
                setState(() => _dayBudgetOverride = minutes),
          ),
        if (topics.isNotEmpty) const SizedBox(height: 12),
        _ScheduleRecommendationsCard(
          uid: uid,
          topics: topicsForPlanning,
          selectedDate: _selectedDate,
          history: quizHistory,
          latestRecommendation: latestRecommendation,
          dynamicResult: dynamicResult,
        ),
        const SizedBox(height: 20),
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
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    _formatDateHeader(_selectedDate, localeCode),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 24,
                  color: colorScheme.primary.withValues(alpha: 0.75),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    strings.noSubjectsForPersonalizedPlan,
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
          sessionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text('$e'),
            ),
            data: (sessionsForDay) {
              final daySchedule = _buildScheduleFromSessionsAndTasks(
                sessions: sessionsForDay,
                tasks: tasks,
                topics: topics,
                date: _selectedDate,
                localeCode: localeCode,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (daySchedule.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.event_available_outlined,
                            size: 24,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              strings.planDayNothingScheduled,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.4,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...daySchedule.map(
                      (item) => _ScheduleCard(
                        item: item,
                        onStartFocus: item.canStartFocus
                            ? () => _openFocusSession(
                                  uid: uid,
                                  item: item,
                                  scheduleDate: _selectedDate,
                                )
                            : null,
                        onEditSession:
                            item.sessionId.isNotEmpty && item.planId.isNotEmpty
                                ? () => _editScheduledSession(
                                      uid: uid,
                                      topics: topics,
                                      item: item,
                                    )
                                : null,
                        onDeleteSession:
                            item.sessionId.isNotEmpty && item.planId.isNotEmpty
                                ? () => _confirmDeleteScheduledSession(
                                      uid: uid,
                                      item: item,
                                    )
                                : null,
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final today = appTodayDateOnly();
    final picked = await showDatePicker(
      context: context,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365 * 2)),
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
  }
}

class _PlanGradientFrame extends StatelessWidget {
  const _PlanGradientFrame({required this.child});

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

class _PlanSectionIcon extends StatelessWidget {
  const _PlanSectionIcon({required this.icon});

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

class _PlanPrimaryCta extends StatelessWidget {
  const _PlanPrimaryCta({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onPrimary = colorScheme.onPrimary;
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primary,
                  Color.lerp(
                        colorScheme.primary,
                        colorScheme.tertiary,
                        0.75,
                      )!,
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.32),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(color: onPrimary, size: 22),
                    child: icon,
                  ),
                  const SizedBox(width: 10),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.titleSmall!.copyWith(
                      color: onPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                    child: label,
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

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader({
    required this.selectedDate,
    required this.days,
    required this.onDayTap,
    required this.onPickDate,
  });

  final DateTime selectedDate;
  final List<DateTime> days;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final localeCode = Localizations.localeOf(context).languageCode;
    final onCont = colorScheme.onPrimaryContainer;

    return Card(
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
              right: -28,
              top: -36,
              child: Icon(
                Icons.calendar_month_rounded,
                size: 108,
                color: colorScheme.primary.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.tertiary.withValues(alpha: 0.12),
                ),
                child: const SizedBox.square(dimension: 80),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(10),
                          minimumSize: const Size(42, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onPickDate,
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                      ),
                      Expanded(
                        child: Text(
                          _formatMonthYear(selectedDate, localeCode),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: onCont,
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(10),
                          minimumSize: const Size(42, 42),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: onPickDate,
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: days.map((day) {
                        final selected = _isSameDay(day, selectedDate);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _DayChip(
                            date: day,
                            selected: selected,
                            onTap: () => onDayTap(day),
                          ),
                        );
                      }).toList(),
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

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      colorScheme.primary,
                      Color.lerp(
                            colorScheme.primary,
                            colorScheme.tertiary,
                            0.72,
                          )!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : colorScheme.surface,
            border: selected
                ? null
                : Border.all(
                    color:
                        colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SizedBox(
              width: 54,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _weekdayShort(date, localeCode),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
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

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    this.onStartFocus,
    this.onEditSession,
    this.onDeleteSession,
  });

  final _ScheduleItem item;
  final VoidCallback? onStartFocus;
  final VoidCallback? onEditSession;
  final VoidCallback? onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = switch (item.priorityBand) {
      _PriorityBand.high => PillarColors.priorityHigh,
      _PriorityBand.medium => PillarColors.priorityMedium,
      _PriorityBand.low => colorScheme.primary,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(
              item.timeLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PlanGradientFrame(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: priorityColor.withValues(alpha: 0.45),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (onStartFocus != null)
                          IconButton.filledTonal(
                            onPressed: onStartFocus,
                            tooltip: strings.startFocusSessionTooltip,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (onEditSession != null)
                          IconButton(
                            onPressed: onEditSession,
                            tooltip: strings.editScheduledSessionTooltip,
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        if (onDeleteSession != null)
                          IconButton(
                            onPressed: onDeleteSession,
                            tooltip: strings.deleteScheduledSessionTooltip,
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              size: 20,
                              color: colorScheme.error,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      strings.scheduleMeta(item.subject, item.durationMin),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (item.isAiSuggested) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'AI Suggested',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (item.performancePercentLabel != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            size: 14,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Performance: ${item.performancePercentLabel}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              item.performanceStatusLabel ?? 'Baseline',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (item.adjustmentReason != null &&
                        item.adjustmentReason!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Adapted for ${_localizedReason(strings, item.adjustmentReason)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (item.missedSessions > 0 ||
                        item.daysSinceLastStudied != null) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (item.missedSessions > 0)
                            _SignalChip(
                              icon: Icons.history_toggle_off_outlined,
                              label: strings
                                  .missedSessionsBadge(item.missedSessions),
                              color: PillarColors.priorityHigh,
                            ),
                          if (item.daysSinceLastStudied != null)
                            _SignalChip(
                              icon: Icons.schedule_rounded,
                              label: strings
                                  .lastStudiedAgo(item.daysSinceLastStudied!),
                              color: colorScheme.primary,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalChip extends StatelessWidget {
  const _SignalChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleRecommendationsCard extends ConsumerWidget {
  const _ScheduleRecommendationsCard({
    required this.uid,
    required this.topics,
    required this.selectedDate,
    required this.history,
    required this.latestRecommendation,
    required this.dynamicResult,
  });

  final String uid;
  final List<TopicPerformanceInput> topics;
  final DateTime selectedDate;
  final List<QuizHistoryEntry> history;
  final Recommendation? latestRecommendation;
  final StudyPlanAdjustmentResult dynamicResult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recommendationWeakAreas = _recommendationWeakAreas(
      latestRecommendation,
    );
    final weakTopicTitles = recommendationWeakAreas.isNotEmpty
        ? recommendationWeakAreas
            .map((area) => _mapWeakAreaToTopicTitle(area, topics))
            .where((item) => item.trim().isNotEmpty)
            .take(4)
            .toList(growable: false)
        : _weakTopicTitlesFromHistory(history, topics);
    final backendRecommendationText =
        latestRecommendation?.recommendationText.trim() ?? '';
    final recommendationText = backendRecommendationText.isNotEmpty
        ? backendRecommendationText
        : weakTopicTitles.isEmpty
            ? (history.isEmpty
                ? 'Complete a quiz to unlock personalized recommendations.'
                : strings.noWeakTopics)
            : 'Focus on ${weakTopicTitles.take(2).join(' and ')} in your next sessions.';
    final recommendationPlanChangeText = _recommendationPlanChangeText(
      strings: strings,
      selectedDate: selectedDate,
      recommendation: latestRecommendation,
      plan: dynamicResult.updatedPlan,
    );
    final showPlanChangeExplanation = _isTodayOrFuture(selectedDate) &&
        dynamicResult.updatedPlan.any(
          (item) =>
              item.recommendedMinutes > 0 &&
              (item.adjustmentReason ?? 'baseline personalization')
                      .trim()
                      .toLowerCase() !=
                  'baseline personalization',
        );
    final topAdjustedTopics = dynamicResult.updatedPlan
        .where((item) => item.recommendedMinutes > 0)
        .take(3)
        .map(
          (item) => strings.adjustedTopicLine(
            item.topicTitle,
            _localizedReason(strings, item.adjustmentReason),
          ),
        )
        .toList(growable: false);

    return ExcludeSemantics(
      child: _PlanGradientFrame(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => _refreshRecommendationsAndPlan(
                      context,
                      ref,
                      strings,
                      uid,
                    ),
                    borderRadius: BorderRadius.circular(999),
                    child: const _PlanSectionIcon(
                      icon: Icons.psychology_alt_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.aiSuggestion,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.15,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: strings.refreshRecommendations,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _refreshRecommendationsAndPlan(
                      context,
                      ref,
                      strings,
                      uid,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                recommendationText,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
              ),
              if ((latestRecommendation?.generatedAtIso ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  strings.lastGeneratedAt(
                    _formatRecommendationGeneratedAt(
                      context,
                      latestRecommendation!.generatedAtIso,
                    ),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
              if (showPlanChangeExplanation) ...[
                const SizedBox(height: 10),
                Text(
                  strings.whyThisPlanChanged,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  recommendationPlanChangeText ??
                      dynamicResult.explanationMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                if (topAdjustedTopics.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    strings.planAdjustedReasonsHeader,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topAdjustedTopics.join('\n'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                strings.weakTopics,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  if (weakTopicTitles.isEmpty) {
                    return Text(
                      strings.noWeakTopics,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    );
                  }
                  return Text(
                    weakTopicTitles.join(' • '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _refreshRecommendationsAndPlan(
  BuildContext context,
  WidgetRef ref,
  AppStrings strings,
  String uid,
) async {
  try {
    await ref.read(recommendationsRepositoryProvider).generateRecommendations();
    await ref.read(studyPlanRepositoryProvider).rebalanceStudyPlan();
    ref.invalidate(latestRecommendationProvider(uid));
    ref.invalidate(quizHistoryStreamProvider(uid));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.recommendationsUpdated)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.couldNotGenerateRecommendations)),
    );
  }
}

List<_ScheduleItem> _buildScheduleFromSessionsAndTasks({
  required List<StudySession> sessions,
  required List<StudyTaskPriority> tasks,
  required List<TopicPerformanceInput> topics,
  required DateTime date,
  required String localeCode,
}) {
  if (sessions.isEmpty && _isTodayOrFuture(date)) {
    return _buildSuggestedScheduleFromTasks(
      tasks: tasks,
      date: date,
      localeCode: localeCode,
      topics: topics,
    );
  }
  final taskByTopic = <String, StudyTaskPriority>{};
  for (final t in tasks) {
    taskByTopic.putIfAbsent(t.topicId, () => t);
  }
  final topicById = <String, TopicPerformanceInput>{};
  final subjectTitleById = <String, String>{};
  for (final t in topics) {
    topicById[t.topicId] = t;
    if (t.subjectId.trim().isNotEmpty && t.subjectTitle.trim().isNotEmpty) {
      subjectTitleById[t.subjectId] = t.subjectTitle;
    }
  }
  final sorted = List<StudySession>.from(sessions)
    ..sort((a, b) {
      final aMinute = a.startMinute;
      final bMinute = b.startMinute;
      if (aMinute != null && bMinute != null) {
        final byTime = aMinute.compareTo(bMinute);
        if (byTime != 0) return byTime;
      } else if (aMinute != null) {
        return -1;
      } else if (bMinute != null) {
        return 1;
      }
      return a.topicId.compareTo(b.topicId);
    });

  final startHour = _isSameDay(date, appTodayDateOnly()) ? 17 : 15;
  var current = DateTime(date.year, date.month, date.day, startHour);
  final items = <_ScheduleItem>[];

  for (final session in sorted) {
    final sessionStart = session.startMinute == null
        ? current
        : DateTime(
            date.year,
            date.month,
            date.day,
            session.startMinute! ~/ 60,
            session.startMinute! % 60,
          );
    final timeLabel = _formatTime(sessionStart, localeCode);
    items.add(
      _ScheduleItem.fromSessionContext(
        session: session,
        timeLabel: timeLabel,
        task: taskByTopic[session.topicId],
        topic: topicById[session.topicId],
        subjectTitleById: subjectTitleById,
      ),
    );
    current = sessionStart.add(Duration(minutes: session.durationMin + 10));
  }
  return items;
}

List<_ScheduleItem> _buildSuggestedScheduleFromTasks({
  required List<StudyTaskPriority> tasks,
  required DateTime date,
  required String localeCode,
  required List<TopicPerformanceInput> topics,
}) {
  if (tasks.isEmpty) return const [];
  final today = appTodayDateOnly();
  final startHour = _isSameDay(date, today) ? 17 : 15;
  var current = DateTime(date.year, date.month, date.day, startHour);
  final topicById = <String, TopicPerformanceInput>{
    for (final t in topics) t.topicId: t,
  };
  final items = <_ScheduleItem>[];
  for (final task in tasks) {
    if (task.recommendedMinutes <= 0) continue;
    final timeLabel = _formatTime(current, localeCode);
    items.add(
      _ScheduleItem.fromTask(
        task,
        timeLabel: timeLabel,
        topic: topicById[task.topicId],
        today: today,
      ),
    );
    current = current.add(Duration(minutes: task.recommendedMinutes + 10));
  }
  return items;
}

List<DateTime> _buildWeekDays({required DateTime anchor}) {
  final day = _dateOnly(anchor);
  final monday = day.subtract(Duration(days: day.weekday - 1));
  return List.generate(7, (i) => monday.add(Duration(days: i)));
}

String _weekdayShort(DateTime d, String localeCode) {
  return DateFormat('EEE', localeCode).format(d);
}

String _formatMonthYear(DateTime d, String localeCode) {
  return DateFormat('MMMM y', localeCode).format(d);
}

String _formatDateHeader(DateTime d, String localeCode) {
  return DateFormat('EEEE d', localeCode).format(d);
}

String _formatTime(DateTime d, String localeCode) {
  return DateFormat.jm(localeCode).format(d);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isTomorrow(DateTime date) {
  final tomorrow = appTodayDateOnly().add(const Duration(days: 1));
  return _isSameDay(_dateOnly(date), tomorrow);
}

bool _isTodayOrFuture(DateTime date) {
  final today = appTodayDateOnly();
  final candidate = _dateOnly(date);
  return !candidate.isBefore(today);
}

class _ScheduleItem {
  const _ScheduleItem({
    required this.planId,
    required this.sessionId,
    required this.topicId,
    required this.timeLabel,
    required this.title,
    required this.subject,
    required this.durationMin,
    required this.startMinute,
    required this.scoreLabel,
    required this.deadlineLabel,
    required this.weaknessLabel,
    required this.difficultyLabel,
    required this.recencyLabel,
    required this.performancePercentLabel,
    required this.performanceStatusLabel,
    required this.adjustmentReason,
    required this.adjustmentReasonLocalizationKey,
    required this.missedSessions,
    required this.daysSinceLastStudied,
    required this.isAiSuggested,
    required this.completed,
    required this.priorityBand,
  });

  factory _ScheduleItem.fromSessionContext({
    required StudySession session,
    required String timeLabel,
    StudyTaskPriority? task,
    TopicPerformanceInput? topic,
    Map<String, String> subjectTitleById = const {},
  }) {
    // Server-side reason is the source of truth when present; fall back to the
    // client-computed reason from the personalization service.
    final serverReason = session.reason?.trim();
    final hasServerReason = serverReason != null && serverReason.isNotEmpty;

    if (task != null) {
      final fromTask = _ScheduleItem.fromTask(
        task,
        timeLabel: timeLabel,
        planId: session.planId,
        sessionId: session.id,
        topic: topic,
        today: appTodayDateOnly(),
      );
      final effectiveReason =
          hasServerReason ? serverReason : fromTask.adjustmentReason;
      final effectiveReasonKey = hasServerReason
          ? serverReason.toLowerCase()
          : fromTask.adjustmentReasonLocalizationKey;
      return _ScheduleItem(
        planId: fromTask.planId,
        sessionId: fromTask.sessionId,
        topicId: fromTask.topicId,
        timeLabel: fromTask.timeLabel,
        title: fromTask.title,
        subject: fromTask.subject,
        durationMin: session.durationMin,
        startMinute: session.startMinute,
        scoreLabel: fromTask.scoreLabel,
        deadlineLabel: fromTask.deadlineLabel,
        weaknessLabel: fromTask.weaknessLabel,
        difficultyLabel: fromTask.difficultyLabel,
        recencyLabel: fromTask.recencyLabel,
        performancePercentLabel: fromTask.performancePercentLabel,
        performanceStatusLabel: fromTask.performanceStatusLabel,
        adjustmentReason: effectiveReason,
        adjustmentReasonLocalizationKey: effectiveReasonKey,
        missedSessions: fromTask.missedSessions,
        daysSinceLastStudied: fromTask.daysSinceLastStudied,
        isAiSuggested: fromTask.isAiSuggested,
        completed: session.completed,
        priorityBand: fromTask.priorityBand,
      );
    }
    final title = topic?.topicTitle ??
        _fallbackTitleFromTopicId(
          session.topicId,
          subjectTitleById: subjectTitleById,
        );
    final subject = topic?.subjectTitle ?? '';
    return _ScheduleItem(
      planId: session.planId,
      sessionId: session.id,
      topicId: session.topicId,
      timeLabel: timeLabel,
      title: title.isEmpty
          ? _fallbackTitleFromTopicId(
              session.topicId,
              subjectTitleById: subjectTitleById,
            )
          : title,
      subject: subject,
      durationMin: session.durationMin,
      startMinute: session.startMinute,
      scoreLabel: '–',
      deadlineLabel: '–',
      weaknessLabel: '–',
      difficultyLabel: '–',
      recencyLabel: '–',
      performancePercentLabel: null,
      performanceStatusLabel: null,
      adjustmentReason: hasServerReason ? serverReason : null,
      adjustmentReasonLocalizationKey:
          hasServerReason ? serverReason.toLowerCase() : null,
      missedSessions: topic?.missedSessions ?? 0,
      daysSinceLastStudied: _daysSince(topic?.lastStudiedAt),
      isAiSuggested: false,
      completed: session.completed,
      priorityBand: _PriorityBand.low,
    );
  }

  factory _ScheduleItem.fromTask(
    StudyTaskPriority task, {
    required String timeLabel,
    String planId = '',
    String sessionId = '',
    TopicPerformanceInput? topic,
    DateTime? today,
  }) {
    final band = task.priorityScore >= 3
        ? _PriorityBand.high
        : task.priorityScore >= 2
            ? _PriorityBand.medium
            : _PriorityBand.low;
    final reasonKey = (task.adjustmentReason ?? '').trim().toLowerCase();
    return _ScheduleItem(
      planId: planId,
      sessionId: sessionId,
      topicId: task.topicId,
      timeLabel: timeLabel,
      title: task.topicTitle,
      subject: task.subjectTitle,
      durationMin: task.recommendedMinutes,
      startMinute: null,
      scoreLabel: task.priorityScore.toStringAsFixed(2),
      deadlineLabel: task.deadlineUrgency.toStringAsFixed(2),
      weaknessLabel: task.weakness.toStringAsFixed(2),
      difficultyLabel: task.difficulty.toStringAsFixed(2),
      recencyLabel: task.timeSinceLastStudied.toStringAsFixed(2),
      performancePercentLabel:
          '${((1 - task.weakness).clamp(0.0, 1.0) * 100).round()}%',
      performanceStatusLabel: _performanceStatusLabel(task.weakness),
      adjustmentReason: task.adjustmentReason,
      adjustmentReasonLocalizationKey: reasonKey.isEmpty ? null : reasonKey,
      missedSessions: topic?.missedSessions ?? 0,
      daysSinceLastStudied: _daysSince(topic?.lastStudiedAt, today: today),
      isAiSuggested: planId.isEmpty && sessionId.isEmpty,
      completed: false,
      priorityBand: band,
    );
  }

  final String planId;
  final String sessionId;
  final String topicId;
  final String timeLabel;
  final String title;
  final String subject;
  final int durationMin;
  final int? startMinute;
  final String scoreLabel;
  final String deadlineLabel;
  final String weaknessLabel;
  final String difficultyLabel;
  final String recencyLabel;
  final String? performancePercentLabel;
  final String? performanceStatusLabel;
  final String? adjustmentReason;
  final String? adjustmentReasonLocalizationKey;
  final int missedSessions;
  final int? daysSinceLastStudied;
  final bool isAiSuggested;
  final bool completed;
  final _PriorityBand priorityBand;

  bool get canStartFocus =>
      planId.isNotEmpty && sessionId.isNotEmpty && !completed;
}

int? _daysSince(DateTime? date, {DateTime? today}) {
  if (date == null) return null;
  final today0 = today ?? appTodayDateOnly();
  final candidate = DateTime(date.year, date.month, date.day);
  return today0.difference(candidate).inDays;
}

String _performanceStatusLabel(double weakness) {
  if (weakness >= 0.7) return 'Needs focus';
  if (weakness >= 0.45) return 'Improving';
  return 'Strong';
}

String _localizedReason(AppStrings strings, String? rawReason) {
  final normalized = (rawReason ?? '').trim().toLowerCase();
  switch (normalized) {
    case 'low quiz performance':
      return strings.reasonLowQuiz;
    case 'upcoming exam':
      return strings.reasonExamSoon;
    case 'missed sessions':
      return strings.reasonMissed;
    case 'long time since last study':
      return strings.reasonStale;
    case 'baseline personalization':
    case '':
      return strings.reasonBaseline;
    default:
      return rawReason ?? strings.reasonBaseline;
  }
}

String _formatRecommendationGeneratedAt(BuildContext context, String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final localeCode = Localizations.localeOf(context).languageCode;
  return DateFormat.yMMMd(localeCode).add_jm().format(parsed.toLocal());
}

String _planDayInlineLabel(AppStrings strings, DateTime date) {
  if (_isSameDay(date, appTodayDateOnly())) {
    return strings.planDayTodayInline;
  }
  if (_isTomorrow(date)) {
    return strings.planDayTomorrowInline;
  }
  return strings.planDaySelectedInline;
}

String? _recommendationPlanChangeText({
  required AppStrings strings,
  required DateTime selectedDate,
  required Recommendation? recommendation,
  required List<StudyTaskPriority> plan,
}) {
  if (!_isTodayOrFuture(selectedDate) || recommendation == null) return null;
  for (final task in plan) {
    if (task.recommendedMinutes <= 0) continue;
    if (_topicMatchesRecommendation(task.topicTitle, recommendation)) {
      return strings.recommendationPlanChanged(
        task.topicTitle,
        _planDayInlineLabel(strings, selectedDate),
      );
    }
  }
  return null;
}

List<String> _recommendationWeakAreas(Recommendation? recommendation) {
  if (recommendation == null) return const [];
  final areas = <String>[];
  final seen = <String>{};
  void addArea(String value) {
    final trimmed = value.trim();
    final normalized = _normalizePerformanceKey(trimmed);
    if (trimmed.isEmpty || normalized.isEmpty || !seen.add(normalized)) {
      return;
    }
    areas.add(trimmed);
  }

  for (final weakArea in recommendation.weakAreas) {
    addArea(weakArea);
  }
  for (final entry in recommendation.confidenceByTopic.entries) {
    if (entry.value < 0.6) {
      addArea(entry.key);
    }
  }
  return areas;
}

List<String> _weakTopicTitlesFromHistory(
  List<QuizHistoryEntry> history,
  List<TopicPerformanceInput> topics,
) {
  final weakCounts = <String, int>{};
  for (final entry in history.take(10)) {
    for (final weak in entry.weakTopicTitles) {
      final key = weak.trim();
      if (key.isEmpty) continue;
      weakCounts[key] = (weakCounts[key] ?? 0) + 1;
    }
  }
  final visibleWeakAreas = weakCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return visibleWeakAreas
      .map((e) => _mapWeakAreaToTopicTitle(e.key, topics))
      .where((item) => item.trim().isNotEmpty)
      .take(4)
      .toList(growable: false);
}

String _mapWeakAreaToTopicTitle(
  String weakArea,
  List<TopicPerformanceInput> topics,
) {
  final normalizedWeak = _normalizePerformanceKey(weakArea);
  for (final topic in topics) {
    final title = topic.topicTitle.trim();
    if (title.isEmpty) continue;
    final normalizedTitle = _normalizePerformanceKey(title);
    if (_performanceKeysMatch(normalizedWeak, normalizedTitle)) {
      return title;
    }
  }
  return weakArea.replaceAll('_', ' ');
}

bool _topicMatchesRecommendation(
  String topicTitle,
  Recommendation recommendation,
) {
  final topicKey = _normalizePerformanceKey(topicTitle);
  if (topicKey.isEmpty) return false;
  return _recommendationWeakAreas(recommendation).any(
    (area) => _performanceKeysMatch(
      topicKey,
      _normalizePerformanceKey(area),
    ),
  );
}

bool _performanceKeysMatch(String a, String b) {
  if (a.isEmpty || b.isEmpty) return false;
  return a.contains(b) || b.contains(a);
}

class _DayBudgetPill extends StatelessWidget {
  const _DayBudgetPill({
    required this.selectedDate,
    required this.currentMinutes,
    required this.preferredMinutes,
    required this.allocatedMinutes,
    required this.onChanged,
  });

  /// Lightweight options so changing the day's budget feels instant. Picked
  /// to bracket common study sessions without overwhelming the UI.
  static const List<int> _options = [30, 60, 90, 120, 180, 240];

  final DateTime selectedDate;
  final int currentMinutes;
  final int preferredMinutes;
  final int allocatedMinutes;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final today = appTodayDateOnly();
    String label;
    if (_isSameDay(selectedDate, today)) {
      label = strings.planTodayMinutesLabel;
    } else if (_isTomorrow(selectedDate)) {
      label = strings.planTomorrowMinutesLabel;
    } else {
      label = strings.planUpcomingMinutesLabel;
    }
    final canReset = currentMinutes != preferredMinutes;

    return _PlanGradientFrame(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _PlanSectionIcon(icon: Icons.timer_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
              Text(
                strings.dailyStudyBudgetValue(currentMinutes),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (canReset)
                IconButton(
                  tooltip: strings.clearExamDate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onPressed: () => onChanged(null),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final minutes = _options[index];
                final isSelected = currentMinutes == minutes;
                return ChoiceChip(
                  label: Text(strings.dailyStudyBudgetValue(minutes)),
                  selected: isSelected,
                  onSelected: (picked) => onChanged(picked ? minutes : null),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.planMinutesAllocatedSummary(
              allocatedMinutes,
              currentMinutes,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ),
    );
  }
}

enum _PriorityBand { high, medium, low }

List<TopicPerformanceInput> _applyPerformanceSignals(
  List<TopicPerformanceInput> topics,
  List<QuizHistoryEntry> history,
) {
  if (topics.isEmpty) return const [];
  if (history.isEmpty) return topics;

  final scores =
      history.map((entry) => entry.scoreFraction).toList(growable: false);
  final baseline = scores.isEmpty
      ? 0.5
      : (scores.reduce((a, b) => a + b) / scores.length).clamp(0.0, 1.0);

  final weakCounts = <String, int>{};
  for (final entry in history.take(20)) {
    for (final weak in entry.weakTopicTitles) {
      final key = _normalizePerformanceKey(weak);
      if (key.isEmpty) continue;
      weakCounts[key] = (weakCounts[key] ?? 0) + 1;
    }
  }

  return topics.map((topic) {
    final normalizedTopic = _normalizePerformanceKey(topic.topicTitle);
    var weakHits = 0;
    weakCounts.forEach((weakKey, count) {
      if (weakKey.contains(normalizedTopic) ||
          normalizedTopic.contains(weakKey)) {
        weakHits += count;
      }
    });
    final penalty = weakHits <= 0 ? 0.0 : (weakHits * 0.12).clamp(0.0, 0.45);
    final derivedAccuracy = (baseline - penalty).clamp(0.0, 1.0);
    return TopicPerformanceInput(
      topicId: topic.topicId,
      topicTitle: topic.topicTitle,
      subjectId: topic.subjectId,
      subjectTitle: topic.subjectTitle,
      examDate: topic.examDate,
      quizAccuracy: derivedAccuracy,
      subjectDifficulty: topic.subjectDifficulty,
      lastStudiedAt: topic.lastStudiedAt,
      missedSessions: topic.missedSessions,
    );
  }).toList(growable: false);
}

List<TopicPerformanceInput> _applyRecommendationSignals(
  List<TopicPerformanceInput> topics,
  Recommendation? recommendation,
) {
  if (topics.isEmpty || recommendation == null) return topics;
  final weakAreas = _recommendationWeakAreas(recommendation);
  if (weakAreas.isEmpty) return topics;

  return topics.map((topic) {
    final matchingConfidence = _confidenceForTopic(
      recommendation,
      topic.topicTitle,
    );
    final isRecommendationWeak = weakAreas.any(
      (area) => _performanceKeysMatch(
        _normalizePerformanceKey(topic.topicTitle),
        _normalizePerformanceKey(area),
      ),
    );
    if (!isRecommendationWeak && matchingConfidence == null) {
      return topic;
    }
    final cap = matchingConfidence != null && matchingConfidence < 0.6
        ? matchingConfidence
        : 0.45;
    final adjustedAccuracy =
        topic.quizAccuracy > cap ? cap : topic.quizAccuracy;
    return TopicPerformanceInput(
      topicId: topic.topicId,
      topicTitle: topic.topicTitle,
      subjectId: topic.subjectId,
      subjectTitle: topic.subjectTitle,
      examDate: topic.examDate,
      quizAccuracy: adjustedAccuracy,
      subjectDifficulty: topic.subjectDifficulty,
      lastStudiedAt: topic.lastStudiedAt,
      missedSessions: topic.missedSessions,
    );
  }).toList(growable: false);
}

double? _confidenceForTopic(
  Recommendation recommendation,
  String topicTitle,
) {
  final topicKey = _normalizePerformanceKey(topicTitle);
  if (topicKey.isEmpty) return null;
  for (final entry in recommendation.confidenceByTopic.entries) {
    final confidenceKey = _normalizePerformanceKey(entry.key);
    if (_performanceKeysMatch(topicKey, confidenceKey)) {
      return entry.value.clamp(0.0, 1.0).toDouble();
    }
  }
  return null;
}

String _normalizePerformanceKey(String value) {
  return value.trim().toLowerCase().replaceAll('_', ' ');
}

String _fallbackTitleFromTopicId(
  String topicId, {
  Map<String, String> subjectTitleById = const {},
}) {
  final raw = topicId.trim();
  if (raw.isEmpty) return 'Topic';
  const syntheticPrefix = 'subject_';
  const syntheticSuffix = '_overview';
  if (raw.startsWith(syntheticPrefix) && raw.endsWith(syntheticSuffix)) {
    final subjectId = raw.substring(
        syntheticPrefix.length, raw.length - syntheticSuffix.length);
    final subjectTitle = subjectTitleById[subjectId]?.trim() ?? '';
    if (subjectTitle.isNotEmpty) {
      return '$subjectTitle overview';
    }
    return 'Course overview';
  }
  return raw;
}
