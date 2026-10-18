import 'package:miji/features/health/domain/health_models.dart';

/// 当前所处周期阶段。用于周期 Hero、日历格子与图例的视觉编码。
///
/// 注意：这是一个纯展示层派生概念，不落库；所有判断都基于
/// [HealthCyclePrediction] 已经算好的日期区间。
enum HealthCyclePhase {
  /// 正在经期。
  period,

  /// 经期结束到易孕期之前。
  follicular,

  /// 易孕期。
  fertile,

  /// 易孕期结束到经前期之前。
  luteal,

  /// 经前期。
  pms,

  /// 孕期模式。
  pregnancy,

  /// 没有足够数据判断。
  none,
}

extension HealthCyclePhaseDerivation on HealthCyclePrediction {
  /// 派生 [date] 当天的周期阶段。
  HealthCyclePhase phaseOn(DateTime date) {
    if (statusKind == HealthTodayStatusKind.pregnancy) {
      return HealthCyclePhase.pregnancy;
    }
    if (statusKind == HealthTodayStatusKind.periodDay) {
      return HealthCyclePhase.period;
    }
    if (statusKind == HealthTodayStatusKind.noPeriodHistory) {
      return HealthCyclePhase.none;
    }

    final day = HealthDate.dateOnly(date);
    final fertileStart = fertileWindowStart;
    final fertileEnd = fertileWindowEnd;
    if (fertileStart != null &&
        fertileEnd != null &&
        !day.isBefore(fertileStart) &&
        !day.isAfter(fertileEnd)) {
      return HealthCyclePhase.fertile;
    }

    final pmsStart = this.pmsStart;
    final pmsEnd = this.pmsEnd;
    if (pmsStart != null &&
        pmsEnd != null &&
        !day.isBefore(pmsStart) &&
        !day.isAfter(pmsEnd)) {
      return HealthCyclePhase.pms;
    }

    if (fertileEnd != null && day.isAfter(fertileEnd)) {
      return HealthCyclePhase.luteal;
    }

    return HealthCyclePhase.follicular;
  }
}

/// 当前周期已进行的天数 / 总天数，用于 Hero 的环形进度。
class HealthCycleProgress {
  const HealthCycleProgress({required this.day, required this.total});

  final int day;
  final int total;

  double get ratio {
    if (total <= 0) {
      return 0;
    }
    return (day / total).clamp(0.0, 1.0);
  }
}

HealthCycleProgress? healthCycleProgressFor(
  HealthCyclePrediction prediction,
  HealthPeriodSettingsModel settings,
) {
  final cycleDay = prediction.currentCycleDay;
  if (cycleDay != null) {
    return HealthCycleProgress(
      day: cycleDay,
      total: settings.averageCycleLength,
    );
  }
  final periodDay = prediction.currentPeriodDay;
  if (periodDay != null) {
    return HealthCycleProgress(
      day: periodDay,
      total: settings.averagePeriodLength,
    );
  }
  return null;
}
