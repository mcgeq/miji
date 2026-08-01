import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_calendar_tab.dart';
import 'package:miji/features/health/presentation/health_daily_log_sheet.dart';
import 'package:miji/features/health/presentation/health_settings_tab.dart';
import 'package:miji/features/health/presentation/health_trends_tab.dart';
import 'package:miji/features/health/presentation/health_today_tab.dart';

void main() {
  testWidgets('HealthTodayTab shows prediction and neutral summary', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: HealthTodayTab(snapshot: _snapshot(), onEditDailyLog: () {}),
      ),
    );

    expect(find.text('周期第 20 天 · 预计 10 天后开始经期'), findsOneWidget);
    expect(find.text('今日共 2 条记录'), findsOneWidget);
  });

  testWidgets(
    'HealthTodayTab hides sexual activity and contraception details',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: HealthTodayTab(snapshot: _snapshot(), onEditDailyLog: () {}),
        ),
      );

      expect(find.textContaining('避孕套'), findsNothing);
      expect(find.textContaining('性生活'), findsNothing);
    },
  );

  testWidgets(
    'HealthDailyLogSheet exposes ordinary fields before private expansion',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: Scaffold(
            body: HealthDailyLogSheet(
              initialDate: DateTime.utc(2026, 7, 18),
              initialLog: HealthDailyLog.empty(DateTime.utc(2026, 7, 18)),
              onSave: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('经量'), findsWidgets);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('睡眠'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('私密生殖健康'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('私密生殖健康'), findsOneWidget);
      expect(find.text('排卵试纸'), findsNothing);
    },
  );
  testWidgets('HealthCalendarTab renders date markers', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: HealthCalendarTab(
          focusedDay: DateTime.utc(2026, 7, 18),
          selectedDay: DateTime.utc(2026, 7, 18),
          markers: [
            HealthCalendarMarker(
              date: DateTime.utc(2026, 7, 18),
              kind: HealthCalendarMarkerKind.dailyLog,
              label: '日记录',
            ),
          ],
          onDaySelected: (_, _) {},
          onQuickAction: (_) {},
          onEditDailyLog: () {},
        ),
      ),
    );

    expect(find.byType(TableCalendar<HealthCalendarMarker>), findsOneWidget);
  });

  testWidgets('HealthSettingsTab exposes period recording toggle', (
    tester,
  ) async {
    HealthPeriodSettingsDraft? saved;
    await tester.pumpWidget(
      _TestApp(
        child: HealthSettingsTab(
          settings: _settings(periodTrackingEnabled: true),
          onSave: (draft) => saved = draft,
          onStartPregnancyMode: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('启用经期记录'));
    await tester.pump();

    expect(saved?.periodTrackingEnabled, isFalse);
  });

  testWidgets(
    'HealthTodayTab hides period quick action when period recording is disabled',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: HealthTodayTab(
            snapshot: _snapshot(
              settings: _settings(periodTrackingEnabled: false),
            ),
            onEditDailyLog: () {},
          ),
        ),
      );

      expect(find.text('开始经期'), findsNothing);
      expect(find.text('经量'), findsWidgets);
    },
  );

  testWidgets(
    'HealthCalendarTab hides period markers when period recording is disabled',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: HealthCalendarTab(
            focusedDay: DateTime.utc(2026, 7, 18),
            selectedDay: DateTime.utc(2026, 7, 18),
            periodTrackingEnabled: false,
            markers: [
              HealthCalendarMarker(
                date: DateTime.utc(2026, 7, 18),
                kind: HealthCalendarMarkerKind.actualPeriod,
                label: '经期',
              ),
              HealthCalendarMarker(
                date: DateTime.utc(2026, 7, 18),
                kind: HealthCalendarMarkerKind.dailyLog,
                label: '日记录',
              ),
            ],
            onDaySelected: (_, _) {},
            onQuickAction: (_) {},
            onEditDailyLog: () {},
          ),
        ),
      );

      expect(find.text('经期'), findsNothing);
      expect(find.text('日记录'), findsWidgets);
    },
  );
  testWidgets('HealthTrendsTab renders one-page dashboard sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: HealthTrendsTab(
          summary: _trendSummary(),
          selectedPhase: HealthTrendPhase.all,
          selectedStartDate: null,
          onPhaseChanged: (_) {},
          onStartDateChanged: (_) {},
        ),
      ),
    );

    expect(find.text('筛选范围'), findsOneWidget);
    expect(find.text('默认最近 3 个周期'), findsOneWidget);
    expect(find.text('周期长度'), findsWidgets);
    expect(find.text('经期时长'), findsWidgets);
    expect(find.text('周期对比'), findsOneWidget);
    expect(find.text('经量趋势'), findsOneWidget);
    expect(find.text('情绪分布'), findsOneWidget);
    expect(find.text('症状分析'), findsOneWidget);
    expect(find.text('健康指标'), findsOneWidget);
    expect(find.text('运动分析'), findsOneWidget);
    expect(find.text('经前记录'), findsOneWidget);
    expect(find.text('数据完整度'), findsOneWidget);
    expect(find.text('记录覆盖'), findsWidgets);
  });

  testWidgets(
    'HealthTrendsTab hides period sections when tracking is disabled',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: HealthTrendsTab(
            summary: _trendSummary(periodTrackingEnabled: false),
            selectedPhase: HealthTrendPhase.nonPeriod,
            selectedStartDate: DateTime.utc(2026, 6, 1),
            onPhaseChanged: (_) {},
            onStartDateChanged: (_) {},
          ),
        ),
      );

      expect(find.text('周期长度'), findsNothing);
      expect(find.text('经期时长'), findsNothing);
      expect(find.text('周期对比'), findsNothing);
      expect(find.text('经量趋势'), findsNothing);
      expect(find.text('经前记录'), findsNothing);
      expect(find.text('情绪分布'), findsOneWidget);
      expect(find.text('症状分析'), findsOneWidget);
      expect(find.text('健康指标'), findsOneWidget);
      expect(find.text('运动分析'), findsOneWidget);
      expect(find.text('数据完整度'), findsOneWidget);
      expect(find.text('从 6月1日 开始'), findsOneWidget);
    },
  );

  testWidgets(
    'HealthSettingsTab exposes three reminder toggles and pregnancy mode entry',
    (tester) async {
      await tester.pumpWidget(
        _TestApp(
          child: HealthSettingsTab(
            settings: _settings(),
            onSave: (_) {},
            onStartPregnancyMode: (_) {},
          ),
        ),
      );

      expect(find.text('经期提醒'), findsOneWidget);
      expect(find.text('排卵提醒'), findsOneWidget);
      expect(find.text('经前提醒'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('孕期模式'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('孕期模式'), findsOneWidget);
    },
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(body: child),
    );
  }
}

