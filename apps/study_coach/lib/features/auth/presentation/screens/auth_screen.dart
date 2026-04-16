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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final authFormState = ref.watch(authFormControllerProvider);

    ref.listen<AuthFormState>(authFormControllerProvider, (previous, next) {
      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(strings.appTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isSignUp ? strings.createAccount : strings.login,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: strings.email),
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
                    decoration: InputDecoration(labelText: strings.password),
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
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: authFormState.isLoading ? null : _submit,
                      child: authFormState.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? strings.signUp : strings.login),
                    ),
                  ),
                  TextButton(
                    onPressed: authFormState.isLoading
                        ? null
                        : () {
                            setState(() => _isSignUp = !_isSignUp);
                            ref.read(authFormControllerProvider.notifier)
                                .clearError();
                          },
                    child: Text(
                      _isSignUp
                          ? strings.alreadyHaveAccountLogin
                          : strings.needAccountSignUp,
                    ),
                  ),
                ],
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
      );
      return;
    }

    await controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }
}
