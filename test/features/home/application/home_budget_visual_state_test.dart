import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

HomeMonthBudgetSummary _budget({double progress = 1.2}) {
  return HomeMonthBudgetSummary(
    hasBudget: true,
    currencyCode: 'CNY',
    budgetId: 'b1',
    budgetName: '本月预算',
    totalMinor: 800000,
    usedMinor: (800000 * progress).round(),
    remainingMinor: 800000 - (800000 * progress).round(),
    progress: progress,
    periodProgress: 0.6,
    paceRatio: 2,
    paceLabel: '已超支',
    remainingDays: 10,
  );
}

const _empty = HomeMonthBudgetSummary.empty(
  currencyCode: 'CNY',
  remainingDays: 10,
);

void main() {
  group('resolveStableBudgetSummary', () {
    test('有预算时直接采用当前摘要', () {
      final current = _budget();
      final result = resolveStableBudgetSummary(
        current: current,
        previous: _budget(progress: 0.5),
        isLoading: false,
        hasEligibleBudget: true,
      );
      expect(identical(result, current), isTrue);
    });

    test('刷新期间暂时无预算时保留上一次摘要（避免超支底色闪回）', () {
      final previous = _budget(progress: 1.2);
      final result = resolveStableBudgetSummary(
        current: _empty,
        previous: previous,
        isLoading: true,
        hasEligibleBudget: true,
      );
      expect(identical(result, previous), isTrue);
    });

    test('用户仍有可用预算时保留上一次摘要', () {
      final previous = _budget(progress: 1.2);
      final result = resolveStableBudgetSummary(
        current: _empty,
        previous: previous,
        isLoading: false,
        hasEligibleBudget: true,
      );
      expect(identical(result, previous), isTrue);
    });

    test('确定没有可用预算时采用当前空摘要', () {
      final result = resolveStableBudgetSummary(
        current: _empty,
        previous: _budget(progress: 1.2),
        isLoading: false,
        hasEligibleBudget: false,
      );
      expect(identical(result, _empty), isTrue);
    });

    test('无历史摘要时返回当前值', () {
      final result = resolveStableBudgetSummary(
        current: _empty,
        previous: null,
        isLoading: true,
        hasEligibleBudget: true,
      );
      expect(identical(result, _empty), isTrue);
    });
  });
}
