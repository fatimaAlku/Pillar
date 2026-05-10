class UserProfileData {
  const UserProfileData({
    required this.majorId,
    required this.majorSource,
    this.dailyStudyMinutes,
  });

  final String? majorId;
  final String? majorSource;

  /// Preferred daily study budget in minutes used to size the dynamic plan.
  /// `null` falls back to [defaultDailyStudyMinutes] in the planner.
  final int? dailyStudyMinutes;

  /// Default daily budget used when the user has not picked a value yet.
  static const int defaultDailyStudyMinutes = 120;

  /// Allowed values surfaced in pickers; the planner clamps to this range.
  static const int minDailyStudyMinutes = 30;
  static const int maxDailyStudyMinutes = 360;

  UserProfileData copyWith({
    String? majorId,
    String? majorSource,
    int? dailyStudyMinutes,
    bool clearMajor = false,
    bool clearDailyStudyMinutes = false,
  }) {
    return UserProfileData(
      majorId: clearMajor ? null : (majorId ?? this.majorId),
      majorSource: clearMajor ? null : (majorSource ?? this.majorSource),
      dailyStudyMinutes: clearDailyStudyMinutes
          ? null
          : (dailyStudyMinutes ?? this.dailyStudyMinutes),
    );
  }
}
