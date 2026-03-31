import '../entities/auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> watchAuthUser();
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });
  Future<void> signOut();
}
