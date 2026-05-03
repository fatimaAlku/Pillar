import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/config/app_time_zone.dart';
import 'core/oauth/google_calendar_oauth_channel_handler.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureAppTimeZonesLoaded();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final container = ProviderContainer();
  installGoogleCalendarOauthChannelHandler(container);
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StudyCoachApp(),
    ),
  );
}
