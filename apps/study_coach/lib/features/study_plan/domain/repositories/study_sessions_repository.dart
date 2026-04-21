import '../entities/study_session.dart';

abstract class StudySessionsRepository {
  Stream<List<StudySession>> watchTodaysSessions(String uid);

  Future<void> setSessionCompleted({
    required String uid,
    required String planId,
    required String sessionId,
    required bool completed,
  });
}
