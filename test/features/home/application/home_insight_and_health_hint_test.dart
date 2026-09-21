import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/health/domain/health_models.dart';

HomeTodaySpendingSummary _today({
  int todayExpenseMinor = 0,
  int monthExpenseMinor = 0,
  int monthIncomeMinor = 0,
  int dailyAverageExpenseMinor = 0,
  int monthExpenseTransactionCount = 0,
}) {
  return HomeTodaySpendingSummary(
    currencyCode: 'CNY',
    todayExpenseMinor: todayExpenseMinor,
    todayIncomeMinor: 0,
    weekExpenseMinor: 0,
    monthExpenseMinor: monthExpenseMinor,
    monthIncomeMinor: monthIncomeMinor,
    monthExpenseTransactionCount: monthExpenseTransactionCount,
    todayTransactionCount: 0,
    dailyAverageExpenseMinor: dailyAverageExpenseMinor,
  );
}

HomeMonthBudgetSummary _budget({
  bool hasBudget = true,
  double progress = 0.5,
  String paceLabel = '节奏正常',
}) {
  return HomeMonthBudgetSummary(
    hasBudget: hasBudget,
    currencyCode: 'CNY',
    budgetId: hasBudget ? 'budget-1' : null,
    budgetName: hasBudget ? '本月预算' : null,
    totalMinor: 800000,
    usedMinor: (800000 * progress).round(),
    remainingMinor: 800000 - (800000 * progress).round(),
    progress: progress,
    periodProgress: 0.5,
    paceRatio: 1,
    paceLabel: paceLabel,
    remainingDays: 15,
  );
}

HomeCategorySpendingItem _category(String name, double ratio) {
  return HomeCategorySpendingItem(
    categoryId: name,
    categoryName: name,
    amountMinor: (1000000 * ratio).round(),
    currencyCode: 'CNY',
    ratio: ratio,
  );
}

