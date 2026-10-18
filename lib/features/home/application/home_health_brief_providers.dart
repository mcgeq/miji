import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';

enum HomeHealthMetricKind { mood, sleep, water, weight }

class HomeHealthMetric {
  const HomeHealthMetric({
    required this.kind,
    required this.emoji,
    required this.label,
    required this.value,
    required this.logged,
  });

  final HomeHealthMetricKind kind;
  final String emoji;
  final String label;
  final String value;
  final bool logged;
}

class HomeHealthBrief {
  const HomeHealthBrief({
    required this.trackingEnabled,
    required this.isPregnancy,
    required this.headline,
    required this.subline,
    required this.phaseLabel,
    required this.ringRatio,
    required this.ringDay,
    required this.ringTotal,
    required this.todayMetrics,
  });

  final bool trackingEnabled;
  final bool isPregnancy;
  final String headline;
  final String subline;
  final String phaseLabel;
  final double ringRatio;
  final int ringDay;
  final int ringTotal;
  final List<HomeHealthMetric> todayMetrics;
}

final homeHealthBriefProvider = FutureProvider<HomeHealthBrief?>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }
  final snapshot = await ref.watch(
    currentUserHealthTodaySnapshotProvider.future,
  );
  if (snapshot == null) {
    return null;
  }
  return buildHomeHealthBrief(snapshot: snapshot);
});

HomeHealthBrief buildHomeHealthBrief({required HealthTodaySnapshot snapshot}) {
  final prediction = snapshot.prediction;
  final settings = snapshot.settings;
  final isPregnancy = prediction.statusKind == HealthTodayStatusKind.pregnancy;

  final progress = healthCycleProgressFor(prediction, settings);
  final phase = prediction.phaseOn(snapshot.date);

  final headline = switch (prediction.statusKind) {
    HealthTodayStatusKind.pregnancy => '孕期第 ${prediction.pregnancyWeek} 周',
    HealthTodayStatusKind.periodDay => '经期第 ${prediction.currentPeriodDay} 天',
    HealthTodayStatusKind.cycleDay =>
      prediction.isOverdue
          ? '经期已推迟 ${prediction.daysUntilNextPeriod!.abs()} 天'
          : '距下次经期还有 ${prediction.daysUntilNextPeriod} 天',
    HealthTodayStatusKind.noPeriodHistory => '还没有周期记录',
  };

  final subline = switch (prediction.statusKind) {
    HealthTodayStatusKind.pregnancy =>
      snapshot.activePregnancy?.dueDate == null
          ? '孕期模式进行中'
          : '预产期 ${_monthDay(snapshot.activePregnancy!.dueDate!)}',
    HealthTodayStatusKind.periodDay => '本次经期进行中',
    HealthTodayStatusKind.cycleDay =>
      prediction.nextPeriodStart == null
          ? ''
          : '${_monthDay(prediction.nextPeriodStart!)} 预计开始',
    HealthTodayStatusKind.noPeriodHistory => '记录一次经期即可开始预测',
  };

  return HomeHealthBrief(
    trackingEnabled: settings.periodTrackingEnabled,
    isPregnancy: isPregnancy,
    headline: headline,
    subline: subline,
    phaseLabel: _phaseLabel(phase),
    ringRatio: progress?.ratio ?? 0,
    ringDay: progress?.day ?? 0,
    ringTotal: progress?.total ?? settings.averageCycleLength,
    todayMetrics: _todayMetrics(snapshot.dailyLog),
  );
}

List<HomeHealthMetric> _todayMetrics(HealthDailyLog log) {
  return [
    HomeHealthMetric(
      kind: HomeHealthMetricKind.mood,
      emoji: '🙂',
      label: '心情',
      value: log.mood == null ? '+' : _moodLabel(log.mood!),
      logged: log.mood != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.sleep,
      emoji: '😴',
      label: '睡眠',
      value: log.sleepMinutes == null ? '+' : _duration(log.sleepMinutes!),
      logged: log.sleepMinutes != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.water,
      emoji: '💧',
      label: '饮水',
      value: log.waterIntake == null ? '+' : '${log.waterIntake}ml',
      logged: log.waterIntake != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.weight,
      emoji: '⚖️',
      label: '体重',
      value: log.weightGrams == null
          ? '+'
          : '${(log.weightGrams! / 1000).toStringAsFixed(1)}kg',
      logged: log.weightGrams != null,
    ),
  ];
}

String _phaseLabel(HealthCyclePhase phase) => switch (phase) {
  HealthCyclePhase.period => '经期',
  HealthCyclePhase.follicular => '卵泡期',
  HealthCyclePhase.fertile => '易孕期',
  HealthCyclePhase.luteal => '黄体期',
  HealthCyclePhase.pms => '经前期',
  HealthCyclePhase.pregnancy => '孕期',
  HealthCyclePhase.none => '',
};

String _duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}m';
}

String _monthDay(DateTime date) => '${date.month}月${date.day}日';

String _moodLabel(HealthMood mood) => switch (mood) {
  HealthMood.happy => '开心',
  HealthMood.sad => '难过',
  HealthMood.angry => '生气',
  HealthMood.anxious => '焦虑',
  HealthMood.calm => '平静',
  HealthMood.irritable => '烦躁',
};
