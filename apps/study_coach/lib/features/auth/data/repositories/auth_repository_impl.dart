import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Stream<AuthUser?> watchAuthUser() {
    return _firebaseAuth.authStateChanges().map((user) {
      if (user == null) {
        return null;
      }
      return AuthUser(uid: user.uid, email: user.email);
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
  }) async {
    await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}
