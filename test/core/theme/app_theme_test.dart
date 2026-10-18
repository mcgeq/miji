import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_palette.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 这个文件只验**装配**：palette 里的值有没有落到正确的槽位、
/// 九套配色是不是彼此独立、缓存实例稳不稳。
///
/// 颜色本身好不好看无法断言，能断言的是「对比度够不够」——
/// 那部分在 `app_theme_contrast_test.dart`，它逐套逐档跑。
void main() {
  group('AppPalettes 目录', () {
    test('九套配色，id 不重复，默认那套一定在里面', () {
      expect(AppPalettes.all, hasLength(9));
      final ids = AppPalettes.all.map((palette) => palette.id).toSet();
      expect(ids, hasLength(9), reason: 'id 重复会让存档指到错误的配色');
      expect(ids, contains(AppPalettes.defaultId));
      for (final palette in AppPalettes.all) {
        expect(palette.name, isNotEmpty);
        expect(palette.tagline, isNotEmpty, reason: '设置页要靠它讲清取舍');
      }
    });

    test('byId 遇到未知 id 退回默认，不返回 null', () {
      // 旧版本存下的 id、手改过的 json、降级后缺失的配色都得有个落脚点，
      // 否则一屏黑白或者直接崩。
      expect(AppPalettes.byId('nope').id, AppPalettes.defaultId);
      expect(AppPalettes.byId('').id, AppPalettes.defaultId);
      expect(AppPalettes.byId(null).id, AppPalettes.defaultId);
      expect(AppPalettes.byId('clay').id, 'clay');
    });

    test('每套都有浅/深两档，且各自绑定了不同的中性面', () {
      for (final palette in AppPalettes.all) {
        expect(palette.light, isNot(same(palette.dark)));
        expect(
          palette.light.surfaceColors.background,
          isNot(palette.dark.surfaceColors.background),
          reason: '${palette.id} 深色页底没换，等于深色模式失效',
        );
        expect(palette.of(Brightness.dark), same(palette.dark));
        expect(palette.of(Brightness.light), same(palette.light));
      }
    });
  });

  group('AppTheme 装配', () {
    for (final palette in AppPalettes.all) {
      for (final brightness in Brightness.values) {
        final label = '${palette.name}·${brightness.name}';
        final theme = brightness == Brightness.dark
            ? AppTheme.dark(palette.id)
            : AppTheme.light(palette.id);
        final mode = palette.of(brightness);
        final scheme = theme.colorScheme;

        test('$label：token 落到正确的槽位', () {
          expect(scheme.brightness, brightness);
          // primary 是文字/图标角色，填充角色在 primarySolid 上，两者不能混。
          expect(scheme.primary, mode.brandColors.primary);
          expect(scheme.primaryContainer, mode.brandColors.primaryContainer);
          expect(
            scheme.onPrimaryContainer,
            mode.brandColors.onPrimaryContainer,
          );
          expect(scheme.secondary, mode.brandColors.secondary);
          expect(scheme.tertiary, mode.brandColors.tertiary);
          expect(scheme.surface, mode.surfaceColors.surface);
          expect(scheme.onSurface, mode.textColors.primary);
          expect(scheme.onSurfaceVariant, mode.textColors.secondary);
          expect(scheme.outline, mode.surfaceColors.outline);
          expect(scheme.outlineVariant, mode.surfaceColors.outlineVariant);
          expect(theme.scaffoldBackgroundColor, mode.surfaceColors.background);
          expect(theme.hintColor, mode.textColors.tertiary);
        });

        test('$label：语义色 / Hero / 图表挂成扩展', () {
          expect(theme.moneyColors, same(mode.money));
          expect(theme.heroGradients, same(mode.hero));
          expect(theme.chartPalette.colors, hasLength(8));
        });

        test('$label：实心控件走 primarySolid，不走 colorScheme.primary', () {
          expect(
            theme.floatingActionButtonTheme.backgroundColor,
            mode.brandColors.primarySolid,
          );
          expect(
            theme.progressIndicatorTheme.color,
            mode.brandColors.primarySolid,
          );
          expect(
            theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
            mode.brandColors.primarySolid,
          );
        });

        test('$label：error 槽位用记账那套语义红，不出现两种「错误红」', () {
          expect(scheme.error, mode.money.expenseStrong);
          expect(scheme.errorContainer, mode.money.expenseContainer);
        });

        test('$label：品牌/超支两张深卡用白字', () {
          // 这两张在九套里都是深底，白字成立；净资产卡则可能是亮卡配深字
          // （蔚蓝那套就是），所以它不在这条断言里 —— 它的对比度由
          // contrast 测试按自己的 onColor 逐档验。
          expect(mode.hero.brand.onColor, const Color(0xFFFFFFFF));
          expect(mode.hero.danger.onColor, const Color(0xFFFFFFFF));
        });
      }
    }

    test('表面阶梯不能四级同色（否则卡片没有层级）', () {
      for (final palette in AppPalettes.all) {
        for (final theme in [
          AppTheme.light(palette.id),
          AppTheme.dark(palette.id),
        ]) {
          expect(
            theme.colorScheme.surfaceContainerLow,
            isNot(theme.colorScheme.surfaceContainerHighest),
            reason: '${palette.id} 的表面阶梯塌了',
          );
        }
      }
    });
  });

  group('主题实例与缓存', () {
    test('同一套配色同一明暗档只构建一次（否则会重放 420ms 过渡）', () {
      // `MaterialApp` 内部是 `AnimatedTheme`：新 data 与旧 data 不相等就播一次过渡。
      // 而 ThemeData 的 == 会把 extensions 按**实例**比较，所以「每次 build 现造
      // 一份」会让 App 根组件每重建一次就重放一次整树重建。
      for (final palette in AppPalettes.all) {
        expect(
          identical(AppTheme.light(palette.id), AppTheme.light(palette.id)),
          isTrue,
        );
        expect(
          identical(AppTheme.dark(palette.id), AppTheme.dark(palette.id)),
          isTrue,
        );
        expect(
          AppTheme.light(palette.id) == AppTheme.dark(palette.id),
          isFalse,
        );
      }
    });

    test('九套配色互不相等（换配色必须真的换掉主题）', () {
      final lights = {
        for (final palette in AppPalettes.all) AppTheme.light(palette.id),
      };
      expect(lights, hasLength(AppPalettes.all.length));
    });

    test('不传参数时用默认配色', () {
      expect(AppTheme.light(), same(AppTheme.light(AppPalettes.defaultId)));
      expect(AppTheme.dark(), same(AppTheme.dark(AppPalettes.defaultId)));
    });
  });

  group('经典蔚蓝保留原值（老用户第一眼不该变）', () {
    test('浅色关键 token 与 v2 完全一致', () {
      final mode = AppPalettes.byId('azure').light;
      expect(mode.surfaceColors.background, const Color(0xFFF3F6F9));
      expect(mode.surfaceColors.surface, const Color(0xFFFFFFFF));
      expect(mode.surfaceColors.raised, const Color(0xFFFFFFFF));
      expect(mode.surfaceColors.sunken, const Color(0xFFEBEDF0));
      expect(mode.surfaceColors.outline, const Color(0xFF848C94));
      expect(mode.surfaceColors.outlineVariant, const Color(0xFFD9DDE1));
      expect(mode.textColors.primary, const Color(0xFF15171A));
      expect(mode.brandColors.primary, const Color(0xFF006AB1));
      expect(mode.brandColors.primarySolid, const Color(0xFF008EE9));
      expect(mode.brandColors.onPrimarySolid, const Color(0xFF001830));
      expect(mode.brandColors.secondary, const Color(0xFF5D7791));
      expect(mode.brandColors.tertiary, const Color(0xFF438883));
      // 净资产是亮卡配深字，品牌/超支是深卡配白字。
      expect(mode.hero.netWorth.onColor, const Color(0xFF10152C));
      expect(mode.hero.brand.onColor, const Color(0xFFFFFFFF));
      expect(mode.hero.amber, const Color(0xFFFFC94F));
    });

    test('深色关键 token 与 v2 完全一致', () {
      final mode = AppPalettes.byId('azure').dark;
      expect(mode.surfaceColors.sunken, const Color(0xFF181A1C));
      expect(mode.surfaceColors.background, const Color(0xFF222426));
      expect(mode.surfaceColors.surface, const Color(0xFF303234));
      expect(mode.surfaceColors.raised, const Color(0xFF3D3F42));
      expect(mode.brandColors.primary, const Color(0xFF89C5FF));
      expect(mode.brandColors.primarySolid, const Color(0xFF74BCFF));
    });
  });

  group('AppMoneyColors', () {
    test('语义色有三档角色：金额(vivid) / 小号文字(Strong) / 淡底(Container)', () {
      final money = AppPalettes.byId('azure').light.money;
      expect(money.income, const Color(0xFF2B933E));
      expect(money.expense, const Color(0xFFCA4B51));
      expect(money.transfer, const Color(0xFF008692));
      expect(money.credit, const Color(0xFF9E5BBA));
      expect(money.warning, const Color(0xFF956D00));
      // success 与 income 同值（语义不同，值不该不同）。
      expect(money.success, money.income);
      expect(money.incomeStrong, const Color(0xFF00651D));
      expect(money.expenseStrong, const Color(0xFF981729));
      expect(money.incomeContainer, const Color(0xFFD6F7D7));
      expect(money.expenseContainer, const Color(0xFFFFE6E5));
    });

    test('lerp 会带上三档角色一起插值', () {
      final light = AppPalettes.byId('azure').light.money;
      final dark = AppPalettes.byId('azure').dark.money;
      final mid = light.lerp(dark, 1);
      expect(mid.income, dark.income);
      expect(mid.incomeStrong, dark.incomeStrong);
      expect(mid.incomeContainer, dark.incomeContainer);
    });
  });

  group('AppHeroGradient', () {
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

  test('深浅两套图表色板同序：同一个分类在两种模式下落在同一个色相', () {
    final light = AppThemeFallbacks.chartPalette.colors;
    final dark = AppThemeFallbacks.darkChartPalette.colors;
    expect(dark, hasLength(light.length));
    for (var i = 0; i < light.length; i++) {
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

  test('没有扩展时回退到默认配色的语义色，而不是抛异常', () {
    final bare = ThemeData();
    expect(bare.moneyColors.income, AppThemeFallbacks.moneyColors.income);
  });
}
