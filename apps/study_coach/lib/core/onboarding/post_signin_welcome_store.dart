import 'package:shared_preferences/shared_preferences.dart';

/// Whether the post-sign-in welcome has been completed for a given account.
class PostSigninWelcomeStore {
  PostSigninWelcomeStore._();

  static String _key(String uid) => 'pillar_post_signin_welcome_$uid';

  static Future<bool> isCompleted(String uid) async {
    if (uid.isEmpty) {
      return false;
    }
    final p = await SharedPreferences.getInstance();
    return p.getBool(_key(uid)) ?? false;
  }

  static Future<void> setCompleted(String uid) async {
    if (uid.isEmpty) {
      return;
    }
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key(uid), true);
  }
}
