import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_palette.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 相对亮度（WCAG 2.1）。
double _luminance(Color color) {
  double channel(double value) {
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

/// 色相角（0~360）。
double hue(Color color) {
  final r = color.r;
  final g = color.g;
  final b = color.b;
  final maxC = math.max(r, math.max(g, b));
  final minC = math.min(r, math.min(g, b));
  final delta = maxC - minC;
  if (delta == 0) {
    return 0;
  }
  final double h;
  if (maxC == r) {
    h = ((g - b) / delta) % 6;
  } else if (maxC == g) {
    h = (b - r) / delta + 2;
  } else {
    h = (r - g) / delta + 4;
  }
  return (h * 60 + 360) % 360;
}

double hueDistance(Color a, Color b) {
  final diff = (hue(a) - hue(b)).abs();
  return math.min(diff, 360 - diff);
}

/// OKLab 距离（感知均匀空间）。
///
/// 亮度差相同的两对颜色，感知上的差别可以差很远 —— 「白 vs 奶油」的
/// 对比度差看着有 1.21:1，其实 ΔE 只有 0.089，肉眼基本读不出来。
/// 判「两个颜色是不是真的分得开」必须用它，不能用 WCAG 对比度。
double oklabDistance(Color a, Color b) {
  double srgbToLinear(double v) {
    return v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  }

  List<double> lab(Color c) {
    final r = srgbToLinear(c.r);
    final g = srgbToLinear(c.g);
    final bb = srgbToLinear(c.b);
    final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * bb;
    final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * bb;
    final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * bb;
    final lc = math.pow(l, 1 / 3).toDouble();
    final mc = math.pow(m, 1 / 3).toDouble();
    final sc = math.pow(s, 1 / 3).toDouble();
    return [
      0.2104542553 * lc + 0.7936177850 * mc - 0.0040720468 * sc,
      1.9779984951 * lc - 2.4285922050 * mc + 0.4505937099 * sc,
      0.0259040371 * lc + 0.7827717662 * mc - 0.8086757660 * sc,
    ];
  }

  final ca = lab(a);
  final cb = lab(b);
  return math.sqrt(
    math.pow(ca[0] - cb[0], 2) +
        math.pow(ca[1] - cb[1], 2) +
        math.pow(ca[2] - cb[2], 2),
  );
}

/// 九套配色的可访问性契约。
///
/// 阈值分两档，不要混用：
/// - **3:1** 给「大号粗体金额」和「非文字图形」（WCAG 1.4.3 大文本 / 1.4.11 图形边界）。
///   放宽到 3:1 是有意的 —— 把语义色按 4.5:1 卡，只能得到墨绿、橄榄这类暗浊色。
/// - **4.5:1** 给正文、小号文字、小号语义文字（`*Strong`）、以及压在语义淡底上的字。
///
/// 九套 × 两档 = 18 组，每组跑同一套断言。新增配色只要进 `AppPalettes.all`
/// 就自动被覆盖 —— 不用再补一份测试，也就不存在「新配色漏验」这种事。
void main() {
  final cases = [
    for (final palette in AppPalettes.all)
      for (final brightness in Brightness.values)
        (
          label: '${palette.name}·${brightness.name}',
          mode: palette.of(brightness),
          theme: brightness == Brightness.dark
              ? AppTheme.dark(palette.id)
              : AppTheme.light(palette.id),
        ),
  ];

  group('Hero 渐变', () {
    for (final item in cases) {
      final label = item.label;
      final mode = item.mode;
      final hero = mode.hero;

      test('$label：三套渐变都在，且各自带卡上正文色', () {
        expect(hero.netWorth.colors.length, greaterThanOrEqualTo(2));
        expect(hero.brand.colors.length, greaterThanOrEqualTo(2));
        expect(hero.danger.colors.length, greaterThanOrEqualTo(2));
      });

      test('$label：卡上正文色在每个停靠点上 ≥ 4.5:1', () {
        final sets = {
          'netWorth': hero.netWorth,
          'brand': hero.brand,
          'danger': hero.danger,
        };
        sets.forEach((name, gradient) {
          for (var index = 0; index < gradient.colors.length; index++) {
            // 关键：拿 gradient.onColor 算，不能一律拿白字算 ——
            // 蔚蓝那套的净资产卡是亮卡，白字只有 2~3:1，它配的是深字。
            final ratio = contrastRatio(
              gradient.onColor,
              gradient.colors[index],
            );
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$label / $name 第 ${index + 1} 档 '
                  '${gradient.colors[index]} 上用正文色 ${gradient.onColor} '
                  '只有 ${ratio.toStringAsFixed(2)}:1',
            );
          }
        });
      });

      test('$label：卡上次级文字用 0.78 降不透明度后仍 ≥ 4.5:1', () {
        for (final entry in {
          'netWorth': hero.netWorth,
          'brand': hero.brand,
          'danger': hero.danger,
        }.entries) {
          final gradient = entry.value;
          // 最亮的那一档是最坏情况（字与底最接近）。
          final brightest = gradient.colors.reduce(
            (a, b) => _luminance(a) >= _luminance(b) ? a : b,
          );
          final faded = Color.alphaBlend(
            gradient.onColor.withValues(
              alpha: AppHeroGradient.secondaryOpacity,
            ),
            brightest,
          );
          final ratio = contrastRatio(faded, brightest);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$label / ${entry.key} 次级文字在最亮档 $brightest 上只有 '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });

      test('$label：Hero 上的琥珀小字在品牌 / 超支卡上 ≥ 4.5:1', () {
        // 琥珀只用在深卡（品牌 / 超支）上；净资产卡是淡卡，那边的次级数字
        // 走 onColor + 降不透明度。
        final amber = hero.amber;
        for (final gradient in [hero.brand, hero.danger]) {
          for (final color in gradient.colors) {
            expect(
              contrastRatio(amber, color),
              greaterThanOrEqualTo(4.5),
              reason: '$label 琥珀字 $amber 在 $color 上不足 4.5:1',
            );
          }
        }
      });

      test('$label：Hero 卡在页面底上分得出来（不是隐形卡）', () {
        // 深色下的病是「卡片 = 页面底」：旧品牌卡照搬浅色值，三档只有 1.07:1，
        // 叠上「用卡片自身色做的投影」（1.02:1）后卡片直接消失。
        // 深色卡做不到高对比（页面底本身就暗），所以门槛按**抬升面**定，
        // 而不是拿 WCAG 的 3:1 硬套。
        final bg = mode.surfaceColors.background;
        // 浅色是「白卡浮在灰底上」，1.07 就够读出边界；深色是「亮卡压在暗底上」，
        // 门槛按抬升面定在 1.15。两档刻意不同，别套同一个数。
        final floor = item.theme.brightness == Brightness.dark ? 1.15 : 1.05;
        for (final gradient in [hero.netWorth, hero.brand, hero.danger]) {
          for (final color in gradient.colors) {
            final ratio = contrastRatio(color, bg);
            expect(
              ratio,
              greaterThanOrEqualTo(floor),
              reason:
                  '$label 卡面 $color 在页面底 $bg 上只有 '
                  '${ratio.toStringAsFixed(2)}:1，卡片边界会消失',
            );
          }
        }
      });
    }

    test('净资产渐变不是纯色（九套都得有色彩流动）', () {
      for (final item in cases) {
        final gradient = item.mode.hero.netWorth;
        final distance = oklabDistance(
          gradient.colors.first,
          gradient.colors.last,
        );
        expect(
          distance,
          greaterThan(0.02),
          reason:
              '${item.label} 净资产渐变两端几乎同色（ΔE ${distance.toStringAsFixed(3)}）',
        );
      }
    });

    test('深色下品牌卡的投影是暗色，不是卡片自身色', () {
      // 深色卡片是「比页面底亮的抬升面」，再拿卡片自己的颜色当投影就是往上打光。
      for (final palette in AppPalettes.all) {
        final brand = palette.dark.hero.brand;
        final bg = palette.dark.surfaceColors.background;
        expect(
          brand.shadow,
          isNot(brand.colors.first),
          reason: '${palette.id} 深色投影用了卡片自身颜色，等于没有投影',
        );
        expect(
          _luminance(brand.shadow),
          lessThan(_luminance(bg)),
          reason: '${palette.id} 深色卡片的投影必须比页面底更暗，抬升面才立得住',
        );
        expect(
          _luminance(brand.colors.first),
          greaterThan(_luminance(bg)),
          reason: '${palette.id} 深色卡片必须比页面底亮，抬升方向不能反',
        );
      }
    });

    test('告警琥珀必须真的与白条分得开，不能是「白里掺一点黄」', () {
      // 奶油色 #FFE6BC 与白色的 ΔE 只有 0.089，在石墨卡上看着就是
      // 「正常的白条，稍微脏一点」—— 告警态比正常态还弱。
      for (final item in cases) {
        final distance = oklabDistance(item.mode.hero.amber, Colors.white);
        expect(
          distance,
          greaterThanOrEqualTo(0.15),
          reason:
              '${item.label} 琥珀与白色 ΔE 只有 '
              '${distance.toStringAsFixed(3)}，告警态会被读成正常态',
        );
      }
    });
  });

  group('强调层与描边', () {
    for (final item in cases) {
      final label = item.label;
      final mode = item.mode;
      final brand = mode.brandColors;
      final surfaces = mode.surfaceColors;
      final scheme = item.theme.colorScheme;

      test('$label：实心按钮（primarySolid + onPrimarySolid）≥ 4.5:1', () {
        final ratio = contrastRatio(brand.primarySolid, brand.onPrimarySolid);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$label 填充按钮只有 ${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('$label：主色当文字 ≥ 4.5:1', () {
        // 这条是「primary 与 primarySolid 必须分成两个角色」的理由本身：
        // 填充色当小号文字通常不够，所以 colorScheme.primary 用的是另一档。
        final ratio = contrastRatio(brand.primary, surfaces.surface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$label primary-as-text 只有 ${ratio.toStringAsFixed(2)}:1；'
              'primary 槽位要放得下「小号文字」，不能用填充色',
        );
      });

      test('$label：选中态 container 配对 ≥ 4.5:1', () {
        expect(
          contrastRatio(brand.onPrimaryContainer, brand.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(brand.secondaryStrong, brand.secondaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$label secondary 容器配不上对',
        );
        expect(
          contrastRatio(brand.tertiaryStrong, brand.tertiaryContainer),
          greaterThanOrEqualTo(4.5),
          reason: '$label tertiary 容器配不上对',
        );
      });

      test('$label：ColorScheme 的 secondary / tertiary 容器也守 4.5:1', () {
        // AppBadge 之类的组件直接从 ColorScheme 取这两组，不经过 palette。
        expect(
          contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(scheme.onTertiaryContainer, scheme.tertiaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$label：控件描边 ≥ 3:1、分隔线只要看得见', () {
        expect(
          contrastRatio(surfaces.outline, surfaces.surface),
          greaterThanOrEqualTo(3.0),
          reason: '$label 控件描边不足 3:1（WCAG 1.4.11）',
        );
        final divider = contrastRatio(
          surfaces.outlineVariant,
          surfaces.surface,
        );
        expect(
          divider,
          greaterThan(1.08),
          reason: '$label 分隔线 $divider:1，等于没有分隔线',
        );
      });

      test('$label：文字三档，前两档 ≥ 4.5:1（含凹槽底）', () {
        for (final background in [
          surfaces.surface,
          surfaces.sunken,
          surfaces.background,
        ]) {
          expect(
            contrastRatio(mode.textColors.primary, background),
            greaterThanOrEqualTo(4.5),
            reason: '$label 正文压在 $background 上不够',
          );
          expect(
            contrastRatio(mode.textColors.secondary, background),
            greaterThanOrEqualTo(4.5),
            reason: '$label 次要文字压在 $background 上不够',
          );
        }
        // 第三档是提示/占位层，与旧体系一样只守 3:1。
        expect(
          contrastRatio(mode.textColors.tertiary, surfaces.surface),
          greaterThanOrEqualTo(3.0),
        );
      });

      test('$label：图表色板每个色对卡片 ≥ 3:1', () {
        for (final index in List.generate(8, (i) => i)) {
          final color = item.theme.chartPalette[index];
          expect(
            contrastRatio(color, surfaces.surface),
            greaterThanOrEqualTo(3.0),
            reason: '$label 图表第 $index 个色 $color 压在卡片上不够',
          );
        }
      });
    }
  });

  group('语义金额色', () {
    for (final item in cases) {
      final label = item.label;
      final mode = item.mode;
      final money = mode.money;
      final surfaces = mode.surfaceColors;

      test('$label：金额色（vivid）在卡上与凹槽上都 ≥ 3:1', () {
        for (final entry in {
          'income': money.income,
          'expense': money.expense,
          'transfer': money.transfer,
          'credit': money.credit,
          'warning': money.warning,
        }.entries) {
          for (final background in [surfaces.surface, surfaces.sunken]) {
            expect(
              contrastRatio(entry.value, background),
              greaterThanOrEqualTo(3.0),
              reason:
                  '$label ${entry.key} ${entry.value} 压在 $background 上只有 '
                  '${contrastRatio(entry.value, background).toStringAsFixed(2)}:1',
            );
          }
        }
      });

      test('$label：小号语义文字（*Strong）在卡上 ≥ 4.5:1', () {
        for (final entry in {
          'income': money.incomeStrong,
          'expense': money.expenseStrong,
          'transfer': money.transferStrong,
          'credit': money.creditStrong,
          'warning': money.warningStrong,
        }.entries) {
          expect(
            contrastRatio(entry.value, surfaces.surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label ${entry.key}Strong 压不住 12px',
          );
        }
      });

      test('$label：*Strong 压在自家 *Container 上 ≥ 4.5:1', () {
        for (final entry in {
          'income': (money.incomeStrong, money.incomeContainer),
          'expense': (money.expenseStrong, money.expenseContainer),
          'transfer': (money.transferStrong, money.transferContainer),
          'credit': (money.creditStrong, money.creditContainer),
          'warning': (money.warningStrong, money.warningContainer),
        }.entries) {
          expect(
            contrastRatio(entry.value.$1, entry.value.$2),
            greaterThanOrEqualTo(4.5),
            reason: '$label ${entry.key} 的「深字 + 淡底」配不上',
          );
        }
      });

      test('$label：五个语义色两两不撞成同一个颜色', () {
        final colors = {
          'income': money.income,
          'expense': money.expense,
          'transfer': money.transfer,
          'credit': money.credit,
          'warning': money.warning,
        };
        final names = colors.keys.toList();
        for (var i = 0; i < names.length; i++) {
          for (var j = i + 1; j < names.length; j++) {
            final distance = hueDistance(colors[names[i]]!, colors[names[j]]!);
            expect(
              distance,
              greaterThanOrEqualTo(20),
              reason:
                  '$label：${names[i]} 与 ${names[j]} 只差 '
                  '${distance.toStringAsFixed(1)}°，会被看成同一个颜色',
            );
          }
        }
      });
    }
  });

  group('AppChartPalette / AppHeroGradients 结构', () {
    test('没有扩展时回退到 fallback，而不是抛异常', () {
      final bare = ThemeData();
      expect(bare.heroGradients.netWorth.colors, isNotEmpty);
      expect(bare.chartPalette.colors, isNotEmpty);
      expect(
        bare.moneyColors.income,
        AppPalettes.byId(AppPalettes.defaultId).light.money.income,
      );
    });

    test('linear 保留停靠点顺序', () {
      const gradient = AppHeroGradient(
        colors: [Color(0xFF111111), Color(0xFF222222), Color(0xFF333333)],
      );
      expect(gradient.linear.colors, gradient.colors);
      expect(gradient.linear.begin, Alignment.topLeft);
      expect(gradient.linear.end, Alignment.bottomRight);
    });

    test('shadow 默认取第一档颜色', () {
      const gradient = AppHeroGradient(
        colors: [Color(0xFF6C507B), Color(0xFF2C8089)],
      );
      expect(gradient.shadow, const Color(0xFF6C507B));
    });

    test('lerp 在档数一致时逐档插值', () {
      const a = AppHeroGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
      const b = AppHeroGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]);
      final mid = a.lerpTo(b, 0.5);
      expect(mid.colors.length, 2);
      // Color.lerp 会给到 8bit 量化附近的值（127 或 128），不做精确比较。
      final grey = mid.colors.first;
      expect(grey.r, closeTo(0.5, 0.01));
      expect(grey.g, closeTo(0.5, 0.01));
      expect(grey.b, closeTo(0.5, 0.01));
    });

    test('lerp 在档数不一致时不做危险插值', () {
      const a = AppHeroGradient(colors: [Color(0xFF000000)]);
      const b = AppHeroGradient(colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]);
      expect(a.lerpTo(b, 0.4).colors, a.colors);
      expect(a.lerpTo(b, 0.6).colors, b.colors);
    });
  });
}
