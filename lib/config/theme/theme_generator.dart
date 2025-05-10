import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:miji/config/theme/app_colors.dart';
import 'package:miji/config/theme/app_text_theme.dart';
import 'package:miji/config/theme/models/custom_theme_config.dart';

class ThemeGenerator {
  ThemeGenerator._();
  static ThemeData generateTheme(ThemeMode mode, CustomThemeConfig? config) {
    final brightness =
        (mode == ThemeMode.system)
            ? PlatformDispatcher.instance.platformBrightness
            : (mode == ThemeMode.dark ? Brightness.dark : Brightness.light);

    final textTheme =
        config?.textTheme ??
        (brightness == Brightness.dark ? darkTextTheme : lightTextTheme);

    return ThemeData(
      brightness: brightness,
      primaryColor: config?.primaryColor ?? AppColors.primaryColor,
      scaffoldBackgroundColor:
          config?.backgroundColor ??
          (brightness == Brightness.dark
              ? AppColors.darkBackgroundColor
              : AppColors.backgroundColor),
      textTheme: textTheme,
    );
  }

  static ThemeData generateLightTheme() => generateTheme(ThemeMode.light, null);
  static ThemeData generateDarkTheme() => generateTheme(ThemeMode.dark, null);
}