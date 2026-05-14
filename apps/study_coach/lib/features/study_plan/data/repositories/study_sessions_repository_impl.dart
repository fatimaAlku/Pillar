import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/config/app_time_zone.dart';
import '../../../../core/constants/firestore_paths.dart';
import 'google_calendar_sync_repository.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/entities/topic_activity_signals.dart';
import '../../domain/repositories/study_sessions_repository.dart';

class StudySessionsRepositoryImpl implements StudySessionsRepository {
  StudySessionsRepositoryImpl(this._db, this._googleCalendarSyncRepository);

  final FirebaseFirestore _db;
  final GoogleCalendarSyncRepository _googleCalendarSyncRepository;

  String _todayKey() => appTodayDateIso();

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

  /// Scheduled sessions are never hard-deleted; removal sets [deletedAt].
  static bool sessionDocIsDeleted(Map<String, dynamic> data) {
    final v = data['deletedAt'];
    if (v == null) return false;
    if (v is Timestamp) return true;
    if (v is String && v.isNotEmpty) return true;
    return false;
  }

  /// Commits a new session. If no active plan exists, creates the plan and the
  /// session in one [WriteBatch] so the client does not depend on two serial
  /// commits (which can misbehave under load or flaky networks).
  Future<_CreatedSessionRef> _commitSessionWrite({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
    required int startMinute,
  }) async {
    final minutes = durationMin.clamp(5, 240);
    final clampedStartMinute = startMinute.clamp(0, 1439);
    final sessionPayload = <String, dynamic>{
      'date': dateIso,
      'topicId': topicId,
      'durationMin': minutes,
      'startMinute': clampedStartMinute,
      'completed': false,
    };

    var planRef = await _activePlanRef(uid);
    if (planRef != null) {
      final sessionRef = planRef.collection(FirestorePaths.sessions).doc();
      await sessionRef.set(sessionPayload);
      return _CreatedSessionRef(planRef.id, sessionRef.id);
    }

    final subjectIds = await _subjectDocIds(uid);
    planRef = await _activePlanRef(uid);
    if (planRef != null) {
      final sessionRef = planRef.collection(FirestorePaths.sessions).doc();
      await sessionRef.set(sessionPayload);
      return _CreatedSessionRef(planRef.id, sessionRef.id);
    }

    final now = DateTime.now().toIso8601String();
    final newPlanRef = _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc();
    final sessionRef = newPlanRef.collection(FirestorePaths.sessions).doc();
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
    return _CreatedSessionRef(newPlanRef.id, sessionRef.id);
  }

  @override
  Future<void> addSession({
    required String uid,
    required String topicId,
    required String dateIso,
    required int durationMin,
    required int startMinute,
  }) async {
    final created = await _commitSessionWrite(
      uid: uid,
      topicId: topicId,
      dateIso: dateIso,
      durationMin: durationMin,
      startMinute: startMinute,
    ).timeout(
      _writeTimeout,
      onTimeout: () => throw TimeoutException(
        'Firestore write timed out after ${_writeTimeout.inSeconds}s',
      ),
    );
    unawaited(
      _googleCalendarSyncRepository.syncSession(
        action: 'create',
        uid: uid,
        planId: created.planId,
        sessionId: created.sessionId,
      ),
    );
  }

  @override
  Stream<List<StudySession>> watchTodaysSessions(String uid) {
    return watchSessionsForDate(uid, _todayKey());
  }

  @override
  Stream<Map<String, TopicActivitySignals>> watchRecentTopicActivity(
    String uid, {
    int windowDays = 14,
  }) {
    final userRef = _db.collection(FirestorePaths.users).doc(uid);
    return userRef
        .collection(FirestorePaths.studyPlans)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .snapshots()
        .asyncExpand((planSnap) {
      if (planSnap.docs.isEmpty) {
        return Stream.value(<String, TopicActivitySignals>{});
      }
      final today = appTodayDateOnly();
      final clampedWindow = windowDays.clamp(1, 90);
      final since = today.subtract(Duration(days: clampedWindow));
      final sinceIso = _dateOnlyIso(since);
      return planSnap.docs.first.reference
          .collection(FirestorePaths.sessions)
          .where('date', isGreaterThanOrEqualTo: sinceIso)
          .snapshots()
          .map(
            (sessionsSnap) => _aggregateActivity(
              today: today,
              docs: sessionsSnap.docs
                  .where((d) => !sessionDocIsDeleted(d.data()))
                  .map((d) => d.data())
                  .toList(growable: false),
            ),
          );
    });
  }

