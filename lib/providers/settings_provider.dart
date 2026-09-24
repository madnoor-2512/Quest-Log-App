import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool morningDigest;
  final bool focusWindow;
  final bool eveningRecap;
  final bool isDarkTheme;

  const SettingsState({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.morningDigest = true,
    this.focusWindow = true,
    this.eveningRecap = false,
    this.isDarkTheme = false,
  });

  SettingsState copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? morningDigest,
    bool? focusWindow,
    bool? eveningRecap,
    bool? isDarkTheme,
  }) {
    return SettingsState(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      morningDigest: morningDigest ?? this.morningDigest,
      focusWindow: focusWindow ?? this.focusWindow,
      eveningRecap: eveningRecap ?? this.eveningRecap,
      isDarkTheme: isDarkTheme ?? this.isDarkTheme,
    );
  }
}

final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends AsyncNotifier<SettingsState> {
  static const _keySound = 'sound_enabled';
  static const _keyVibration = 'vibration_enabled';
  static const _keyMorning = 'morning_digest';
  static const _keyFocus = 'focus_window';
  static const _keyEvening = 'evening_recap';
  static const _keyDarkTheme = 'is_dark_theme';

  @override
  Future<SettingsState> build() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsState(
      soundEnabled: prefs.getBool(_keySound) ?? true,
      vibrationEnabled: prefs.getBool(_keyVibration) ?? true,
      morningDigest: prefs.getBool(_keyMorning) ?? true,
      focusWindow: prefs.getBool(_keyFocus) ?? true,
      eveningRecap: prefs.getBool(_keyEvening) ?? false,
      isDarkTheme: prefs.getBool(_keyDarkTheme) ?? false,
    );
  }

  Future<void> _save(SettingsState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySound, s.soundEnabled);
    await prefs.setBool(_keyVibration, s.vibrationEnabled);
    await prefs.setBool(_keyMorning, s.morningDigest);
    await prefs.setBool(_keyFocus, s.focusWindow);
    await prefs.setBool(_keyEvening, s.eveningRecap);
    await prefs.setBool(_keyDarkTheme, s.isDarkTheme);
  }

  Future<void> resetToDefaults() async {
    const defaults = SettingsState();
    state = const AsyncValue.data(defaults);
    await _save(defaults);
  }

  Future<void> toggleSound() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(soundEnabled: !s.soundEnabled);
    state = AsyncValue.data(n);
    await _save(n);
  }

  Future<void> toggleVibration() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(vibrationEnabled: !s.vibrationEnabled);
    state = AsyncValue.data(n);
    await _save(n);
  }

  Future<void> toggleMorningDigest() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(morningDigest: !s.morningDigest);
    state = AsyncValue.data(n);
    await _save(n);
  }

  Future<void> toggleFocusWindow() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(focusWindow: !s.focusWindow);
    state = AsyncValue.data(n);
    await _save(n);
  }

  Future<void> toggleEveningRecap() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(eveningRecap: !s.eveningRecap);
    state = AsyncValue.data(n);
    await _save(n);
  }

  Future<void> toggleDarkTheme() async {
    final s = state.valueOrNull ?? const SettingsState();
    final n = s.copyWith(isDarkTheme: !s.isDarkTheme);
    state = AsyncValue.data(n);
    await _save(n);
  }
}
