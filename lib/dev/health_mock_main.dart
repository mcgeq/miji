import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/presentation/health_calendar_tab.dart';
import 'package:miji/features/health/presentation/health_settings_tab.dart';
import 'package:miji/features/health/presentation/health_today_tab.dart';
import 'package:miji/features/health/presentation/health_trends_tab.dart';

void main() {
  runApp(const HealthMockApp());
}

class HealthMockApp extends StatelessWidget {
  const HealthMockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '经期 Mock 数据预览',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const Scaffold(appBar: _HealthMockAppBar(), body: HealthMockHome()),
    );
  }
}

class HealthMockHome extends StatefulWidget {
  const HealthMockHome({super.key});

  @override
  State<HealthMockHome> createState() => _HealthMockHomeState();
}

enum _HealthMockPanel { today, calendar, trends, settings }

class _HealthMockHomeState extends State<HealthMockHome> {
  static final _mockToday = DateTime.utc(2026, 7, 18);

  var _selectedPanel = _HealthMockPanel.calendar;
  var _focusedDay = _mockToday;
  var _selectedDay = _mockToday;
  var _selectedPhase = HealthTrendPhase.all;
  DateTime? _selectedStartDate;
  HealthPeriodRecordModel? _activePeriod;
  HealthPregnancyStatus? _activePregnancy;

