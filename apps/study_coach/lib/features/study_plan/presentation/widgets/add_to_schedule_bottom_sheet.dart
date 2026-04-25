import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/study_personalization_models.dart';

/// Presents topic and duration, then calls [onSave] to persist a Firestore session.
Future<void> showAddToScheduleBottomSheet(
  BuildContext context, {
  required AppStrings strings,
  required List<TopicPerformanceInput> topics,
  required DateTime scheduleDate,
  String? initialTopicId,
  int? initialDurationMin,
  int? initialStartMinute,
  required Future<void> Function(
    String topicId,
    int durationMin,
    int startMinute,
  ) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final locale = Localizations.localeOf(ctx).languageCode;
      final dayLabel =
          DateFormat.yMMMEd(locale).format(scheduleDate);
      final idx = initialTopicId == null
          ? -1
          : topics.indexWhere((t) => t.topicId == initialTopicId);
      final selected =
          idx >= 0 ? topics[idx] : topics.first;
      return _AddToScheduleBody(
        hostContext: context,
        strings: strings,
        dayLabel: dayLabel,
        topics: topics,
        initialTopic: selected,
        initialDurationMin: (initialDurationMin ?? 30).clamp(15, 120),
        initialStartMinute:
            (initialStartMinute ?? (DateTime.now().hour * 60) + DateTime.now().minute)
                .clamp(0, 1439),
        onSave: onSave,
      );
    },
  );
}

class _AddToScheduleBody extends StatefulWidget {
  const _AddToScheduleBody({
    required this.hostContext,
    required this.strings,
    required this.dayLabel,
    required this.topics,
    required this.initialTopic,
    required this.initialDurationMin,
    required this.initialStartMinute,
    required this.onSave,
  });

  final BuildContext hostContext;
  final AppStrings strings;
  final String dayLabel;
  final List<TopicPerformanceInput> topics;
  final TopicPerformanceInput initialTopic;
  final int initialDurationMin;
  final int initialStartMinute;
  final Future<void> Function(
    String topicId,
    int durationMin,
    int startMinute,
  ) onSave;

  @override
  State<_AddToScheduleBody> createState() => _AddToScheduleBodyState();
}

class _AddToScheduleBodyState extends State<_AddToScheduleBody> {
  late TopicPerformanceInput _topic;
  late double _duration;
  late TimeOfDay _time;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic;
    _duration = widget.initialDurationMin.toDouble();
    _time = TimeOfDay(
      hour: widget.initialStartMinute ~/ 60,
      minute: widget.initialStartMinute % 60,
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final hostMessenger = ScaffoldMessenger.maybeOf(widget.hostContext);
    Navigator.of(context).pop();
    hostMessenger?.showSnackBar(
      SnackBar(content: Text(widget.strings.sessionScheduledSuccess)),
    );

    unawaited(
      widget
          .onSave(
            _topic.topicId,
            _duration.round(),
            (_time.hour * 60) + _time.minute,
          )
          .catchError((error) {
        final message = error is TimeoutException
            ? widget.strings.saveToScheduleTimedOut
            : widget.strings.couldNotScheduleSession;
        hostMessenger?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = widget.strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings.addToScheduleSheetTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            strings.scheduleSessionForDay(widget.dayLabel),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          InputDecorator(
            decoration: InputDecoration(
              labelText: strings.topicForSession,
              border: const OutlineInputBorder(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<TopicPerformanceInput>(
                isExpanded: true,
                value: _topic,
                borderRadius: BorderRadius.circular(12),
                items: widget.topics
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
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v == null) return;
                        setState(() => _topic = v);
                      },
              ),
            ),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: InputDecoration(
              labelText: strings.studyTime,
              border: const OutlineInputBorder(),
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _time,
                        );
                        if (picked == null || !mounted) return;
                        setState(() => _time = picked);
                      },
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(
                  MaterialLocalizations.of(context).formatTimeOfDay(_time),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
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
                    value: _duration,
                    label: '${_duration.round()}',
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _duration = v),
                  ),
                ),
                Text('${_duration.round()}'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(strings.saveToSchedule),
          ),
        ],
      ),
    );
  }
}
