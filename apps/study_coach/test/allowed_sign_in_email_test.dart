import 'package:flutter_test/flutter_test.dart';
import 'package:pillar_study_coach/features/auth/domain/allowed_sign_in_email.dart';

void main() {
  test('accepts Gmail addresses', () {
    expect(isAllowedSignInEmail('student@gmail.com'), isTrue);
    expect(isAllowedSignInEmail('  Student@Gmail.COM  '), isTrue);
  });

  test('rejects non-Gmail addresses', () {
    expect(isAllowedSignInEmail('student@student.polytechnic.bh'), isFalse);
    expect(isAllowedSignInEmail('student@outlook.com'), isFalse);
    expect(isAllowedSignInEmail(''), isFalse);
  });
}
