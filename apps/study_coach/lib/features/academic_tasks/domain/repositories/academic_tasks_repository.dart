import '../entities/academic_task.dart';

abstract class AcademicTasksRepository {
  Stream<List<AcademicTask>> watchTasks(String uid);

  Future<String> createTask({
    required String uid,
    required String title,
    required AcademicTaskType type,
    required String dueDateIso,
    String subjectId = '',
    int estimatedMinutes = 60,
    AcademicTaskPriority priority = AcademicTaskPriority.medium,
    String notes = '',
  });

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
  });

  Future<void> setTaskCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  });

  Future<void> deleteTask({
    required String uid,
    required String taskId,
  });
}
