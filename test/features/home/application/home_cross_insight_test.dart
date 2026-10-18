import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/home/application/home_cross_insight_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

HealthTrendSummary trend({
  int? sleep,
  int? weight,
  int loggedDays = 5,
  bool tracking = true,
}) {
  return HealthTrendSummary(
    cycleLengths: const [],
    periodDurations: const [],
    recentPeriods: const [],
    loggedDaysInLast30Days: loggedDays,
    predictionBasis: HealthPredictionBasis.history,
    query: const HealthTrendQuery(),
    periodTrackingEnabled: tracking,
    rangeStart: DateTime.utc(2026, 10, 6),
    rangeEnd: DateTime.utc(2026, 10, 12),
    cycleLengthSeries: const [],
    periodDurationSeries: const [],
    flowDistribution: const [],
    moodDistribution: const [],
    symptomDistribution: const [],
    exerciseDistribution: const [],
    healthMetrics: HealthTrendMetricAverages(
      loggedDays: loggedDays,
      averageSleepMinutes: sleep,
      averageWeightGrams: weight,
    ),
    pmsSymptomDistribution: const [],
    completeness: const HealthTrendCompleteness(
      expectedDays: 7,
      loggedDays: 5,
      moodDays: 5,
      symptomDays: 0,
      metricDays: 5,
    ),
  );
}

void main() {
  group('action insights', () {
    test('completion rate', () {
      final items = buildActionInsights(
        const TodoStatsSummary(
          plannedCount: 10,
          completedPlannedCount: 8,
          completionRate: 0.8,
        ),
      );
      expect(items.single.kind, HomeInsightKind.actionCompletion);
      expect(items.single.plainText, contains('80%'));
      expect(items.single.target, HomeInsightTarget.gtd);
      expect(items.single.tone, HomeInsightTone.positive);
    });

    test('flags overdue tasks', () {
      final items = buildActionInsights(
        const TodoStatsSummary(overdueCount: 3),
      );
      expect(items.any((i) => i.kind == HomeInsightKind.actionOverdue), isTrue);
    });

    test('empty without stats', () {
      expect(buildActionInsights(null), isEmpty);
    });
  });

  group('health insights', () {
    test('sleep insight when enough data', () {
      final items = buildHealthInsights(trend(sleep: 400));
      expect(items.single.kind, HomeInsightKind.healthSleep);
      expect(items.single.plainText, contains('6h40m'));
      expect(items.single.tone, HomeInsightTone.warning);
      expect(items.single.target, HomeInsightTarget.health);
    });

    test('weight insight', () {
      final items = buildHealthInsights(trend(weight: 52400));
      expect(items.single.plainText, contains('52.4kg'));
    });

    test('empty when too few logged days', () {
      expect(buildHealthInsights(trend(sleep: 400, loggedDays: 1)), isEmpty);
    });

    test('empty when tracking off or null', () {
      expect(buildHealthInsights(null), isEmpty);
      expect(buildHealthInsights(trend(sleep: 400, tracking: false)), isEmpty);
    });
  });
}
