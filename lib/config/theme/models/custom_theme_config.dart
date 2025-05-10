import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

@HiveType(typeId: 0)
class CustomThemeConfig {
  @HiveField(0)
  final Color primaryColor;
  @HiveField(1)
  final Color backgroundColor;
  @HiveField(2)
  final TextTheme textTheme;

  CustomThemeConfig({
    required this.primaryColor,
    required this.backgroundColor,
    required this.textTheme,
  });

  CustomThemeConfig copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    TextTheme? textTheme,
  }) {
    return CustomThemeConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textTheme: textTheme ?? this.textTheme,
    );
  }
}
