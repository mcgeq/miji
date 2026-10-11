import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_calendar_tab.dart';
import 'package:miji/features/health/presentation/health_daily_log_sheet.dart';
import 'package:miji/features/health/presentation/health_dialog_shell.dart';
import 'package:miji/features/health/presentation/health_log_grid.dart';
import 'package:miji/features/health/presentation/health_month_grid.dart';
import 'package:miji/features/health/presentation/health_settings_tab.dart';
import 'package:miji/features/health/presentation/health_today_tab.dart';
import 'package:miji/features/health/presentation/health_trends_tab.dart';

void main() {
  testWidgets('HealthTodayTab shows cycle hero and today records', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: HealthTodayTab(snapshot: _snapshot(), onEditDailyLog: () {}),
      ),
    );

    // 周期 Hero：当前周期第 20 天。
    expect(find.text('当前周期第 20 天'), findsOneWidget);
    // 快速记录磁贴。
    expect(find.byType(HealthLogGrid), findsOneWidget);
    // 今日记录计数（只在标题出现一次）。
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

  testWidgets('HealthTodayTab hides period tile when tracking is disabled', (
    tester,
  ) async {
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

    // 磁贴现在只显示图标，标签走 Tooltip / Semantics。
    expect(find.byTooltip('经期'), findsNothing);
    expect(find.byTooltip('经量'), findsOneWidget);
    expect(find.text('经量'), findsNothing);
  });

  testWidgets(
    'HealthDailyLogSheet renders its fields inside the dialog scroll host',
    (tester) async {
      // 弹窗由 AppDialogKeyboardScroll 提供滚动，记录表本身不能再嵌套一个
      // ListView，否则会拿到无界高度，导致整个弹窗布局失败、内容空白。
      await tester.pumpWidget(
        _TestApp(
          child: Scaffold(
            body: SingleChildScrollView(
              child: HealthDailyLogSheet(
                initialDate: DateTime.utc(2026, 7, 18),
                initialLog: HealthDailyLog.empty(DateTime.utc(2026, 7, 18)),
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('经量'), findsWidgets);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('睡眠'), findsOneWidget);
      expect(find.text('备注'), findsOneWidget);
      expect(find.text('私密生殖健康'), findsOneWidget);
      // 折叠区未展开时不显示排卵试纸。
      expect(find.text('排卵试纸'), findsNothing);
    },
  );

  testWidgets('HealthDailyLogSheet round-trips an existing log', (
    tester,
  ) async {
    final existing = _log();
    await tester.pumpWidget(
      _TestApp(
        child: Scaffold(
          body: SingleChildScrollView(
            child: HealthDailyLogSheet(
              initialDate: existing.date,
              initialLog: existing,
              onSave: (_) {},
            ),
          ),
        ),
      ),
    );

    // 已记录的经量与情绪应回填为选中态。
    expect(find.text('中量'), findsOneWidget);
    expect(find.text('平静'), findsOneWidget);
  });

  testWidgets('HealthCalendarTab renders the month grid', (tester) async {
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

    expect(find.byType(HealthMonthGrid), findsOneWidget);
    expect(find.text('18'), findsWidgets);
  });

  testWidgets('HealthCalendarTab hides period legend when tracking is off', (
    tester,
  ) async {
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

    // 图例与标记文案都不出现，但网格仍在。
    expect(find.text('预计经期'), findsNothing);
    expect(find.byType(HealthMonthGrid), findsOneWidget);
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
    'HealthSettingsTab exposes three reminder toggles and pregnancy entry',
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
      // 之前被隐藏回写的两个字段现在要显式出现。
      await tester.scrollUntilVisible(
        find.text('参与健康数据同步'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('参与健康数据同步'), findsOneWidget);
      expect(find.text('匿名使用统计'), findsOneWidget);
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

  testWidgets('record sheet dialog renders content on phone and desktop', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> openAndVerify(Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showAppResponsiveDialog<void>(
                    context: context,
                    builder: (ctx) => HealthEntryDialog(
                      icon: Icons.edit_note_rounded,
                      title: '每日记录',
                      onSave: () {},
                      child: HealthDailyLogSheet(
                        initialDate: DateTime.utc(2026, 7, 18),
                        initialLog: HealthDailyLog.empty(
                          DateTime.utc(2026, 7, 18),
                        ),
                        onSave: (_) {},
                      ),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // 修复前这里嵌套了 ListView，列表拿到无界高度，弹窗整块空白。
      expect(find.text('经量'), findsWidgets);
      expect(find.text('情绪'), findsOneWidget);
      expect(find.text('私密生殖健康'), findsOneWidget);

      await tester.tap(find.byTooltip('取消'));
      await tester.pumpAndSettle();
    }

    await openAndVerify(const Size(400, 820));
    await openAndVerify(const Size(1000, 820));
  });
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

HealthDailyLog _log() {
  return HealthDailyLog(
    id: 'daily_1',
    date: DateTime.utc(2026, 7, 18),
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
      daysUntilNextPeriod: 10,
      nextPeriodStart: DateTime.utc(2026, 7, 28),
      nextPeriodEnd: DateTime.utc(2026, 8, 1),
      fertileWindowStart: DateTime.utc(2026, 7, 12),
      fertileWindowEnd: DateTime.utc(2026, 7, 17),
      pmsStart: DateTime.utc(2026, 7, 21),
      pmsEnd: DateTime.utc(2026, 7, 27),
    ),
    activePeriod: null,
    dailyLog: _log(),
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
