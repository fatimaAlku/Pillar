import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/progress_snapshot.dart';
import '../../domain/repositories/progress_repository.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<ProgressSnapshot> watchProgress(String uid) async* {
    ProgressSnapshot? lastSnapshot;
    while (true) {
      try {
        final snapshot = await _compute(uid);
        lastSnapshot = snapshot;
        yield snapshot;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          // Keep UI usable during transient Firestore outages.
          yield lastSnapshot ?? ProgressSnapshot.empty;
        } else {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 20));
    }
  }

  Future<ProgressSnapshot> _compute(String uid) async {
    final userDoc = await _db.collection(FirestorePaths.users).doc(uid).get();
    final majorId = (userDoc.data()?['majorId'] as String?)?.trim();

    final roadmapData = await _computeRoadmap(uid, majorId);
    final sessionCompletion = await _computeSessionCompletion(uid);
    final quizData = await _computeQuizSignal(uid);

    final overall = (roadmapData.$1 * 0.4) +
        (sessionCompletion * 0.35) +
        (quizData.$1 * 0.25);

    return ProgressSnapshot(
      overallProgress: overall.clamp(0.0, 1.0),
      roadmapCompletion: roadmapData.$1.clamp(0.0, 1.0),
      sessionsCompletion: sessionCompletion.clamp(0.0, 1.0),
      avgScore: quizData.$1.clamp(0.0, 1.0),
      weakAreas: quizData.$2,
      majorId: (majorId == null || majorId.isEmpty) ? null : majorId,
    );
  }

  Future<(double, int)> _computeRoadmap(String uid, String? majorId) async {
    if (majorId == null || majorId.isEmpty) {
      return (0.0, 0);
    }
    final doc = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.roadmapProgress)
        .doc(majorId)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    final completed =
        (data['completedItemKeys'] as List?)?.whereType<String>().length ?? 0;
    final total = (data['totalItemCount'] as num?)?.toInt() ?? 0;
    if (total <= 0) return (0.0, completed);
    return ((completed / total), completed);
  }

  Future<double> _computeSessionCompletion(String uid) async {
    final activePlanQuery = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (activePlanQuery.docs.isEmpty) return 0.0;

    final since = DateTime.now().subtract(const Duration(days: 14));
    final sinceIso = _toDateIso(since);
    final sessionsQuery = await activePlanQuery.docs.first.reference
        .collection(FirestorePaths.sessions)
        .where('date', isGreaterThanOrEqualTo: sinceIso)
        .get();
    if (sessionsQuery.docs.isEmpty) return 0.0;

    final completedCount = sessionsQuery.docs.where((doc) {
      final value = doc.data()['completed'];
      return value == true;
    }).length;
    return completedCount / sessionsQuery.docs.length;
  }

  Future<(double, List<String>)> _computeQuizSignal(String uid) async {
    final quizzesQuery = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.quizzes)
        .limit(12)
        .get();

    final scores = <double>[];
    final weakCounts = <String, int>{};
    for (final quizDoc in quizzesQuery.docs) {
      final attempts = await quizDoc.reference
          .collection(FirestorePaths.attempts)
          .orderBy('completedAt', descending: true)
          .limit(5)
          .get();
      for (final attempt in attempts.docs) {
        final rawScore = attempt.data()['score'];
        if (rawScore is num) {
          scores.add(rawScore.toDouble().clamp(0.0, 1.0));
        }
        final weakTags = attempt.data()['weakTags'];
        if (weakTags is List) {
          for (final tag in weakTags.whereType<String>()) {
            final trimmed = tag.trim();
            if (trimmed.isEmpty) continue;
            weakCounts[trimmed] = (weakCounts[trimmed] ?? 0) + 1;
          }
        }
      }
    }

    final avg =
        scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
    final weakAreas = weakCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return (avg, weakAreas.take(3).map((e) => e.key).toList());
  }

  String _toDateIso(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
