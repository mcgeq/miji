// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           app_themes.dart
// Description:    About App Theme
// Create   Date:  2025-04-12 10:54:55
// Last Modified:  2025-04-12 10:55:01
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------
import 'package:flutter/material.dart';
import 'package:miji/constants/constants.dart'; // Adjust import path

class AppThemes {
  AppThemes._();

  static final lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: AppConstants.seedColor),
    brightness: Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[100],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            AppConstants.seedColor, // Use seed color or specific blue
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      // Added style for TextButton
      style: TextButton.styleFrom(foregroundColor: AppConstants.seedColor),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black54),
      // Define other text styles if needed
    ),
    cardTheme: CardTheme(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    checkboxTheme: CheckboxThemeData(
      // Added consistent checkbox theme
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppConstants.seedColor; // Selected color
        }
        return null; // Default (usually grey outline)
      }),
      checkColor: WidgetStateProperty.all(
        Colors.white,
      ), // Color of the checkmark
    ),
    inputDecorationTheme: const InputDecorationTheme(
      // Added consistent input theme
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppConstants.seedColor, width: 2.0),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      // Added FAB theme
      backgroundColor: AppConstants.seedColor,
      foregroundColor: Colors.white,
    ),
    // Add other theme properties as needed
  );

  static final darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppConstants.seedColor,
      brightness: Brightness.dark,
    ),
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[900],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      elevation: 1,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            Colors.blueGrey[700], // Adjusted dark theme button color
        foregroundColor: Colors.white,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      // Added style for TextButton
      style: TextButton.styleFrom(foregroundColor: Colors.blueGrey[200]),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white70),
      bodyMedium: TextStyle(color: Colors.white54),
    ),
    cardTheme: CardTheme(
      color: Colors.grey[850],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ), // Slightly darker card
    checkboxTheme: CheckboxThemeData(
      // Added consistent checkbox theme for dark
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.blueGrey[600]; // Selected color for dark
        }
        return Colors.grey[700]; // Unselected color slightly visible
      }),
      checkColor: WidgetStateProperty.all(
        Colors.white,
      ), // Color of the checkmark
      side: BorderSide(color: Colors.grey[600]!), // Border color for checkbox
    ),
    inputDecorationTheme: InputDecorationTheme(
      // Added consistent input theme for dark
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey[200]!, width: 2.0),
      ),
      hintStyle: TextStyle(color: Colors.grey[500]),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      // Added FAB theme for dark
      backgroundColor: Colors.blueGrey[600],
      foregroundColor: Colors.white,
    ),
    // Add other theme properties as needed
  );
}
