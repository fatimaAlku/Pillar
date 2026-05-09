import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'root_scaffold_messenger.dart';
import '../core/oauth/google_calendar_oauth_resume_bridge.dart';
import '../core/state/app_providers.dart';
import '../core/state/app_locale_controller.dart';
import '../core/state/theme_mode_controller.dart';
import '../core/theme/pillar_theme.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/auth/presentation/screens/verify_email_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/welcome/presentation/screens/post_signin_welcome_screen.dart';
import 'splash_screen.dart';

final startupDelayProvider = FutureProvider<void>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 1200));
});

class StudyCoachApp extends ConsumerWidget {
  const StudyCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const lightScheme = pillarLightColorScheme;
    final darkScheme = pillarDarkColorScheme();
    final themeMode = ref.watch(themeModeProvider);
    final appLocale = ref.watch(appLocaleProvider);

    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'Pillar',
      debugShowCheckedModeBanner: false,
      theme: buildPillarTheme(lightScheme),
      darkTheme: buildPillarTheme(darkScheme),
      themeMode: themeMode,
      locale: appLocale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) =>
          GoogleCalendarOauthResumeBridge(child: child),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupDelayProvider);
    if (startup.isLoading) {
      return const SplashScreen();
    }

    final authUser = ref.watch(currentAuthUserProvider);
    final retainAuthDuringSignUp = ref.watch(retainAuthGateForSignUpProvider);
    final loggedInUser = authUser.asData?.value;
    final needsWelcomeCheck = loggedInUser != null &&
        !retainAuthDuringSignUp &&
        loggedInUser.emailVerified;
    final welcomeCompletedAsync = needsWelcomeCheck
        ? ref.watch(postSigninWelcomeCompletedProvider(loggedInUser.uid))
        : null;

    return authUser.when(
      data: (user) {
        if (user == null || retainAuthDuringSignUp) {
          return const AuthScreen();
        }
        if (!user.emailVerified) {
          return VerifyEmailScreen(email: user.email);
        }
        return welcomeCompletedAsync!.when(
          data: (completed) => completed
              ? const DashboardScreen()
              : PostSigninWelcomeScreen(uid: user.uid),
          loading: () => const SplashScreen(),
          error: (_, __) => const DashboardScreen(),
        );
      },
      loading: () => const SplashScreen(),
      error: (_, __) => const AuthScreen(),
    );
  }
}
