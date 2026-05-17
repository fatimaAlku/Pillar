import 'package:pillar_study_coach/features/academic_tasks/domain/entities/academic_task.dart';
import 'package:pillar_study_coach/features/quizzes/domain/entities/quiz_history_entry.dart';
import 'package:pillar_study_coach/features/quizzes/domain/entities/quiz_submission_result.dart';
import 'package:pillar_study_coach/features/quizzes/domain/repositories/quiz_history_repository.dart';
import 'package:pillar_study_coach/features/recommendations/domain/entities/recommendation.dart';
import 'package:pillar_study_coach/features/roadmap/domain/repositories/roadmap_progress_repository.dart';
import 'package:pillar_study_coach/features/recommendations/domain/repositories/recommendations_repository.dart';
import 'package:pillar_study_coach/features/academic_tasks/domain/repositories/academic_tasks_repository.dart';
import 'package:pillar_study_coach/features/study_plan/domain/entities/study_session.dart';
import 'package:pillar_study_coach/features/study_plan/domain/entities/topic_activity_signals.dart';
import 'package:pillar_study_coach/features/study_plan/domain/repositories/study_plan_repository.dart';
import 'package:pillar_study_coach/features/study_plan/domain/repositories/study_sessions_repository.dart';
import 'package:pillar_study_coach/features/subjects/domain/entities/subject.dart';
import 'package:pillar_study_coach/features/subjects/domain/entities/topic_item.dart';
import 'package:pillar_study_coach/features/subjects/domain/repositories/subjects_repository.dart';

class FakeStudySessionsRepository implements StudySessionsRepository {
  @override
  Stream<List<StudySession>> watchTodaysSessions(String uid) =>
      Stream.value(const []);

  @override
  Stream<List<StudySession>> watchSessionsForDate(String uid, String dateIso) =>
      Stream.value(const []);

  @override
  Stream<List<StudySession>> watchUpcomingSessions(
    String uid, {
    int horizonDays = 30,
  }) =>
      Stream.value(const []);

  @override
  Stream<Map<String, TopicActivitySignals>> watchRecentTopicActivity(
    String uid, {
    int windowDays = 14,
  }) =>
      Stream.value(const {});

  @override
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
    required int startMinute,
  }) async {}

  @override
  Future<void> setSessionCompleted({
    required String uid,
    required String planId,
    required String sessionId,
    required bool completed,
  }) async {}

  @override
  Future<void> updateSession({
    required String uid,
    required String planId,
    required String sessionId,
    String? topicId,
    int? durationMin,
    int? startMinute,
  }) async {}

  @override
  Future<void> deleteSession({
    required String uid,
    required String planId,
    required String sessionId,
  }) async {}
}

class FakeAcademicTasksRepository implements AcademicTasksRepository {
  @override
  Stream<List<AcademicTask>> watchTasks(String uid) => Stream.value(const []);

  @override
  Future<String> createTask({
    required String uid,
    required String title,
    required AcademicTaskType type,
    required String dueDateIso,
    String subjectId = '',
    int estimatedMinutes = 60,
    AcademicTaskPriority priority = AcademicTaskPriority.medium,
    String notes = '',
  }) async =>
      'task-1';

  @override
  Future<void> updateTask({
    required String uid,
    required String taskId,
    required String title,
    required AcademicTaskType type,
    required String dueDateIso,
    String subjectId = '',
    int estimatedMinutes = 60,
    AcademicTaskPriority priority = AcademicTaskPriority.medium,
    String notes = '',
  }) async {}

  @override
  Future<void> setTaskCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  }) async {}

  @override
  Future<void> deleteTask({
    required String uid,
    required String taskId,
  }) async {}
}

class FakeSubjectsRepository implements SubjectsRepository {
  @override
  Stream<List<Subject>> watchSubjects(String uid) => Stream.value(const []);

  @override
  Stream<List<TopicItem>> watchTopics({
    required String uid,
    required String subjectId,
  }) =>
      Stream.value(const []);

  @override
  Future<String> createSubject({
    required String uid,
    required String name,
    String examDateIso = '',
    String color = '',
  }) async =>
      'subject-1';

  @override
  Future<void> updateSubject({
    required String uid,
    required String subjectId,
    required String name,
    String examDateIso = '',
    String? color,
  }) async {}

  @override
  Future<void> deleteSubject({
    required String uid,
    required String subjectId,
  }) async {}

  @override
  Future<String> addTopic({
    required String uid,
    required String subjectId,
    required String title,
    double difficultyEstimate = 0.5,
  }) async =>
      'topic-1';

  @override
  Future<void> updateTopic({
    required String uid,
    required String subjectId,
    required String topicId,
    required String title,
    double difficultyEstimate = 0.5,
  }) async {}

  @override
  Future<void> deleteTopic({
    required String uid,
    required String subjectId,
    required String topicId,
  }) async {}
}

class FakeQuizHistoryRepository implements QuizHistoryRepository {
  @override
  Future<void> saveAttempt({
    required String uid,
    required QuizSubmissionResult result,
    required DateTime completedAt,
  }) async {}

  @override
  Stream<List<QuizHistoryEntry>> watchHistory(String uid, {int limit = 30}) =>
      Stream.value(const []);

  @override
  Future<void> deleteAttempt({
    required String uid,
    required String entryId,
  }) async {}
}

class FakeRecommendationsRepository implements RecommendationsRepository {
  @override
  Future<void> generateRecommendations() async {}

  @override
  Stream<Recommendation?> watchLatestRecommendation(String uid) =>
      Stream.value(null);
}

class FakeRoadmapProgressRepository implements RoadmapProgressRepository {
  @override
  Stream<Set<String>> watchCompletedItemKeys({
    required String uid,
    required String majorId,
  }) =>
      Stream.value(<String>{});

  @override
  Future<void> toggleItem({
    required String uid,
    required String majorId,
    required String itemKey,
    required bool completed,
    required int totalItemCount,
  }) async {}
}

class FakeStudyPlanRepository implements StudyPlanRepository {
  @override
  Future<void> generateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  }) async {}

  @override
  Future<void> rebalanceStudyPlan() async {}

  @override
  Future<void> refreshOrGenerateStudyPlan({
    required String uid,
    required List<String> subjectIds,
  }) async {}
}
