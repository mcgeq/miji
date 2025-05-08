// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           theme_provider.dart
// Description:    About Theme
// Create   Date:  2025-04-12 10:53:45
// Last Modified:  2025-05-08 20:25:41
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import 'package:flutter/material.dart';

import 'package:miji/config/theme/app_themes.dart';

import 'package:miji/config/theme/theme_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_provider.g.dart';

const String _themePrefsKey = 'isDarkMode';

@Riverpod(keepAlive: true)
class ThemeNotifier extends _$ThemeNotifier {
  late SharedPreferences _prefs;

  @override
  Future<ThemeState> build() async {
    _prefs = await SharedPreferences.getInstance();
    final mode = _loadThemeFromPrefs();
    final theme = _getThemeData(mode);
    return ThemeState(mode: mode, theme: theme);
  }

  ThemeMode _loadThemeFromPrefs() {
    final isDark = _prefs.getBool(_themePrefsKey) ?? false; // Default to light
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  ThemeData _getThemeData(ThemeMode mode) {
    return mode == ThemeMode.dark ? AppThemes.darkTheme : AppThemes.lightTheme;
  }

  Future<void> toggleTheme() async {
    final current = state.value!;
    final newMode =
        current.mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final newTheme = _getThemeData(newMode);
    state = AsyncValue.data(
      ThemeState(mode: newMode, theme: newTheme),
    ); // Update state immediately for responsiveness

    try {
      await _prefs.setBool(_themePrefsKey, newMode == ThemeMode.dark);
    } catch (e) {
      // Handle potential error saving prefs
      // Revert state or show error?
      state = AsyncValue.data(current); // Revert on error
      // Optionally log the error
    }
  }
}