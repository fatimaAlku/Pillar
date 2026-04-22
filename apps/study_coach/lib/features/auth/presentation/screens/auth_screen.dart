import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../controllers/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isSignUp
                                      ? strings.createAccount
                                      : strings.login,
                                  style:
                                      theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isSignUp
                                      ? 'Create your account to personalize your learning.'
                                      : 'Welcome back. Continue your learning streak.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHigh
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  if (_isSignUp) {
                                                    setState(() =>
                                                        _isSignUp = false);
                                                    ref
                                                        .read(
                                                            authFormControllerProvider
                                                                .notifier)
                                                        .clearError();
                                                  }
                                                },
                                          style: TextButton.styleFrom(
                                            backgroundColor: _isSignUp
                                                ? Colors.transparent
                                                : colorScheme.primary,
                                            foregroundColor: _isSignUp
                                                ? colorScheme.onSurfaceVariant
                                                : colorScheme.onPrimary,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(strings.login),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextButton(
                                          onPressed: isLoading
                                              ? null
                                              : () {
                                                  if (!_isSignUp) {
                                                    setState(
                                                        () => _isSignUp = true);
                                                    ref
                                                        .read(
                                                            authFormControllerProvider
                                                                .notifier)
                                                        .clearError();
                                                  }
                                                },
                                          style: TextButton.styleFrom(
                                            backgroundColor: _isSignUp
                                                ? colorScheme.primary
                                                : Colors.transparent,
                                            foregroundColor: _isSignUp
                                                ? colorScheme.onPrimary
                                                : colorScheme.onSurfaceVariant,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                          child: Text(strings.signUp),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (_isSignUp) ...[
                                  TextFormField(
                                    controller: _usernameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    autofillHints: const [AutofillHints.name],
                                    decoration: InputDecoration(
                                      labelText: strings.username,
                                      prefixIcon: const Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (value) {
                                      final name = value?.trim() ?? '';
                                      if (name.isEmpty) {
                                        return strings.usernameRequired;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: InputDecoration(
                                    labelText: strings.email,
                                    prefixIcon:
                                        const Icon(Icons.mail_outline_rounded),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty) {
                                      return strings.emailRequired;
                                    }
                                    if (!email.contains('@')) {
                                      return strings.enterValidEmail;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  autofillHints: _isSignUp
                                      ? const [AutofillHints.newPassword]
                                      : const [AutofillHints.password],
                                  decoration: InputDecoration(
                                    labelText: strings.password,
                                    prefixIcon:
                                        const Icon(Icons.lock_outline_rounded),
                                  ),
                                  validator: (value) {
                                    final password = value ?? '';
                                    if (password.isEmpty) {
                                      return strings.passwordRequired;
                                    }
                                    if (password.length < 6) {
                                      return strings.minimumSixChars;
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: isLoading ? null : _submit,
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.3,
                                            ),
                                          )
                                        : Text(
                                            _isSignUp
                                                ? strings.signUp
                                                : strings.login,
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: isLoading
                                        ? null
                                        : () {
                                            setState(
                                                () => _isSignUp = !_isSignUp);
                                            ref
                                                .read(authFormControllerProvider
                                                    .notifier)
                                                .clearError();
                                          },
                                    child: Text(
                                      _isSignUp
                                          ? strings.alreadyHaveAccountLogin
                                          : strings.needAccountSignUp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final controller = ref.read(authFormControllerProvider.notifier);
    if (_isSignUp) {
      await controller.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _usernameController.text,
      );
      return;
    }

    await controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }
}
