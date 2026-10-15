import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

void main() {
  group('AppThemeTokens', () {
    test('浅色：A 晴空（宝蓝 + 冷白灰底）', () {
      // 主色三个角色各管一件事，不再像旧体系那样 primary / primaryFill 两套并存。
      expect(AppThemeTokens.lightPrimary, const Color(0xFF006AB1));
      expect(AppThemeTokens.lightPrimarySolid, const Color(0xFF008EE9));
      expect(AppThemeTokens.lightOnPrimarySolid, const Color(0xFF001830));
      expect(AppThemeTokens.lightPrimaryContainer, const Color(0xFFDFEFFF));
      expect(AppThemeTokens.lightOnPrimaryContainer, const Color(0xFF004D83));
      expect(AppThemeTokens.lightSecondary, const Color(0xFF5D7791));
      expect(AppThemeTokens.lightTertiary, const Color(0xFF438883));
      // 中性面：灰底 + 纯白卡。surface 与 raised **同色**是刻意的——
      // 层级靠「白浮在灰上」+ 阴影，不靠四级明度微差（旧体系正因为只差 4% 才看不出层级）。
      expect(AppThemeTokens.lightBackground, const Color(0xFFF3F6F9));
      expect(AppThemeTokens.lightSurface, const Color(0xFFFFFFFF));
      expect(AppThemeTokens.lightSurfaceRaised, const Color(0xFFFFFFFF));
      expect(AppThemeTokens.lightSurfaceSunken, const Color(0xFFEBEDF0));
      // 文字三档
      expect(AppThemeTokens.lightText, const Color(0xFF15171A));
      expect(AppThemeTokens.lightTextSecondary, const Color(0xFF585B5E));
      expect(AppThemeTokens.lightTextTertiary, const Color(0xFF797C7F));
      // 描边两档
      expect(AppThemeTokens.lightOutline, const Color(0xFF848C94));
      expect(AppThemeTokens.lightOutlineVariant, const Color(0xFFD9DDE1));
      // Hero 卡的正文色：净资产是亮卡，配深字
      expect(AppThemeTokens.lightOnNetWorth, const Color(0xFF10152C));
      expect(AppThemeTokens.lightOnBrand, const Color(0xFFFFFFFF));
      expect(AppThemeTokens.lightOnDanger, const Color(0xFFFFFFFF));
      expect(AppThemeTokens.lightHeroAmber, const Color(0xFFFFE6BC));
    });

    test('深色：A 晴空（深灰蓝，不是浅色调暗）', () {
      expect(AppThemeTokens.darkPrimary, const Color(0xFF89C5FF));
      expect(AppThemeTokens.darkPrimarySolid, const Color(0xFF74BCFF));
      expect(AppThemeTokens.darkOnPrimarySolid, const Color(0xFF001B33));
      expect(AppThemeTokens.darkPrimaryContainer, const Color(0xFF093050));
      expect(AppThemeTokens.darkOnPrimaryContainer, const Color(0xFFAFD7FF));
      // 旧深色底是 #0E0A07 近黑，压在暗环境里太硬；现在是深灰蓝，越上层越亮。
      expect(AppThemeTokens.darkSurfaceSunken, const Color(0xFF181A1C));
      expect(AppThemeTokens.darkBackground, const Color(0xFF222426));
      expect(AppThemeTokens.darkSurface, const Color(0xFF303234));
      expect(AppThemeTokens.darkSurfaceRaised, const Color(0xFF3D3F42));
      expect(AppThemeTokens.darkOutline, const Color(0xFF838A92));
      expect(AppThemeTokens.darkOutlineVariant, const Color(0xFF494E52));
      expect(AppThemeTokens.darkHeroAmber, const Color(0xFFFFE6BC));
    });

    test('主题提供表面阶梯与图表色板', () {
      final light = AppTheme.light();
      final low = light.colorScheme.surfaceContainerLow;
      final high = light.colorScheme.surfaceContainerHighest;
      expect(light.colorScheme.surface, AppThemeTokens.lightSurface);
      expect(low, isNot(high), reason: '表面阶梯不该四级同色');
      expect(light.chartPalette.colors, hasLength(8));
      expect(AppTheme.dark().chartPalette.colors, hasLength(8));
    });

    test('深浅两套图表色板同序：同一个分类在两种模式下落在同一个色相', () {
      final light = AppThemeFallbacks.chartPalette.colors;
      final dark = AppTheme.darkChartPalette.colors;
      expect(dark, hasLength(light.length));
      for (var i = 0; i < light.length; i++) {
        // 同序的检验方式：两个模式下第 i 个色的色相相差不超过 25°。
        final diff =
            (HSVColor.fromColor(light[i]).hue - HSVColor.fromColor(dark[i]).hue)
                .abs();
        expect(
          math.min(diff, 360 - diff),
          lessThan(25),
          reason: '第 $i 个色在两个模式下色相不一致，切主题会重排分类颜色',
        );
      }
    });
  });

  group('AppMoneyColors', () {
    test('语义色有三档角色：金额(vivid) / 小号文字(Strong) / 淡底(Container)', () {
      final money = AppThemeFallbacks.moneyColors;
      // 金额档是正色（放宽到 3:1 之后才拿得到），不是旧体系那种墨绿 / 橄榄。
      expect(money.income, const Color(0xFF2B933E));
      expect(money.expense, const Color(0xFFCA4B51));
      expect(money.transfer, const Color(0xFF008692));
      expect(money.credit, const Color(0xFF9E5BBA));
      expect(money.warning, const Color(0xFF956D00));
      // success 与 income 同值（语义不同，值不该不同）。
      expect(money.success, money.income);
      // 小号文字档：比金额档深，压得住 12px。
      expect(money.incomeStrong, const Color(0xFF00651D));
      expect(money.expenseStrong, const Color(0xFF981729));
      expect(money.transferStrong, const Color(0xFF005961));
      expect(money.creditStrong, const Color(0xFF712F8C));
      expect(money.warningStrong, const Color(0xFF634700));
      // 淡底档：实色，替掉 `withValues(alpha:.12)`。
      expect(money.incomeContainer, const Color(0xFFD6F7D7));
      expect(money.expenseContainer, const Color(0xFFFFE6E5));
      expect(money.transferContainer, const Color(0xFFC3F8FF));
      expect(money.creditContainer, const Color(0xFFF7E6FF));
      expect(money.warningContainer, const Color(0xFFFFEAC4));
    });

    test('lerp 会带上三档角色一起插值', () {
      final mid = AppThemeFallbacks.moneyColors.lerp(
        AppTheme.darkMoneyColors,
        1,
      );
      expect(mid.income, AppTheme.darkMoneyColors.income);
      expect(mid.incomeStrong, AppTheme.darkMoneyColors.incomeStrong);
      expect(mid.incomeContainer, AppTheme.darkMoneyColors.incomeContainer);
    });
  });

  group('AppHeroGradient', () {
    test('卡上正文色由 token 给，不再一律白字', () {
      final gradients = AppTheme.light().heroGradients;
      expect(gradients.netWorth.onColor, AppThemeTokens.lightOnNetWorth);
      expect(gradients.brand.onColor, AppThemeTokens.lightOnBrand);
      expect(gradients.danger.onColor, AppThemeTokens.lightOnDanger);
    });

    test('onColor 会跟着 lerp 走', () {
      const a = AppHeroGradient(
        colors: [Color(0xFF000000)],
        onColor: Color(0xFF000000),
      );
      const b = AppHeroGradient(
        colors: [Color(0xFFFFFFFF)],
        onColor: Color(0xFFFFFFFF),
      );
      expect(a.lerpTo(b, 1).onColor, const Color(0xFFFFFFFF));
      expect(a.lerpTo(b, 0).onColor, const Color(0xFF000000));
    });

    test('默认 onColor 是白字（深卡不需要每次显式声明）', () {
      const gradient = AppHeroGradient(colors: [Color(0xFF111111)]);
      expect(gradient.onColor, const Color(0xFFFFFFFF));
    });
  });

  group('AppTheme', () {
    test('浅色主题把 A 的 token 灌进正确的槽位', () {
      final theme = AppTheme.light();

      expect(theme.colorScheme.brightness, Brightness.light);
      // primary 是文字/图标角色（要过 AA），填充角色在 primarySolid 上。
      expect(theme.colorScheme.primary, AppThemeTokens.lightPrimary);
      expect(theme.colorScheme.primaryContainer, const Color(0xFFDFEFFF));
      expect(
        theme.colorScheme.onPrimaryContainer,
        AppThemeTokens.lightOnPrimaryContainer,
      );
      expect(theme.colorScheme.secondary, AppThemeTokens.lightSecondary);
      expect(theme.colorScheme.tertiary, AppThemeTokens.lightTertiary);
      expect(theme.colorScheme.surface, AppThemeTokens.lightSurface);
      expect(theme.colorScheme.outline, AppThemeTokens.lightOutline);
      expect(theme.scaffoldBackgroundColor, AppThemeTokens.lightBackground);
      expect(theme.hintColor, AppThemeTokens.lightTextTertiary);
    });

    test('深色主题把 A 的 token 灌进正确的槽位', () {
      final theme = AppTheme.dark();

      expect(theme.colorScheme.brightness, Brightness.dark);
      expect(theme.colorScheme.primary, AppThemeTokens.darkPrimary);
      expect(theme.colorScheme.surface, AppThemeTokens.darkSurface);
      expect(theme.colorScheme.outline, AppThemeTokens.darkOutline);
      expect(theme.scaffoldBackgroundColor, AppThemeTokens.darkBackground);
      expect(theme.hintColor, AppThemeTokens.darkTextTertiary);
    });

    test('实心控件走 primarySolid + onPrimarySolid，不走 colorScheme.primary', () {
      for (final entry in {
        'light': (AppTheme.light(), AppThemeTokens.lightPrimarySolid),
        'dark': (AppTheme.dark(), AppThemeTokens.darkPrimarySolid),
      }.entries) {
        final theme = entry.value.$1;
        expect(
          theme.floatingActionButtonTheme.backgroundColor,
          entry.value.$2,
          reason: '${entry.key} FAB 应取 primarySolid',
        );
        expect(
          theme.progressIndicatorTheme.color,
          entry.value.$2,
          reason: '${entry.key} 进度条应取 primarySolid',
        );
      }
    });

    test('error 槽位直接用记账那套语义红，避免出现两种「错误红」', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();
      expect(
        light.colorScheme.error,
        AppThemeFallbacks.moneyColors.expenseStrong,
      );
      expect(
        light.colorScheme.errorContainer,
        AppThemeFallbacks.moneyColors.expenseContainer,
      );
      expect(dark.colorScheme.error, AppTheme.darkMoneyColors.expenseStrong);
      expect(
        dark.colorScheme.errorContainer,
        AppTheme.darkMoneyColors.expenseContainer,
      );
    });

    test('没有扩展时回退到浅色语义色，而不是抛异常', () {
      final bare = ThemeData();
      expect(bare.moneyColors.income, AppThemeFallbacks.moneyColors.income);
    });

    test('主题实例必须稳定（否则 MaterialApp 会反复重放 420ms 过渡）', () {
      // `MaterialApp` 内部是 `AnimatedTheme`：新 data 与旧 data 不相等就播一次过渡。
      // 而 ThemeData 的 == 会把 extensions 里的对象按实例比较，所以「每次 build 现造
      // 一份」会让 App 根组件每重建一次就重放一次整树重建。
      // 这里锁死「同一实例」，回归时能立刻发现。
      expect(identical(AppTheme.light(), AppTheme.light()), isTrue);
      expect(identical(AppTheme.dark(), AppTheme.dark()), isTrue);
      expect(AppTheme.light() == AppTheme.light(), isTrue);
      expect(AppTheme.dark() == AppTheme.dark(), isTrue);
      // 两份主题之间仍必须是不相等的（否则浅深色切换就再也不会有过渡）。
      expect(AppTheme.light() == AppTheme.dark(), isFalse);
    });
  });
}
