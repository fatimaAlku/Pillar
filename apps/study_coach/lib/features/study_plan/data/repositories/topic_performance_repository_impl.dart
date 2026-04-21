import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../subjects/data/models/subject_model.dart';
import '../../domain/entities/study_personalization_models.dart';
import '../../domain/repositories/topic_performance_repository.dart';

class TopicPerformanceRepositoryImpl implements TopicPerformanceRepository {
  TopicPerformanceRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<TopicPerformanceInput>> watchTopicPerformanceInputs(String uid) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .snapshots()
        .asyncMap(_mapSnapshot);
  }

  Future<List<TopicPerformanceInput>> _mapSnapshot(
    QuerySnapshot<Map<String, dynamic>> subjectSnap,
  ) async {
    final now = DateTime.now();
    final inputs = <TopicPerformanceInput>[];
    for (final doc in subjectSnap.docs) {
      final subject = SubjectModel.fromMap(doc.id, doc.data());
      final examDate = _examDateForSubject(subject.examDateIso, now);
      final topicsSnap =
          await doc.reference.collection(FirestorePaths.topics).get();
      if (topicsSnap.docs.isEmpty) {
        if (subject.name.isNotEmpty) {
          inputs.add(
            TopicPerformanceInput(
              topicId: 'subject_${subject.id}_overview',
              topicTitle: subject.name,
              subjectId: subject.id,
              subjectTitle: subject.name,
              examDate: examDate,
              quizAccuracy: 0.5,
              subjectDifficulty: 0.5,
              lastStudiedAt: null,
              missedSessions: 0,
            ),
          );
        }
      } else {
        for (final t in topicsSnap.docs) {
          inputs.add(_fromTopicDoc(
            subject: subject,
            topicId: t.id,
            data: t.data(),
            examDate: examDate,
          ));
        }
      }
    }
    return inputs;
  }

  TopicPerformanceInput _fromTopicDoc({
    required SubjectModel subject,
    required String topicId,
    required Map<String, dynamic> data,
    required DateTime examDate,
  }) {
    final title = (data['title'] as String?)?.trim().isNotEmpty == true
        ? data['title'] as String
        : 'Topic';
    final raw = data['difficultyEstimate'];
    final difficulty = raw is num
        ? raw.toDouble().clamp(0.0, 1.0)
        : 0.5;
    return TopicPerformanceInput(
      topicId: topicId,
      topicTitle: title,
      subjectId: subject.id,
      subjectTitle: subject.name,
      examDate: examDate,
      quizAccuracy: 0.5,
      subjectDifficulty: difficulty,
      lastStudiedAt: null,
      missedSessions: 0,
    );
  }

  static DateTime _examDateForSubject(String examDateIso, DateTime now) {
    if (examDateIso.isEmpty) {
      return now.add(const Duration(days: 21));
    }
    final parsed = DateTime.tryParse(examDateIso);
    if (parsed == null) {
      return now.add(const Duration(days: 21));
    }
    return parsed;
  }
}
