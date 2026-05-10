import '../entities/study_session.dart';
import '../entities/topic_activity_signals.dart';

abstract class StudySessionsRepository {
  Stream<List<StudySession>> watchTodaysSessions(String uid);

  /// Sessions on the active study plan for [dateIso] (`yyyy-MM-dd`).
  Stream<List<StudySession>> watchSessionsForDate(String uid, String dateIso);

  /// Aggregated per-topic session activity over the trailing [windowDays]
  /// (defaulting to two weeks). Powers dynamic "missed sessions" + "last
  /// studied" signals in the planner.
  Stream<Map<String, TopicActivitySignals>> watchRecentTopicActivity(
    String uid, {
    int windowDays = 14,
  });

  /// Creates a session on the active study plan. [dateIso] must be `yyyy-MM-dd`.
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
    required int startMinute,
  });

  Future<void> setSessionCompleted({
    required String uid,
    required String planId,
    required String sessionId,
    required bool completed,
  });

  Future<void> updateSession({
    required String uid,
    required String planId,
    required String sessionId,
    String? topicId,
    int? durationMin,
    int? startMinute,
  });

  Future<void> deleteSession({
    required String uid,
    required String planId,
    required String sessionId,
  });
}
