import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _focusModeEnabledPreferenceKey = 'focus_mode_enabled';

class FocusModeState {
  const FocusModeState({required this.enabled});

  final bool enabled;
}

class FocusModeController extends StateNotifier<FocusModeState> {
  FocusModeController()
      : super(const FocusModeState(enabled: false)) {
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    final preferences = await SharedPreferences.getInstance();
    final enabled =
        preferences.getBool(_focusModeEnabledPreferenceKey) ?? false;
    state = FocusModeState(enabled: enabled);
  }

  Future<void> setEnabled(bool value) async {
    if (state.enabled == value) return;
    state = FocusModeState(enabled: value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_focusModeEnabledPreferenceKey, value);
  }

  Future<void> toggle() => setEnabled(!state.enabled);
}

final focusModeProvider =
    StateNotifierProvider<FocusModeController, FocusModeState>((ref) {
  return FocusModeController();
});
