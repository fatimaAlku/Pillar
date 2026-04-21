import 'package:flutter/material.dart';

/// Reference palette: soft light UI, indigo primary (#6C5CE7), cool gray scaffold.
abstract final class PillarColors {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color scaffoldLight = Color(0xFFF8F9FB);
  static const Color success = Color(0xFF52C9A4);
  static const Color priorityHigh = Color(0xFFE5748F);
  static const Color priorityMedium = Color(0xFFF3B95F);
}

const ColorScheme pillarLightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: PillarColors.primary,
  onPrimary: Color(0xFFFFFFFF),
  secondary: Color(0xFF9B8CFF),
  onSecondary: Color(0xFFFFFFFF),
  error: Color(0xFFE0526C),
  onError: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  onSurface: Color(0xFF2D3436),
  primaryContainer: Color(0xFFEBE7FF),
  onPrimaryContainer: Color(0xFF352A7A),
  secondaryContainer: Color(0xFFE4E6FF),
  onSecondaryContainer: Color(0xFF2C2F5C),
  tertiary: Color(0xFFFF8FA3),
  onTertiary: Color(0xFF5C1F2A),
  tertiaryContainer: Color(0xFFFFE4EA),
  onTertiaryContainer: Color(0xFF5C2430),
  outline: Color(0xFFDDE1E8),
  outlineVariant: Color(0xFFECEFF4),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFF8F9FC),
  surfaceContainer: Color(0xFFF3F4F8),
  surfaceContainerHigh: Color(0xFFEEEFF5),
  surfaceContainerHighest: Color(0xFFE8EAF0),
  onSurfaceVariant: Color(0xFF64717D),
  shadow: Color(0x1A2D3436),
  scrim: Color(0x66000000),
  inverseSurface: Color(0xFF2D3250),
  onInverseSurface: Color(0xFFF5F6FA),
  inversePrimary: Color(0xFFB4AAFF),
);

ColorScheme pillarDarkColorScheme() {
  return ColorScheme.fromSeed(
    seedColor: PillarColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    surface: const Color(0xFF1A1B26),
    surfaceContainerLowest: const Color(0xFF12131A),
    surfaceContainerLow: const Color(0xFF1E1F2C),
    surfaceContainer: const Color(0xFF232433),
    surfaceContainerHigh: const Color(0xFF2A2B3C),
    surfaceContainerHighest: const Color(0xFF323346),
  );
}

ThemeData buildPillarTheme(ColorScheme colorScheme) {
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
    scaffoldBackgroundColor: isDarkMode
        ? colorScheme.surface
        : PillarColors.scaffoldLight,
    textTheme: textTheme,
    shadowColor: colorScheme.shadow,
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
      elevation: isDarkMode ? 0 : 2,
      shadowColor: colorScheme.shadow,
      surfaceTintColor: Colors.transparent,
      color: colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surface,
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      backgroundColor: isDarkMode
          ? colorScheme.surfaceContainerLow
          : colorScheme.surface,
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
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        textStyle: textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        side: BorderSide(color: colorScheme.outline),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor:
          isDarkMode ? colorScheme.inverseSurface : colorScheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 1,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      side: BorderSide.none,
      labelStyle: textTheme.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
  );
}
