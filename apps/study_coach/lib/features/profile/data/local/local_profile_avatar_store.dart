import 'package:shared_preferences/shared_preferences.dart';

class LocalProfileAvatarStore {
  static const maleAvatarId = 'male';
  static const femaleAvatarId = 'female';
  static const supportedAvatarIds = {maleAvatarId, femaleAvatarId};

  Future<String?> getSelectedAvatarId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key(uid));
    if (id == null || !supportedAvatarIds.contains(id)) return null;
    return id;
  }

  Future<void> setSelectedAvatarId({
    required String uid,
    required String avatarId,
  }) async {
    if (!supportedAvatarIds.contains(avatarId)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), avatarId);
  }

  Future<void> clearSelectedAvatarId(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }

  String _key(String uid) => 'profile_avatar_id_$uid';
}
