import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/state/app_providers.dart';
import '../../../../core/state/feature_state.dart';

final authControllerProvider = Provider<FeatureState>((ref) {
  final userAsync = ref.watch(currentAuthUserProvider);
  final user = userAsync.valueOrNull;
  final status = user == null ? 'signed_out_or_loading' : 'signed_in';
  return FeatureState(status);
});

class AuthFormState {
  const AuthFormState({
    this.isLoading = false,
    this.errorMessage,
  });

  final bool isLoading;
  final String? errorMessage;

  AuthFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final authFormControllerProvider =
    StateNotifierProvider<AuthFormController, AuthFormState>((ref) {
  return AuthFormController(ref);
});

class AuthFormController extends StateNotifier<AuthFormState> {
  AuthFormController(this._ref) : super(const AuthFormState());

  final Ref _ref;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      await _ref.read(authRepositoryProvider).signInWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    await _runAuthAction(() async {
      await _ref.read(authRepositoryProvider).createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );
    });
  }

  Future<void> signOut() async {
    await _ref.read(authRepositoryProvider).signOut();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false, clearError: true);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseAuthError(e.code),
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  String _mapFirebaseAuthError(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak (minimum 6 characters).';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
