import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/academic_task.dart';
import '../../domain/repositories/academic_tasks_repository.dart';
import '../models/academic_task_model.dart';

class AcademicTasksRepositoryImpl implements AcademicTasksRepository {
  AcademicTasksRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AcademicTask>> watchTasks(String uid) {
    return _tasksRef(uid).orderBy('dueDate').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => AcademicTaskModel.fromMap(doc.id, doc.data()))
              .toList(growable: false),
        );
  }

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
  }) async {
    final ref = await _tasksRef(uid).add({
      'title': title.trim(),
      'type': type.name,
      'subjectId': subjectId.trim(),
      'dueDate': dueDateIso,
      'estimatedMinutes': estimatedMinutes.clamp(0, 24 * 60),
      'priority': priority.name,
      'status': AcademicTaskStatus.open.name,
      'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

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
  }) async {
    await _tasksRef(uid).doc(taskId).update({
      'title': title.trim(),
      'type': type.name,
      'subjectId': subjectId.trim(),
      'dueDate': dueDateIso,
      'estimatedMinutes': estimatedMinutes.clamp(0, 24 * 60),
      'priority': priority.name,
      'notes': notes.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setTaskCompleted({
    required String uid,
    required String taskId,
    required bool completed,
  }) async {
    await _tasksRef(uid).doc(taskId).update({
      'status': completed
          ? AcademicTaskStatus.completed.name
          : AcademicTaskStatus.open.name,
      'completedAt':
          completed ? FieldValue.serverTimestamp() : FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteTask({
    required String uid,
    required String taskId,
  }) async {
    await _tasksRef(uid).doc(taskId).delete();
  }

  CollectionReference<Map<String, dynamic>> _tasksRef(String uid) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.academicTasks);
  }
}
