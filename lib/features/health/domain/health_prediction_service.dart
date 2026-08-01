import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';

class HealthPredictionService {
  const HealthPredictionService._();

  static HealthCyclePrediction predictCycle({
    required DateTime today,
    required HealthPeriodSettingsModel settings,
    required List<HealthPeriodRecordModel> periods,
    required HealthPregnancyStatus? activePregnancy,
  }) {
    final todayOnly = HealthDate.dateOnly(today);
    if (activePregnancy?.status == HealthPregnancyRecordStatus.active) {
      final pregnancy = activePregnancy!;
      final week =
          todayOnly
                  .difference(HealthDate.dateOnly(pregnancy.startDate))
                  .inDays ~/
              7 +
          1;
      return HealthCyclePrediction.pregnancy(
        mainStatus: healthPredictionPregnancyLabel(week, pregnancy.dueDate),
        pregnancyWeek: week,
      );
    }

    final sorted = [...periods]
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    HealthPeriodRecordModel? active;
    for (final period in sorted) {
      if (period.containsDate(todayOnly) && period.endDate == null) {
        active = period;
      }
    }
    if (active != null) {
      final periodDay =
          todayOnly.difference(HealthDate.dateOnly(active.startDate)).inDays +
          1;
      return HealthCyclePrediction.periodDay(
        mainStatus: healthPredictionPeriodDayLabel(periodDay),
        currentPeriodDay: periodDay,
        basis: sorted.length >= 2
            ? HealthPredictionBasis.history
            : HealthPredictionBasis.settings,
      );
    }

    if (sorted.isEmpty) {
      return HealthCyclePrediction.noHistory(mainStatus: '');
    }

    final cycleLength = _cycleLength(sorted, settings.averageCycleLength);
    final latestStart = HealthDate.dateOnly(sorted.last.startDate);
    final nextStart = latestStart.add(Duration(days: cycleLength));
    final nextEnd = nextStart.add(
      Duration(days: settings.averagePeriodLength - 1),
    );
    final currentCycleDay = todayOnly.difference(latestStart).inDays + 1;
    final daysUntil = nextStart.difference(todayOnly).inDays;
    return HealthCyclePrediction.cycleDay(
      basis: sorted.length >= 2
          ? HealthPredictionBasis.history
          : HealthPredictionBasis.settings,
      mainStatus: healthPredictionCycleDayLabel(currentCycleDay, daysUntil),
      currentCycleDay: currentCycleDay,
      nextPeriodStart: nextStart,
      nextPeriodEnd: nextEnd,
      fertileWindowStart: nextStart.subtract(const Duration(days: 16)),
      fertileWindowEnd: nextStart.subtract(const Duration(days: 11)),
      pmsStart: nextStart.subtract(const Duration(days: 7)),
      pmsEnd: nextStart.subtract(const Duration(days: 1)),
    );
  }

  static int _cycleLength(List<HealthPeriodRecordModel> sorted, int fallback) {
    if (sorted.length < 2) {
      return fallback;
    }
    final gaps = <int>[];
    for (var i = 1; i < sorted.length; i += 1) {
      gaps.add(
        HealthDate.dateOnly(
          sorted[i].startDate,
        ).difference(HealthDate.dateOnly(sorted[i - 1].startDate)).inDays,
      );
    }
    final recent = gaps.length > 3 ? gaps.sublist(gaps.length - 3) : gaps;
    return (recent.reduce((a, b) => a + b) / recent.length).round();
  }
}
