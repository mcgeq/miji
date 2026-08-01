import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart';
import 'package:miji/features/health/presentation/health_trend_charts.dart';
import 'package:miji/features/health/presentation/health_trend_sections.dart';

class HealthTrendsTab extends StatelessWidget {
  const HealthTrendsTab({
    required this.summary,
    required this.selectedPhase,
    required this.selectedStartDate,
    required this.onPhaseChanged,
    required this.onStartDateChanged,
    super.key,
  });

  final HealthTrendSummary summary;
  final HealthTrendPhase selectedPhase;
  final DateTime? selectedStartDate;
  final ValueChanged<HealthTrendPhase> onPhaseChanged;
  final ValueChanged<DateTime?> onStartDateChanged;

  @override
  Widget build(BuildContext context) {
    final periodTrackingEnabled = summary.periodTrackingEnabled;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TrendFilters(
            selectedPhase: selectedPhase,
            selectedStartDate: selectedStartDate,
            onPhaseChanged: onPhaseChanged,
            onStartDateChanged: onStartDateChanged,
          ),
          const SizedBox(height: 12),
          if (periodTrackingEnabled) ...[
            HealthTrendSection(
              title: '周期长度',
              icon: Icons.timeline_rounded,
              subtitle: '基于最近记录',
              child: HealthTrendLineChart(
                points: summary.cycleLengthSeries,
                emptyLabel: '暂无可统计记录',
              ),
            ),
            const SizedBox(height: 12),
            HealthTrendSection(
              title: '经期时长',
              icon: Icons.calendar_view_week_rounded,
              subtitle: '按已结束经期统计',
              child: HealthTrendLineChart(
                points: summary.periodDurationSeries,
                emptyLabel: '暂无可统计记录',
              ),
            ),
            const SizedBox(height: 12),
            HealthTrendSection(
              title: '周期对比',
              icon: Icons.compare_arrows_rounded,
              child: _CycleComparisonRows(
                cycleLengths: summary.cycleLengths,
                periodDurations: summary.periodDurations,
              ),
            ),
            const SizedBox(height: 12),
            HealthTrendSection(
              title: '经量趋势',
              icon: Icons.water_drop_outlined,
              child: HealthTrendBucketBars<HealthFlowLevel>(
                buckets: summary.flowDistribution,
                labelFor: healthFlowLabel,
                emptyLabel: '暂无可统计记录',
              ),
            ),
            const SizedBox(height: 12),
          ],
          HealthTrendSection(
            title: '情绪分布',
            icon: Icons.mood_outlined,
            child: HealthTrendBucketBars<HealthMood>(
              buckets: summary.moodDistribution,
              labelFor: healthMoodLabel,
              emptyLabel: '暂无可统计记录',
            ),
          ),
          const SizedBox(height: 12),
          HealthTrendSection(
            title: '症状分析',
            icon: Icons.healing_outlined,
            child: HealthTrendBucketBars<HealthSymptomType>(
              buckets: summary.symptomDistribution,
              labelFor: healthSymptomTypeLabel,
              emptyLabel: '暂无可统计记录',
            ),
          ),
          const SizedBox(height: 12),
          HealthTrendSection(
            title: '健康指标',
            icon: Icons.monitor_heart_outlined,
            child: _HealthMetricsRows(metrics: summary.healthMetrics),
          ),
          const SizedBox(height: 12),
          HealthTrendSection(
            title: '运动分析',
            icon: Icons.directions_run_rounded,
            child: HealthTrendBucketBars<HealthExerciseIntensity>(
              buckets: summary.exerciseDistribution,
              labelFor: _exerciseIntensityLabel,
              emptyLabel: '暂无可统计记录',
            ),
          ),
          const SizedBox(height: 12),
          if (periodTrackingEnabled) ...[
            HealthTrendSection(
              title: '经前记录',
              icon: Icons.event_note_outlined,
              child: HealthTrendBucketBars<HealthSymptomType>(
                buckets: summary.pmsSymptomDistribution,
                labelFor: healthSymptomTypeLabel,
                emptyLabel: '暂无可统计记录',
              ),
            ),
            const SizedBox(height: 12),
          ],
          HealthTrendSection(
            title: '数据完整度',
            icon: Icons.fact_check_outlined,
            subtitle: '记录覆盖',
            child: _CompletenessRows(completeness: summary.completeness),
          ),
        ],
      ),
    );
  }
}

class _TrendFilters extends StatelessWidget {
  const _TrendFilters({
    required this.selectedPhase,
    required this.selectedStartDate,
    required this.onPhaseChanged,
    required this.onStartDateChanged,
  });

  final HealthTrendPhase selectedPhase;
  final DateTime? selectedStartDate;
  final ValueChanged<HealthTrendPhase> onPhaseChanged;
  final ValueChanged<DateTime?> onStartDateChanged;

