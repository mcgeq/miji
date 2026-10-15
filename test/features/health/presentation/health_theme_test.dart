import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/presentation/health_theme.dart';

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

double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// 预测卡上的三种状态。
const _phases = [
  HealthCyclePhase.period,
  HealthCyclePhase.fertile,
  HealthCyclePhase.pms,
];

void main() {
  for (final entry in <(String, ThemeData)>[
    ('浅色', AppTheme.light()),
    ('深色', AppTheme.dark()),
  ]) {
    final mode = entry.$1;
    final theme = entry.$2;
    final palette = HealthPalette(theme.brightness);
    final card = theme.colorScheme.surfaceContainerLow;

    test('$mode：阶段文字档在同色淡底与卡面上都 ≥4.5:1', () {
      for (final phase in _phases) {
        final ink = palette.phaseInk(phase);
        final tint = Color.alphaBlend(palette.phaseSurface(phase), card);
        expect(
          _contrast(ink, tint),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $phase 的文字档压在同色淡底上不合格（$ink on $tint）',
        );
        expect(
          _contrast(ink, card),
          greaterThanOrEqualTo(4.5),
          reason: '$mode $phase 的文字档压在卡面上不合格（$ink on $card）',
        );
      }
    });

    test('$mode：本色（图例圆点 / 色块）在卡面上 ≥3:1', () {
      for (final phase in _phases) {
        expect(
          _contrast(palette.phase(phase), card),
          greaterThanOrEqualTo(3.0),
          reason: '$mode $phase 本色当图形用不合格',
        );
      }
    });
  }
}
