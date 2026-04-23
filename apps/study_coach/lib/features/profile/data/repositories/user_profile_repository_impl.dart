import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../domain/entities/user_profile_data.dart';
import '../../domain/repositories/user_profile_repository.dart';

class UserProfileRepositoryImpl implements UserProfileRepository {
  UserProfileRepositoryImpl(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<UserProfileData?> watchProfile(String uid) {
    return _db.collection(FirestorePaths.users).doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() ?? <String, dynamic>{};
      final majorId = (data['majorId'] as String?)?.trim();
      final majorSource = (data['majorSource'] as String?)?.trim();
      return UserProfileData(
        majorId: (majorId == null || majorId.isEmpty) ? null : majorId,
        majorSource:
            (majorSource == null || majorSource.isEmpty) ? null : majorSource,
      );
    });
  }

  @override
  Future<void> setMajor({
    required String uid,
    required String majorId,
    required String source,
  }) async {
    await _db.collection(FirestorePaths.users).doc(uid).set({
      'majorId': majorId.trim(),
      'majorSource': source.trim(),
      'majorSelectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
