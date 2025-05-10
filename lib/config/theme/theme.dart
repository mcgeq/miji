import 'package:flutter/material.dart';
import 'package:miji/config/theme/theme_generator.dart';

class AppTheme {
  AppTheme._();
  static final ThemeData lightTheme = ThemeGenerator.generateLightTheme();
  static final ThemeData darkTheme = ThemeGenerator.generateDarkTheme();
}
