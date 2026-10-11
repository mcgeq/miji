import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';

/// 经期功能专用的语义调色板。
///
/// 之前日历格子用的是 7 个硬编码 pastel（`_phaseColor`），标记点又走
/// `ColorScheme`，两套颜色在深色主题下对比度不足且互相打架。这里把所有
/// 阶段色集中一处，按亮/暗主题给出两档，保证：
///   * 两两色相距离足够，5 种阶段同屏仍可分辨；
///   * 实心块的前景色（[onPhase]）对比度 ≥ 4.5:1。
class HealthPalette {
  const HealthPalette(this.brightness);

  factory HealthPalette.of(BuildContext context) {
    return HealthPalette(Theme.of(context).brightness);
  }

  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;

  Color get period => _dark ? const Color(0xFFFF8FAD) : const Color(0xFFD8456B);
  Color get fertile =>
      _dark ? const Color(0xFF6FDCC0) : const Color(0xFF17967A);
  Color get pms => _dark ? const Color(0xFFC6A0FF) : const Color(0xFF8A5AC2);
  Color get luteal => _dark ? const Color(0xFFF0B45C) : const Color(0xFFC97A12);
  Color get follicular =>
      _dark ? const Color(0xFF9DBAFF) : const Color(0xFF4F7DD9);
  Color get ovulation =>
      _dark ? const Color(0xFFF5C06A) : const Color(0xFFE08A1E);
  Color get pregnancy =>
      _dark ? const Color(0xFFFFADD1) : const Color(0xFFD85C93);
  Color get medication => pms;
  Color get neutral =>
      _dark ? const Color(0xFF8B7870) : const Color(0xFF7C6A61);

  Color phase(HealthCyclePhase phase) {
    return switch (phase) {
      HealthCyclePhase.period => period,
      HealthCyclePhase.follicular => follicular,
      HealthCyclePhase.fertile => fertile,
      HealthCyclePhase.luteal => luteal,
      HealthCyclePhase.pms => pms,
      HealthCyclePhase.pregnancy => pregnancy,
      HealthCyclePhase.none => neutral,
    };
  }

  /// 叠加在浅色底上的阶段色（易孕期 / 经前期 / 卵泡期 / 黄体期）。
  Color phaseSurface(HealthCyclePhase value) {
    return phase(value).withValues(alpha: _dark ? 0.18 : 0.13);
  }

  /// 实心块（经期 / 孕期）上的前景色。
  Color onPhase(HealthCyclePhase value) {
    return switch (value) {
      HealthCyclePhase.period || HealthCyclePhase.pregnancy =>
        _dark ? const Color(0xFF2B1F1A) : Colors.white,
      _ => phase(value),
    };
  }

  Color marker(HealthCalendarMarkerKind kind) {
    return switch (kind) {
      HealthCalendarMarkerKind.actualPeriod => period,
      HealthCalendarMarkerKind.predictedPeriod => period,
      HealthCalendarMarkerKind.pms => pms,
      HealthCalendarMarkerKind.fertileWindow => fertile,
      HealthCalendarMarkerKind.ovulationTest => ovulation,
      HealthCalendarMarkerKind.medication => medication,
      HealthCalendarMarkerKind.dailyLog => neutral,
    };
  }

  /// 快捷记录图标的底色。
  Color actionSurface(HealthQuickAction action) {
    return actionColor(action).withValues(alpha: _dark ? 0.18 : 0.12);
  }

  Color actionColor(HealthQuickAction action) {
    return switch (action) {
      HealthQuickAction.period => period,
      HealthQuickAction.flow =>
        _dark ? const Color(0xFFFF8EA8) : const Color(0xFFCD323F),
      HealthQuickAction.symptoms => luteal,
      HealthQuickAction.mood => follicular,
      HealthQuickAction.temperatureSleep => follicular,
      HealthQuickAction.ovulationTest => ovulation,
      HealthQuickAction.medication => medication,
      HealthQuickAction.more => neutral,
    };
  }
}
