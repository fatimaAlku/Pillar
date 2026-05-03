import 'package:shared_preferences/shared_preferences.dart';

/// Persists PKCE + state so OAuth can finish after a tab switch, cold start, or
/// when [ProfileTabScreen] is not mounted (dashboard only builds one tab).
class GoogleCalendarOauthPendingStore {
  GoogleCalendarOauthPendingStore._();

  static const _kState = 'pillar_google_cal_oauth_state';
  static const _kVerifier = 'pillar_google_cal_oauth_verifier';

  static Future<void> save(String state, String codeVerifier) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kState, state);
    await p.setString(_kVerifier, codeVerifier);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kState);
    await p.remove(_kVerifier);
  }

  static Future<({String state, String verifier})?> load() async {
    final p = await SharedPreferences.getInstance();
    final state = p.getString(_kState);
    final verifier = p.getString(_kVerifier);
    if (state == null ||
        verifier == null ||
        state.isEmpty ||
        verifier.isEmpty) {
      return null;
    }
    return (state: state, verifier: verifier);
  }
}
