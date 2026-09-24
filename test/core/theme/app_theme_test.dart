import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/core/theme/app_theme_extension.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

void main() {
  group('AppThemeTokens', () {
    test('浅色：D2 暖纸 · 靛蓝（docs/theme-studio.html）', () {
      expect(AppThemeTokens.lightPrimary, const Color(0xFF4269D3));
      expect(AppThemeTokens.lightPrimaryFill, const Color(0xFF5E88F6));
      expect(AppThemeTokens.lightOnPrimaryFill, const Color(0xFF03001F));
      expect(AppThemeTokens.lightPrimaryContainer, const Color(0xFFDDE8FF));
      expect(AppThemeTokens.lightOnPrimaryContainer, const Color(0xFF2E488E));
      expect(AppThemeTokens.lightSecondary, const Color(0xFF626E8A));
      expect(AppThemeTokens.lightTertiary, const Color(0xFF8B608C));
      expect(AppThemeTokens.lightFocus, const Color(0xFF007C7D));
      // 中性层：暖纸四级
      expect(AppThemeTokens.lightSurfaceSunken, const Color(0xFFECE7E1));
      expect(AppThemeTokens.lightBackground, const Color(0xFFF2EDE6));
      expect(AppThemeTokens.lightSurface, const Color(0xFFFBF6F0));
      expect(AppThemeTokens.lightSurfaceRaised, const Color(0xFFF6F1EB));
      // 描边两档
      expect(AppThemeTokens.lightOutline, const Color(0xFF998D80));
      expect(AppThemeTokens.lightOutlineVariant, const Color(0xFFDAD5CF));
      expect(AppThemeTokens.lightHeroAmber, const Color(0xFFFFE6BC));
    });

    test('深色：D2 暖纸 · 靛蓝（暗色重定档）', () {
      expect(AppThemeTokens.darkPrimary, const Color(0xFF759DFF));
      expect(AppThemeTokens.darkPrimaryFill, const Color(0xFFCADBFF));
      expect(AppThemeTokens.darkOnPrimaryFill, const Color(0xFF03001F));
      expect(AppThemeTokens.darkSurfaceSunken, const Color(0xFF090604));
      expect(AppThemeTokens.darkBackground, const Color(0xFF0E0A07));
      expect(AppThemeTokens.darkSurface, const Color(0xFF17130F));
      expect(AppThemeTokens.darkSurfaceRaised, const Color(0xFF221D18));
      expect(AppThemeTokens.darkOutline, const Color(0xFF6B6257));
      expect(AppThemeTokens.darkOutlineVariant, const Color(0xFF322E2A));
      expect(AppThemeTokens.darkHeroAmber, const Color(0xFFFFE6BC));
    });

    test('主题提供四档表面阶梯与图表色板', () {
      final light = AppTheme.light();
      final low = light.colorScheme.surfaceContainerLow;
      final high = light.colorScheme.surfaceContainerHighest;
      expect(light.colorScheme.surface, AppThemeTokens.lightSurface);
      expect(low, isNot(high), reason: '表面阶梯不该四级同色');
      expect(light.chartPalette.colors, hasLength(8));
      expect(AppTheme.dark().chartPalette.colors, hasLength(8));
    });
  });

  group('AppSemanticColors', () {
    test('exposes GTD focus colors as a theme extension', () {
      const colors = AppSemanticColors(
        focus: AppThemeTokens.lightFocus,
        focusContainer: AppThemeTokens.lightFocusContainer,
      );

      expect(colors.focus, AppThemeTokens.lightFocus);
      expect(colors.focusContainer, AppThemeTokens.lightFocusContainer);
    });

    test('lerps semantic colors', () {
      const light = AppSemanticColors(
        focus: AppThemeTokens.lightFocus,
        focusContainer: AppThemeTokens.lightFocusContainer,
      );
      const dark = AppSemanticColors(
        focus: AppThemeTokens.darkFocus,
        focusContainer: AppThemeTokens.darkFocusContainer,
      );

      final result = light.lerp(dark, 1);

      expect(result.focus, AppThemeTokens.darkFocus);
      expect(result.focusContainer, AppThemeTokens.darkFocusContainer);
    });
  });

  group('AppTheme', () {
    test('builds the Warm Daily light theme', () {
      final theme = AppTheme.light();
      final semanticColors = theme.extension<AppSemanticColors>();

      expect(theme.colorScheme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppThemeTokens.lightPrimary);
      expect(theme.colorScheme.secondary, AppThemeTokens.lightSecondary);
      expect(theme.colorScheme.tertiary, AppThemeTokens.lightTertiary);
      expect(theme.colorScheme.surface, AppThemeTokens.lightSurface);
      expect(theme.colorScheme.outline, AppThemeTokens.lightOutline);
      expect(theme.scaffoldBackgroundColor, AppThemeTokens.lightBackground);
      expect(semanticColors?.focus, AppThemeTokens.lightFocus);
      expect(
        semanticColors?.focusContainer,
        AppThemeTokens.lightFocusContainer,
      );
    });

    test('builds the Warm Daily dark theme', () {
      final theme = AppTheme.dark();
      final semanticColors = theme.extension<AppSemanticColors>();

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppThemeTokens.darkPrimary);
      expect(theme.colorScheme.secondary, AppThemeTokens.darkSecondary);
      expect(theme.colorScheme.tertiary, AppThemeTokens.darkTertiary);
      expect(theme.colorScheme.surface, AppThemeTokens.darkSurface);
      expect(theme.colorScheme.outline, AppThemeTokens.darkOutline);
      expect(theme.scaffoldBackgroundColor, AppThemeTokens.darkBackground);
      expect(semanticColors?.focus, AppThemeTokens.darkFocus);
      expect(semanticColors?.focusContainer, AppThemeTokens.darkFocusContainer);
    });
  });
}
