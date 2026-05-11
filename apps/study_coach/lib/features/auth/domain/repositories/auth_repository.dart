import '../entities/auth_user.dart';
import 'dart:typed_data';

abstract class AuthRepository {
  Stream<AuthUser?> watchAuthUser();
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sends a 6-digit verification code to the signed-in user’s email (Cloud Function).
  Future<void> sendEmailVerificationOtp({String? languageCode});

  /// Verifies the email with [code] and refreshes the Firebase user (Cloud Function + reload).
  Future<void> verifyEmailWithOtp(String code);

  /// Reloads the current user from Firebase (e.g. after verification on another device).
  Future<void> reloadCurrentUser();

  Future<String> uploadProfilePhoto({
    required String uid,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  });
  Future<void> updateProfile({
    String? displayName,

    /// Pass an empty string to clear the current photo URL.
    String? photoUrl,
  });
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
  Future<void> signOut();
}