  @override
  Widget build(BuildContext context) {
    return HealthTrendSection(
      title: '筛选范围',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final phase in HealthTrendPhase.values)
                ChoiceChip(
                  label: Text(_phaseLabel(phase)),
                  selected: selectedPhase == phase,
                  onSelected: (_) => onPhaseChanged(phase),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedStartDate ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: now,
                    );
                    if (picked != null) {
                      onStartDateChanged(
                        DateTime.utc(picked.year, picked.month, picked.day),
                      );
                    }
                  },
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    selectedStartDate == null
                        ? '默认最近 3 个周期'
                        : '从 ${healthMonthDayLabel(selectedStartDate!)} 开始',
                  ),
                ),
              ),
              if (selectedStartDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '清除起始日期',
                  onPressed: () => onStartDateChanged(null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CycleComparisonRows extends StatelessWidget {
  const _CycleComparisonRows({
    required this.cycleLengths,
    required this.periodDurations,
  });

  final List<int> cycleLengths;
  final List<int> periodDurations;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HealthTrendMetricRow(
          label: '周期长度',
          value: _daysAverageLabel(cycleLengths),
        ),
        HealthTrendMetricRow(
          label: '经期时长',
          value: _daysAverageLabel(periodDurations),
        ),
      ],
    );
  }
}

class _HealthMetricsRows extends StatelessWidget {
  const _HealthMetricsRows({required this.metrics});

  final HealthTrendMetricAverages metrics;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HealthTrendMetricRow(label: '记录天数', value: '${metrics.loggedDays} 天'),
        HealthTrendMetricRow(
          label: '睡眠',
          value: _minutesLabel(metrics.averageSleepMinutes),
        ),
        HealthTrendMetricRow(
          label: '饮水',
          value: _millilitersLabel(metrics.averageWaterIntake),
        ),
        HealthTrendMetricRow(
          label: '体重',
          value: _gramsLabel(metrics.averageWeightGrams),
        ),
        HealthTrendMetricRow(
          label: '体温',
          value: _tenthsCelsiusLabel(metrics.averageTemperatureCelsiusTenths),
        ),
        HealthTrendMetricRow(
          label: '压力',
          value: _plainNumberLabel(metrics.averageStressLevel),
        ),
        HealthTrendMetricRow(
          label: '热量',
          value: _caloriesLabel(metrics.averageCalories),
        ),
      ],
    );
  }
}

class _CompletenessRows extends StatelessWidget {
  const _CompletenessRows({required this.completeness});

  final HealthTrendCompleteness completeness;

  @override
  Widget build(BuildContext context) {
    final coverage = completeness.coverageRatio.clamp(0, 1).toDouble();
    final percent = (coverage * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: coverage),
        const SizedBox(height: 10),
        HealthTrendMetricRow(label: '记录覆盖', value: '$percent%'),
        HealthTrendMetricRow(
          label: '应记录天数',
          value: '${completeness.expectedDays} 天',
        ),
        HealthTrendMetricRow(
          label: '已记录天数',
          value: '${completeness.loggedDays} 天',
        ),
        HealthTrendMetricRow(
          label: '情绪记录',
          value: '${completeness.moodDays} 天',
        ),
        HealthTrendMetricRow(
          label: '症状记录',
          value: '${completeness.symptomDays} 天',
        ),
        HealthTrendMetricRow(
          label: '指标记录',
          value: '${completeness.metricDays} 天',
        ),
      ],
    );
  }
}

String _phaseLabel(HealthTrendPhase phase) {
  return switch (phase) {
    HealthTrendPhase.all => '全部',
    HealthTrendPhase.period => '经期',
    HealthTrendPhase.pms => '经前',
    HealthTrendPhase.fertileWindow => '易孕期',
    HealthTrendPhase.nonPeriod => '非经期',
  };
}

String _exerciseIntensityLabel(HealthExerciseIntensity value) {
  return switch (value) {
    HealthExerciseIntensity.none => '未运动',
    HealthExerciseIntensity.light => '轻度',
    HealthExerciseIntensity.medium => '中度',
    HealthExerciseIntensity.heavy => '高强度',
  };
}

String _daysAverageLabel(List<int> values) {
  if (values.isEmpty) {
    return '暂无可统计记录';
  }
  final total = values.fold<int>(0, (sum, value) => sum + value);
  return '${(total / values.length).round()} 天';
}

String _minutesLabel(int? value) {
  if (value == null) return '暂无可统计记录';
  final hours = value ~/ 60;
  final minutes = value % 60;
  return '$hours小时$minutes分钟';
}

String _millilitersLabel(int? value) {
  return value == null ? '暂无可统计记录' : '$value ml';
}

String _gramsLabel(int? value) {
  return value == null ? '暂无可统计记录' : '${(value / 1000).toStringAsFixed(1)} kg';
}

String _tenthsCelsiusLabel(int? value) {
  return value == null ? '暂无可统计记录' : '${(value / 10).toStringAsFixed(1)}℃';
}

String _plainNumberLabel(int? value) {
  return value == null ? '暂无可统计记录' : '$value';
}

String _caloriesLabel(int? value) {
  return value == null ? '暂无可统计记录' : '$value kcal';
}
