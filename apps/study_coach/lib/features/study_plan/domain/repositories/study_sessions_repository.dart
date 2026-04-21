import '../entities/study_session.dart';

abstract class StudySessionsRepository {
  Stream<List<StudySession>> watchTodaysSessions(String uid);

  /// Sessions on the active study plan for [dateIso] (`yyyy-MM-dd`).
  Stream<List<StudySession>> watchSessionsForDate(String uid, String dateIso);

  /// Creates a session on the active study plan. [dateIso] must be `yyyy-MM-dd`.
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
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
  });

  Future<void> deleteSession({
    required String uid,
    required String planId,
    required String sessionId,
  });
}
