import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/study_plan/presentation/controllers/study_plan_firestore_providers.dart';
import '../state/app_providers.dart';
import 'student_notification_service.dart';
import 'student_reminder_sync_controller.dart';

final flutterLocalNotificationsPluginProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

final studentNotificationServiceProvider =
    Provider<StudentNotificationService>((ref) {
  return StudentNotificationService(
    ref.watch(flutterLocalNotificationsPluginProvider),
  );
});

final studentReminderSyncControllerProvider = Provider.autoDispose
    .family<StudentReminderSyncController, String>((ref, uid) {
  final controller = StudentReminderSyncController(
    uid: uid,
    notificationService: ref.watch(studentNotificationServiceProvider),
    studySessionsRepository: ref.watch(studySessionsRepositoryProvider),
    academicTasksRepository: ref.watch(academicTasksRepositoryProvider),
    subjectsRepository: ref.watch(subjectsRepositoryProvider),
  )..start();
  ref.onDispose(controller.dispose);
  return controller;
});
