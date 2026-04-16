import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appLocalePreferenceKey = 'app_locale';

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final preferences = await SharedPreferences.getInstance();
    final storedLanguageCode =
        preferences.getString(_appLocalePreferenceKey) ?? 'en';
    state = Locale(storedLanguageCode);
  }

  Future<void> setLocale(Locale locale) async {
    if (state.languageCode == locale.languageCode) {
      return;
    }

    state = Locale(locale.languageCode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_appLocalePreferenceKey, state.languageCode);
  }

  Future<void> toggleLocale() {
    final nextLocale = state.languageCode == 'ar'
        ? const Locale('en')
        : const Locale('ar');
    return setLocale(nextLocale);
  }
}

final appLocaleProvider =
    StateNotifierProvider<AppLocaleController, Locale>((ref) {
      return AppLocaleController();
    });
