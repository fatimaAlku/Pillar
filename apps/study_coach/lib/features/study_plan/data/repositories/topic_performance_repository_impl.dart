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
        .asyncMap((snapshot) => _mapSnapshot(uid, snapshot));
  }

  Future<List<TopicPerformanceInput>> _mapSnapshot(
    String uid,
    QuerySnapshot<Map<String, dynamic>> subjectSnap,
  ) async {
    final now = DateTime.now();
    final quizSignals = await _loadQuizSignals(uid);
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
              quizAccuracy: _resolveQuizAccuracy(
                topicTitle: subject.name,
                fallback: quizSignals.globalScore,
                signals: quizSignals.byWeakTitle,
              ),
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
            quizSignals: quizSignals,
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
    required _QuizSignals quizSignals,
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
      quizAccuracy: _resolveQuizAccuracy(
        topicTitle: title,
        fallback: quizSignals.globalScore,
        signals: quizSignals.byWeakTitle,
      ),
      subjectDifficulty: difficulty,
      lastStudiedAt: null,
      missedSessions: 0,
    );
  }

  Future<_QuizSignals> _loadQuizSignals(String uid) async {
    QuerySnapshot<Map<String, dynamic>> historySnap;
    try {
      historySnap = await _db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.quizHistory)
          .orderBy('completedAt', descending: true)
          .limit(30)
          .get();
    } catch (_) {
      historySnap = await _db
          .collection(FirestorePaths.users)
          .doc(uid)
          .collection(FirestorePaths.quizHistory)
          .limit(30)
          .get();
    }

    final scores = <double>[];
    final weakCounts = <String, int>{};
    for (final doc in historySnap.docs) {
      final data = doc.data();
      final rawScore = data['scoreFraction'];
      if (rawScore is num) {
        scores.add(rawScore.toDouble().clamp(0.0, 1.0));
      }

      final weakRaw = data['weakTopicTitles'];
      if (weakRaw is List) {
        for (final weak in weakRaw.whereType<String>()) {
          final normalized = _normalize(weak);
          if (normalized.isEmpty) continue;
          weakCounts[normalized] = (weakCounts[normalized] ?? 0) + 1;
        }
      }
    }

    final global = scores.isEmpty
        ? 0.5
        : (scores.reduce((a, b) => a + b) / scores.length).clamp(0.0, 1.0);
    return _QuizSignals(
      globalScore: global,
      byWeakTitle: weakCounts,
    );
  }

  double _resolveQuizAccuracy({
    required String topicTitle,
    required double fallback,
    required Map<String, int> signals,
  }) {
    final normalizedTopic = _normalize(topicTitle);
    if (normalizedTopic.isEmpty) return fallback;
    var weakHits = 0;
    signals.forEach((weakTitle, count) {
      if (weakTitle.contains(normalizedTopic) ||
          normalizedTopic.contains(weakTitle)) {
        weakHits += count;
      }
    });
    if (weakHits <= 0) return fallback;
    final penalty = (weakHits * 0.12).clamp(0.0, 0.45);
    final adjusted = fallback - penalty;
    return adjusted.clamp(0.0, 1.0);
  }

  String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll('_', ' ');
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

class _QuizSignals {
  const _QuizSignals({
    required this.globalScore,
    required this.byWeakTitle,
  });

  final double globalScore;
  final Map<String, int> byWeakTitle;
}
