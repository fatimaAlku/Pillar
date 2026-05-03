/// Compile-time Google OAuth values (pass via `--dart-define-from-file=...`).
class GoogleOauthEnv {
  GoogleOauthEnv._();

  static const clientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

  static const redirectUriString = String.fromEnvironment(
    'GOOGLE_REDIRECT_URI',
    defaultValue: 'com.example.pillarStudyCoach:/oauth2redirect',
  );

  static Uri get redirectUri {
    final parsed = Uri.tryParse(redirectUriString.trim());
    if (parsed != null && parsed.hasScheme) {
      return parsed;
    }
    return Uri.parse('com.example.pillarStudyCoach:/oauth2redirect');
  }
}
