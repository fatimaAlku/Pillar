import '../entities/user_profile_data.dart';

abstract class UserProfileRepository {
  Stream<UserProfileData?> watchProfile(String uid);

  Future<void> setMajor({
    required String uid,
    required String majorId,
    required String source,
  });

  /// Persists the user's preferred daily study budget (in minutes). Pass
  /// `null` to clear the override and fall back to the planner default.
  Future<void> setDailyStudyMinutes({
    required String uid,
    required int? minutes,
  });
}
