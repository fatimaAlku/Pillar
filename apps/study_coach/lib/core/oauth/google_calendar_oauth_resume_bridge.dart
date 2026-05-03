import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'google_calendar_oauth_channel_handler.dart';

/// Pulls OAuth redirect URLs saved natively when the platform → Dart invoke was missed.
class GoogleCalendarOauthResumeBridge extends StatefulWidget {
  const GoogleCalendarOauthResumeBridge({super.key, required this.child});

  final Widget? child;

  @override
  State<GoogleCalendarOauthResumeBridge> createState() =>
      _GoogleCalendarOauthResumeBridgeState();
}

class _GoogleCalendarOauthResumeBridgeState
    extends State<GoogleCalendarOauthResumeBridge> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_pull());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_pull());
    }
  }

  Future<void> _pull() async {
    if (!mounted) return;
    final container = ProviderScope.containerOf(context);
    await consumePendingGoogleOAuthFromNative(container);
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
