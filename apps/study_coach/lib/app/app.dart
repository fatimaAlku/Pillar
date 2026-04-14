import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/state/app_providers.dart';
import '../core/state/theme_mode_controller.dart';
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
    const lightScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF6B5CFF),
      onPrimary: Colors.white,
      secondary: Color(0xFF7D87FF),
      onSecondary: Colors.white,
      error: Color(0xFFCC4561),
      onError: Colors.white,
      surface: Color(0xFFFDFDFF),
      onSurface: Color(0xFF1F1E2E),
      primaryContainer: Color(0xFFE8E7FF),
      onPrimaryContainer: Color(0xFF251F63),
      secondaryContainer: Color(0xFFE4E9FF),
      onSecondaryContainer: Color(0xFF232B67),
      tertiary: Color(0xFFC66ADB),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF4E6FF),
      onTertiaryContainer: Color(0xFF4D2458),
      outline: Color(0xFFDADAF0),
      outlineVariant: Color(0xFFE8E8F6),
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: Color(0xFFF7F7FE),
      surfaceContainer: Color(0xFFF3F3FC),
      surfaceContainerHigh: Color(0xFFEEEEFA),
      surfaceContainerHighest: Color(0xFFE8E8F7),
      onSurfaceVariant: Color(0xFF6A6B84),
      shadow: Color(0x22000000),
      scrim: Color(0x66000000),
      inverseSurface: Color(0xFF2B2A3F),
      onInverseSurface: Color(0xFFF6F5FF),
      inversePrimary: Color(0xFFD2CCFF),
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: lightScheme.primary,
      brightness: Brightness.dark,
    );
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Pillar',
      debugShowCheckedModeBanner: false,
      theme: _buildThemeData(lightScheme),
      darkTheme: _buildThemeData(darkScheme),
      themeMode: themeMode,
      home: const _AuthGate(),
    );
  }
}

ThemeData _buildThemeData(ColorScheme colorScheme) {
  final isDarkMode = colorScheme.brightness == Brightness.dark;
  final textTheme = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
  ).textTheme.apply(
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDarkMode ? colorScheme.surface : const Color(0xFFF4F5FB),
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.3),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor:
          isDarkMode ? colorScheme.surfaceContainerLow : const Color(0xFFFDFDFF),
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      selectedIconTheme: const IconThemeData(size: 24),
      unselectedIconTheme: const IconThemeData(size: 22),
      selectedLabelStyle: textTheme.labelSmall?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        minimumSize: const Size.fromHeight(50),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isDarkMode ? colorScheme.inverseSurface : const Color(0xFF2E2D43),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: isDarkMode
            ? colorScheme.onInverseSurface
            : const Color(0xFFF7F7FE),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
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
