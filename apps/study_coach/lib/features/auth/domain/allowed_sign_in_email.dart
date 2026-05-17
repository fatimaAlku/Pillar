const allowedSignInEmailSuffix = '@gmail.com';

bool isAllowedSignInEmail(String raw) {
  final email = raw.trim().toLowerCase();
  return email.isNotEmpty && email.endsWith(allowedSignInEmailSuffix);
}
