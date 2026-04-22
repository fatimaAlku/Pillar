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
