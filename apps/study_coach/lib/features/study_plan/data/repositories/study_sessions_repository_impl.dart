import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_sessions_repository.dart';

class StudySessionsRepositoryImpl implements StudySessionsRepository {
  StudySessionsRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  String _todayKey() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  @override
  Stream<List<StudySession>> watchTodaysSessions(String uid) {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    return userRef
        .collection(FirestorePaths.studyPlans)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .asyncExpand((planSnap) {
      if (planSnap.docs.isEmpty) {
        return Stream.value(<StudySession>[]);
      }
      final planDoc = planSnap.docs.first;
      final planId = planDoc.id;
      final today = _todayKey();
      return planDoc.reference
          .collection(FirestorePaths.sessions)
          .where('date', isEqualTo: today)
          .snapshots()
          .map(
            (sessionsSnap) => sessionsSnap.docs
                .map((d) => _fromDoc(planId: planId, id: d.id, data: d.data()))
                .toList(),
          );
    });
  }

  StudySession _fromDoc({
    required String planId,
    required String id,
    required Map<String, dynamic> data,
  }) {
    final durationRaw = data['durationMin'];
    final durationMin = durationRaw is int
        ? durationRaw
        : (durationRaw is num ? durationRaw.toInt() : 30);
    final completed = data['completed'] == true;
    final topicId = data['topicId'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    return StudySession(
      id: id,
      planId: planId,
      topicId: topicId,
      date: date,
      durationMin: durationMin,
      completed: completed,
    );
  }

  @override
  Future<void> setSessionCompleted({
    required String uid,
    required String planId,
    required String sessionId,
    required bool completed,
  }) async {
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc(planId)
        .collection(FirestorePaths.sessions)
        .doc(sessionId)
        .update({'completed': completed});
  }
}
