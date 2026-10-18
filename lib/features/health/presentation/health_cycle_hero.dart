import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';

/// 常驻在「今日 / 日历」顶部的周期状态卡。
///
/// 现状只有选中「今天」才展示一行 indicators 字符串；这里改成任何日期都
/// 显示当前周期第几天、所处阶段与下次经期倒计时，字段全部来自现有
/// [HealthCyclePrediction]。
class HealthCycleHero extends StatelessWidget {
  const HealthCycleHero({
    required this.snapshot,
    required this.date,
    super.key,
  });

  final HealthTodaySnapshot snapshot;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final prediction = snapshot.prediction;
    final settings = snapshot.settings;

    if (!settings.periodTrackingEnabled) {
      return _HeroShell(
        colors: const [Color(0xFF7C6A61), Color(0xFF5C4C45)],
        children: [
          const _HeroTag(text: '经期记录已关闭'),
          const SizedBox(height: 14),
          const _HeroBig(value: '仅记录', unit: '每日数据'),
          const SizedBox(height: 6),
          const _HeroFoot(text: '重新开启后可查看周期预测与阶段'),
        ],
      );
    }

    final phase = prediction.phaseOn(date);
    final progress = healthCycleProgressFor(prediction, settings);
    final overdue = prediction.isOverdue;

    final colors = switch (prediction.statusKind) {
      HealthTodayStatusKind.pregnancy => const [
        Color(0xFFD85C93),
        Color(0xFFB85AC2),
        Color(0xFF8E4BC4),
      ],
      _ when overdue => const [Color(0xFFC97A12), Color(0xFFD8456B)],
      _ => const [Color(0xFFD8456B), Color(0xFFC24A80), Color(0xFF8E4BC4)],
    };

    final title = switch (prediction.statusKind) {
      HealthTodayStatusKind.pregnancy => '孕 ${prediction.pregnancyWeek ?? 0}',
      HealthTodayStatusKind.periodDay => '${prediction.currentPeriodDay ?? 0}',
      HealthTodayStatusKind.cycleDay => '${prediction.currentCycleDay ?? 0}',
      HealthTodayStatusKind.noPeriodHistory => '—',
    };
    final unit = switch (prediction.statusKind) {
      HealthTodayStatusKind.pregnancy => '周',
      HealthTodayStatusKind.periodDay => '天',
      HealthTodayStatusKind.cycleDay => '天',
      HealthTodayStatusKind.noPeriodHistory => '',
    };
    final label = switch (prediction.statusKind) {
      HealthTodayStatusKind.pregnancy => '孕期进行中',
      HealthTodayStatusKind.periodDay => '经期第 ${prediction.currentPeriodDay} 天',
      HealthTodayStatusKind.cycleDay => '当前周期第 ${prediction.currentCycleDay} 天',
      HealthTodayStatusKind.noPeriodHistory => '还没有经期记录',
    };

    final foot = _buildFoot(prediction);

    return _HeroShell(
      colors: colors,
      children: [
        Row(
          children: [
            _HeroTag(text: healthCyclePhaseLabel(phase)),
            const SizedBox(width: 8),
            if (settings.periodReminderEnabled ||
                settings.ovulationReminderEnabled ||
                settings.pmsReminderEnabled)
              const _HeroSoftTag(text: '提醒已开'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroBig(value: title, unit: unit),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (progress != null)
              _HeroRing(
                ratio: progress.ratio,
                top: '${progress.day}/${progress.total}',
                bottom: prediction.statusKind == HealthTodayStatusKind.periodDay
                    ? '经期进度'
                    : '周期进度',
              ),
          ],
        ),
        if (foot != null) ...[
          const SizedBox(height: 14),
          _HeroFoot(text: foot),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            _HeroPill(label: '平均周期', value: '${settings.averageCycleLength} 天'),
            const SizedBox(width: 8),
            _HeroPill(
              label: '平均经期',
              value: '${settings.averagePeriodLength} 天',
            ),
            const SizedBox(width: 8),
            _HeroPill(
              label: '预测依据',
              value: healthPredictionBasisLabel(prediction.basis),
            ),
          ],
        ),
      ],
    );
  }

  String? _buildFoot(HealthCyclePrediction prediction) {
    switch (prediction.statusKind) {
      case HealthTodayStatusKind.noPeriodHistory:
        return null;
      case HealthTodayStatusKind.pregnancy:
        final due = snapshot.activePregnancy?.dueDate;
        return due == null ? '预产期未设置' : '预产期 ${healthMonthDayLabel(due)}';
      case HealthTodayStatusKind.periodDay:
        return '记录当天的经量与症状，预测会更准';
      case HealthTodayStatusKind.cycleDay:
        final next = prediction.nextPeriodStart;
        final daysUntil = prediction.daysUntilNextPeriod;
        if (next == null || daysUntil == null) {
          return null;
        }
        return '${healthCycleCountdownLabel(daysUntil)} · 预计 ${healthMonthDayLabel(next)} 开始';
    }
  }
}

class _HeroShell extends StatelessWidget {
  const _HeroShell({required this.colors, required this.children});

  final List<Color> colors;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.32),
            blurRadius: 26,
            offset: const Offset(0, 14),
            spreadRadius: -16,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            top: -80,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ],
      ),
    );
  }
}

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _HeroSoftTag extends StatelessWidget {
  const _HeroSoftTag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF9BF5D4),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBig extends StatelessWidget {
  const _HeroBig({required this.value, required this.unit});

  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 38,
          height: 1.02,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        children: [
          if (unit.isNotEmpty)
            TextSpan(
              text: ' $unit',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroFoot extends StatelessWidget {
  const _HeroFoot({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: 0,
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.ratio,
    required this.top,
    required this.bottom,
  });

  final double ratio;
  final String top;
  final String bottom;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: CircularProgressIndicator(
              value: ratio,
              strokeWidth: 8,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.24),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                top,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                bottom,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
