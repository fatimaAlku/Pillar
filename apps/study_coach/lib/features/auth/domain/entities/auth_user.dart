class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;

  /// Set at sign-up (Firebase Auth profile display name).
  final String? displayName;

  /// Optional photo URL from Firebase Auth profile.
  final String? photoUrl;
}
