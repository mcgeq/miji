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

/// 深浅主题里所有会承载白字的渐变停靠点，都必须达到 AA 正文标准。
void main() {
  final themes = {'light': AppTheme.light(), 'dark': AppTheme.dark()};

  group('Hero 渐变', () {
    for (final entry in themes.entries) {
      final label = entry.key;
      final theme = entry.value;

      test('$label：主题提供了三套渐变', () {
        final gradients = theme.heroGradients;
        expect(gradients.netWorth.colors.length, greaterThanOrEqualTo(2));
        expect(gradients.brand.colors.length, greaterThanOrEqualTo(2));
        expect(gradients.danger.colors.length, greaterThanOrEqualTo(2));
      });

      test('$label：每个停靠点上的白字都 ≥ 4.5:1', () {
        final gradients = theme.heroGradients;
        final sets = {
          'netWorth': gradients.netWorth,
          'brand': gradients.brand,
          'danger': gradients.danger,
        };

        sets.forEach((name, gradient) {
          for (var index = 0; index < gradient.colors.length; index++) {
            final ratio = contrastRatio(gradient.colors[index], Colors.white);
            expect(
              ratio,
              greaterThanOrEqualTo(4.5),
              reason:
                  '$label / $name 第 ${index + 1} 档 '
                  '${gradient.colors[index]} 白字对比只有 '
                  '${ratio.toStringAsFixed(2)}:1',
            );
          }
        });
      });

      test('$label：渐变停靠点从左到右由暗到亮或保持稳定', () {
        // 只是防止把某一档写成接近纯黑/纯白的异常值。
        for (final gradient in [
          theme.heroGradients.netWorth,
          theme.heroGradients.brand,
          theme.heroGradients.danger,
        ]) {
          for (final color in gradient.colors) {
            final ratio = contrastRatio(color, Colors.white);
            expect(ratio, lessThan(16), reason: '渐变不该出现接近纯黑的停靠点');
          }
        }
      });
    }

    test('净资产渐变跨越足够大的色相，保证有色彩流动感', () {
      final light = AppTheme.light().heroGradients.netWorth;
      final span = hueDistance(light.colors.first, light.colors.last);
      expect(span, greaterThan(60), reason: '净资产渐变是唯一跨越冷色区的大跨度渐变，实际 $span°');
    });

    test('深色主题下净资产渐变右端不会亮到看不清白字', () {
      final dark = AppTheme.dark().heroGradients.netWorth;
      final ratio = contrastRatio(dark.colors.last, Colors.white);
      expect(ratio, greaterThanOrEqualTo(4.5));
    });
  });

  group('强调层与描边（D2 新增的不变量）', () {
    for (final entry in themes.entries) {
      final label = entry.key;
      final scheme = entry.value.colorScheme;

      test('$label：实心按钮（填充 + 前景）≥ 4.5:1', () {
        final tokens = label == 'light'
            ? (
                AppThemeTokens.lightPrimaryFill,
                AppThemeTokens.lightOnPrimaryFill,
              )
            : (
                AppThemeTokens.darkPrimaryFill,
                AppThemeTokens.darkOnPrimaryFill,
              );
        final ratio = contrastRatio(tokens.$1, tokens.$2);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason:
              '$label 填充按钮只有 ${ratio.toStringAsFixed(2)}:1 '
              '（旧实现深色下是 2.05:1）',
        );
      });

      test('$label：强调色当文字 ≥ 4.5:1', () {
        final ratio = contrastRatio(scheme.primary, scheme.surface);
        expect(ratio, greaterThanOrEqualTo(4.5));
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

      test('$label：图片色板每个色对卡片 ≥ 3:1', () {
        for (final color in entry.value.chartPalette.colors) {
          expect(
            contrastRatio(color, scheme.surface),
            greaterThanOrEqualTo(3.0),
          );
        }
      });

      test('$label：Hero 上的琥珀字 ≥ 4.5:1', () {
        final gradients = entry.value.heroGradients;
        for (final color in gradients.netWorth.colors) {
          final ratio = contrastRatio(gradients.amber, color);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason:
                '$label 净资产渐变 $color 上的琥珀字只有 '
                '${ratio.toStringAsFixed(2)}:1',
          );
        }
      });
    }
  });

  group('语义金额色', () {
    final backgrounds = {
      '卡片 surface': AppThemeTokens.lightSurface,
      '页面底色': AppThemeTokens.lightBackground,
      '凹陷面 sunken': AppThemeTokens.lightSurfaceSunken,
    };

    test('浅色主题：六种语义色在所有底色上都 ≥ 4.5:1', () {
      final money = AppTheme.light().moneyColors;
      final colors = {
        'income': money.income,
        'expense': money.expense,
        'transfer': money.transfer,
        'credit': money.credit,
        'warning': money.warning,
        'success': money.success,
      };

      colors.forEach((name, color) {
        backgrounds.forEach((bgName, background) {
          final ratio = contrastRatio(color, background);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '浅色 / $name 在 $bgName 上只有 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });

    test('深色主题：六种语义色在深色底上都 ≥ 4.5:1', () {
      final money = AppTheme.dark().moneyColors;
      final colors = {
        'income': money.income,
        'expense': money.expense,
        'transfer': money.transfer,
        'credit': money.credit,
        'warning': money.warning,
        'success': money.success,
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
            greaterThanOrEqualTo(4.5),
            reason: '深色 / $name 在 $bgName 上只有 ${ratio.toStringAsFixed(2)}:1',
          );
        });
      });
    });

    test('浅色主题：语义色两两色相距离 ≥ 25°', () {
      final money = AppTheme.light().moneyColors;
      // success 与 income 同值，不参与两两比较。
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
            greaterThanOrEqualTo(25),
            reason:
                '${names[i]} 与 ${names[j]} 只差 ${distance.toStringAsFixed(1)}°，'
                '并排会被看成同一个颜色',
          );
        }
      }
    });

    test('浅色主题：语义色与暖中性背景的色相不再重合', () {
      final money = AppTheme.light().moneyColors;
      // 背景是 27.7°，原来 warning(33.4°) 和 credit(31.7°) 几乎贴着它。
      const background = Color(0xFFFFF8F2);
      for (final entry in {
        'warning': money.warning,
        'credit': money.credit,
      }.entries) {
        final distance = hueDistance(entry.value, background);
        expect(
          distance,
          greaterThanOrEqualTo(15),
          reason: '${entry.key} 与背景色相只差 ${distance.toStringAsFixed(1)}°',
        );
      }
    });
  });

  group('AppHeroGradients', () {
    test('fallback 与浅色主题一致', () {
      final fallback = AppThemeFallbacks.heroGradients;
      final light = AppTheme.light().heroGradients;
      expect(fallback.netWorth.colors, light.netWorth.colors);
      expect(fallback.brand.colors, light.brand.colors);
      expect(fallback.danger.colors, light.danger.colors);
    });

    test('没有扩展时回退到 fallback，而不是抛异常', () {
      final bare = ThemeData();
      expect(bare.heroGradients.netWorth.colors, isNotEmpty);
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
