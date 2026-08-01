import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/core/theme/app_theme_extension.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

void main() {
  group('AppThemeTokens', () {
    test('contains the approved Warm Daily light palette', () {
      expect(AppThemeTokens.lightPrimary, const Color(0xFFE45F4F));
      expect(AppThemeTokens.lightSecondary, const Color(0xFF21A78B));
      expect(AppThemeTokens.lightTertiary, const Color(0xFFD85C93));
      expect(AppThemeTokens.lightFocus, const Color(0xFF6C67D8));
      expect(AppThemeTokens.lightBackground, const Color(0xFFFFF8F2));
      expect(AppThemeTokens.lightSurface, const Color(0xFFFFFFFF));
      expect(AppThemeTokens.lightSurfaceAlt, const Color(0xFFFFF0E5));
      expect(AppThemeTokens.lightOutline, const Color(0xFFEAD8CC));
    });

    test('contains the approved Warm Daily dark palette', () {
      expect(AppThemeTokens.darkPrimary, const Color(0xFFFF9A88));
      expect(AppThemeTokens.darkSecondary, const Color(0xFF7AE1C8));
      expect(AppThemeTokens.darkTertiary, const Color(0xFFFFADD1));
      expect(AppThemeTokens.darkFocus, const Color(0xFFC1BCFF));
      expect(AppThemeTokens.darkBackground, const Color(0xFF1B1412));
      expect(AppThemeTokens.darkSurface, const Color(0xFF241C19));
      expect(AppThemeTokens.darkSurfaceAlt, const Color(0xFF30231E));
      expect(AppThemeTokens.darkOutline, const Color(0xFF57433A));
    });
  });

  group('AppSemanticColors', () {
    test('exposes GTD focus colors as a theme extension', () {
      const colors = AppSemanticColors(
        focus: AppThemeTokens.lightFocus,
        focusContainer: AppThemeTokens.lightFocusContainer,
      );

      expect(colors.focus, const Color(0xFF6C67D8));
      expect(colors.focusContainer, const Color(0xFFEBE9FF));
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
