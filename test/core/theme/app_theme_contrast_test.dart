import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

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

/// A 晴空这套配色的可访问性契约。
///
/// 阈值分两档，不要混用：
/// - **3:1** 给「大号粗体金额」和「非文字图形」（WCAG 1.4.3 大文本 / 1.4.11 图形边界）。
///   放宽到 3:1 是有意的——把语义色按 4.5:1 卡，只能得到 `#0D5900` 墨绿这类暗浊色。
/// - **4.5:1** 给正文、小号文字、小号语义文字（`*Strong`）、以及压在语义淡底上的字。
void main() {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  group('Hero 渐变', () {
    for (final entry in themes.entries) {
      final label = entry.key;
      final theme = entry.value;

      test('$label：主题提供了三套渐变，且各自带卡上正文色', () {
        final gradients = theme.heroGradients;
        expect(gradients.netWorth.colors.length, greaterThanOrEqualTo(2));
        expect(gradients.brand.colors.length, greaterThanOrEqualTo(2));
        expect(gradients.danger.colors.length, greaterThanOrEqualTo(2));
      });

      test('$label：卡上正文色在每个停靠点上 ≥ 4.5:1', () {
        final gradients = theme.heroGradients;
        final sets = {
          'netWorth': gradients.netWorth,
          'brand': gradients.brand,
          'danger': gradients.danger,
        };

        sets.forEach((name, gradient) {
          for (var index = 0; index < gradient.colors.length; index++) {
            // 关键：拿 gradient.onColor 算，不能一律拿白字算。
            // 净资产卡是亮卡，白字只有 2~3:1，它的正文是深字。
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
          'netWorth': theme.heroGradients.netWorth,
          'brand': theme.heroGradients.brand,
          'danger': theme.heroGradients.danger,
        }.entries) {
          final gradient = entry.value;
          // 最亮的那个停靠点是最坏情况（字与底最接近）。
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

      test('$label：渐变停靠点不会亮到接近纯白', () {
        for (final gradient in [
          theme.heroGradients.netWorth,
          theme.heroGradients.brand,
          theme.heroGradients.danger,
        ]) {
          for (final color in gradient.colors) {
            expect(
              contrastRatio(color, Colors.white),
              lessThan(20),
              reason: '渐变不该出现接近纯白的停靠点',
            );
          }
        }
      });

      test('$label：Hero 上的琥珀小字在品牌 / 超支卡上 ≥ 4.5:1', () {
        // 琥珀只用在深卡（品牌石墨 / 超支深红）上；
        // 净资产卡是亮卡，那边的次级数字走 onColor + 降不透明度。
        final amber = theme.heroGradients.amber;
        for (final gradient in [
          theme.heroGradients.brand,
          theme.heroGradients.danger,
        ]) {
          for (final color in gradient.colors) {
            expect(
              contrastRatio(amber, color),
              greaterThanOrEqualTo(4.5),
              reason: '$label 琥珀字 $amber 在 $color 上不足 4.5:1',
            );
          }
        }
      });
    }

    test('净资产渐变在冷色区里有色彩流动（色相跨度 > 40°）', () {
      // 上一版这里卡的是 60°，因为它是「紫→青」跨色区的大跨度渐变。
      // A 的净资产是「亮蓝 → 淡紫」的同族渐变（跨 50° 左右），品牌色已经由
      // 石墨卡承担，所以这里只守卫「别退化成一个纯色」，不再要求跨色区。
      for (final entry in themes.entries) {
        final gradient = entry.value.heroGradients.netWorth;
        final span = hueDistance(gradient.colors.first, gradient.colors.last);
        expect(
          span,
          greaterThan(40),
          reason: '${entry.key} 净资产渐变色相只跨了 ${span.toStringAsFixed(1)}°',
        );
      }
    });

    test('净资产卡用深字、品牌/超支卡用白字', () {
      expect(
        AppThemeFallbacks.heroGradients.netWorth.onColor,
        AppThemeTokens.lightOnNetWorth,
      );
      expect(
        AppThemeFallbacks.heroGradients.brand.onColor,
        AppThemeTokens.lightOnBrand,
      );
      expect(
        AppThemeFallbacks.heroGradients.danger.onColor,
        AppThemeTokens.lightOnDanger,
      );
    });

    test('石墨卡在自己的页面底上分得出来（不是隐形卡）', () {
      // 深色下的病是「卡片 = 页面底」：旧深色品牌卡是 #212A33/#353B43/#2C3038，
      // 而深色页面底就是 #222426，三档只有 1.07 / 1.38 / 1.18:1。
      // 深色卡片做不到高对比（页面底本身就暗），所以门槛按「抬升面」定，
      // 而不是拿 WCAG 的 3:1 硬套 —— 常规卡 #303234 也才 1.21:1。
      for (final stops in [
        (AppThemeTokens.lightBackground, AppThemeFallbacks.heroGradients.brand),
        (AppThemeTokens.darkBackground, AppTheme.dark().heroGradients.brand),
      ]) {
        final bg = stops.$1;
        final light = bg == AppThemeTokens.lightBackground;
        final floor = light ? 8.0 : 1.30;
        for (final color in stops.$2.colors) {
          expect(
            contrastRatio(color, bg),
            greaterThanOrEqualTo(floor),
            reason:
                '石墨卡 $color 在页面底 $bg 上只有 '
                '${contrastRatio(color, bg).toStringAsFixed(2)}:1，卡片边界会消失',
          );
        }
      }
    });

    test('深色石墨卡的投影是暗色，不是卡片自身色', () {
      // 卡片现在是「比页面底亮的抬升面」，再拿卡片自己的颜色当投影就是往上打光。
      final brand = AppTheme.dark().heroGradients.brand;
      expect(
        brand.shadow,
        isNot(brand.colors.first),
        reason: '投影色不能是卡片自身颜色，否则深色下等于没有投影',
      );
      expect(
        _luminance(brand.shadow),
        lessThan(_luminance(AppThemeTokens.darkBackground)),
        reason: '深色卡片的投影必须比页面底更暗，抬升面才立得住',
      );
      // 卡片本身必须比页面底亮，否则抬升方向和常规卡相反。
      expect(
        _luminance(brand.colors.first),
        greaterThan(_luminance(AppThemeTokens.darkBackground)),
      );
    });

    test('告警琥珀必须真的与白条分得开，不能是「白里掺一点黄」', () {
      // 旧值 #FFE6BC 与白色的 ΔE 只有 0.089，在石墨卡上看着就是
      // 「正常的白条，稍微脏一点」—— 告警态比正常态还弱。
      for (final entry in themes.entries) {
        final distance = oklabDistance(
          entry.value.heroGradients.amber,
          Colors.white,
        );
        expect(
          distance,
          greaterThanOrEqualTo(0.15),
          reason:
              '${entry.key} 琥珀与白色 ΔE 只有 '
              '${distance.toStringAsFixed(3)}，告警态会被读成正常态',
        );
      }
    });

    test('fallback 与浅色主题一致', () {
      final fallback = AppThemeFallbacks.heroGradients;
      final light = AppTheme.light().heroGradients;
      expect(fallback.netWorth.colors, light.netWorth.colors);
      expect(fallback.brand.colors, light.brand.colors);
      expect(fallback.danger.colors, light.danger.colors);
    });
  });

  group('强调层与描边', () {
    for (final entry in themes.entries) {
      final label = entry.key;
      final theme = entry.value;
      final scheme = theme.colorScheme;

      test('$label：实心按钮（primarySolid + onPrimarySolid）≥ 4.5:1', () {
        final tokens = label == 'light'
            ? (
                AppThemeTokens.lightPrimarySolid,
                AppThemeTokens.lightOnPrimarySolid,
              )
            : (
                AppThemeTokens.darkPrimarySolid,
                AppThemeTokens.darkOnPrimarySolid,
              );
        final ratio = contrastRatio(tokens.$1, tokens.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$label 填充按钮只有 ${ratio.toStringAsFixed(2)}:1',
        );
      });

      test('$label：强调色当文字 ≥ 4.5:1', () {
        // 这条是「primary 与 primarySolid 必须分成两个角色」的理由本身：
        // primarySolid 当文字只有 3.5:1，所以 colorScheme.primary 用的是深版。
        final ratio = contrastRatio(scheme.primary, scheme.surface);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$label primary-as-text 只有 ${ratio.toStringAsFixed(2)}:1；'
              'primary 槽位要放得下「小号文字」，不能用填充色',
        );
      });

      test('$label：选中态 container 配对 ≥ 4.5:1', () {
        final ratio = contrastRatio(
          scheme.onPrimaryContainer,
          scheme.primaryContainer,
        );
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '同色淡底 + 同色文字的老写法只有 3.03:1',
        );
      });

      test('$label：Flex 推出来的 secondary / tertiary 容器也守 4.5:1', () {
        // 这两组不在 A 的 token 表里（表只给了本色），由 FlexColorScheme 推导，
        // 所以得单独盯着——AppBadge 之类的组件会用到它们。
        expect(
          contrastRatio(scheme.onSecondaryContainer, scheme.secondaryContainer),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(scheme.onTertiaryContainer, scheme.tertiaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      });

      test('$label：控件描边 ≥ 3:1、分隔线只要可见', () {
        expect(
          contrastRatio(scheme.outline, scheme.surface),
          greaterThanOrEqualTo(3.0),
          reason: 'WCAG 1.4.11：控件边界 3:1',
        );
        expect(
          contrastRatio(scheme.outlineVariant, scheme.surface),
          greaterThan(1.1),
        );
      });

      test('$label：文字三档，前两档 ≥ 4.5:1（含凹槽底）', () {
        final tokens = label == 'light'
            ? (
                AppThemeTokens.lightText,
                AppThemeTokens.lightTextSecondary,
                AppThemeTokens.lightSurfaceSunken,
              )
            : (
                AppThemeTokens.darkText,
                AppThemeTokens.darkTextSecondary,
                AppThemeTokens.darkSurfaceSunken,
              );
        expect(
          contrastRatio(tokens.$1, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.$2, scheme.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          contrastRatio(tokens.$2, tokens.$3),
          greaterThanOrEqualTo(4.5),
          reason: '次要文字压在凹槽面上也要能读',
        );
      });

      test('$label：图表色板每个色对卡片 ≥ 3:1', () {
        for (final color in theme.chartPalette.colors) {
          expect(
            contrastRatio(color, scheme.surface),
            greaterThanOrEqualTo(3.0),
          );
        }
      });
    }
  });

  group('语义金额色', () {
    test('浅色：金额色（vivid）在三种底上都 ≥ 3:1', () {
      final money = AppTheme.light().moneyColors;
      final backgrounds = {
        '卡片 surface': AppThemeTokens.lightSurface,
        '页面底色': AppThemeTokens.lightBackground,
        '凹陷面 sunken': AppThemeTokens.lightSurfaceSunken,
      };
      final colors = {
        'income': money.income,
        'expense': money.expense,
        'transfer': money.transfer,
        'credit': money.credit,
        'warning': money.warning,
      };

      colors.forEach((name, color) {
        backgrounds.forEach((bgName, background) {
          final ratio = contrastRatio(color, background);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason:
                '浅色 / $name 在 $bgName 上只有 ${ratio.toStringAsFixed(2)}:1'
                '（金额是大号粗体，按 3:1 判）',
          );
        });
      });
    });

    test('深色：金额色在深色底上 ≥ 3:1', () {
      final money = AppTheme.dark().moneyColors;
      final colors = {
        'income': money.income,
        'expense': money.expense,
        'transfer': money.transfer,
        'credit': money.credit,
        'warning': money.warning,
      };
      final backgrounds = {
        '卡片 surface': AppThemeTokens.darkSurface,
        '页面底色': AppThemeTokens.darkBackground,
      };

      colors.forEach((name, color) {
        backgrounds.forEach((bgName, background) {
          final ratio = contrastRatio(color, background);
          expect(
            ratio,
            greaterThanOrEqualTo(3.0),
            reason: '深色 / $name 在 $bgName 上只有 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });

    test('两套模式：小号语义文字（*Strong）在 surface 上都 ≥ 4.5:1', () {
      for (final entry in {
        '浅色': (AppTheme.light(), AppThemeTokens.lightSurface),
        '深色': (AppTheme.dark(), AppThemeTokens.darkSurface),
      }.entries) {
        final money = entry.value.$1.moneyColors;
        final surface = entry.value.$2;
        final colors = {
          'incomeStrong': money.incomeStrong,
          'expenseStrong': money.expenseStrong,
          'transferStrong': money.transferStrong,
          'creditStrong': money.creditStrong,
          'warningStrong': money.warningStrong,
        };
        colors.forEach((name, color) {
          final ratio = contrastRatio(color, surface);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '${entry.key} / $name 在 surface 上只有 '
                '${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('两套模式：*Strong 压在自家 *Container 上 ≥ 4.5:1', () {
      // 这是「容器层」的核心契约：淡底和底上的字成对交付，
      // 调用方不会再拼出「浅底 + 浅字」这种只有 3:1 的组合。
      for (final entry in {
        '浅色': AppTheme.light().moneyColors,
        '深色': AppTheme.dark().moneyColors,
      }.entries) {
        final money = entry.value;
        final pairs = {
          'income': (money.incomeStrong, money.incomeContainer),
          'expense': (money.expenseStrong, money.expenseContainer),
          'transfer': (money.transferStrong, money.transferContainer),
          'credit': (money.creditStrong, money.creditContainer),
          'warning': (money.warningStrong, money.warningContainer),
        };
        pairs.forEach((name, pair) {
          final ratio = contrastRatio(pair.$1, pair.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} / $name 容器字底只有 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    test('两套模式：语义色两两不再撞成同一个颜色', () {
      // v2 不再追求 v1 的「色觉缺陷下 ΔE ≥ 0.06」：五个语义色几乎占满色环，
      // 主色放哪都会挨着某一个，靠 ΔE 拉开会让整盘色变脏。
      // 改为**场景隔离**——主色只出现在按钮/导航/图标，语义色只出现在金额/tag。
      // 这条断言只是防止两个语义色被写成同一个颜色。
      for (final entry in {
        '浅色': AppTheme.light().moneyColors,
        '深色': AppTheme.dark().moneyColors,
      }.entries) {
        final money = entry.value;
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
                  '${entry.key}：${names[i]} 与 ${names[j]} 只差 '
                  '${distance.toStringAsFixed(1)}°，会被看成同一个颜色',
            );
          }
        }
      }
    });
  });

  group('AppChartPalette / AppHeroGradients 结构', () {
    test('没有扩展时回退到 fallback，而不是抛异常', () {
      final bare = ThemeData();
      expect(bare.heroGradients.netWorth.colors, isNotEmpty);
      expect(bare.chartPalette.colors, isNotEmpty);
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
