import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/state/app_providers.dart';
import '../../data/repositories/google_calendar_sync_repository.dart';
import '../../data/repositories/study_sessions_repository_impl.dart';
import '../../data/repositories/topic_performance_repository_impl.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_sessions_repository.dart';
import '../../domain/repositories/topic_performance_repository.dart';

final topicPerformanceRepositoryProvider =
    Provider<TopicPerformanceRepository>((ref) {
  return TopicPerformanceRepositoryImpl(ref.watch(firestoreProvider));
});

final studySessionsRepositoryProvider =
    Provider<StudySessionsRepository>((ref) {
  return StudySessionsRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(googleCalendarSyncRepositoryProvider),
  );
});

final googleCalendarSyncRepositoryProvider =
    Provider<GoogleCalendarSyncRepository>((ref) {
  return GoogleCalendarSyncRepository(ref.watch(functionsProvider));
});

final topicPerformanceInputsStreamProvider = StreamProvider.family<
    List<TopicPerformanceInput>, String>((ref, uid) {
  return ref
      .watch(topicPerformanceRepositoryProvider)
      .watchTopicPerformanceInputs(uid);
});

final todaysSessionsStreamProvider =
    StreamProvider.family<List<StudySession>, String>((ref, uid) {
  return ref.watch(studySessionsRepositoryProvider).watchTodaysSessions(uid);
});

/// Watches sessions for [dateIso] (`yyyy-MM-dd`) on the active study plan.
class SessionsForDateKey {
  const SessionsForDateKey(this.uid, this.dateIso);

  final String uid;
  final String dateIso;

  @override
  bool operator ==(Object other) =>
      other is SessionsForDateKey &&
      other.uid == uid &&
      other.dateIso == dateIso;

  @override
  int get hashCode => Object.hash(uid, dateIso);
}

final sessionsForDateStreamProvider =
    StreamProvider.autoDispose.family<List<StudySession>, SessionsForDateKey>(
  (ref, key) {
    return ref
        .watch(studySessionsRepositoryProvider)
        .watchSessionsForDate(key.uid, key.dateIso);
  },
);
