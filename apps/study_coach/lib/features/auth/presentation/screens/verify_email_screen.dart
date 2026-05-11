import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../controllers/auth_controller.dart';

/// Shown when the user is signed in but Firebase [emailVerified] is false.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
  });

  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _otpController = TextEditingController();
  bool _autoSendStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoSendStarted) {
        return;
      }
      _autoSendStarted = true;
      ref.read(authFormControllerProvider.notifier).resendVerificationEmail();
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authFormState = ref.watch(authFormControllerProvider);
    final isLoading = authFormState.isLoading;

    ref.listen<AuthFormState>(authFormControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    final emailLine = widget.email != null && widget.email!.trim().isNotEmpty
        ? widget.email!.trim()
        : strings.verifyEmailNoAddressPlaceholder;

    final otp = _otpController.text.trim();
    final canSubmitOtp = otp.length == 6 && !isLoading;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.5),
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor,
            ],
            stops: const [0, 0.28, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 48,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          strings.verifyEmailTitle,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          strings.verifyEmailBody(emailLine),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _otpController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            letterSpacing: 8,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            labelText: strings.verifyEmailOtpLabel,
                            hintText: strings.verifyEmailOtpHint,
                            border: const OutlineInputBorder(),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: !canSubmitOtp
                              ? null
                              : () async {
                                  await ref
                                      .read(authFormControllerProvider.notifier)
                                      .verifyEmailWithOtp(otp);
                                },
                          child: Text(strings.verifyEmailConfirmCode),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await ref
                                      .read(authFormControllerProvider.notifier)
                                      .resendVerificationEmail();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (ref
                                          .read(authFormControllerProvider)
                                          .errorMessage ==
                                      null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(strings.verifyEmailResent),
                                      ),
                                    );
                                  }
                                },
                          child: Text(strings.verifyEmailResend),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await ref
                                      .read(authFormControllerProvider.notifier)
                                      .reloadAuthUserAfterVerification();
                                },
                          child: Text(strings.verifyEmailCheckedInbox),
                        ),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => ref
                                  .read(authFormControllerProvider.notifier)
                                  .signOut(),
                          child: Text(strings.verifyEmailSignOut),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
