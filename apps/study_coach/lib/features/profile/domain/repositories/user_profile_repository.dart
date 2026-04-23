import '../entities/user_profile_data.dart';

abstract class UserProfileRepository {
  Stream<UserProfileData?> watchProfile(String uid);

  Future<void> setMajor({
    required String uid,
    required String majorId,
    required String source,
  });
}
