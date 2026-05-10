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
      final dailyMinutesRaw = data['dailyStudyMinutes'];
      int? dailyMinutes;
      if (dailyMinutesRaw is num) {
        dailyMinutes = dailyMinutesRaw.toInt().clamp(
              UserProfileData.minDailyStudyMinutes,
              UserProfileData.maxDailyStudyMinutes,
            );
      }
      return UserProfileData(
        majorId: (majorId == null || majorId.isEmpty) ? null : majorId,
        majorSource:
            (majorSource == null || majorSource.isEmpty) ? null : majorSource,
        dailyStudyMinutes: dailyMinutes,
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

  @override
  Future<void> setDailyStudyMinutes({
    required String uid,
    required int? minutes,
  }) async {
    final ref = _db.collection(FirestorePaths.users).doc(uid);
    if (minutes == null) {
      await ref.set({
        'dailyStudyMinutes': FieldValue.delete(),
        'dailyStudyMinutesUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return;
    }
    final clamped = minutes.clamp(
      UserProfileData.minDailyStudyMinutes,
      UserProfileData.maxDailyStudyMinutes,
    );
    await ref.set({
      'dailyStudyMinutes': clamped,
      'dailyStudyMinutesUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
