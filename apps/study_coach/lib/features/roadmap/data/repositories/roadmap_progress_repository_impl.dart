import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/repositories/roadmap_progress_repository.dart';

class RoadmapProgressRepositoryImpl implements RoadmapProgressRepository {
  RoadmapProgressRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid, String majorId) {
    return _db
        .collection(FirestorePaths.users)
        .doc(uid)
        .collection(FirestorePaths.roadmapProgress)
        .doc(majorId);
  }

  @override
  Stream<Set<String>> watchCompletedItemKeys({
    required String uid,
    required String majorId,
  }) {
    return _doc(uid, majorId).snapshots().map((doc) {
      final data = doc.data();
      final raw = data?['completedItemKeys'];
      if (raw is! List) return <String>{};
      return raw.whereType<String>().toSet();
    });
  }

  @override
  Future<void> toggleItem({
    required String uid,
    required String majorId,
    required String itemKey,
    required bool completed,
    required int totalItemCount,
  }) async {
    final update = {
      'updatedAt': FieldValue.serverTimestamp(),
      'version': 1,
      'totalItemCount': totalItemCount,
      'completedItemKeys': completed
          ? FieldValue.arrayUnion([itemKey])
          : FieldValue.arrayRemove([itemKey]),
    };
    await _doc(uid, majorId).set(update, SetOptions(merge: true));
  }
}
