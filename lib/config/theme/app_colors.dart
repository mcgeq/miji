import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Core Colors
  static const primaryColor = Color(0xFF4A90E2);
  static const secondaryColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFD32F2F);
  static const warningColor = Color(0xFFFFA726);
  static const successColor = Color(0xFF388E3C);
  static const infoColor = Color(0xFF1976D2);

  // Light Mode Colors
  static const lightBackgroundColor = Color(0xFFF5F5F5);
  static const lightTextColor = Color(0xFF212121);
  static const lightCardColor = Color(0xFFFFFFFF);

  // Dark Mode Colors
  static const darkBackgroundColor = Color(0xFF121212);
  static const darkTextColor = Color(0xFFE0E0E0);
  static const darkCardColor = Color(0xFF1E1E1E);

  // Text Styles
  static const titleText = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: lightTextColor,
  );

  static const subtitleText = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: lightTextColor,
  );

  static const bodyText = TextStyle(fontSize: 16, color: lightTextColor);

  static const buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const linkText = TextStyle(
    fontSize: 16,
    color: primaryColor,
    decoration: TextDecoration.underline,
  );

  // Dark Mode Text Styles
  static final darkTitleText = titleText.copyWith(color: darkTextColor);
  static final darkSubtitleText = subtitleText.copyWith(color: darkTextColor);
  static final darkBodyText = bodyText.copyWith(color: darkTextColor);

  // Button Styles
  static final elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    textStyle: buttonText,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  static final outlinedButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: const BorderSide(color: primaryColor),
    textStyle: buttonText.copyWith(color: primaryColor),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  static final textButtonStyle = TextButton.styleFrom(
    foregroundColor: primaryColor,
    textStyle: buttonText.copyWith(color: primaryColor),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );

  // Input Decoration
  static final inputDecoration = InputDecoration(
    filled: true,
    fillColor: lightCardColor,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor),
    ),
  );

  // Card Style
  static final cardDecoration = BoxDecoration(
    color: lightCardColor,
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      const BoxShadow(
        color: Color.fromRGBO(0, 0, 0, 0.1), // Fixed deprecated withOpacity
        blurRadius: 4,
        offset: Offset(0, 2),
      ),
    ],
  );

  // List Item Style
  static final listItemDecoration = BoxDecoration(
    color: lightCardColor,
    borderRadius: BorderRadius.circular(8),
  );

  // Theme Data for Light and Dark Modes
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackgroundColor,
    cardColor: lightCardColor,
    textTheme: const TextTheme(
      headlineSmall: titleText, // Fixed: headline6 → headlineSmall
      titleMedium: subtitleText, // Fixed: subtitle1 → titleMedium
      bodyMedium: bodyText, // Fixed: bodyText2 → bodyMedium
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightCardColor,
      border: inputDecoration.border,
      focusedBorder: inputDecoration.focusedBorder,
    ),
    cardTheme: CardTheme(
      color: lightCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackgroundColor,
    cardColor: darkCardColor,
    textTheme: TextTheme(
      headlineSmall: darkTitleText, // Fixed: headline6 → headlineSmall
      titleMedium: darkSubtitleText, // Fixed: subtitle1 → titleMedium
      bodyMedium: darkBodyText, // Fixed: bodyText2 → bodyMedium
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: elevatedButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: outlinedButtonStyle),
    textButtonTheme: TextButtonThemeData(style: textButtonStyle),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardColor,
      border: inputDecoration.border,
      focusedBorder: inputDecoration.focusedBorder,
    ),
    cardTheme: CardTheme(
      color: darkCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
    ),
  );
}