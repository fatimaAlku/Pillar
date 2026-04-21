import 'dart:async';

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

  Future<DocumentReference<Map<String, dynamic>>?> _activePlanRef(
    String uid,
  ) async {
    final snap = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.reference;
  }

  Future<List<String>> _subjectDocIds(String uid) async {
    final snap = await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.subjects)
        .get();
    return snap.docs.map((d) => d.id).toList();
  }

  static const _writeTimeout = Duration(seconds: 45);

  /// Commits a new session. If no active plan exists, creates the plan and the
  /// session in one [WriteBatch] so the client does not depend on two serial
  /// commits (which can misbehave under load or flaky networks).
  Future<void> _commitSessionWrite({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
  }) async {
    final minutes = durationMin.clamp(5, 240);
    final sessionPayload = <String, dynamic>{
      'date': dateIso,
      'topicId': topicId,
      'durationMin': minutes,
      'completed': false,
    };

    var planRef = await _activePlanRef(uid);
    if (planRef != null) {
      await planRef
          .collection(FirestorePaths.sessions)
          .doc()
          .set(sessionPayload);
      return;
    }

    final subjectIds = await _subjectDocIds(uid);
    planRef = await _activePlanRef(uid);
    if (planRef != null) {
      await planRef
          .collection(FirestorePaths.sessions)
          .doc()
          .set(sessionPayload);
      return;
    }

    final now = DateTime.now().toIso8601String();
    final newPlanRef = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc();
    final sessionRef =
        newPlanRef.collection(FirestorePaths.sessions).doc();
    final batch = _db.batch()
      ..set(newPlanRef, {
        'startDate': now,
        'endDate': now,
        'generatedAt': now,
        'status': 'active',
        'generatedBy': 'schedule',
        'lastAdjustedAt': now,
        'subjectIds': subjectIds,
      })
      ..set(sessionRef, sessionPayload);
    await batch.commit();
  }

  @override
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
  }) async {
    await _commitSessionWrite(
      uid: uid,
      topicId: topicId,
      dateIso: dateIso,
      durationMin: durationMin,
    ).timeout(
      _writeTimeout,
      onTimeout: () => throw TimeoutException(
        'Firestore write timed out after ${_writeTimeout.inSeconds}s',
      ),
    );
  }

  @override
  Stream<List<StudySession>> watchTodaysSessions(String uid) {
    return watchSessionsForDate(uid, _todayKey());
  }

  @override
  Stream<List<StudySession>> watchSessionsForDate(String uid, String dateIso) {
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
      return planDoc.reference
          .collection(FirestorePaths.sessions)
          .where('date', isEqualTo: dateIso)
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

  @override
  Future<void> updateSession({
    required String uid,
    required String planId,
    required String sessionId,
    String? topicId,
    int? durationMin,
  }) async {
    final updates = <String, dynamic>{};
    if (topicId != null) updates['topicId'] = topicId;
    if (durationMin != null) {
      updates['durationMin'] = durationMin.clamp(5, 240);
    }
    if (updates.isEmpty) return;
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc(planId)
        .collection(FirestorePaths.sessions)
        .doc(sessionId)
        .update(updates);
  }

  @override
  Future<void> deleteSession({
    required String uid,
    required String planId,
    required String sessionId,
  }) async {
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc(planId)
        .collection(FirestorePaths.sessions)
        .doc(sessionId)
        .delete();
  }
}
