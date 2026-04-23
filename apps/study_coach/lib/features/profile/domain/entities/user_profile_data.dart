class UserProfileData {
  const UserProfileData({
    required this.majorId,
    required this.majorSource,
  });

  final String? majorId;
  final String? majorSource;

  UserProfileData copyWith({
    String? majorId,
    String? majorSource,
    bool clearMajor = false,
  }) {
    return UserProfileData(
      majorId: clearMajor ? null : (majorId ?? this.majorId),
      majorSource: clearMajor ? null : (majorSource ?? this.majorSource),
    );
  }
}
