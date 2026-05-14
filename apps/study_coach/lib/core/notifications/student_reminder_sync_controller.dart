import 'dart:async';

import '../../features/academic_tasks/domain/entities/academic_task.dart';
import '../../features/academic_tasks/domain/repositories/academic_tasks_repository.dart';
import '../../features/study_plan/domain/entities/study_session.dart';
import '../../features/study_plan/domain/repositories/study_sessions_repository.dart';
import '../../features/subjects/domain/entities/subject.dart';
import '../../features/subjects/domain/repositories/subjects_repository.dart';
import 'student_notification_service.dart';
import 'student_reminder.dart';

class StudentReminderSyncController {
  StudentReminderSyncController({
    required this.uid,
    required StudentNotificationService notificationService,
    required StudySessionsRepository studySessionsRepository,
    required AcademicTasksRepository academicTasksRepository,
    required SubjectsRepository subjectsRepository,
  })  : _notificationService = notificationService,
        _studySessionsRepository = studySessionsRepository,
        _academicTasksRepository = academicTasksRepository,
        _subjectsRepository = subjectsRepository;

  final String uid;
  final StudentNotificationService _notificationService;
  final StudySessionsRepository _studySessionsRepository;
  final AcademicTasksRepository _academicTasksRepository;
  final SubjectsRepository _subjectsRepository;

  StreamSubscription<List<StudySession>>? _sessionsSub;
  StreamSubscription<List<AcademicTask>>? _tasksSub;
  StreamSubscription<List<Subject>>? _subjectsSub;

  List<StudySession>? _sessions;
  List<AcademicTask>? _tasks;
  List<Subject>? _subjects;
  List<StudentReminder>? _pendingReminders;

  bool _started = false;
  bool _syncing = false;
  bool _disposed = false;

  void start() {
    if (_started) return;
    _started = true;
    unawaited(_notificationService.initialize());
    _sessionsSub = _studySessionsRepository.watchUpcomingSessions(uid).listen(
          _onSessions,
          onError: (Object error, StackTrace stackTrace) {
            _ignoreStreamError(error, stackTrace);
            _onSessions(const <StudySession>[]);
          },
        );
    _tasksSub = _academicTasksRepository.watchTasks(uid).listen(
          _onTasks,
          onError: (Object error, StackTrace stackTrace) {
            _ignoreStreamError(error, stackTrace);
            _onTasks(const <AcademicTask>[]);
          },
        );
    _subjectsSub = _subjectsRepository.watchSubjects(uid).listen(
          _onSubjects,
          onError: (Object error, StackTrace stackTrace) {
            _ignoreStreamError(error, stackTrace);
            _onSubjects(const <Subject>[]);
          },
        );
  }

  void dispose() {
    _disposed = true;
    unawaited(_sessionsSub?.cancel());
    unawaited(_tasksSub?.cancel());
    unawaited(_subjectsSub?.cancel());
  }

  void _onSessions(List<StudySession> sessions) {
    _sessions = sessions;
    _queueSyncIfReady();
  }

  void _onTasks(List<AcademicTask> tasks) {
    _tasks = tasks;
    _queueSyncIfReady();
  }

  void _onSubjects(List<Subject> subjects) {
    _subjects = subjects;
    _queueSyncIfReady();
  }

  void _queueSyncIfReady() {
    final sessions = _sessions;
    final tasks = _tasks;
    final subjects = _subjects;
    if (_disposed || sessions == null || tasks == null || subjects == null) {
      return;
    }
    _pendingReminders = buildStudentReminders(
      uid: uid,
      sessions: sessions,
      tasks: tasks,
      subjects: subjects,
    );
    if (!_syncing) {
      unawaited(_drainPendingSyncs());
    }
  }

  Future<void> _drainPendingSyncs() async {
    _syncing = true;
    try {
      while (!_disposed && _pendingReminders != null) {
        final reminders = _pendingReminders!;
        _pendingReminders = null;
        try {
          await _notificationService.reconcileReminders(reminders);
        } catch (_) {
          // Reminder sync should never interrupt the signed-in app shell.
        }
      }
    } finally {
      _syncing = false;
      if (!_disposed && _pendingReminders != null) {
        unawaited(_drainPendingSyncs());
      }
    }
  }

  void _ignoreStreamError(Object error, StackTrace stackTrace) {}
}
