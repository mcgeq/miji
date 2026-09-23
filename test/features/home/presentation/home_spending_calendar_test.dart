import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/features/home/presentation/home_overview_card.dart';
import 'package:miji/features/home/presentation/home_spending_calendar.dart';

/// 日历的三个关键行为：格子口径（净额/空日/未来日）、点开某天的明细、
/// 以及翻月只改共享的月份状态（真正查库由 provider 负责，见
/// `home_month_daily_spending_provider_test.dart`）。
void main() {
  final march = DateTime(2026, 3);

  Widget host(
    Widget child, {
    HomeMonthlyDailySpending? summary,
    DateTime? month,
    bool masked = false,
    ValueChanged<int>? onMonthChanged,
    VoidCallback? onOpenTransactions,
    Future<HomeMonthlyDailySpending>? pending,

    /// 换一套 overrides 重新 pump 时要用新的 key，
    /// 否则 Riverpod 会报「更新了未覆盖过的 provider 的覆盖」。
    Key? key,
  }) {
    final targetMonth = month ?? march;
    return ProviderScope(
      key: key,
      overrides: [
        moneyAmountsMaskedProvider.overrideWithValue(masked),
        homeMonthDailySpendingProvider(targetMonth).overrideWith(
          (ref) async =>
              pending ?? summary ?? HomeMonthlyDailySpending.empty(targetMonth),
        ),
      ],
      child: MoneyPrivacyScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(width: 360, child: child),
            ),
          ),
        ),
      ),
    );
  }

  HomeSpendingCalendar calendar({
    DateTime? month,
    ValueChanged<int>? onMonthChanged,
    VoidCallback? onOpenTransactions,
    VoidCallback? onAddTransaction,
  }) {
    return HomeSpendingCalendar(
      month: month ?? march,
      onMonthChanged: onMonthChanged ?? (_) {},
      onOpenTransactions: onOpenTransactions ?? () {},
      onAddTransaction: onAddTransaction,
    );
  }

  testWidgets('格子显示当日净额，空日显示破折号', (tester) async {
    await tester.pumpWidget(
      host(
        calendar(),
        summary: _summary(
          march,
          days: {
            2: (expense: 20000, income: 0, count: 1),
            5: (expense: 0, income: 50000, count: 1),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 支出日带负号、收入日带正号。
    expect(find.text('-200'), findsOneWidget);
    expect(find.text('+500'), findsOneWidget);
    // 空日：破折号，且和「金额为 0」区分开。
    expect(find.text('—'), findsNWidgets(29));
    // 整月标题与净额。
    expect(find.text('2026年3月'), findsOneWidget);
    expect(find.text('本月净额'), findsOneWidget);
  });

  testWidgets('大额在格子里缩写，避免撑破格子', (tester) async {
    await tester.pumpWidget(
      host(
        calendar(),
        summary: _summary(
          march,
          days: {9: (expense: 1234500, income: 0, count: 1)},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 一格一个（表头「本月净额」也用同一套紧凑写法）。
    expect(find.text('-1.2万'), findsNWidgets(2));
  });

  testWidgets('遮罩打开时格子显示圆点', (tester) async {
    await tester.pumpWidget(
      host(
        calendar(),
        masked: true,
        summary: _summary(
          march,
          days: {2: (expense: 20000, income: 0, count: 1)},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('-200'), findsNothing);
    expect(find.text('••'), findsWidgets);
  });

  testWidgets('点某天展开当日明细', (tester) async {
    final summary = _summary(
      march,
      days: {15: (expense: 20000, income: 5000, count: 5)},
      transactions: {
        15: [
          _txn(
            DateTime(2026, 3, 15, 21),
            5000,
            description: '红包',
            type: MoneyTransactionType.income,
          ),
          _txn(DateTime(2026, 3, 15, 9), 20000, description: '早餐'),
          _txn(DateTime(2026, 3, 15, 12), 3000, description: '午饭'),
          _txn(DateTime(2026, 3, 15, 18), 4000, description: '咖啡'),
          _txn(DateTime(2026, 3, 15, 20), 6000, description: '打车'),
        ],
      },
    );
    await tester.pumpWidget(host(calendar(), summary: summary));
    await tester.pumpAndSettle();

    // 未点之前没有明细。
    expect(find.text('3月15日 · 周日'), findsNothing);

    await tester.tap(find.text('15'));
    await tester.pumpAndSettle();

    expect(find.text('3月15日 · 周日'), findsOneWidget);
    expect(find.text('支出'), findsOneWidget);
    expect(find.text('收入'), findsOneWidget);
    expect(find.text('净额'), findsOneWidget);
    expect(find.text('5 笔'), findsOneWidget);
    // 明细最多列 3 条，超过时给「查看全部」。
    expect(find.textContaining('查看全部'), findsOneWidget);
  });

  testWidgets('空日点开可以补记一笔', (tester) async {
    var added = 0;
    await tester.pumpWidget(
      host(
        calendar(onAddTransaction: () => added += 1),
        summary: _summary(march, days: const {}),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();

    expect(find.text('这天没有记账'), findsOneWidget);
    await tester.tap(find.text('补记一笔'));
    await tester.pumpAndSettle();
    expect(added, 1);
  });

  testWidgets('翻月只改共享的月份状态', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      host(
        calendar(month: DateTime(2026, 2), onMonthChanged: changes.add),
        month: DateTime(2026, 2),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上个月'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('下个月'));
    await tester.pumpAndSettle();

    expect(changes, [-1, 1]);
  });

  testWidgets('不在本月时提供「回到本月」', (tester) async {
    final changes = <int>[];
    await tester.pumpWidget(
      host(
        calendar(month: DateTime(2026, 2), onMonthChanged: changes.add),
        month: DateTime(2026, 2),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('回到本月'), findsOneWidget);
    await tester.tap(find.text('回到本月'));
    await tester.pumpAndSettle();
    expect(changes, [0]);
  });

  testWidgets('本月不显示「回到本月」', (tester) async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    await tester.pumpWidget(host(calendar(month: month), month: month));
    await tester.pumpAndSettle();

    expect(find.text('回到本月'), findsNothing);
  });

  testWidgets('未来日期不可点', (tester) async {
    // 下个月整月都是未来，点任何一天都不该展开明细。
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1);
    await tester.pumpWidget(host(calendar(month: nextMonth), month: nextMonth));
    await tester.pumpAndSettle();

    await tester.tap(find.text('10'));
    await tester.pumpAndSettle();

    expect(find.text('这天没有记账'), findsNothing);
  });

  group('formatCompactSignedAmount', () {
    test('整数元 + 千分位 + 符号', () {
      expect(formatCompactSignedAmount(-20000), '-200');
      expect(formatCompactSignedAmount(5000), '+50');
      expect(formatCompactSignedAmount(-124000), '-1,240');
      expect(formatCompactSignedAmount(0), '+0');
    });

    test('上万缩写', () {
      expect(formatCompactSignedAmount(-1234500), '-1.2万');
      expect(formatCompactSignedAmount(2000000), '+2.0万');
    });
  });

  testWidgets('翻月加载中不会把整卡压扁再撑回来', (tester) async {
    // 回归：原来加载中会把整块网格换成矮骨架屏，AnimatedSize 于是先把卡片
    // 压扁、数据回来再撑开 —— 看起来就是「翻个月卡片先缩小再恢复」。
    // 这里比的是**同一个月**加载中 vs 加载完成的高度。
    final pending = Completer<HomeMonthlyDailySpending>();
    await tester.pumpWidget(
      host(
        calendar(month: march),
        month: march,
        pending: pending.future,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    // 加载中网格仍在（日期格照常渲染，只有数字位置是骨架）。
    expect(find.text('1'), findsOneWidget, reason: '加载中网格也要占位');
    expect(find.byType(AppSkeletonBox), findsWidgets);
    expect(find.text('—'), findsNothing, reason: '加载中不该先画成空日');
    final loadingHeight = tester.getSize(find.byType(HomeOverviewPanel)).height;

    pending.complete(
      _summary(march, days: {2: (expense: 20000, income: 0, count: 1)}),
    );
    await tester.pumpAndSettle();

    // 一格 + 表头「本月净额」各一处。
    expect(find.text('-200'), findsNWidgets(2));
    expect(
      tester.getSize(find.byType(HomeOverviewPanel)).height,
      closeTo(loadingHeight, 1),
      reason: '加载前后高度必须一致，否则翻月会「缩回去再长出来」',
    );
  });
}

/// 造一个月的聚合结果：`days` 里给出每天的收支，`transactions` 给出当日流水。
HomeMonthlyDailySpending _summary(
  DateTime month, {
  required Map<int, ({int expense, int income, int count})> days,
  Map<int, List<MoneyTransactionEntity>> transactions = const {},
}) {
  final byDay = <DateTime, HomeDailySpendingPoint>{
    for (final entry in days.entries)
      DateTime(month.year, month.month, entry.key): HomeDailySpendingPoint(
        date: DateTime(month.year, month.month, entry.key),
        expenseMinor: entry.value.expense,
        incomeMinor: entry.value.income,
        transactionCount: entry.value.count,
        isInMonth: true,
      ),
  };
  final transactionsByDay = <DateTime, List<MoneyTransactionEntity>>{
    for (final entry in transactions.entries)
      DateTime(month.year, month.month, entry.key): entry.value,
  };
  final expenseMinor = days.values.fold<int>(0, (sum, d) => sum + d.expense);
  final incomeMinor = days.values.fold<int>(0, (sum, d) => sum + d.income);
  final count = days.values.fold<int>(0, (sum, d) => sum + d.count);

  return HomeMonthlyDailySpending(
    month: month,
    byDay: byDay,
    transactionsByDay: transactionsByDay,
    expenseMinor: expenseMinor,
    incomeMinor: incomeMinor,
    transactionCount: count,
    dailyAverageExpenseMinor: expenseMinor == 0 ? 0 : expenseMinor ~/ 31,
  );
}

MoneyTransactionEntity _txn(
  DateTime at,
  int amountMinor, {
  String description = '',
  MoneyTransactionType type = MoneyTransactionType.expense,
}) {
  final now = DateTime.utc(2026, 1, 1);
  return MoneyTransactionEntity(
    id: 'txn-${at.millisecondsSinceEpoch}-$amountMinor',
    userId: 'user-1',
    type: type,
    status: MoneyTransactionStatus.completed,
    transactionAt: at,
    amountMinor: amountMinor,
    refundAmountMinor: 0,
    currencyCode: 'CNY',
    description: description,
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
