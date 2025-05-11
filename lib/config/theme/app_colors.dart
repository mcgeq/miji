import 'package:flutter/material.dart';

class AppColors {
  AppColors._();
  static const primaryColor = Color(0xFF4A90E2);
  static const secondaryColor = Color(0xFF2E7D32);
  static const backgroundColor = Color(0xFFF5F5F5);
  static const darkBackgroundColor = Color(0xFF121212);
  static const textColor = Color(0xFF212121);
  static const darkTextColor = Color(0xFFE0E0E0);
  static final TextStyle headerText = const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static final TextStyle bodyText = const TextStyle(
    fontSize: 16,
    color: Colors.black87,
  );

  static final ButtonStyle elevatedButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontSize: 16),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  );
}
