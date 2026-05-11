import 'package:flutter_test/flutter_test.dart';
import 'package:pillar_study_coach/core/config/app_time_zone.dart';
import 'package:pillar_study_coach/core/notifications/student_reminder.dart';
import 'package:pillar_study_coach/features/academic_tasks/domain/entities/academic_task.dart';
import 'package:pillar_study_coach/features/study_plan/domain/entities/study_session.dart';
import 'package:pillar_study_coach/features/subjects/domain/entities/subject.dart';

void main() {
  setUpAll(ensureAppTimeZonesLoaded);

  test('builds student reminders from study data', () {
    final tomorrow = appTodayDateOnly().add(const Duration(days: 1));
    final examDay = appTodayDateOnly().add(const Duration(days: 8));

    final reminders = buildStudentReminders(
      uid: 'student-1',
      sessions: [
        StudySession(
          id: 'session-1',
          planId: 'plan-1',
          topicId: 'topic-1',
          date: _dateIso(tomorrow),
          durationMin: 60,
          startMinute: 10 * 60,
          completed: false,
        ),
      ],
      tasks: [
        AcademicTask(
          id: 'task-1',
          title: 'Calculus project',
          type: AcademicTaskType.project,
          dueDateIso: _dateIso(tomorrow),
        ),
      ],
      subjects: [
        Subject(
          id: 'subject-1',
          name: 'Biology',
          examDateIso: _dateIso(examDay),
        ),
      ],
    );

    expect(
      reminders.map((r) => r.kind),
      containsAll([
        StudentReminderKind.dailyPlan,
        StudentReminderKind.studySession,
        StudentReminderKind.missedStudySession,
        StudentReminderKind.academicDeadline,
        StudentReminderKind.examCountdown,
      ]),
    );
  });

  test('omits completed sessions and completed tasks', () {
    final tomorrow = appTodayDateOnly().add(const Duration(days: 1));

    final reminders = buildStudentReminders(
      uid: 'student-1',
      sessions: [
        StudySession(
          id: 'session-1',
          planId: 'plan-1',
          topicId: 'topic-1',
          date: _dateIso(tomorrow),
          durationMin: 60,
          startMinute: 10 * 60,
          completed: true,
        ),
      ],
      tasks: [
        AcademicTask(
          id: 'task-1',
          title: 'Finished task',
          type: AcademicTaskType.homework,
          dueDateIso: _dateIso(tomorrow),
          status: AcademicTaskStatus.completed,
        ),
      ],
      subjects: const [],
    );

    expect(
      reminders.map((r) => r.kind),
      isNot(contains(StudentReminderKind.studySession)),
    );
    expect(
      reminders.map((r) => r.kind),
      isNot(contains(StudentReminderKind.academicDeadline)),
    );
  });

  test('generates stable integer ids for reminder keys', () {
    final first = stableStudentReminderId('student-reminder:key');
    final second = stableStudentReminderId('student-reminder:key');

    expect(first, second);
    expect(first, greaterThan(0));
  });
}

String _dateIso(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
