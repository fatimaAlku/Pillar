import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../features/academic_tasks/domain/entities/academic_task.dart';
import '../../features/study_plan/domain/entities/study_session.dart';
import '../../features/subjects/domain/entities/subject.dart';
import '../config/app_time_zone.dart';

const int kStudentReminderLimit = 60;

enum StudentReminderKind {
  dailyPlan,
  studySession,
  missedStudySession,
  academicDeadline,
  examCountdown,
}

class StudentReminder {
  const StudentReminder({
    required this.key,
    required this.title,
    required this.body,
    required this.fireAt,
    required this.kind,
    this.repeatsDaily = false,
  });

  final String key;
  final String title;
  final String body;
  final tz.TZDateTime fireAt;
  final StudentReminderKind kind;
  final bool repeatsDaily;

  int get id => stableStudentReminderId(key);
}

List<StudentReminder> buildStudentReminders({
  required String uid,
  required List<StudySession> sessions,
  required List<AcademicTask> tasks,
  required List<Subject> subjects,
}) {
  final now = appNow();
  final reminders = <StudentReminder>[
    _dailyPlanReminder(uid: uid, now: now),
    ..._studySessionReminders(uid: uid, sessions: sessions, now: now),
    ..._academicTaskReminders(uid: uid, tasks: tasks, now: now),
    ..._examCountdownReminders(uid: uid, subjects: subjects, now: now),
  ]..sort((a, b) => a.fireAt.compareTo(b.fireAt));

  final daily = reminders.where((r) => r.repeatsDaily).toList(growable: false);
  final oneOffs =
      reminders.where((r) => !r.repeatsDaily).take(kStudentReminderLimit);
  return [...daily, ...oneOffs].take(kStudentReminderLimit).toList();
}

int stableStudentReminderId(String key) {
  final bytes = sha1.convert(utf8.encode(key)).bytes;
  final value =
      ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
          0x7fffffff;
  return value == 0 ? 1 : value;
}

StudentReminder _dailyPlanReminder({
  required String uid,
  required tz.TZDateTime now,
}) {
  var fireAt = tz.TZDateTime(
    appTimeZoneLocation,
    now.year,
    now.month,
    now.day,
    8,
  );
  if (!fireAt.isAfter(now)) {
    fireAt = fireAt.add(const Duration(days: 1));
  }
  return StudentReminder(
    key: 'student-reminder:$uid:daily-plan',
    title: 'Plan your study day',
    body: 'Review today\'s sessions, tasks, and exam countdowns.',
    fireAt: fireAt,
    kind: StudentReminderKind.dailyPlan,
    repeatsDaily: true,
  );
}

Iterable<StudentReminder> _studySessionReminders({
  required String uid,
  required List<StudySession> sessions,
  required tz.TZDateTime now,
}) sync* {
  for (final session in sessions) {
    if (session.completed || session.startMinute == null) continue;
    final startAt = _sessionStartAt(session);
    if (startAt == null) continue;

    final reminderAt = startAt.subtract(const Duration(minutes: 15));
    if (reminderAt.isAfter(now)) {
      yield StudentReminder(
        key:
            'student-reminder:$uid:study-session:${session.planId}:${session.id}:start',
        title: 'Study session soon',
        body:
            'Your ${session.durationMin}-minute study session starts in 15 minutes.',
        fireAt: reminderAt,
        kind: StudentReminderKind.studySession,
      );
    }

    final missedAt = startAt
        .add(Duration(minutes: session.durationMin))
        .add(const Duration(minutes: 30));
    if (missedAt.isAfter(now)) {
      yield StudentReminder(
        key:
            'student-reminder:$uid:study-session:${session.planId}:${session.id}:missed',
        title: 'Did you miss a study session?',
        body: 'Mark it complete or reschedule it so your plan stays accurate.',
        fireAt: missedAt,
        kind: StudentReminderKind.missedStudySession,
      );
    }
  }
}

Iterable<StudentReminder> _academicTaskReminders({
  required String uid,
  required List<AcademicTask> tasks,
  required tz.TZDateTime now,
}) sync* {
  for (final task in tasks) {
    if (task.isCompleted || task.status == AcademicTaskStatus.archived) {
      continue;
    }
    final dueDay = _dateOnly(task.dueDateIso);
    if (dueDay == null) continue;

    final dayBefore = _atAppTime(dueDay.subtract(const Duration(days: 1)), 18);
    if (dayBefore.isAfter(now)) {
      yield StudentReminder(
        key: 'student-reminder:$uid:academic-task:${task.id}:day-before',
        title: 'Deadline tomorrow',
        body: '${task.title} is due tomorrow.',
        fireAt: dayBefore,
        kind: StudentReminderKind.academicDeadline,
      );
    }

    final dueMorning = _atAppTime(dueDay, 9);
    if (dueMorning.isAfter(now)) {
      yield StudentReminder(
        key: 'student-reminder:$uid:academic-task:${task.id}:due-day',
        title: 'Deadline today',
        body: '${task.title} is due today.',
        fireAt: dueMorning,
        kind: StudentReminderKind.academicDeadline,
      );
    }
  }
}

Iterable<StudentReminder> _examCountdownReminders({
  required String uid,
  required List<Subject> subjects,
  required tz.TZDateTime now,
}) sync* {
  const countdownDays = [7, 3, 1];
  for (final subject in subjects) {
    final examDay = _dateOnly(subject.examDateIso);
    if (examDay == null) continue;

    for (final daysBefore in countdownDays) {
      final fireAt = _atAppTime(
        examDay.subtract(Duration(days: daysBefore)),
        9,
      );
      if (!fireAt.isAfter(now)) continue;
      yield StudentReminder(
        key:
            'student-reminder:$uid:subject-exam:${subject.id}:$daysBefore-days',
        title: '$daysBefore day${daysBefore == 1 ? '' : 's'} until exam',
        body: '${subject.name} exam is coming up. Check your study plan.',
        fireAt: fireAt,
        kind: StudentReminderKind.examCountdown,
      );
    }

    final examMorning = _atAppTime(examDay, 8);
    if (examMorning.isAfter(now)) {
      yield StudentReminder(
        key: 'student-reminder:$uid:subject-exam:${subject.id}:exam-day',
        title: '${subject.name} exam today',
        body: 'Good luck. Review your final notes before you go.',
        fireAt: examMorning,
        kind: StudentReminderKind.examCountdown,
      );
    }
  }
}

tz.TZDateTime? _sessionStartAt(StudySession session) {
  final day = _dateOnly(session.date);
  final minute = session.startMinute;
  if (day == null || minute == null) return null;
  return tz.TZDateTime(
    appTimeZoneLocation,
    day.year,
    day.month,
    day.day,
    minute ~/ 60,
    minute % 60,
  );
}

DateTime? _dateOnly(String value) {
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

tz.TZDateTime _atAppTime(DateTime day, int hour) {
  return tz.TZDateTime(
    appTimeZoneLocation,
    day.year,
    day.month,
    day.day,
    hour,
  );
}
