// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           theme_provider.dart
// Description:    About Theme
// Create   Date:  2025-04-12 10:53:45
// Last Modified:  2025-04-12 10:53:54
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mcge_pisces/presentation/theme/app_themes.dart'; // Adjust import path

part 'theme_provider.g.dart';

const String _themePrefsKey = 'isDarkMode';

@Riverpod(keepAlive: true)
class ThemeNotifier extends _$ThemeNotifier {
  late SharedPreferences _prefs;

  @override
  Future<ThemeMode> build() async {
    _prefs = await SharedPreferences.getInstance();
    return _loadThemeFromPrefs();
  }

  ThemeMode _loadThemeFromPrefs() {
    final isDark = _prefs.getBool(_themePrefsKey) ?? false; // Default to light
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<void> toggleTheme() async {
    final currentMode =
        state.value ?? ThemeMode.light; // Get current state safely
    final newMode =
        currentMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final isDark = newMode == ThemeMode.dark;

    state = AsyncValue.data(
      newMode,
    ); // Update state immediately for responsiveness

    try {
      await _prefs.setBool(_themePrefsKey, isDark);
    } catch (e) {
      // Handle potential error saving prefs
      // Revert state or show error?
      state = AsyncValue.data(currentMode); // Revert on error
      // Optionally log the error
    }
  }

  // Expose the themes directly (optional, could also be accessed via AppThemes)
  ThemeData get lightTheme => AppThemes.lightTheme;
  ThemeData get darkTheme => AppThemes.darkTheme;
}