HealthPeriodSettingsModel _settings({bool periodTrackingEnabled = true}) {
  return HealthPeriodSettingsModel(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    periodTrackingEnabled: periodTrackingEnabled,
    periodReminderEnabled: true,
    ovulationReminderEnabled: true,
    pmsReminderEnabled: true,
    reminderDays: 1,
    dataSyncEnabled: true,
    analyticsEnabled: false,
  );
}

HealthTodaySnapshot _snapshot({
  DateTime? date,
  HealthPeriodSettingsModel? settings,
}) {
  final snapshotDate = date ?? DateTime.utc(2026, 7, 18);
  return HealthTodaySnapshot(
    date: snapshotDate,
    settings: settings ?? _settings(),
    prediction: HealthCyclePrediction.cycleDay(
      basis: HealthPredictionBasis.history,
      mainStatus: '周期第 20 天 · 预计 10 天后开始经期',
      currentCycleDay: 20,
      nextPeriodStart: DateTime.utc(2026, 7, 28),
      nextPeriodEnd: DateTime.utc(2026, 8, 1),
      fertileWindowStart: DateTime.utc(2026, 7, 12),
      fertileWindowEnd: DateTime.utc(2026, 7, 17),
      pmsStart: DateTime.utc(2026, 7, 21),
      pmsEnd: DateTime.utc(2026, 7, 27),
    ),
    activePeriod: null,
    dailyLog: HealthDailyLog(
      id: 'daily_1',
      date: snapshotDate,
      periodRecordId: null,
      flowLevel: HealthFlowLevel.medium,
      symptoms: const [],
      mood: HealthMood.calm,
      exerciseIntensity: null,
      sexualActivity: true,
      contraceptionMethod: HealthContraceptionMethod.condom,
      ovulationTest: null,
      medications: const [],
      diet: null,
      waterIntake: null,
      sleepMinutes: null,
      weightGrams: null,
      temperatureCelsiusTenths: null,
      stressLevel: null,
      calories: null,
      notes: null,
    ),
    activePregnancy: null,
  );
}

HealthTrendSummary _trendSummary({bool periodTrackingEnabled = true}) {
  return HealthTrendSummary(
    cycleLengths: periodTrackingEnabled ? const [27, 29] : const [],
    periodDurations: periodTrackingEnabled ? const [5, 4] : const [],
    recentPeriods: periodTrackingEnabled
        ? [
            HealthPeriodRecordModel(
              id: 'period_1',
              startDate: DateTime.utc(2026, 7, 1),
              endDate: DateTime.utc(2026, 7, 5),
              notes: null,
            ),
          ]
        : const [],
    loggedDaysInLast30Days: 4,
    predictionBasis: HealthPredictionBasis.history,
    query: const HealthTrendQuery(),
    periodTrackingEnabled: periodTrackingEnabled,
    rangeStart: DateTime.utc(2026, 7, 1),
    rangeEnd: DateTime.utc(2026, 7, 5),
    cycleLengthSeries: periodTrackingEnabled
        ? [
            HealthTrendPoint(
              date: DateTime.utc(2026, 7, 1),
              value: 29,
              label: '7月1日',
            ),
          ]
        : const [],
    periodDurationSeries: periodTrackingEnabled
        ? [
            HealthTrendPoint(
              date: DateTime.utc(2026, 7, 1),
              value: 5,
              label: '7月1日',
            ),
          ]
        : const [],
    flowDistribution: periodTrackingEnabled
        ? const [HealthTrendBucket(value: HealthFlowLevel.medium, count: 2)]
        : const [],
    moodDistribution: const [
      HealthTrendBucket(value: HealthMood.calm, count: 3),
    ],
    symptomDistribution: const [
      HealthTrendBucket(value: HealthSymptomType.cramps, count: 2),
    ],
    exerciseDistribution: const [
      HealthTrendBucket(value: HealthExerciseIntensity.light, count: 1),
    ],
    healthMetrics: const HealthTrendMetricAverages(
      loggedDays: 4,
      averageSleepMinutes: 420,
      averageWaterIntake: 1600,
      averageWeightGrams: 56000,
      averageTemperatureCelsiusTenths: 365,
      averageStressLevel: 3,
      averageCalories: 1800,
    ),
    pmsSymptomDistribution: periodTrackingEnabled
        ? const [HealthTrendBucket(value: HealthSymptomType.headache, count: 1)]
        : const [],
    completeness: const HealthTrendCompleteness(
      expectedDays: 5,
      loggedDays: 4,
      moodDays: 3,
      symptomDays: 2,
      metricDays: 4,
    ),
  );
}
