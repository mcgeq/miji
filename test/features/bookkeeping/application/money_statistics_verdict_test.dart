import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/money_statistics_verdict.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

/// 统计页结论条：把「比上期多了还是少了」直接写成人话。
void main() {
  test('reports a decrease as good news for expenses', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        expenseMinor: 414000,
        previousExpenseMinor: 470000,
        topCategory: ('餐饮', 124000, 0.30),
      ),
      typeFocus: MoneyStatisticsTypeFocus.expense,
    );

    expect(verdict, isNotNull);
    expect(verdict!.tone, StatisticsTone.positive);
    expect(verdict.text, contains('支出 ¥4,140.00'));
    expect(verdict.text, contains('较上期 ↓12%'));
    expect(verdict.text, contains('最大头是 餐饮'));
  });

  test('reports an increase as bad news for expenses', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        expenseMinor: 570000,
        previousExpenseMinor: 470000,
        topCategory: ('购物', 198000, 0.48),
      ),
      typeFocus: MoneyStatisticsTypeFocus.expense,
    );

    expect(verdict!.tone, StatisticsTone.negative);
    expect(verdict.text, contains('较上期 ↑21%'));
  });

  test('treats income growth as good news and skips the top category', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        incomeMinor: 1200000,
        previousIncomeMinor: 1000000,
        topCategory: ('工资', 1200000, 1),
      ),
      typeFocus: MoneyStatisticsTypeFocus.income,
    );

    expect(verdict!.tone, StatisticsTone.positive);
    expect(verdict.text, contains('收入 ¥12,000.00'));
    expect(verdict.text, contains('较上期 ↑20%'));
    // 收入视角不展示「最大头是…」（那是支出结构的说法）。
    expect(verdict.text, isNot(contains('最大头')));
  });

  test('neutral when previous period has no baseline', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        expenseMinor: 100000,
        previousExpenseMinor: 0,
        topCategory: ('餐饮', 100000, 1),
      ),
      typeFocus: MoneyStatisticsTypeFocus.expense,
    );

    expect(verdict!.tone, StatisticsTone.neutral);
    expect(verdict.text, isNot(contains('较上期')));
  });

  test('mentions anomaly count when present', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        expenseMinor: 414000,
        previousExpenseMinor: 400000,
        topCategory: ('餐饮', 124000, 0.3),
      ),
      typeFocus: MoneyStatisticsTypeFocus.expense,
      anomalyCount: 2,
    );

    expect(verdict!.text, contains('2 项异常波动'));
  });

  test('masks money when the privacy switch is on', () {
    final verdict = buildStatisticsVerdict(
      summary: _summary(
        expenseMinor: 414000,
        previousExpenseMinor: 400000,
        topCategory: ('餐饮', 124000, 0.3),
      ),
      typeFocus: MoneyStatisticsTypeFocus.expense,
      masked: true,
    );

    expect(verdict!.text, contains('••••'));
    expect(verdict.text, isNot(contains('4,140')));
  });

  test('returns null when there is nothing to say', () {
    expect(
      buildStatisticsVerdict(
        summary: const MoneyStatisticsSummary.empty(),
        typeFocus: MoneyStatisticsTypeFocus.expense,
      ),
      isNull,
    );
  });
}

MoneyStatisticsSummary _summary({
  int expenseMinor = 0,
  int incomeMinor = 0,
  int previousExpenseMinor = 0,
  int previousIncomeMinor = 0,
  (String, int, double) topCategory = ('餐饮', 0, 0),
}) {
  return MoneyStatisticsSummary(
    currencyCode: 'CNY',
    totalIncomeMinor: incomeMinor,
    totalExpenseMinor: expenseMinor,
    incomeTransactionCount: incomeMinor > 0 ? 1 : 0,
    expenseTransactionCount: expenseMinor > 0 ? 1 : 0,
    trend: const <MoneyStatisticsTrendPoint>[],
    expenseCategories: topCategory.$2 == 0
        ? const <MoneyStatisticsCategorySlice>[]
        : [
            MoneyStatisticsCategorySlice(
              categoryId: 'c1',
              categoryName: topCategory.$1,
              amountMinor: topCategory.$2,
              percentage: topCategory.$3,
            ),
          ],
    incomeCategories: const <MoneyStatisticsCategorySlice>[],
    accounts: const <MoneyStatisticsAccountSlice>[],
    accountTypes: const <MoneyStatisticsAccountTypeSlice>[],
    paymentMethods: const <MoneyStatisticsPaymentMethodSlice>[],
    accountPaymentMethods: const <MoneyStatisticsAccountPaymentMethodSlice>[],
    merchants: const <MoneyStatisticsRankSlice>[],
    expenseSubCategories: const <MoneyStatisticsRankSlice>[],
    incomeSubCategories: const <MoneyStatisticsRankSlice>[],
    hasMixedCurrencies: false,
    familyMembers: const <MoneyStatisticsMemberSlice>[],
    previousPeriod: MoneyStatisticsComparisonSummary(
      incomeMinor: previousIncomeMinor,
      expenseMinor: previousExpenseMinor,
      incomeTransactionCount: previousIncomeMinor > 0 ? 1 : 0,
      expenseTransactionCount: previousExpenseMinor > 0 ? 1 : 0,
    ),
    samePeriodLastYear: const MoneyStatisticsComparisonSummary.empty(),
  );
}
