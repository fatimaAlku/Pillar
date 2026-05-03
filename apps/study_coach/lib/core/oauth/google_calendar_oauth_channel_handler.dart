import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/root_scaffold_messenger.dart';
import '../localization/app_strings.dart';
import '../state/google_calendar_connection_provider.dart';
import '../../features/study_plan/presentation/controllers/study_plan_firestore_providers.dart';
import 'google_calendar_oauth_pending_store.dart';
import 'google_oauth_env.dart';

const _googleOauthChannel = MethodChannel('pillar.google_oauth');

bool _oauthHandling = false;

Future<void> _clearNativePendingOAuthStore() async {
  try {
    await _googleOauthChannel.invokeMethod<dynamic>('clearPendingOAuthUrl');
  } catch (_) {}
}

void _snack(AppStrings strings, String text) {
  void show() {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  show();
  if (rootScaffoldMessengerKey.currentState == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }
}

/// Completes Google OAuth using [url] (same for platform invoke and native pull).
Future<void> processGoogleOAuthRedirect(ProviderContainer container, String url) async {
  if (_oauthHandling) {
    return;
  }
  _oauthHandling = true;
  final strings = AppStrings.fromPlatformLocale();
  try {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final callbackUri = Uri.parse(trimmed);
    final code = callbackUri.queryParameters['code'];
    final stateParam = callbackUri.queryParameters['state'];
    final oauthError = callbackUri.queryParameters['error'];

    if (oauthError != null) {
      await GoogleCalendarOauthPendingStore.clear();
      _snack(strings, strings.googleAuthorizationCancelled);
      return;
    }

    if (FirebaseAuth.instance.currentUser == null) {
      await GoogleCalendarOauthPendingStore.clear();
      _snack(strings, strings.googleConnectFailed);
      return;
    }

    if (GoogleOauthEnv.clientId.trim().isEmpty) {
      _snack(strings, strings.googleMissingConfig);
      return;
    }

    if (code == null || code.isEmpty) {
      _snack(strings, strings.googleConnectFailed);
      return;
    }

    final pending = await GoogleCalendarOauthPendingStore.load();
    if (pending == null) {
      _snack(strings, strings.googleConnectFailed);
      return;
    }
    if (stateParam != pending.state) {
      await GoogleCalendarOauthPendingStore.clear();
      _snack(strings, strings.googleConnectFailed);
      return;
    }

    await GoogleCalendarOauthPendingStore.clear();

    try {
      await container.read(googleCalendarSyncRepositoryProvider).connectWithAuthCode(
            code: code,
            redirectUri: GoogleOauthEnv.redirectUri.toString(),
            codeVerifier: pending.verifier,
            clientId: GoogleOauthEnv.clientId,
          );
      container.read(googleCalendarConnectionBumpProvider.notifier).state++;
      _snack(strings, strings.googleConnectedSuccess);
    } on FirebaseFunctionsException catch (e) {
      final detail = (e.message ?? '').trim();
      final message = detail.isNotEmpty
          ? (detail.length > 220 ? '${detail.substring(0, 220)}…' : detail)
          : strings.googleConnectFailed;
      _snack(strings, message);
    } catch (_) {
      _snack(strings, strings.googleConnectFailed);
    }
  } finally {
    try {
      await _clearNativePendingOAuthStore();
    } catch (_) {}
    _oauthHandling = false;
  }
}

/// Reads URL persisted by iOS/Android when [invokeMethod] to Dart was not delivered.
Future<void> consumePendingGoogleOAuthFromNative(ProviderContainer container) async {
  try {
    final raw = await _googleOauthChannel.invokeMethod<dynamic>('consumePendingOAuthUrl');
    final url = raw is String ? raw.trim() : '';
    if (url.isEmpty) {
      return;
    }
    await processGoogleOAuthRedirect(container, url);
  } on MissingPluginException {
    // Native side may not implement on some platforms.
  } catch (_) {}
}

/// Registers once. Handles OAuth redirect even when Profile is not mounted.
void installGoogleCalendarOauthChannelHandler(ProviderContainer container) {
  _googleOauthChannel.setMethodCallHandler((call) async {
    if (call.method != 'onGoogleAuthRedirect') {
      return null;
    }
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? const {};
    final url = (args['url'] as String?)?.trim();
    if (url == null || url.isEmpty) {
      return null;
    }
    await processGoogleOAuthRedirect(container, url);
    return null;
  });
}
