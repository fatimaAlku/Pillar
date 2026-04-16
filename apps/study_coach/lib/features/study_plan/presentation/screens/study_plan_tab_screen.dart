import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../controllers/study_plan_controller.dart';

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
    final localeCode = Localizations.localeOf(context).languageCode;
    final days = _buildWeekDays(anchor: _selectedDate);
    final input = StudyPlanPersonalizationInput(
      topics: _seedTopics(now: DateTime.now()),
      availableStudyMinutes: 180,
      now: DateTime.now(),
    );
    final dynamicResult = ref.watch(studyPlanDynamicResultProvider(input));
    final tasks = dynamicResult.updatedPlan;
    final daySchedule = _buildScheduleForDay(
      tasks: tasks,
      date: _selectedDate,
      localeCode: localeCode,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      strings.adaptiveScheduleBlurb,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _CalendarHeader(
          selectedDate: _selectedDate,
          days: days,
          onDayTap: (d) => setState(() => _selectedDate = d),
          onPickDate: _pickDate,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(strings.schedulingEditorComingSoon)),
            );
          },
          icon: const Icon(Icons.add),
          label: Text(strings.addSchedule),
        ),
        const SizedBox(height: 18),
        Text(
          _formatDateHeader(_selectedDate, localeCode),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        ...daySchedule.map((item) => _ScheduleCard(item: item)),
        const SizedBox(height: 14),
        _PriorityLegend(
          tasks: tasks,
          explanationMessage: dynamicResult.explanationMessage,
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
  const _ScheduleCard({required this.item});

  final _ScheduleItem item;

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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

class _PriorityLegend extends StatelessWidget {
  const _PriorityLegend({
    required this.tasks,
    required this.explanationMessage,
  });
  final List<StudyTaskPriority> tasks;
  final String explanationMessage;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final totalMin = tasks.fold<int>(0, (acc, t) => acc + t.recommendedMinutes);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          strings.personalizedPlanFooter(totalMin, explanationMessage),
        ),
      ),
    );
  }
}

List<_ScheduleItem> _buildScheduleForDay({
  required List<StudyTaskPriority> tasks,
  required DateTime date,
  required String localeCode,
}) {
  if (tasks.isEmpty) return const [];
  final startHour = _isSameDay(date, _dateOnly(DateTime.now())) ? 17 : 15;
  var current = DateTime(date.year, date.month, date.day, startHour);
  final items = <_ScheduleItem>[];

  for (final task in tasks.take(5)) {
    final timeLabel = _formatTime(current, localeCode);
    items.add(_ScheduleItem.fromTask(task, timeLabel: timeLabel));
    current = current.add(Duration(minutes: task.recommendedMinutes + 10));
  }
  return items;
}

List<TopicPerformanceInput> _seedTopics({required DateTime now}) {
  return [
    TopicPerformanceInput(
      topicId: 'topic_bst',
      topicTitle: 'Binary Search Trees',
      subjectId: 'subject_ds',
      subjectTitle: 'Data Structures',
      examDate: now.add(const Duration(days: 12)),
      quizAccuracy: 0.42,
      subjectDifficulty: 0.8,
      lastStudiedAt: now.subtract(const Duration(days: 6)),
      missedSessions: 1,
    ),
    TopicPerformanceInput(
      topicId: 'topic_graphs',
      topicTitle: 'Graph Traversal',
      subjectId: 'subject_ds',
      subjectTitle: 'Data Structures',
      examDate: now.add(const Duration(days: 12)),
      quizAccuracy: 0.55,
      subjectDifficulty: 0.85,
      lastStudiedAt: now.subtract(const Duration(days: 8)),
      missedSessions: 0,
    ),
    TopicPerformanceInput(
      topicId: 'topic_thermo',
      topicTitle: 'Thermodynamics Laws',
      subjectId: 'subject_phys',
      subjectTitle: 'Physics',
      examDate: now.add(const Duration(days: 7)),
      quizAccuracy: 0.37,
      subjectDifficulty: 0.75,
      lastStudiedAt: now.subtract(const Duration(days: 10)),
      missedSessions: 2,
    ),
    TopicPerformanceInput(
      topicId: 'topic_kinetics',
      topicTitle: 'Chemical Kinetics',
      subjectId: 'subject_chem',
      subjectTitle: 'Chemistry',
      examDate: now.add(const Duration(days: 18)),
      quizAccuracy: 0.68,
      subjectDifficulty: 0.62,
      lastStudiedAt: now.subtract(const Duration(days: 3)),
      missedSessions: 0,
    ),
    TopicPerformanceInput(
      topicId: 'topic_calculus',
      topicTitle: 'Integration Techniques',
      subjectId: 'subject_math',
      subjectTitle: 'Calculus',
      examDate: now.add(const Duration(days: 9)),
      quizAccuracy: 0.49,
      subjectDifficulty: 0.7,
      lastStudiedAt: now.subtract(const Duration(days: 5)),
      missedSessions: 1,
    ),
  ];
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

  factory _ScheduleItem.fromTask(
    StudyTaskPriority task, {
    required String timeLabel,
  }) {
    final band = task.priorityScore >= 3
        ? _PriorityBand.high
        : task.priorityScore >= 2
            ? _PriorityBand.medium
            : _PriorityBand.low;
    return _ScheduleItem(
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

