import 'package:cloud_functions/cloud_functions.dart';

class GoogleCalendarSyncRepository {
  GoogleCalendarSyncRepository(this._functions);

  final FirebaseFunctions _functions;

  static Map<String, dynamic> _asJsonMap(dynamic data) {
    if (data == null) return {};
    if (data is Map) {
      return Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    }
    return {};
  }

  static bool _asBool(dynamic value) {
    if (value == true) return true;
    if (value == false) return false;
    if (value is num && value != 0) return true;
    if (value is String) {
      final s = value.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  Future<void> syncSession({
    required String action,
    required String uid,
    required String planId,
    required String sessionId,
  }) async {
    await _functions.httpsCallable('syncStudySessionToGoogleCalendar').call({
      'action': action,
      'uid': uid,
      'planId': planId,
      'sessionId': sessionId,
    });
  }

  Future<Map<String, dynamic>> googleStatus() async {
    final result =
        await _functions.httpsCallable('getGoogleCalendarConnectionStatus').call();
    final m = _asJsonMap(result.data);
    return {
      'connected': _asBool(m['connected']),
      'email': m['email'],
      'needsReconnect': _asBool(m['needsReconnect']),
      'lastSyncedAt': m['lastSyncedAt'],
    };
  }

  Future<Map<String, dynamic>> connectWithAuthCode({
    required String code,
    required String redirectUri,
    required String codeVerifier,
    required String clientId,
  }) async {
    final result = await _functions.httpsCallable('connectGoogleCalendarWithAuthCode').call({
      'code': code,
      'redirectUri': redirectUri,
      'codeVerifier': codeVerifier,
      'clientId': clientId,
    });
    final m = _asJsonMap(result.data);
    return {
      'connected': _asBool(m['connected']),
      'email': m['email'],
    };
  }

  Future<void> disconnectGoogleCalendar() async {
    await _functions.httpsCallable('disconnectGoogleCalendar').call();
  }
}
