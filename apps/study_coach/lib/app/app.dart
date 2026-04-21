import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/app_providers.dart';
import '../core/state/app_locale_controller.dart';
import '../core/state/theme_mode_controller.dart';
import '../core/theme/pillar_theme.dart';
import '../features/auth/presentation/screens/auth_screen.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
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
    return authUser.when(
      data: (user) => user == null ? const AuthScreen() : const DashboardScreen(),
      loading: () => const SplashScreen(),
      error: (_, __) => const AuthScreen(),
    );
  }
}
