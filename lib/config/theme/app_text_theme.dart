import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';

TextTheme lightTextTheme = const TextTheme(
  bodyMedium: TextStyle(color: AppColors.lightTextColor, fontSize: 16),
  titleLarge: TextStyle(
    color: AppColors.primaryColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
);

TextTheme darkTextTheme = const TextTheme(
  bodyMedium: TextStyle(color: AppColors.darkTextColor, fontSize: 16),
  titleLarge: TextStyle(
    color: AppColors.primaryColor,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  ),
);