  static Map<String, TopicActivitySignals> _aggregateActivity({
    required DateTime today,
    required List<Map<String, dynamic>> docs,
  }) {
    if (docs.isEmpty) return const <String, TopicActivitySignals>{};
    final lastByTopic = <String, DateTime>{};
    final missedByTopic = <String, int>{};
    final completedByTopic = <String, int>{};

    for (final data in docs) {
      final topicId = (data['topicId'] as String?)?.trim() ?? '';
      if (topicId.isEmpty) continue;
      final dateIso = (data['date'] as String?)?.trim() ?? '';
      final dateOnly = appParseCalendarDateOnly(dateIso);
      if (dateOnly == null) continue;
      final isPast = dateOnly.isBefore(today);
      final completed = data['completed'] == true;

      if (completed) {
        completedByTopic[topicId] = (completedByTopic[topicId] ?? 0) + 1;
        final existing = lastByTopic[topicId];
        if (existing == null || dateOnly.isAfter(existing)) {
          lastByTopic[topicId] = dateOnly;
        }
      } else if (isPast) {
        missedByTopic[topicId] = (missedByTopic[topicId] ?? 0) + 1;
      }
    }

    final keys = <String>{
      ...lastByTopic.keys,
      ...missedByTopic.keys,
      ...completedByTopic.keys,
    };
    final out = <String, TopicActivitySignals>{};
    for (final key in keys) {
      out[key] = TopicActivitySignals(
        lastStudiedAt: lastByTopic[key],
        missedSessions: missedByTopic[key] ?? 0,
        completedSessions: completedByTopic[key] ?? 0,
      );
    }
    return out;
  }

  static String _dateOnlyIso(DateTime date) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
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
                .where((d) => !sessionDocIsDeleted(d.data()))
                .map((d) => _fromDoc(planId: planId, id: d.id, data: d.data()))
                .toList(),
          );
    });
  }

  @override
  Stream<List<StudySession>> watchUpcomingSessions(
    String uid, {
    int horizonDays = 30,
  }) {
    final horizon = horizonDays.clamp(1, 365);
    final todayIso = appTodayDateIso();
    final through = appEndDateIsoFromToday(horizon);
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
          .where('date', isGreaterThanOrEqualTo: todayIso)
          .where('date', isLessThanOrEqualTo: through)
          .snapshots()
          .map(
        (sessionsSnap) {
          final sessions = sessionsSnap.docs
              .where((d) => !sessionDocIsDeleted(d.data()))
              .map((d) => _fromDoc(planId: planId, id: d.id, data: d.data()))
              .toList();
          sessions.sort((a, b) {
            final dateCompare = a.date.compareTo(b.date);
            if (dateCompare != 0) return dateCompare;
            return (a.startMinute ?? 0).compareTo(b.startMinute ?? 0);
          });
          return sessions;
        },
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
    final startMinuteRaw = data['startMinute'];
    final startMinute = startMinuteRaw is int
        ? startMinuteRaw.clamp(0, 1439)
        : (startMinuteRaw is num
            ? startMinuteRaw.toInt().clamp(0, 1439)
            : null);
    final reasonRaw = data['reason'];
    final reason = reasonRaw is String && reasonRaw.trim().isNotEmpty
        ? reasonRaw.trim()
        : null;
    return StudySession(
      id: id,
      planId: planId,
      topicId: topicId,
      date: date,
      durationMin: durationMin,
      startMinute: startMinute,
      completed: completed,
      reason: reason,
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
    int? startMinute,
  }) async {
    final updates = <String, dynamic>{};
    if (topicId != null) updates['topicId'] = topicId;
    if (durationMin != null) {
      updates['durationMin'] = durationMin.clamp(5, 240);
    }
    if (startMinute != null) {
      updates['startMinute'] = startMinute.clamp(0, 1439);
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
    unawaited(
      _googleCalendarSyncRepository.syncSession(
        action: 'update',
        uid: uid,
        planId: planId,
        sessionId: sessionId,
      ),
    );
  }

  @override
  Future<void> deleteSession({
    required String uid,
    required String planId,
    required String sessionId,
  }) async {
    final deletedAt = DateTime.now().toUtc().toIso8601String();
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.studyPlans)
        .doc(planId)
        .collection(FirestorePaths.sessions)
        .doc(sessionId)
        .update({'deletedAt': deletedAt});
    unawaited(
      _googleCalendarSyncRepository.syncSession(
        action: 'delete',
        uid: uid,
        planId: planId,
        sessionId: sessionId,
      ),
    );
  }
}

class _CreatedSessionRef {
  const _CreatedSessionRef(this.planId, this.sessionId);

  final String planId;
  final String sessionId;
}
