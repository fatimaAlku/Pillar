import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/academic_tasks/domain/entities/academic_task.dart';
import '../config/app_time_zone.dart';
import '../constants/firestore_paths.dart';

/// Writes realistic sample data into the signed-in user's Firestore tree for
/// live demos (subjects, plan sessions, quiz history, insights, tasks).
class DemoDataSeeder {
  DemoDataSeeder(this._db);

  final FirebaseFirestore _db;

  static const demoPlanId = 'demo_active_plan';

  static const _subjectDataStructuresId = 'demo_subject_data_structures';
  static const _subjectDatabaseId = 'demo_subject_database';

  Future<void> seedForUser(String uid) async {
    final now = DateTime.now().toUtc();
    final nowIso = now.toIso8601String();
    final todayIso = appTodayDateIso();

    final userRef = _db.collection(FirestorePaths.users).doc(uid);

    await userRef.set({
      'majorId': 'computer_science',
      'majorSource': 'demo',
      'dailyStudyMinutes': 120,
      'demoSeededAt': nowIso,
    }, SetOptions(merge: true));

    final dsRef =
        userRef.collection(FirestorePaths.subjects).doc(_subjectDataStructuresId);
    final dbRef =
        userRef.collection(FirestorePaths.subjects).doc(_subjectDatabaseId);

    final dsExamIso = _examDateIso(todayIso, 18);
    final dbExamIso = _examDateIso(todayIso, 32);

    await dsRef.set({
      'name': 'Data Structures',
      'color': '#5C6BC0',
      'examDate': dsExamIso,
    });
    await dbRef.set({
      'name': 'Database Systems',
      'color': '#26A69A',
      'examDate': dbExamIso,
    });

    const dsTopics = <({String id, String title, double difficulty})>[
      (id: 'demo_topic_arrays', title: 'Arrays & Linked Lists', difficulty: 0.45),
      (id: 'demo_topic_trees', title: 'Trees & Binary Search Trees', difficulty: 0.62),
      (id: 'demo_topic_graphs', title: 'Graph Algorithms', difficulty: 0.7),
    ];
    const dbTopics = <({String id, String title, double difficulty})>[
      (id: 'demo_topic_sql', title: 'SQL & Relational Model', difficulty: 0.5),
      (id: 'demo_topic_normalization', title: 'Normalization', difficulty: 0.68),
      (id: 'demo_topic_transactions', title: 'Transactions & ACID', difficulty: 0.72),
    ];

    for (final t in dsTopics) {
      await dsRef.collection(FirestorePaths.topics).doc(t.id).set({
        'title': t.title,
        'difficultyEstimate': t.difficulty,
      });
    }
    for (final t in dbTopics) {
      await dbRef.collection(FirestorePaths.topics).doc(t.id).set({
        'title': t.title,
        'difficultyEstimate': t.difficulty,
      });
    }

    await _supersedeActivePlans(userRef, nowIso);

    final allTopicIds = [
      ...dsTopics.map((t) => t.id),
      ...dbTopics.map((t) => t.id),
    ];
    const reasons = <String>[
      'low quiz performance',
      'upcoming exam',
      'missed sessions',
      'baseline personalization',
    ];

    final planRef =
        userRef.collection(FirestorePaths.studyPlans).doc(demoPlanId);
    await _clearPlanSessions(planRef);

    final lastDayIso = _addCalendarDaysIso(todayIso, 13);
    await planRef.set({
      'startDate': '${_addCalendarDaysIso(todayIso, -1)}T08:00:00.000Z',
      'endDate': '${lastDayIso}T20:00:00.000Z',
      'generatedAt': nowIso,
      'status': 'active',
      'generatedBy': 'demo',
      'lastAdjustedAt': nowIso,
      'subjectIds': [_subjectDataStructuresId, _subjectDatabaseId],
      'horizonDays': 14,
      'dailyStudyMinutes': 120,
    });

    var topicIndex = 0;
    var minuteCursor = 17 * 60;
    final batch = _db.batch();

    void queueSession({
      required String dateIso,
      required String topicId,
      required int durationMin,
      required int startMinute,
      required bool completed,
      required String reason,
    }) {
      final sessionRef = planRef.collection(FirestorePaths.sessions).doc();
      batch.set(sessionRef, {
        'date': dateIso,
        'topicId': topicId,
        'durationMin': durationMin,
        'startMinute': startMinute,
        'completed': completed,
        'reason': reason,
      });
    }

    final yesterdayIso = _addCalendarDaysIso(todayIso, -1);
    queueSession(
      dateIso: yesterdayIso,
      topicId: allTopicIds[topicIndex % allTopicIds.length],
      durationMin: 45,
      startMinute: 17 * 60,
      completed: true,
      reason: reasons[2],
    );
    topicIndex += 1;

    for (var dayOffset = 0; dayOffset < 14; dayOffset++) {
      final dayIso = _addCalendarDaysIso(todayIso, dayOffset);
      final sessionsThisDay = dayOffset == 0 ? 2 : (dayOffset.isEven ? 2 : 1);
      for (var s = 0; s < sessionsThisDay; s++) {
        final topicId = allTopicIds[topicIndex % allTopicIds.length];
        topicIndex += 1;
        final duration = 35 + (topicIndex % 3) * 10;
        final startMinute = minuteCursor.clamp(0, 21 * 60);
        minuteCursor += duration + 10;
        final completed = dayOffset == 0 && s == 0;
        queueSession(
          dateIso: dayIso,
          topicId: topicId,
          durationMin: duration,
          startMinute: startMinute,
          completed: completed,
          reason: reasons[(topicIndex + dayOffset) % reasons.length],
        );
      }
      minuteCursor = 17 * 60;
    }

    await batch.commit();

    final historyRef = userRef.collection(FirestorePaths.quizHistory);
    final threeDaysAgo = now.subtract(const Duration(days: 3));
    final twoDaysAgo = now.subtract(const Duration(days: 2));
    final oneDayAgo = now.subtract(const Duration(days: 1));

    await historyRef.doc('demo_quiz_history_1').set({
      'completedAt': Timestamp.fromDate(threeDaysAgo),
      'scoreFraction': 0.55,
      'correctCount': 5,
      'totalCount': 10,
      'weakTopicTitles': ['Graph Algorithms', 'Normalization'],
      'linkedSubjectId': _subjectDataStructuresId,
      'linkedSubjectTitle': 'Data Structures',
      'linkedTopicIds': ['demo_topic_graphs'],
      'linkedTopicTitles': ['Graph Algorithms'],
    });
    await historyRef.doc('demo_quiz_history_2').set({
      'completedAt': Timestamp.fromDate(twoDaysAgo),
      'scoreFraction': 0.72,
      'correctCount': 7,
      'totalCount': 10,
      'weakTopicTitles': ['Trees & Binary Search Trees'],
      'linkedSubjectId': _subjectDataStructuresId,
      'linkedSubjectTitle': 'Data Structures',
      'linkedTopicIds': ['demo_topic_trees'],
      'linkedTopicTitles': ['Trees & Binary Search Trees'],
    });
    await historyRef.doc('demo_quiz_history_3').set({
      'completedAt': Timestamp.fromDate(oneDayAgo),
      'scoreFraction': 0.8,
      'correctCount': 8,
      'totalCount': 10,
      'weakTopicTitles': ['Transactions & ACID'],
      'linkedSubjectId': _subjectDatabaseId,
      'linkedSubjectTitle': 'Database Systems',
      'linkedTopicIds': ['demo_topic_transactions'],
      'linkedTopicTitles': ['Transactions & ACID'],
    });

    await userRef
        .collection(FirestorePaths.insights)
        .doc('demo_insight_latest')
        .set({
      'weakAreas': [
        'Graph Algorithms',
        'Normalization',
        'Transactions & ACID',
      ],
      'strengths': ['Arrays & Linked Lists', 'SQL & Relational Model'],
      'confidenceByTopic': {
        'Arrays & Linked Lists': 0.82,
        'Trees & Binary Search Trees': 0.68,
        'Graph Algorithms': 0.42,
        'SQL & Relational Model': 0.75,
        'Normalization': 0.51,
        'Transactions & ACID': 0.48,
      },
      'recommendationText':
          'Focus your next study blocks on graph traversal and database normalization. '
          'You are performing well on linear structures and SQL basics — keep those sharp with '
          'short review quizzes while allocating more plan time to weaker topics before exams.',
      'generatedAt': nowIso,
      'quizSampleSize': 3,
    });

    final tasksRef = userRef.collection(FirestorePaths.academicTasks);
    await tasksRef.doc('demo_task_project').set({
      'title': 'Data Structures project milestone',
      'type': AcademicTaskType.project.name,
      'subjectId': _subjectDataStructuresId,
      'dueDate': _examDateIso(todayIso, 10),
      'estimatedMinutes': 120,
      'priority': AcademicTaskPriority.high.name,
      'status': AcademicTaskStatus.open.name,
      'notes': 'Submit design document and complexity analysis.',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await tasksRef.doc('demo_task_lab').set({
      'title': 'Database lab: ER diagram',
      'type': AcademicTaskType.lab.name,
      'subjectId': _subjectDatabaseId,
      'dueDate': _examDateIso(todayIso, 5),
      'estimatedMinutes': 90,
      'priority': AcademicTaskPriority.medium.name,
      'status': AcademicTaskStatus.open.name,
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await tasksRef.doc('demo_task_quiz').set({
      'title': 'Online quiz — Trees',
      'type': AcademicTaskType.quiz.name,
      'subjectId': _subjectDataStructuresId,
      'dueDate': _examDateIso(todayIso, 3),
      'estimatedMinutes': 45,
      'priority': AcademicTaskPriority.high.name,
      'status': AcademicTaskStatus.open.name,
      'notes': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await userRef
        .collection(FirestorePaths.roadmapProgress)
        .doc('computer_science')
        .set({
      'completedItemKeys': [
        'cs_y1_s1_a0',
        'cs_y1_s1_a1',
        'cs_y1_s2_a0',
      ],
      'updatedAt': nowIso,
      'version': 1,
      'totalItemCount': 120,
    }, SetOptions(merge: true));
  }

  Future<void> _clearPlanSessions(
    DocumentReference<Map<String, dynamic>> planRef,
  ) async {
    final existing = await planRef.collection(FirestorePaths.sessions).get();
    if (existing.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<void> _supersedeActivePlans(
    DocumentReference<Map<String, dynamic>> userRef,
    String nowIso,
  ) async {
    final active = await userRef
        .collection(FirestorePaths.studyPlans)
        .where('status', isEqualTo: 'active')
        .get();
    for (final doc in active.docs) {
      if (doc.id == demoPlanId) continue;
      await doc.reference.update({
        'status': 'superseded',
        'supersededAt': nowIso,
      });
    }
  }

  static String _addCalendarDaysIso(String isoDate, int days) {
    final parsed = appParseCalendarDateOnly(isoDate);
    if (parsed == null) return isoDate;
    final shifted = parsed.add(Duration(days: days));
    return '${shifted.year.toString().padLeft(4, '0')}-'
        '${shifted.month.toString().padLeft(2, '0')}-'
        '${shifted.day.toString().padLeft(2, '0')}';
  }

  static String _examDateIso(String todayIso, int daysFromToday) {
    final day = _addCalendarDaysIso(todayIso, daysFromToday);
    return '${day}T12:00:00.000Z';
  }
}
