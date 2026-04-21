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
  required Future<void> Function(String topicId, int durationMin) onSave,
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
        strings: strings,
        dayLabel: dayLabel,
        topics: topics,
        initialTopic: selected,
        initialDurationMin: (initialDurationMin ?? 30).clamp(15, 120),
        onSave: onSave,
      );
    },
  );
}

class _AddToScheduleBody extends StatefulWidget {
  const _AddToScheduleBody({
    required this.strings,
    required this.dayLabel,
    required this.topics,
    required this.initialTopic,
    required this.initialDurationMin,
    required this.onSave,
  });

  final AppStrings strings;
  final String dayLabel;
  final List<TopicPerformanceInput> topics;
  final TopicPerformanceInput initialTopic;
  final int initialDurationMin;
  final Future<void> Function(String topicId, int durationMin) onSave;

  @override
  State<_AddToScheduleBody> createState() => _AddToScheduleBodyState();
}

class _AddToScheduleBodyState extends State<_AddToScheduleBody> {
  late TopicPerformanceInput _topic;
  late double _duration;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _topic = widget.initialTopic;
    _duration = widget.initialDurationMin.toDouble();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await widget.onSave(_topic.topicId, _duration.round());
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(widget.strings.sessionScheduledSuccess)),
      );
      nav.pop();
    } catch (e) {
      final message = e is TimeoutException
          ? widget.strings.saveToScheduleTimedOut
          : widget.strings.couldNotScheduleSession;
      messenger.showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
