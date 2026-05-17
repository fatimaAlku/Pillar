import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../controllers/study_plan_firestore_providers.dart';

/// Confirms and soft-deletes a persisted study-plan session.
Future<void> confirmAndDeleteStudySession({
  required BuildContext context,
  required WidgetRef ref,
  required String uid,
  required String planId,
  required String sessionId,
}) async {
  if (planId.isEmpty || sessionId.isEmpty) return;
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
  if (confirmed != true || !context.mounted) return;
  try {
    await ref.read(studySessionsRepositoryProvider).deleteSession(
          uid: uid,
          planId: planId,
          sessionId: sessionId,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.sessionDeleted)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.couldNotDeleteSession)),
    );
  }
}

/// Opens the edit dialog and persists changes when the user saves.
Future<void> editStudySession({
  required BuildContext context,
  required WidgetRef ref,
  required String uid,
  required List<TopicPerformanceInput> topics,
  required String planId,
  required String sessionId,
  required String topicId,
  required int durationMin,
  required int? startMinute,
}) async {
  if (topics.isEmpty || planId.isEmpty || sessionId.isEmpty) return;
  final strings = AppStrings.of(context);
  final idx = topics.indexWhere((t) => t.topicId == topicId);
  var topicSel = idx >= 0 ? topics[idx] : topics.first;
  double duration = durationMin.toDouble().clamp(15.0, 240.0);
  var sessionTime = TimeOfDay(
    hour: (startMinute ?? (17 * 60)) ~/ 60,
    minute: (startMinute ?? (17 * 60)) % 60,
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
                            max: 240,
                            divisions: 45,
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

  if (saved != true || !context.mounted) return;

  final newTopicId = topicSel.topicId;
  final newDuration = duration.round();
  final newStartMinute = (sessionTime.hour * 60) + sessionTime.minute;
  if (newTopicId == topicId &&
      newDuration == durationMin &&
      newStartMinute == startMinute) {
    return;
  }

  try {
    await ref.read(studySessionsRepositoryProvider).updateSession(
          uid: uid,
          planId: planId,
          sessionId: sessionId,
          topicId: newTopicId != topicId ? newTopicId : null,
          durationMin: newDuration != durationMin ? newDuration : null,
          startMinute: newStartMinute != startMinute ? newStartMinute : null,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.sessionUpdated)),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.couldNotUpdateSession)),
    );
  }
}
