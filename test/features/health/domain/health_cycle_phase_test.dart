import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';

void main() {
  HealthPeriodSettingsModel settings() {
    return const HealthPeriodSettingsModel(
      averageCycleLength: 28,
      averagePeriodLength: 5,
      periodTrackingEnabled: true,
      periodReminderEnabled: true,
      ovulationReminderEnabled: true,
      pmsReminderEnabled: true,
      reminderDays: 1,
      dataSyncEnabled: true,
      analyticsEnabled: false,
    );
  }

  HealthCyclePrediction cyclePrediction() {
    return HealthCyclePrediction.cycleDay(
      basis: HealthPredictionBasis.history,
      mainStatus: '周期第 20 天 · 预计 10 天后开始经期',
      currentCycleDay: 20,
      daysUntilNextPeriod: 10,
      nextPeriodStart: DateTime.utc(2026, 7, 28),
      nextPeriodEnd: DateTime.utc(2026, 8, 1),
      fertileWindowStart: DateTime.utc(2026, 7, 12),
      fertileWindowEnd: DateTime.utc(2026, 7, 17),
      pmsStart: DateTime.utc(2026, 7, 21),
      pmsEnd: DateTime.utc(2026, 7, 27),
    );
  }

  test('derives fertile window phase', () {
    final prediction = cyclePrediction();
    expect(
      prediction.phaseOn(DateTime.utc(2026, 7, 14)),
      HealthCyclePhase.fertile,
    );
  });

  test('derives luteal phase between fertile window and PMS', () {
    final prediction = cyclePrediction();
    expect(
      prediction.phaseOn(DateTime.utc(2026, 7, 18)),
      HealthCyclePhase.luteal,
    );
  });

  test('derives PMS phase', () {
    final prediction = cyclePrediction();
    expect(prediction.phaseOn(DateTime.utc(2026, 7, 24)), HealthCyclePhase.pms);
  });

  test('derives follicular phase before the fertile window', () {
    final prediction = cyclePrediction();
    expect(
      prediction.phaseOn(DateTime.utc(2026, 7, 8)),
      HealthCyclePhase.follicular,
    );
  });

  test('period and pregnancy override everything', () {
    final period = HealthCyclePrediction.periodDay(
      mainStatus: '经期第 2 天',
      currentPeriodDay: 2,
      basis: HealthPredictionBasis.history,
    );
    expect(period.phaseOn(DateTime.utc(2026, 7, 18)), HealthCyclePhase.period);

    final pregnancy = HealthCyclePrediction.pregnancy(
      mainStatus: '孕 11 周',
      pregnancyWeek: 11,
    );
    expect(
      pregnancy.phaseOn(DateTime.utc(2026, 7, 18)),
      HealthCyclePhase.pregnancy,
    );

    const noHistory = HealthCyclePrediction.noHistory(mainStatus: '');
    expect(noHistory.phaseOn(DateTime.utc(2026, 7, 18)), HealthCyclePhase.none);
  });

  test('computes cycle progress from prediction and settings', () {
    final progress = healthCycleProgressFor(cyclePrediction(), settings());
    expect(progress, isNotNull);
    expect(progress!.day, 20);
    expect(progress.total, 28);
    expect(progress.ratio, closeTo(20 / 28, 0.0001));
  });

  test('overdue prediction reports negative days until next period', () {
    final overdue = HealthCyclePrediction.cycleDay(
      basis: HealthPredictionBasis.history,
      mainStatus: '周期第 31 天 · 已推迟 3 天',
      currentCycleDay: 31,
      daysUntilNextPeriod: -3,
      nextPeriodStart: DateTime.utc(2026, 7, 25),
      nextPeriodEnd: DateTime.utc(2026, 7, 29),
      fertileWindowStart: DateTime.utc(2026, 7, 9),
      fertileWindowEnd: DateTime.utc(2026, 7, 14),
      pmsStart: DateTime.utc(2026, 7, 18),
      pmsEnd: DateTime.utc(2026, 7, 24),
    );
    expect(overdue.isOverdue, isTrue);
  });
}
