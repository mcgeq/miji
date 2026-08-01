import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme_extension.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static const _fontFamilyFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Roboto',
    'sans-serif',
  ];

  static ThemeData light() {
    final theme = FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppThemeTokens.lightPrimary,
        secondary: AppThemeTokens.lightSecondary,
        tertiary: AppThemeTokens.lightTertiary,
      ),
      useMaterial3: true,
    );

    return _withThemeOverrides(
      theme,
      colorScheme: theme.colorScheme.copyWith(
        primary: AppThemeTokens.lightPrimary,
        secondary: AppThemeTokens.lightSecondary,
        tertiary: AppThemeTokens.lightTertiary,
        surface: AppThemeTokens.lightSurface,
        surfaceContainerLowest: AppThemeTokens.lightSurface,
        surfaceContainerLow: AppThemeTokens.lightSurface,
        surfaceContainer: AppThemeTokens.lightSurfaceAlt,
        surfaceContainerHigh: AppThemeTokens.lightSurfaceAlt,
        surfaceContainerHighest: AppThemeTokens.lightSurfaceAlt,
        outline: AppThemeTokens.lightOutline,
        outlineVariant: AppThemeTokens.lightOutline,
      ),
      scaffoldBackgroundColor: AppThemeTokens.lightBackground,
      semanticColors: const AppSemanticColors(
        focus: AppThemeTokens.lightFocus,
        focusContainer: AppThemeTokens.lightFocusContainer,
      ),
      moneyColors: const AppMoneyColors(
        income: Color(0xFF168A5B),
        expense: Color(0xFFD44D6E),
        transfer: Color(0xFF4F7DD9),
        credit: Color(0xFFB36A18),
        warning: Color(0xFFE08A1E),
        success: Color(0xFF168A5B),
      ),
    );
  }

  static ThemeData dark() {
    final theme = FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppThemeTokens.darkPrimary,
        secondary: AppThemeTokens.darkSecondary,
        tertiary: AppThemeTokens.darkTertiary,
      ),
      useMaterial3: true,
    );

    return _withThemeOverrides(
      theme,
      colorScheme: theme.colorScheme.copyWith(
        primary: AppThemeTokens.darkPrimary,
        secondary: AppThemeTokens.darkSecondary,
        tertiary: AppThemeTokens.darkTertiary,
        surface: AppThemeTokens.darkSurface,
        surfaceContainerLowest: AppThemeTokens.darkSurfaceAlt,
        surfaceContainerLow: AppThemeTokens.darkSurfaceAlt,
        surfaceContainer: AppThemeTokens.darkSurfaceAlt,
        surfaceContainerHigh: Color.lerp(
          AppThemeTokens.darkSurfaceAlt,
          AppThemeTokens.darkOutline,
          0.28,
        ),
        surfaceContainerHighest: Color.lerp(
          AppThemeTokens.darkSurfaceAlt,
          AppThemeTokens.darkOutline,
          0.42,
        ),
        outline: AppThemeTokens.darkOutline,
        outlineVariant: AppThemeTokens.darkOutline,
      ),
      scaffoldBackgroundColor: AppThemeTokens.darkBackground,
      semanticColors: const AppSemanticColors(
        focus: AppThemeTokens.darkFocus,
        focusContainer: AppThemeTokens.darkFocusContainer,
      ),
      moneyColors: const AppMoneyColors(
        income: Color(0xFF7ED8A6),
        expense: Color(0xFFFF9AAF),
        transfer: Color(0xFFA8BFFF),
        credit: Color(0xFFFFC27A),
        warning: Color(0xFFFFC66B),
        success: Color(0xFF7ED8A6),
      ),
    );
  }

  static ThemeData _withThemeOverrides(
    ThemeData theme, {
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required AppSemanticColors semanticColors,
    required AppMoneyColors moneyColors,
  }) {
    return theme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: _withTextFallback(theme.textTheme),
      primaryTextTheme: _withTextFallback(theme.primaryTextTheme),
      extensions: <ThemeExtension<dynamic>>[
        semanticColors,
        moneyColors,
        AppThemeFallbacks.spacingTokens,
        AppThemeFallbacks.radiusTokens,
        AppThemeFallbacks.controlTokens,
      ],
    );
  }

  static TextTheme _withTextFallback(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: _withFontFallback(textTheme.displayLarge),
      displayMedium: _withFontFallback(textTheme.displayMedium),
      displaySmall: _withFontFallback(textTheme.displaySmall),
      headlineLarge: _withFontFallback(textTheme.headlineLarge),
      headlineMedium: _withFontFallback(textTheme.headlineMedium),
      headlineSmall: _withFontFallback(textTheme.headlineSmall),
      titleLarge: _withFontFallback(textTheme.titleLarge),
      titleMedium: _withFontFallback(textTheme.titleMedium),
      titleSmall: _withFontFallback(textTheme.titleSmall),
      bodyLarge: _withFontFallback(textTheme.bodyLarge),
      bodyMedium: _withFontFallback(textTheme.bodyMedium),
      bodySmall: _withFontFallback(textTheme.bodySmall),
      labelLarge: _withFontFallback(textTheme.labelLarge),
      labelMedium: _withFontFallback(textTheme.labelMedium),
      labelSmall: _withFontFallback(textTheme.labelSmall),
    );
  }

  static TextStyle? _withFontFallback(TextStyle? style) {
    return style?.copyWith(
      fontFamilyFallback: _fontFamilyFallback,
      letterSpacing: 0,
    );
  }
}
