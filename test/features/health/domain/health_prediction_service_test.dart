import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/domain/health_prediction_service.dart';

void main() {
  const settings = HealthPeriodSettingsModel(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    periodTrackingEnabled: true,
    periodReminderEnabled: true,
    ovulationReminderEnabled: true,
    pmsReminderEnabled: true,
    reminderDays: 1,
    dataSyncEnabled: true,
    analyticsEnabled: true,
  );

  test('uses settings when there is no period history', () {
    final prediction = HealthPredictionService.predictCycle(
      today: DateTime.utc(2026, 7, 18),
      settings: settings,
      periods: const [],
      activePregnancy: null,
    );

    expect(prediction.basis, HealthPredictionBasis.settings);
    expect(prediction.statusKind, HealthTodayStatusKind.noPeriodHistory);
    expect(prediction.mainStatus, '');
  });

  test('estimates next period from recent period starts', () {
    final prediction = HealthPredictionService.predictCycle(
      today: DateTime.utc(2026, 7, 18),
      settings: settings,
      periods: [
        HealthPeriodRecordModel(
          id: 'period_1',
          startDate: DateTime.utc(2026, 5, 31),
          endDate: DateTime.utc(2026, 6, 4),
          notes: null,
        ),
        HealthPeriodRecordModel(
          id: 'period_2',
          startDate: DateTime.utc(2026, 6, 29),
          endDate: DateTime.utc(2026, 7, 3),
          notes: null,
        ),
      ],
      activePregnancy: null,
    );

    expect(prediction.basis, HealthPredictionBasis.history);
    expect(prediction.currentCycleDay, 20);
    expect(prediction.nextPeriodStart, DateTime.utc(2026, 7, 28));
    expect(prediction.nextPeriodEnd, DateTime.utc(2026, 8, 1));
    expect(prediction.mainStatus, '周期第 20 天 · 预计 10 天后开始经期');
  });

  test('reports active period day when latest period is open', () {
    final prediction = HealthPredictionService.predictCycle(
      today: DateTime.utc(2026, 7, 18),
      settings: settings,
      periods: [
        HealthPeriodRecordModel(
          id: 'period_1',
          startDate: DateTime.utc(2026, 7, 16),
          endDate: null,
          notes: null,
        ),
      ],
      activePregnancy: null,
    );

    expect(prediction.statusKind, HealthTodayStatusKind.periodDay);
    expect(prediction.currentPeriodDay, 3);
    expect(prediction.mainStatus, '经期第 3 天 · 记录经量和症状');
  });

  test('pregnancy mode overrides cycle status', () {
    final prediction = HealthPredictionService.predictCycle(
      today: DateTime.utc(2026, 7, 18),
      settings: settings,
      periods: [
        HealthPeriodRecordModel(
          id: 'period_1',
          startDate: DateTime.utc(2026, 7, 16),
          endDate: null,
          notes: null,
        ),
      ],
      activePregnancy: HealthPregnancyStatus(
        id: 'pregnancy_1',
        startDate: DateTime.utc(2026, 5, 9),
        dueDate: DateTime.utc(2027, 4, 7),
        endDate: null,
        status: HealthPregnancyRecordStatus.active,
        notes: null,
      ),
    );

    expect(prediction.statusKind, HealthTodayStatusKind.pregnancy);
    expect(prediction.pregnancyWeek, 11);
    expect(prediction.mainStatus, '孕 11 周 · 预产期 4月7日');
  });
}
