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
        onPrimary: Colors.white,
        primaryContainer: AppThemeTokens.lightPrimaryContainer,
        onPrimaryContainer: AppThemeTokens.lightOnPrimaryContainer,
        secondary: AppThemeTokens.lightSecondary,
        tertiary: AppThemeTokens.lightTertiary,
        surface: AppThemeTokens.lightSurface,
        onSurface: AppThemeTokens.lightText,
        onSurfaceVariant: AppThemeTokens.lightTextSecondary,
        // 四级表面阶梯：越低越“陷进去”，让卡片浮起来（不再四级同色）
        surfaceContainerLowest: AppThemeTokens.lightSurface,
        surfaceContainerLow: AppThemeTokens.lightSurfaceRaised,
        surfaceContainer: AppThemeTokens.lightSurfaceRaised,
        surfaceContainerHigh: AppThemeTokens.lightSurfaceSunken,
        surfaceContainerHighest: AppThemeTokens.lightSurfaceSunken,
        // 描边两档：控件描边 3:1，分隔线只求可见
        outline: AppThemeTokens.lightOutline,
        outlineVariant: AppThemeTokens.lightOutlineVariant,
      ),
      scaffoldBackgroundColor: AppThemeTokens.lightBackground,
      semanticColors: const AppSemanticColors(
        focus: AppThemeTokens.lightFocus,
        focusContainer: AppThemeTokens.lightFocusContainer,
      ),
      moneyColors: AppThemeFallbacks.moneyColors,
      heroGradients: AppThemeFallbacks.heroGradients,
      chartPalette: AppThemeFallbacks.chartPalette,
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
        onPrimary: Colors.white,
        primaryContainer: AppThemeTokens.darkPrimaryContainer,
        onPrimaryContainer: AppThemeTokens.darkOnPrimaryContainer,
        secondary: AppThemeTokens.darkSecondary,
        tertiary: AppThemeTokens.darkTertiary,
        surface: AppThemeTokens.darkSurface,
        onSurface: AppThemeTokens.darkText,
        onSurfaceVariant: AppThemeTokens.darkTextSecondary,
        surfaceContainerLowest: AppThemeTokens.darkSurfaceSunken,
        surfaceContainerLow: AppThemeTokens.darkBackground,
        surfaceContainer: AppThemeTokens.darkSurface,
        surfaceContainerHigh: AppThemeTokens.darkSurfaceRaised,
        surfaceContainerHighest: AppThemeTokens.darkSurfaceRaised,
        outline: AppThemeTokens.darkOutline,
        outlineVariant: AppThemeTokens.darkOutlineVariant,
      ),
      scaffoldBackgroundColor: AppThemeTokens.darkBackground,
      semanticColors: const AppSemanticColors(
        focus: AppThemeTokens.darkFocus,
        focusContainer: AppThemeTokens.darkFocusContainer,
      ),
      moneyColors: const AppMoneyColors(
        income: Color(0xFF9DF7B0),
        expense: Color(0xFFFFB5AA),
        transfer: Color(0xFF3FCDF6),
        credit: Color(0xFFF7DDFF),
        warning: Color(0xFFC8B648),
        success: Color(0xFF9DF7B0),
      ),
      heroGradients: const AppHeroGradients(
        // 每个端点都同时满足「白字 ≥4.5」与「琥珀字 ≥4.5」（求解器算出来的）。
        netWorth: AppHeroGradient(
          colors: [Color(0xFF6A55C6), Color(0xFF006EA0), Color(0xFF007370)],
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFFA15500), Color(0xFF9C6400), Color(0xFF936E00)],
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFFB2397C), Color(0xFFBF3D6D), Color(0xFFCB4453)],
        ),
        amber: AppThemeTokens.darkHeroAmber,
      ),
      chartPalette: const AppChartPalette(
        colors: [
          Color(0xFFEEB062),
          Color(0xFF45D3E3),
          Color(0xFFF29ED5),
          Color(0xFFBAC769),
          Color(0xFF8AC3FF),
          Color(0xFFFFA097),
          Color(0xFF70D6A4),
          Color(0xFFC4AEFF),
        ],
      ),
    );
  }

  static ThemeData _withThemeOverrides(
    ThemeData theme, {
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required AppSemanticColors semanticColors,
    required AppMoneyColors moneyColors,
    required AppHeroGradients heroGradients,
    required AppChartPalette chartPalette,
  }) {
    return theme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      textTheme: _withTextFallback(theme.textTheme),
      primaryTextTheme: _withTextFallback(theme.primaryTextTheme),
      extensions: <ThemeExtension<dynamic>>[
        semanticColors,
        moneyColors,
        heroGradients,
        chartPalette,
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
