import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

/// 日聚合是日历和趋势卡共用的口径，这里盯住三件事：
/// 月内合计不能把「补白天数」算进来、退款要扣掉、日均的摊平基数。
void main() {
  group('buildMonthlyDailySpending', () {
    test('把交易按天聚合出 支出 / 收入 / 笔数', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 20),
        transactions: [
          _txn(DateTime(2026, 3, 2, 9), 12000),
          _txn(DateTime(2026, 3, 2, 19), 8000),
          _txn(DateTime(2026, 3, 5), 5000, type: MoneyTransactionType.income),
        ],
      );

      expect(summary.expenseMinor, 20000);
      expect(summary.incomeMinor, 5000);
      expect(summary.transactionCount, 3);
      expect(summary.netMinor, -15000);

      final day2 = summary.pointForDay(2);
      expect(day2.expenseMinor, 20000);
      expect(day2.transactionCount, 2);
      expect(day2.netMinor, -20000);

      final day5 = summary.pointForDay(5);
      expect(day5.incomeMinor, 5000);
      expect(day5.netMinor, 5000);
    });

    test('补白天数只进 byDay，不算进月合计', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 20),
        transactions: [
          _txn(DateTime(2026, 3, 1), 10000),
          // 3 月 28 日之前/4 月初的补白天数（趋势的滚动窗口可能跨月）。
          _txn(DateTime(2026, 2, 26), 7000),
          _txn(DateTime(2026, 4, 3), 9000),
        ],
      );

      expect(summary.expenseMinor, 10000, reason: '月合计只算 3 月内的');
      // 跨月那两天仍留在 byDay 里，趋势窗口查得到。
      expect(summary.byDay[DateTime(2026, 2, 26)]?.expenseMinor, 7000);
      expect(summary.byDay[DateTime(2026, 4, 3)]?.expenseMinor, 9000);
      expect(summary.byDay[DateTime(2026, 2, 26)]?.isInMonth, isFalse);
      expect(summary.byDay[DateTime(2026, 3, 1)]?.isInMonth, isTrue);
    });

    test('退款要从当日与当月金额里扣掉', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 20),
        transactions: [
          _txn(DateTime(2026, 3, 8), 30000, refundAmountMinor: 12000),
        ],
      );

      expect(summary.pointForDay(8).expenseMinor, 18000);
      expect(summary.expenseMinor, 18000);
    });

    test('当月日均按「已过天数」摊，历史月按整月天数摊', () {
      final currentMonth = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 10),
        transactions: [_txn(DateTime(2026, 3, 1), 30000)],
      );
      // 300 元 / 10 天
      expect(currentMonth.dailyAverageExpenseMinor, 3000);

      final pastMonth = buildMonthlyDailySpending(
        month: DateTime(2026, 2),
        today: DateTime(2026, 3, 10),
        transactions: [_txn(DateTime(2026, 2, 3), 30000)],
      );
      // 300 元 / 28 天（2026 年 2 月）
      expect(pastMonth.dailyAverageExpenseMinor, 1071);
    });

    test('空月返回全 0，不缺格', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 10),
        transactions: const [],
      );

      expect(summary.expenseMinor, 0);
      expect(summary.incomeMinor, 0);
      expect(summary.transactionCount, 0);
      expect(summary.dailyAverageExpenseMinor, 0);
      expect(summary.byDay, isEmpty);
      expect(summary.pointForDay(15).transactionCount, 0);
      expect(summary.pointForDay(15).netMinor, 0);
    });

    test('当日流水按时间倒序、只留当天', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 20),
        transactions: [
          _txn(DateTime(2026, 3, 4, 8), 1000),
          _txn(DateTime(2026, 3, 4, 21), 2000),
          _txn(DateTime(2026, 3, 5, 9), 3000),
        ],
      );

      final dayFour = summary.transactionsForDay(4);
      expect(dayFour, hasLength(2));
      expect(dayFour.first.transactionAt.hour, 21);
      expect(dayFour.last.transactionAt.hour, 8);
      expect(summary.transactionsForDay(5), hasLength(1));
      expect(summary.transactionsForDay(6), isEmpty);
    });

    test('金额为 0 的交易不计入（避免画出一根空柱）', () {
      final summary = buildMonthlyDailySpending(
        month: DateTime(2026, 3),
        today: DateTime(2026, 3, 20),
        transactions: [_txn(DateTime(2026, 3, 7), 0)],
      );

      expect(summary.transactionCount, 0);
      expect(summary.byDay, isEmpty);
    });
  });
}

MoneyTransactionEntity _txn(
  DateTime at,
  int amountMinor, {
  MoneyTransactionType type = MoneyTransactionType.expense,
  int refundAmountMinor = 0,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return MoneyTransactionEntity(
    id: 'txn-${at.millisecondsSinceEpoch}-$amountMinor-$type',
    userId: 'user-1',
    type: type,
    status: MoneyTransactionStatus.completed,
    transactionAt: at,
    amountMinor: amountMinor,
    refundAmountMinor: refundAmountMinor,
    currencyCode: 'CNY',
    description: '',
    notes: null,
    merchant: null,
    location: null,
    accountId: 'account-1',
    toAccountId: null,
    categoryId: 'category-1',
    subCategoryId: null,
    paymentMethod: MoneyPaymentMethod.other,
    customPaymentMethodName: null,
    actualPayerAccount: 'default',
    relatedTransactionId: null,
    installmentPlanId: null,
    sourceTemplateRunId: null,
    interestRateBasisPoints: null,
    totalInterestMinor: 0,
    calcMethod: null,
    tags: const [],
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}
