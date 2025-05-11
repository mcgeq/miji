import 'package:flutter/material.dart';

class CustomThemeConfig {
  final Color primaryColor;
  final Color backgroundColor;
  final TextTheme textTheme;
  final ThemeMode themeMode;

  CustomThemeConfig({
    required this.primaryColor,
    required this.backgroundColor,
    required this.textTheme,
    this.themeMode = ThemeMode.system,
  });

  // 添加 copyWith 方法
  CustomThemeConfig copyWith({
    Color? primaryColor,
    Color? backgroundColor,
    TextTheme? textTheme,
    ThemeMode? themeMode,
  }) {
    return CustomThemeConfig(
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      textTheme: textTheme ?? this.textTheme,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'primaryColor': primaryColor.toARGB32(), // 使用 .value 存储颜色值
      'backgroundColor': backgroundColor.toARGB32(),
      'textTheme': _textThemeToJson(textTheme),
      'themeMode': themeMode.toString(),
    };
  }

  factory CustomThemeConfig.fromJson(Map<String, dynamic> json) {
    return CustomThemeConfig(
      primaryColor: Color(json['primaryColor']),
      backgroundColor: Color(json['backgroundColor']),
      textTheme: _textThemeFromJson(json['textTheme'] ?? {}),
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.toString() == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
    );
  }

  static Map<String, dynamic> _textThemeToJson(TextTheme textTheme) {
    return {
      if (textTheme.headlineLarge != null)
        'headlineLarge': _textStyleToJson(textTheme.headlineLarge!),
      if (textTheme.headlineMedium != null)
        'headlineMedium': _textStyleToJson(textTheme.headlineMedium!),
      if (textTheme.headlineSmall != null)
        'headlineSmall': _textStyleToJson(textTheme.headlineSmall!),
    };
  }

  static TextTheme _textThemeFromJson(Map<String, dynamic> json) {
    return TextTheme(
      headlineLarge:
          json['headlineLarge'] != null
              ? _textStyleFromJson(json['headlineLarge'])
              : null,
      headlineMedium:
          json['headlineMedium'] != null
              ? _textStyleFromJson(json['headlineMedium'])
              : null,
      headlineSmall:
          json['headlineSmall'] != null
              ? _textStyleFromJson(json['headlineSmall'])
              : null,
    );
  }

  static Map<String, dynamic> _textStyleToJson(TextStyle style) {
    return {
      'fontSize': style.fontSize,
      'fontWeight': style.fontWeight?.toString(),
      'color': style.color?.toARGB32(), // 使用 .value 存储颜色值
    };
  }

  static TextStyle _textStyleFromJson(Map<String, dynamic> json) {
    return TextStyle(
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontWeight:
          json['fontWeight'] != null
              ? FontWeight.values.firstWhere(
                (fw) => fw.toString() == json['fontWeight'],
                orElse: () => FontWeight.normal,
              )
              : null,
      color: json['color'] != null ? Color(json['color'] as int) : null,
    );
  }
}