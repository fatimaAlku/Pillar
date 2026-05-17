import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/quiz_history_entry.dart';
import '../../domain/entities/quiz_submission_result.dart';
import '../../domain/repositories/quiz_history_repository.dart';

class QuizHistoryRepositoryImpl implements QuizHistoryRepository {
  QuizHistoryRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> saveAttempt({
    required String uid,
    required QuizSubmissionResult result,
    required DateTime completedAt,
  }) async {
    final weakTopicTitles = result.weakTopics
        .map((e) => e.topicTitle.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final data = <String, dynamic>{
      'completedAt': Timestamp.fromDate(completedAt),
      'scoreFraction': result.scoreFraction.clamp(0.0, 1.0),
      'correctCount': result.correctCount,
      'totalCount': result.totalCount,
      'weakTopicTitles': weakTopicTitles,
    };

    final link = result.linkContext;
    if (link != null && link.hasSubject) {
      data['linkedSubjectId'] = link.subjectId.trim();
      data['linkedSubjectTitle'] = link.subjectTitle.trim();
      data['linkedTopicIds'] = List<String>.from(link.linkedTopicIds);
      data['linkedTopicTitles'] = List<String>.from(link.linkedTopicTitles);
    }

    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.quizHistory)
        .add(data);
  }

  @override
  Stream<List<QuizHistoryEntry>> watchHistory(String uid, {int limit = 30}) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.quizHistory)
        .orderBy('completedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final completedAtRaw = data['completedAt'];
        final completedAt = completedAtRaw is Timestamp
            ? completedAtRaw.toDate()
            : DateTime.fromMillisecondsSinceEpoch(0);
        final weakRaw = data['weakTopicTitles'];
        final weakTopics = weakRaw is List
            ? weakRaw
                .whereType<String>()
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
            : const <String>[];
        final correctCount = (data['correctCount'] as num?)?.toInt() ?? 0;
        final totalCount = (data['totalCount'] as num?)?.toInt() ?? 0;
        final scoreFraction = (data['scoreFraction'] as num?)?.toDouble() ??
            (totalCount == 0 ? 0 : (correctCount / totalCount));

        final sid = (data['linkedSubjectId'] as String?)?.trim();
        final stitle = (data['linkedSubjectTitle'] as String?)?.trim();
        final idsRaw = data['linkedTopicIds'];
        final titlesRaw = data['linkedTopicTitles'];
        final linkedIds = idsRaw is List
            ? idsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false)
            : const <String>[];
        final linkedTitles = titlesRaw is List
            ? titlesRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList(growable: false)
            : const <String>[];

        return QuizHistoryEntry(
          id: doc.id,
          completedAt: completedAt,
          correctCount: correctCount,
          totalCount: totalCount,
          scoreFraction: scoreFraction.clamp(0.0, 1.0),
          weakTopicTitles: weakTopics,
          linkedSubjectId: (sid == null || sid.isEmpty) ? null : sid,
          linkedSubjectTitle: (stitle == null || stitle.isEmpty) ? null : stitle,
          linkedTopicIds: linkedIds,
          linkedTopicTitles: linkedTitles,
        );
      }).toList(growable: false);
    });
  }

  @override
  Future<void> deleteAttempt({
    required String uid,
    required String entryId,
  }) async {
    final id = entryId.trim();
    if (id.isEmpty) return;
    await _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.quizHistory)
        .doc(id)
        .delete();
  }
}
