import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModePreferenceKey = 'theme_mode';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.light) {
    _loadSavedThemeMode();
  }

  Future<void> _loadSavedThemeMode() async {
    final preferences = await SharedPreferences.getInstance();
    final storedThemeMode = preferences.getString(_themeModePreferenceKey);
    if (storedThemeMode == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (state == themeMode) {
      return;
    }
    state = themeMode;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themeModePreferenceKey,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  Future<void> toggleThemeMode() {
    final nextMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    return setThemeMode(nextMode);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
      return ThemeModeController();
    });
