import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _themeModeKey = 'theme_mode';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  bool _hasSelection = false;

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || _hasSelection) return;
      final index = prefs.get(_themeModeKey);
      state = index is int && index >= 0 && index < ThemeMode.values.length
          ? ThemeMode.values[index]
          : ThemeMode.system;
    } catch (_) {
      // A missing/unavailable preference store must not prevent app startup.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (!mounted) return;
    _hasSelection = true;
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setInt(_themeModeKey, mode.index)) {
      throw StateError('Could not save theme preference.');
    }
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }
}
