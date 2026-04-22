import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._firebaseAuth, this._firebaseStorage);

  final FirebaseAuth _firebaseAuth;
  final FirebaseStorage _firebaseStorage;

  @override
  Stream<AuthUser?> watchAuthUser() {
    return _firebaseAuth.userChanges().map((user) {
      if (user == null) {
        return null;
      }
      return AuthUser(
        uid: user.uid,
        email: user.email,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
    });
  }

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      await credential.user?.updateDisplayName(name);
      await credential.user?.reload();
    }
  }

  @override
  Future<String> uploadProfilePhoto({
    required String uid,
    String? filePath,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final resolvedFileName = fileName ??
        (filePath != null && filePath.isNotEmpty
            ? filePath.split('/').last
            : 'avatar.jpg');
    final dotIndex = resolvedFileName.lastIndexOf('.');
    final extension = dotIndex > 0
        ? resolvedFileName.substring(dotIndex + 1).toLowerCase()
        : 'jpg';
    final safeExtension =
        RegExp(r'^[a-z0-9]+$').hasMatch(extension) ? extension : 'jpg';
    final objectPath =
        'users/$uid/profile/avatar_${DateTime.now().millisecondsSinceEpoch}.$safeExtension';
    final ref = _firebaseStorage.ref().child(objectPath);
    UploadTask uploadTask;
    if (fileBytes != null && fileBytes.isNotEmpty) {
      uploadTask = ref.putData(fileBytes);
    } else if (filePath != null && filePath.isNotEmpty) {
      uploadTask = ref.putFile(File(filePath));
    } else {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'No image data found for profile photo upload.',
      );
    }
    final snapshot = await uploadTask;
    // On some platforms, download URL lookup can race right after upload.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        return await snapshot.ref.getDownloadURL();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found' || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 250 * (attempt + 1)));
      }
    }
    throw FirebaseException(
      plugin: 'firebase_storage',
      code: 'object-not-found',
      message: 'Uploaded photo was not found when requesting download URL.',
    );
  }

  @override
  Future<void> updateProfile({
    String? displayName,
    String? photoUrl,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return;

    final trimmedName = displayName?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
    }
    if (photoUrl != null) {
      await user.updatePhotoURL(photoUrl.isEmpty ? null : photoUrl);
    }
    await user.reload();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No authenticated user found.',
      );
    }
    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Current account does not have an email address.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
    await user.reload();
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
