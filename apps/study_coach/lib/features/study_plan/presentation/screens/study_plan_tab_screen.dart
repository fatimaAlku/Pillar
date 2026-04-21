import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';
import '../../../../core/state/app_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
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
                              onChanged: (v) =>
                                  setLocal(() => duration = v),
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
    if (newTopicId == item.topicId && newDuration == item.durationMin) {
      return;
    }
    try {
      await ref.read(studySessionsRepositoryProvider).updateSession(
            uid: uid,
            planId: item.planId,
            sessionId: item.sessionId,
            topicId: newTopicId != item.topicId ? newTopicId : null,
            durationMin: newDuration != item.durationMin ? newDuration : null,
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
      onSave: (topicId, durationMin) async {
        await ref.read(studySessionsRepositoryProvider).addSession(
              uid: uid,
              topicId: topicId,
              dateIso: dateIso,
              durationMin: durationMin,
            );
      },
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
    final input = StudyPlanPersonalizationInput(
      topics: topics,
      availableStudyMinutes: 180,
      now: DateTime.now(),
    );
    final tasks =
        ref.watch(studyPlanDynamicResultProvider(input)).updatedPlan;
    final dateIso = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final sessionsAsync =
        ref.watch(sessionsForDateStreamProvider(SessionsForDateKey(uid, dateIso)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _CalendarHeader(
          selectedDate: _selectedDate,
          days: days,
          onDayTap: (d) => setState(() => _selectedDate = d),
          onPickDate: _pickDate,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: topics.isEmpty
              ? null
              : () => _openAddToSchedule(
                    uid: uid,
                    topics: topics,
                    scheduleDate: _selectedDate,
                  ),
          icon: const Icon(Icons.add),
          label: Text(strings.addSchedule),
        ),
        const SizedBox(height: 18),
        Text(
          _formatDateHeader(_selectedDate, localeCode),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (topics.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              strings.noSubjectsForPersonalizedPlan,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        strings.planDayNothingScheduled,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    )
                  else
                    ...daySchedule.map(
                      (item) => _ScheduleCard(
                        item: item,
                        onAddToSchedule: () => _openAddToSchedule(
                          uid: uid,
                          topics: topics,
                          scheduleDate: _selectedDate,
                          initialTopicId: item.topicId,
                          initialDurationMin: item.durationMin,
                        ),
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
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: _selectedDate,
    );
    if (picked == null) return;
    setState(() => _selectedDate = _dateOnly(picked));
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
    final color = theme.colorScheme.primaryContainer;
    final localeCode = Localizations.localeOf(context).languageCode;

    return Card(
      elevation: 0,
      color: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    _formatMonthYear(selectedDate, localeCode),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
    final bg = selected ? colorScheme.onSurface : colorScheme.surface;
    final fg = selected ? colorScheme.surface : colorScheme.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 54,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              Text(
                _weekdayShort(date, localeCode),
                style: theme.textTheme.labelSmall?.copyWith(color: fg),
              ),
              const SizedBox(height: 6),
              Text(
                '${date.day}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({
    required this.item,
    this.onAddToSchedule,
    this.onEditSession,
    this.onDeleteSession,
  });

  final _ScheduleItem item;
  final VoidCallback? onAddToSchedule;
  final VoidCallback? onEditSession;
  final VoidCallback? onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = switch (item.priorityBand) {
      _PriorityBand.high => const Color(0xFFD34A6A),
      _PriorityBand.medium => const Color(0xFFE09B2D),
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
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.75),
                ),
              ),
              color: colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: priorityColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                    const SizedBox(height: 6),
                    Text(
                      strings.priorityBreakdown(
                        item.scoreLabel,
                        item.deadlineLabel,
                        item.weaknessLabel,
                        item.difficultyLabel,
                        item.recencyLabel,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (onAddToSchedule != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: onAddToSchedule,
                          icon: const Icon(
                            Icons.event_available_outlined,
                            size: 18,
                          ),
                          label: Text(strings.addToScheduleFromCard),
                        ),
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

List<_ScheduleItem> _buildScheduleFromSessionsAndTasks({
  required List<StudySession> sessions,
  required List<StudyTaskPriority> tasks,
  required List<TopicPerformanceInput> topics,
  required DateTime date,
  required String localeCode,
}) {
  if (sessions.isEmpty) return const [];
  final taskByTopic = <String, StudyTaskPriority>{};
  for (final t in tasks) {
    taskByTopic.putIfAbsent(t.topicId, () => t);
  }
  final topicById = <String, TopicPerformanceInput>{};
  for (final t in topics) {
    topicById[t.topicId] = t;
  }
  final sorted = List<StudySession>.from(sessions)
    ..sort((a, b) => a.topicId.compareTo(b.topicId));

  final startHour = _isSameDay(date, _dateOnly(DateTime.now())) ? 17 : 15;
  var current = DateTime(date.year, date.month, date.day, startHour);
  final items = <_ScheduleItem>[];

  for (final session in sorted) {
    final timeLabel = _formatTime(current, localeCode);
    items.add(
      _ScheduleItem.fromSessionContext(
        session: session,
        timeLabel: timeLabel,
        task: taskByTopic[session.topicId],
        topic: topicById[session.topicId],
      ),
    );
    current = current.add(Duration(minutes: session.durationMin + 10));
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

class _ScheduleItem {
  const _ScheduleItem({
    required this.planId,
    required this.sessionId,
    required this.topicId,
    required this.timeLabel,
    required this.title,
    required this.subject,
    required this.durationMin,
    required this.scoreLabel,
    required this.deadlineLabel,
    required this.weaknessLabel,
    required this.difficultyLabel,
    required this.recencyLabel,
    required this.priorityBand,
  });

  factory _ScheduleItem.fromSessionContext({
    required StudySession session,
    required String timeLabel,
    StudyTaskPriority? task,
    TopicPerformanceInput? topic,
  }) {
    if (task != null) {
      final fromTask = _ScheduleItem.fromTask(
        task,
        timeLabel: timeLabel,
        planId: session.planId,
        sessionId: session.id,
      );
      return _ScheduleItem(
        planId: fromTask.planId,
        sessionId: fromTask.sessionId,
        topicId: fromTask.topicId,
        timeLabel: fromTask.timeLabel,
        title: fromTask.title,
        subject: fromTask.subject,
        durationMin: session.durationMin,
        scoreLabel: fromTask.scoreLabel,
        deadlineLabel: fromTask.deadlineLabel,
        weaknessLabel: fromTask.weaknessLabel,
        difficultyLabel: fromTask.difficultyLabel,
        recencyLabel: fromTask.recencyLabel,
        priorityBand: fromTask.priorityBand,
      );
    }
    final title = topic?.topicTitle ?? session.topicId;
    final subject = topic?.subjectTitle ?? '';
    return _ScheduleItem(
      planId: session.planId,
      sessionId: session.id,
      topicId: session.topicId,
      timeLabel: timeLabel,
      title: title.isEmpty ? session.topicId : title,
      subject: subject,
      durationMin: session.durationMin,
      scoreLabel: '–',
      deadlineLabel: '–',
      weaknessLabel: '–',
      difficultyLabel: '–',
      recencyLabel: '–',
      priorityBand: _PriorityBand.low,
    );
  }

  factory _ScheduleItem.fromTask(
    StudyTaskPriority task, {
    required String timeLabel,
    String planId = '',
    String sessionId = '',
  }) {
    final band = task.priorityScore >= 3
        ? _PriorityBand.high
        : task.priorityScore >= 2
            ? _PriorityBand.medium
            : _PriorityBand.low;
    return _ScheduleItem(
      planId: planId,
      sessionId: sessionId,
      topicId: task.topicId,
      timeLabel: timeLabel,
      title: task.topicTitle,
      subject: task.subjectTitle,
      durationMin: task.recommendedMinutes,
      scoreLabel: task.priorityScore.toStringAsFixed(2),
      deadlineLabel: task.deadlineUrgency.toStringAsFixed(2),
      weaknessLabel: task.weakness.toStringAsFixed(2),
      difficultyLabel: task.difficulty.toStringAsFixed(2),
      recencyLabel: task.timeSinceLastStudied.toStringAsFixed(2),
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
  final String scoreLabel;
  final String deadlineLabel;
  final String weaknessLabel;
  final String difficultyLabel;
  final String recencyLabel;
  final _PriorityBand priorityBand;
}

enum _PriorityBand { high, medium, low }