  var _settings = const HealthPeriodSettingsModel(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    periodTrackingEnabled: true,
    periodReminderEnabled: true,
    ovulationReminderEnabled: true,
    pmsReminderEnabled: true,
    reminderDays: 2,
    dataSyncEnabled: false,
    analyticsEnabled: false,
  );

  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      maxWidth: 760,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: AppSlidingSegmentedControl<_HealthMockPanel>(
              minSegmentWidth: 76,
              value: _selectedPanel,
              segments: const [
                AppSlidingSegment(
                  value: _HealthMockPanel.today,
                  icon: Icons.today_rounded,
                  label: '今日',
                ),
                AppSlidingSegment(
                  value: _HealthMockPanel.calendar,
                  icon: Icons.calendar_month_rounded,
                  label: '日历',
                ),
                AppSlidingSegment(
                  value: _HealthMockPanel.trends,
                  icon: Icons.insights_rounded,
                  label: '趋势',
                ),
                AppSlidingSegment(
                  value: _HealthMockPanel.settings,
                  icon: Icons.tune_rounded,
                  label: '设置',
                ),
              ],
              onChanged: (panel) {
                setState(() => _selectedPanel = panel);
              },
            ),
          ),
          const SizedBox(height: 18),
          Expanded(child: _buildSelectedPanel()),
        ],
      ),
    );
  }

  Widget _buildSelectedPanel() {
    return switch (_selectedPanel) {
      _HealthMockPanel.today => HealthTodayTab(
        snapshot: _todaySnapshot(),
        periodTrackingEnabled: _settings.periodTrackingEnabled,
        onEditDailyLog: () => _showMemoryOnlyNotice('每日记录'),
        onQuickAction: _handleQuickAction,
      ),
      _HealthMockPanel.calendar => HealthCalendarTab(
        focusedDay: _focusedDay,
        selectedDay: _selectedDay,
        markers: _calendarMarkers(),
        periodTrackingEnabled: _settings.periodTrackingEnabled,
        todaySnapshot: _todaySnapshot(),
        onPageChanged: (focusedDay) {
          setState(() => _focusedDay = focusedDay);
        },
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onQuickAction: _handleQuickAction,
        onEditDailyLog: () => _showMemoryOnlyNotice('每日记录'),
      ),
      _HealthMockPanel.trends => HealthTrendsTab(
        summary: _trendSummary(),
        selectedPhase: _selectedPhase,
        selectedStartDate: _selectedStartDate,
        onPhaseChanged: (phase) {
          setState(() => _selectedPhase = phase);
        },
        onStartDateChanged: (date) {
          setState(() => _selectedStartDate = date);
        },
      ),
      _HealthMockPanel.settings => HealthSettingsTab(
        settings: _settings,
        activePregnancy: _activePregnancy,
        onSave: (draft) {
          setState(() => _settings = draft);
          _showMemoryOnlyNotice('设置');
        },
        onStartPregnancyMode: (draft) {
          setState(() {
            _activePregnancy = HealthPregnancyStatus(
              id: 'mock_pregnancy',
              startDate: draft.startDate,
              dueDate: draft.dueDate,
              endDate: null,
              status: HealthPregnancyRecordStatus.active,
              notes: draft.notes,
            );
          });
          _showMemoryOnlyNotice('孕期模式');
        },
        onEndPregnancyMode: (draft) {
          setState(() => _activePregnancy = null);
          _showMemoryOnlyNotice('结束孕期模式');
        },
        onCancelPregnancyMode: () {
          setState(() => _activePregnancy = null);
          _showMemoryOnlyNotice('取消孕期模式');
        },
      ),
    };
  }

  void _handleQuickAction(HealthQuickAction action) {
    if (action == HealthQuickAction.period) {
      if (!_settings.periodTrackingEnabled) {
        return;
      }
      setState(() {
        _activePeriod = _activePeriod == null
            ? HealthPeriodRecordModel(
                id: 'mock_open_period',
                startDate: _selectedDay,
                endDate: null,
                notes: '仅用于预览',
              )
            : null;
      });
    }
    _showMemoryOnlyNotice(
      healthQuickActionLabel(action, _activePeriod != null),
    );
  }

  void _showMemoryOnlyNotice(String label) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text('$label 已在预览内响应，不会写入数据库')));
  }

  HealthTodaySnapshot _todaySnapshot() {
    return HealthTodaySnapshot(
      date: _mockToday,
      settings: _settings,
      prediction: _settings.periodTrackingEnabled
          ? HealthCyclePrediction.cycleDay(
              basis: HealthPredictionBasis.history,
              mainStatus: '周期第 20 天 · 预计 10 天后开始经期',
              currentCycleDay: 20,
              nextPeriodStart: DateTime.utc(2026, 7, 28),
              nextPeriodEnd: DateTime.utc(2026, 8, 1),
              fertileWindowStart: DateTime.utc(2026, 7, 12),
              fertileWindowEnd: DateTime.utc(2026, 7, 17),
              pmsStart: DateTime.utc(2026, 7, 21),
              pmsEnd: DateTime.utc(2026, 7, 27),
              indicators: const ['历史预测', '经前提醒已开', '易孕期已过'],
            )
          : const HealthCyclePrediction.noHistory(
              mainStatus: '经期记录已关闭 · 仅查看每日记录统计',
            ),
      activePeriod: _activePeriod,
      dailyLog: _dailyLog(_mockToday),
      activePregnancy: _activePregnancy,
    );
  }

  HealthDailyLog _dailyLog(DateTime date) {
    return HealthDailyLog(
      id: 'mock_daily_${HealthDate.dayKey(date)}',
      date: date,
      periodRecordId: _settings.periodTrackingEnabled ? 'mock_period_3' : null,
      flowLevel: _settings.periodTrackingEnabled
          ? HealthFlowLevel.medium
          : null,
      symptoms: const [
        HealthSymptomLog(
          id: 'mock_symptom_1',
          type: HealthSymptomType.cramps,
          intensity: HealthIntensity.medium,
          notes: '午后明显',
        ),
        HealthSymptomLog(
          id: 'mock_symptom_2',
          type: HealthSymptomType.fatigue,
          intensity: HealthIntensity.light,
          notes: null,
        ),
      ],
      mood: HealthMood.calm,
      exerciseIntensity: HealthExerciseIntensity.light,
      sexualActivity: null,
      contraceptionMethod: null,
      ovulationTest: HealthOvulationTestLog(
        id: 'mock_ovulation',
        testDate: date,
        result: HealthOvulationTestResult.negative,
        lineIntensity: HealthTestLineIntensity.low,
        notes: null,
      ),
      medications: [
        HealthMedicationLog(
          id: 'mock_medication',
          name: '布洛芬',
          dosage: '200mg',
          frequency: HealthMedicationFrequency.once,
          startDate: date,
          endDate: null,
          notes: '预览数据',
          periodRecordId: null,
        ),
      ],
      diet: '清淡饮食',
      waterIntake: 1600,
      sleepMinutes: 430,
      weightGrams: 56000,
      temperatureCelsiusTenths: 365,
      stressLevel: 3,
      calories: 1800,
      notes: '这是内存 mock 数据，不会保存。',
    );
  }

  List<HealthCalendarMarker> _calendarMarkers() {
    return [
      for (var day = 1; day <= 5; day += 1)
        HealthCalendarMarker(
          date: DateTime.utc(2026, 7, day),
          kind: HealthCalendarMarkerKind.actualPeriod,
          label: '经期',
        ),
      for (var day = 28; day <= 31; day += 1)
        HealthCalendarMarker(
          date: DateTime.utc(2026, 7, day),
          kind: HealthCalendarMarkerKind.predictedPeriod,
          label: '预计经期',
        ),
      HealthCalendarMarker(
        date: DateTime.utc(2026, 8, 1),
        kind: HealthCalendarMarkerKind.predictedPeriod,
        label: '预计经期',
      ),
      for (var day = 21; day <= 27; day += 1)
        HealthCalendarMarker(
          date: DateTime.utc(2026, 7, day),
          kind: HealthCalendarMarkerKind.pms,
          label: '经前综合征',
        ),
      for (var day = 12; day <= 17; day += 1)
        HealthCalendarMarker(
          date: DateTime.utc(2026, 7, day),
          kind: HealthCalendarMarkerKind.fertileWindow,
          label: '易孕期',
        ),
      HealthCalendarMarker(
        date: _mockToday,
        kind: HealthCalendarMarkerKind.dailyLog,
        label: '日记录',
      ),
      HealthCalendarMarker(
        date: _mockToday,
        kind: HealthCalendarMarkerKind.medication,
        label: '用药',
      ),
      HealthCalendarMarker(
        date: DateTime.utc(2026, 7, 14),
        kind: HealthCalendarMarkerKind.ovulationTest,
        label: '排卵试纸',
      ),
    ];
  }

  HealthTrendSummary _trendSummary() {
    final periodTrackingEnabled = _settings.periodTrackingEnabled;
    return HealthTrendSummary(
      cycleLengths: periodTrackingEnabled ? const [28, 29, 27] : const [],
      periodDurations: periodTrackingEnabled ? const [5, 5, 4] : const [],
      recentPeriods: periodTrackingEnabled ? _recentPeriods() : const [],
      loggedDaysInLast30Days: 18,
      predictionBasis: HealthPredictionBasis.history,
      query: HealthTrendQuery(
        startDate: _selectedStartDate,
        phase: _selectedPhase,
      ),
      periodTrackingEnabled: periodTrackingEnabled,
      rangeStart: _selectedStartDate ?? DateTime.utc(2026, 5, 5),
      rangeEnd: _mockToday,
      cycleLengthSeries: periodTrackingEnabled
          ? [
              HealthTrendPoint(
                date: DateTime.utc(2026, 5, 5),
                value: 28,
                label: '5月5日',
              ),
              HealthTrendPoint(
                date: DateTime.utc(2026, 6, 2),
                value: 29,
                label: '6月2日',
              ),
              HealthTrendPoint(
                date: DateTime.utc(2026, 7, 1),
                value: 27,
                label: '7月1日',
              ),
            ]
          : const [],
      periodDurationSeries: periodTrackingEnabled
          ? [
              HealthTrendPoint(
                date: DateTime.utc(2026, 5, 5),
                value: 5,
                label: '5月5日',
              ),
              HealthTrendPoint(
                date: DateTime.utc(2026, 6, 2),
                value: 5,
                label: '6月2日',
              ),
              HealthTrendPoint(
                date: DateTime.utc(2026, 7, 1),
                value: 4,
                label: '7月1日',
              ),
            ]
          : const [],
      flowDistribution: periodTrackingEnabled
          ? const [
              HealthTrendBucket(value: HealthFlowLevel.medium, count: 7),
              HealthTrendBucket(value: HealthFlowLevel.light, count: 4),
              HealthTrendBucket(value: HealthFlowLevel.heavy, count: 2),
            ]
          : const [],
      moodDistribution: const [
        HealthTrendBucket(value: HealthMood.calm, count: 8),
        HealthTrendBucket(value: HealthMood.anxious, count: 4),
        HealthTrendBucket(value: HealthMood.happy, count: 3),
      ],
      symptomDistribution: const [
        HealthTrendBucket(value: HealthSymptomType.cramps, count: 6),
        HealthTrendBucket(value: HealthSymptomType.fatigue, count: 5),
        HealthTrendBucket(value: HealthSymptomType.headache, count: 2),
      ],
      exerciseDistribution: const [
        HealthTrendBucket(value: HealthExerciseIntensity.light, count: 7),
        HealthTrendBucket(value: HealthExerciseIntensity.none, count: 4),
        HealthTrendBucket(value: HealthExerciseIntensity.medium, count: 3),
      ],
      healthMetrics: const HealthTrendMetricAverages(
        loggedDays: 18,
        averageSleepMinutes: 428,
        averageWaterIntake: 1550,
        averageWeightGrams: 56100,
        averageTemperatureCelsiusTenths: 365,
        averageStressLevel: 3,
        averageCalories: 1820,
      ),
      pmsSymptomDistribution: periodTrackingEnabled
          ? const [
              HealthTrendBucket(
                value: HealthSymptomType.breastTenderness,
                count: 3,
              ),
              HealthTrendBucket(value: HealthSymptomType.moodSwing, count: 2),
            ]
          : const [],
      completeness: const HealthTrendCompleteness(
        expectedDays: 45,
        loggedDays: 18,
        moodDays: 15,
        symptomDays: 11,
        metricDays: 14,
      ),
    );
  }

  List<HealthPeriodRecordModel> _recentPeriods() {
    return [
      HealthPeriodRecordModel(
        id: 'mock_period_1',
        startDate: DateTime.utc(2026, 5, 5),
        endDate: DateTime.utc(2026, 5, 9),
        notes: '第一个 mock 周期',
      ),
      HealthPeriodRecordModel(
        id: 'mock_period_2',
        startDate: DateTime.utc(2026, 6, 2),
        endDate: DateTime.utc(2026, 6, 6),
        notes: '第二个 mock 周期',
      ),
      HealthPeriodRecordModel(
        id: 'mock_period_3',
        startDate: DateTime.utc(2026, 7, 1),
        endDate: DateTime.utc(2026, 7, 4),
        notes: '最近一个 mock 周期',
      ),
    ];
  }
}

class _HealthMockAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HealthMockAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('经期 Mock 数据预览'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 16),
          child: Center(child: Text('内存数据')),
        ),
      ],
    );
  }
}
