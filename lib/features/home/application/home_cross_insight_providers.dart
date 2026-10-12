import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 跨模块洞察：在记账洞察之外补行动 / 健康两条线。
///
/// 现成的 [homeInsightProvider] 保持纯记账不变（它有独立测试）；这里只做合并、
/// 重排序与截断。
const _maxInsightItems = 4;

final homeCrossInsightProvider = FutureProvider<HomeInsight?>((ref) async {
  final money = await ref.watch(homeInsightProvider.future);
  final todoStats = await ref.watch(todoStatsSummaryProvider.future);
  final healthTrend = await ref.watch(
    currentUserHealthTrendSummaryProvider.future,
  );

  final items = <HomeInsightItem>[
    ...?money?.items,
    ...buildActionInsights(todoStats),
    ...buildHealthInsights(healthTrend),
  ];
  if (items.isEmpty) {
    return null;
  }
  final sorted = [...items]
    ..sort((a, b) => b.severity.compareTo(a.severity));
  return HomeInsight(items: sorted.take(_maxInsightItems).toList(growable: false));
});

List<HomeInsightItem> buildActionInsights(TodoStatsSummary? stats) {
  if (stats == null) {
    return const [];
  }
  final out = <HomeInsightItem>[];
  final rate = stats.completionRate;
  if (rate != null && stats.plannedCount > 0) {
    final percent = (rate * 100).round();
    out.add(
      HomeInsightItem(
        kind: HomeInsightKind.actionCompletion,
        tone: percent >= 80
            ? HomeInsightTone.positive
            : HomeInsightTone.neutral,
        target: HomeInsightTarget.gtd,
        actionLabel: '看待办',
        segments: [
          const HomeInsightSegment('本周完成率 '),
          HomeInsightSegment('$percent%', emphasis: true),
        ],
      ),
    );
  }
  if (stats.overdueCount > 0) {
    out.add(
      HomeInsightItem(
        kind: HomeInsightKind.actionOverdue,
        tone: HomeInsightTone.warning,
        target: HomeInsightTarget.gtd,
        actionLabel: '看待办',
        segments: [
          const HomeInsightSegment('还有 '),
          HomeInsightSegment('${stats.overdueCount} 个', emphasis: true),
          const HomeInsightSegment('任务逾期'),
        ],
      ),
    );
  }
  return out;
}

List<HomeInsightItem> buildHealthInsights(HealthTrendSummary? trend) {
  if (trend == null || !trend.periodTrackingEnabled) {
    return const [];
  }
  final metrics = trend.healthMetrics;
  // 记录天数太少时平均值没有意义，不展示。
  if (metrics.loggedDays < 3) {
    return const [];
  }

  final out = <HomeInsightItem>[];
  final sleep = metrics.averageSleepMinutes;
  if (sleep != null) {
    out.add(
      HomeInsightItem(
        kind: HomeInsightKind.healthSleep,
        tone: sleep < 420
            ? HomeInsightTone.warning
            : HomeInsightTone.neutral,
        target: HomeInsightTarget.health,
        actionLabel: '看健康',
        segments: [
          const HomeInsightSegment('最近睡眠平均 '),
          HomeInsightSegment(_formatDuration(sleep), emphasis: true),
        ],
      ),
    );
  }
  final weight = metrics.averageWeightGrams;
  if (weight != null) {
    out.add(
      HomeInsightItem(
        kind: HomeInsightKind.healthWeight,
        tone: HomeInsightTone.neutral,
        target: HomeInsightTarget.health,
        actionLabel: '看健康',
        segments: [
          const HomeInsightSegment('最近体重 '),
          HomeInsightSegment(
            '${(weight / 1000).toStringAsFixed(1)}kg',
            emphasis: true,
          ),
        ],
      ),
    );
  }
  return out;
}

String _formatDuration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}m';
}
