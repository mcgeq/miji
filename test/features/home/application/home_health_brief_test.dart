import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

HealthDailyLog log({
  HealthMood? mood,
  int? sleepMinutes,
  int? waterIntake,
  int? weightGrams,
}) {
  return HealthDailyLog(
    id: null,
    date: DateTime.utc(2026, 10, 12),
    periodRecordId: null,
    flowLevel: null,
    symptoms: const [],
    mood: mood,
    exerciseIntensity: null,
    sexualActivity: null,
    contraceptionMethod: null,
    ovulationTest: null,
    medications: const [],
    diet: null,
    waterIntake: waterIntake,
    sleepMinutes: sleepMinutes,
    weightGrams: weightGrams,
    temperatureCelsiusTenths: null,
    stressLevel: null,
    calories: null,
    notes: null,
  );
}

HealthTodaySnapshot snapshot({required HealthDailyLog dailyLog}) {
  const settings = HealthPeriodSettingsModel(
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
  return HealthTodaySnapshot(
    date: DateTime.utc(2026, 10, 12),
    settings: settings,
    prediction: HealthCyclePrediction.cycleDay(
      basis: HealthPredictionBasis.history,
      mainStatus: '周期第 12 天',
      currentCycleDay: 12,
      daysUntilNextPeriod: 16,
      nextPeriodStart: DateTime.utc(2026, 10, 28),
      nextPeriodEnd: DateTime.utc(2026, 11, 1),
      fertileWindowStart: DateTime.utc(2026, 10, 20),
      fertileWindowEnd: DateTime.utc(2026, 10, 25),
      pmsStart: DateTime.utc(2026, 10, 24),
      pmsEnd: DateTime.utc(2026, 10, 30),
    ),
    activePeriod: null,
    dailyLog: dailyLog,
    activePregnancy: null,
  );
}

void main() {
  test('builds four today log metrics with empty flags', () {
    final brief = buildHomeHealthBrief(
      snapshot: snapshot(
        dailyLog: log(mood: HealthMood.calm, sleepMinutes: 440),
      ),
    );
    expect(brief.todayMetrics.length, 4);
    expect(brief.todayMetrics[0].logged, isTrue);
    expect(brief.todayMetrics[0].value, '平静');
    expect(brief.todayMetrics[1].value, '7h20m');
    expect(brief.todayMetrics[2].logged, isFalse); // 饮水
  });

  test('builds headline and phase for a cycle day', () {
    final brief = buildHomeHealthBrief(snapshot: snapshot(dailyLog: log()));
    expect(brief.trackingEnabled, isTrue);
    expect(brief.headline, contains('16'));
    expect(brief.phaseLabel, '卵泡期');
    expect(brief.ringDay, 12);
    expect(brief.ringTotal, 28);
    expect(brief.subline, contains('10月28日'));
  });

  test('reports a late period', () {
    const settings = HealthPeriodSettingsModel(
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
    final snap = HealthTodaySnapshot(
      date: DateTime.utc(2026, 10, 12),
      settings: settings,
      prediction: HealthCyclePrediction.cycleDay(
        basis: HealthPredictionBasis.history,
        mainStatus: '延期',
        currentCycleDay: 30,
        daysUntilNextPeriod: -2,
        nextPeriodStart: DateTime.utc(2026, 10, 10),
        nextPeriodEnd: DateTime.utc(2026, 10, 14),
        fertileWindowStart: DateTime.utc(2026, 9, 26),
        fertileWindowEnd: DateTime.utc(2026, 10, 1),
        pmsStart: DateTime.utc(2026, 10, 3),
        pmsEnd: DateTime.utc(2026, 10, 9),
      ),
      activePeriod: null,
      dailyLog: log(),
      activePregnancy: null,
    );
    final brief = buildHomeHealthBrief(snapshot: snap);
    expect(brief.headline, contains('推迟'));
    expect(brief.headline, contains('2'));
  });
}
