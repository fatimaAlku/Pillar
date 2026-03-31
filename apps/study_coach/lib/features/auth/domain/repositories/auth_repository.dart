import '../entities/auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> watchAuthUser();
}