void main() {
  group('buildHomeInsight', () {
    test('returns null when there is no data at all', () {
      final insight = buildHomeInsight(
        today: _today(),
        budget: _budget(hasBudget: false, progress: 0),
        categories: const [],
      );

      expect(insight, isNull);
    });

    test('renders each fact as its own item instead of one sentence', () {
      final insight = buildHomeInsight(
        today: _today(
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
          monthExpenseTransactionCount: 16,
        ),
        budget: _budget(progress: 1.05),
        categories: [_category('贷款还款', 0.47)],
        now: DateTime(2026, 9, 20, 20),
      );

      expect(insight, isNotNull);
      expect(insight!.items.length, 3);
      expect(insight.items.map((item) => item.plainText), [
        '本月预算已超支 ¥400.00',
        '贷款还款占本月支出 47%',
        '今天还没有支出记录',
      ]);
    });

    test('sorts by severity so the alert comes first', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 5800,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(progress: 1.05),
        categories: [_category('餐饮', 0.34)],
      );

      expect(insight!.items.first.kind, HomeInsightKind.budgetExceeded);
      expect(insight.items.first.tone, HomeInsightTone.danger);
      // 少花是好事，语气应为正向。
      final spending = insight.items.firstWhere(
        (item) => item.kind == HomeInsightKind.spendingVsAverage,
      );
      expect(spending.tone, HomeInsightTone.positive);
      expect(spending.plainText, contains('今天比日均少花'));
    });

    test('caps the number of items', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 5800,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(progress: 1.05),
        categories: [_category('餐饮', 0.34)],
      );

      expect(insight!.items.length, lessThanOrEqualTo(homeInsightMaxItems));
    });

    test('warns while the budget is still within the limit', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 5800,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(progress: 0.9, paceLabel: homeInsightFastPaceLabel),
        categories: const [],
      );

      final pace = insight!.items.firstWhere(
        (item) => item.kind == HomeInsightKind.budgetPace,
      );
      expect(pace.tone, HomeInsightTone.warning);
      expect(pace.segments.map((s) => s.text).join(), contains('花得比时间进度快'));
    });

    test('does not warn about pace when the budget is on track', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 5800,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(progress: 0.5),
        categories: const [],
      );

      expect(
        insight!.items.where((item) => item.kind == HomeInsightKind.budgetPace),
        isEmpty,
      );
    });

    test('omits low-share categories', () {
      final insight = buildHomeInsight(
        today: _today(todayExpenseMinor: 1000, monthExpenseMinor: 100000),
        budget: _budget(hasBudget: false, progress: 0),
        categories: [_category('餐饮', 0.12)],
      );

      expect(
        insight!.items.where(
          (item) => item.kind == HomeInsightKind.topCategory,
        ),
        isEmpty,
      );
    });

    test('attaches a jump target to actionable items only', () {
      final insight = buildHomeInsight(
        today: _today(
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(progress: 1.05),
        categories: [_category('贷款还款', 0.47)],
        now: DateTime(2026, 9, 20, 20),
      );

      final byKind = {for (final item in insight!.items) item.kind: item};
      expect(
        byKind[HomeInsightKind.budgetExceeded]!.target,
        HomeInsightTarget.budgets,
      );
      expect(byKind[HomeInsightKind.budgetExceeded]!.actionLabel, '看预算');
      expect(
        byKind[HomeInsightKind.topCategory]!.target,
        HomeInsightTarget.categories,
      );
      // 「今天还没记」只是提示，不该可点击。
      expect(byKind[HomeInsightKind.noSpendingToday]!.target, isNull);
    });

    test('only nudges about missing records after the evening cutoff', () {
      HomeInsight? build(int hour) {
        return buildHomeInsight(
          today: _today(
            monthExpenseMinor: 657900,
            dailyAverageExpenseMinor: 21200,
          ),
          budget: _budget(hasBudget: false, progress: 0),
          categories: const [],
          now: DateTime(2026, 9, 20, hour),
        );
      }

      bool hasHint(HomeInsight? insight) {
        return insight?.items.any(
              (item) => item.kind == HomeInsightKind.noSpendingToday,
            ) ??
            false;
      }

      // 白天不提示：此时没有别的可说，整块洞察直接隐藏。
      expect(hasHint(build(9)), isFalse);
      expect(build(9), isNull);
      expect(hasHint(build(homeInsightNoSpendingHintHour - 1)), isFalse);

      // 到点后提示。
      expect(hasHint(build(homeInsightNoSpendingHintHour)), isTrue);
      expect(hasHint(build(23)), isTrue);
      expect(build(23)!.items.single.plainText, '今天还没有支出记录');
    });

    test('never nudges once something was spent today', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 5800,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(hasBudget: false, progress: 0),
        categories: const [],
        now: DateTime(2026, 9, 20, 23),
      );

      expect(
        insight!.items.where(
          (item) => item.kind == HomeInsightKind.noSpendingToday,
        ),
        isEmpty,
      );
    });

    test('reports spending above the daily average as neutral', () {
      final insight = buildHomeInsight(
        today: _today(
          todayExpenseMinor: 30000,
          monthExpenseMinor: 657900,
          dailyAverageExpenseMinor: 21200,
        ),
        budget: _budget(hasBudget: false, progress: 0),
        categories: const [],
      );

      final spending = insight!.items.single;
      expect(spending.plainText, contains('今天比日均多花'));
      expect(spending.tone, HomeInsightTone.neutral);
    });
  });

  group('HomeCategoryBudgetProgress', () {
    test('reports progress, near-limit and exceeded states', () {
      const nearLimit = HomeCategoryBudgetProgress(
        budgetId: 'b1',
        name: '餐饮',
        amountMinor: 200000,
        usedMinor: 170000,
        currencyCode: 'CNY',
      );
      const exceeded = HomeCategoryBudgetProgress(
        budgetId: 'b2',
        name: '购物',
        amountMinor: 150000,
        usedMinor: 160000,
        currencyCode: 'CNY',
      );

      expect(nearLimit.progress, closeTo(0.85, 0.001));
      expect(nearLimit.isNearLimit, isTrue);
      expect(nearLimit.isExceeded, isFalse);
      expect(exceeded.isExceeded, isTrue);
      expect(exceeded.progress, greaterThan(1));
    });

    test('guards against a zero amount budget', () {
      const zero = HomeCategoryBudgetProgress(
        budgetId: 'b3',
        name: '空预算',
        amountMinor: 0,
        usedMinor: 0,
        currencyCode: 'CNY',
      );

      expect(zero.progress, 0);
      expect(zero.isExceeded, isFalse);
    });
  });

  group('HomeNetAssetSummary', () {
    test('computes net assets from assets minus liabilities', () {
      const summary = HomeNetAssetSummary(
        currencyCode: 'CNY',
        assetMinor: 5820000,
        liabilityMinor: 590000,
      );

      expect(summary.netAssetMinor, 5230000);
      expect(summary.hasAccounts, isTrue);
    });

    test('empty summary exposes zero balances', () {
      const summary = HomeNetAssetSummary.empty();

      expect(summary.netAssetMinor, 0);
      expect(summary.hasAccounts, isFalse);
    });
  });

  group('HomeStreak', () {
    test('marks the streak as capped when it fills the window', () {
      const streak = HomeStreak(
        days: homeStreakWindowDays,
        hasRecordedToday: true,
        cappedAt: homeStreakWindowDays,
      );

      expect(streak.isCapped, isTrue);
    });

    test('empty streak is not capped', () {
      expect(const HomeStreak.empty().isCapped, isFalse);
    });
  });

  group('buildHomeHealthHint', () {
    final reference = DateTime(2024, 10, 16);

    test('returns null when tracking is off or there is no history', () {
      expect(
        buildHomeHealthHint(
          prediction: const HealthCyclePrediction.noHistory(mainStatus: '暂无记录'),
          hasDailyLogToday: false,
          referenceDate: reference,
        ),
        isNull,
      );
    });

    test('reports days until the next period', () {
      final hint = buildHomeHealthHint(
        prediction: HealthCyclePrediction.cycleDay(
          basis: HealthPredictionBasis.history,
          mainStatus: '周期第 20 天',
          currentCycleDay: 20,
          nextPeriodStart: DateTime(2024, 10, 21),
          nextPeriodEnd: DateTime(2024, 10, 25),
          fertileWindowStart: DateTime(2024, 10, 5),
          fertileWindowEnd: DateTime(2024, 10, 10),
          pmsStart: DateTime(2024, 10, 18),
          pmsEnd: DateTime(2024, 10, 21),
        ),
        hasDailyLogToday: false,
        referenceDate: reference,
      );

      expect(hint, isNotNull);
      expect(hint!.kind, HomeHealthHintKind.period);
      expect(hint.title, '距下次经期还有 5 天');
      expect(hint.detail, contains('10月21日预计开始'));
      expect(hint.detail, contains('今天还没记录'));
    });

    test('reports a late period', () {
      final hint = buildHomeHealthHint(
        prediction: HealthCyclePrediction.cycleDay(
          basis: HealthPredictionBasis.history,
          mainStatus: '周期第 30 天',
          currentCycleDay: 30,
          nextPeriodStart: DateTime(2024, 10, 12),
          nextPeriodEnd: DateTime(2024, 10, 16),
          fertileWindowStart: DateTime(2024, 9, 26),
          fertileWindowEnd: DateTime(2024, 10, 1),
          pmsStart: DateTime(2024, 10, 9),
          pmsEnd: DateTime(2024, 10, 12),
        ),
        hasDailyLogToday: true,
        referenceDate: reference,
      );

      expect(hint!.title, '经期已推迟 4 天');
    });

    test('reports the current period day', () {
      final hint = buildHomeHealthHint(
        prediction: const HealthCyclePrediction.periodDay(
          mainStatus: '经期第 2 天',
          currentPeriodDay: 2,
          basis: HealthPredictionBasis.history,
        ),
        hasDailyLogToday: true,
        referenceDate: reference,
      );

      expect(hint!.title, '经期第 2 天');
      expect(hint.detail, '今天已记录');
    });
  });
}
