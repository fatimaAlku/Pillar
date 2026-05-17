import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pillar_study_coach/app/app.dart';
import 'package:pillar_study_coach/core/notifications/student_notification_service.dart';
import 'package:pillar_study_coach/core/notifications/student_reminder.dart';
import 'package:pillar_study_coach/core/notifications/student_reminder_providers.dart';
import 'package:pillar_study_coach/core/notifications/student_reminder_sync_controller.dart';
import 'package:pillar_study_coach/core/state/app_providers.dart';
import 'package:pillar_study_coach/features/auth/domain/entities/auth_user.dart';
import 'package:pillar_study_coach/features/profile/domain/entities/user_profile_data.dart';
import 'package:pillar_study_coach/features/study_plan/domain/entities/study_personalization_models.dart';
import 'package:pillar_study_coach/features/quizzes/data/services/quiz_ai_service.dart';
import 'package:pillar_study_coach/features/quizzes/domain/entities/quiz_question.dart';
import 'package:pillar_study_coach/features/roadmap/presentation/controllers/roadmap_progress_providers.dart';
import 'package:pillar_study_coach/features/study_plan/presentation/controllers/study_plan_firestore_providers.dart';

import 'fake_repositories.dart';

class NoopQuizAiService implements QuizAiService {
  @override
  Future<List<QuizQuestion>> generateQuiz({
    required List<String> topics,
    required String difficulty,
    required int numberOfQuestions,
    String? notesText,
    String languageCode = 'en',
    String quizEmphasis = 'balanced',
  }) async =>
      const [];
}

class NoopStudentNotificationService extends StudentNotificationService {
  NoopStudentNotificationService()
      : super(FlutterLocalNotificationsPlugin());

  @override
  Future<void> initialize() async {}

  @override
  Future<void> reconcileReminders(List<StudentReminder> reminders) async {}

  @override
  Future<void> clearScheduledStudentReminders() async {}
}

/// Skips splash and lands on the auth screen with no Firebase session.
List<Override> unauthenticatedAppOverrides() => [
      startupDelayProvider.overrideWith((ref) async {}),
      currentAuthUserProvider.overrideWith((ref) => Stream.value(null)),
    ];

/// Signed-in dashboard smoke tests without Firebase initialization.
List<Override> authenticatedAppOverrides({
  required AuthUser user,
  UserProfileData profile = const UserProfileData(
    majorId: 'computer_science',
    majorSource: 'test',
  ),
}) =>
    [
      startupDelayProvider.overrideWith((ref) async {}),
      currentAuthUserProvider.overrideWith((ref) => Stream.value(user)),
      postSigninWelcomeCompletedProvider.overrideWith((ref, uid) async => true),
      userProfileStreamProvider.overrideWith((ref, uid) => Stream.value(profile)),
      studySessionsRepositoryProvider.overrideWith(
        (ref) => FakeStudySessionsRepository(),
      ),
      academicTasksRepositoryProvider.overrideWith(
        (ref) => FakeAcademicTasksRepository(),
      ),
      subjectsRepositoryProvider.overrideWith(
        (ref) => FakeSubjectsRepository(),
      ),
      studyPlanRepositoryProvider.overrideWith(
        (ref) => FakeStudyPlanRepository(),
      ),
      quizHistoryRepositoryProvider.overrideWith(
        (ref) => FakeQuizHistoryRepository(),
      ),
      recommendationsRepositoryProvider.overrideWith(
        (ref) => FakeRecommendationsRepository(),
      ),
      subjectsStreamProvider.overrideWith(
        (ref, uid) => Stream.value(const []),
      ),
      quizAiServiceProvider.overrideWithValue(NoopQuizAiService()),
      roadmapProgressRepositoryProvider.overrideWith(
        (ref) => FakeRoadmapProgressRepository(),
      ),
      topicPerformanceInputsStreamProvider.overrideWith(
        (ref, uid) => Stream.value(const <TopicPerformanceInput>[]),
      ),
      quizHistoryStreamProvider.overrideWith(
        (ref, uid) => Stream.value(const []),
      ),
      latestRecommendationProvider.overrideWith(
        (ref, uid) => Stream.value(null),
      ),
      studentNotificationServiceProvider.overrideWith(
        (ref) => NoopStudentNotificationService(),
      ),
      studentReminderSyncControllerProvider.overrideWith((ref, uid) {
        final controller = StudentReminderSyncController(
          uid: uid,
          notificationService: ref.watch(studentNotificationServiceProvider),
          studySessionsRepository: ref.watch(studySessionsRepositoryProvider),
          academicTasksRepository: ref.watch(academicTasksRepositoryProvider),
          subjectsRepository: ref.watch(subjectsRepositoryProvider),
        );
        ref.onDispose(controller.dispose);
        return controller;
      }),
    ];
