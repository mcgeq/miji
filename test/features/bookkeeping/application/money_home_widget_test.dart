import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/money_home_widget.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

HomeTodaySpendingSummary _summary({
  int expenseMinor = 0,
  int incomeMinor = 0,
  int count = 0,
  int weekMinor = 0,
  int monthMinor = 0,
  int dailyMinor = 0,
}) {
  return HomeTodaySpendingSummary(
    currencyCode: 'CNY',
    todayExpenseMinor: expenseMinor,
    todayIncomeMinor: incomeMinor,
    weekExpenseMinor: weekMinor,
    monthExpenseMinor: monthMinor,
    monthIncomeMinor: incomeMinor,
    monthExpenseTransactionCount: count,
    todayTransactionCount: count,
    dailyAverageExpenseMinor: dailyMinor,
  );
}

MoneyWidgetSnapshot _snapshot({
  HomeTodaySpendingSummary? summary,
  bool masked = false,
  bool unlocked = true,
  DateTime? now,
}) {
  return MoneyWidgetSnapshot.fromTodaySummary(
    summary: summary ?? _summary(),
    masked: masked,
    unlocked: unlocked,
    ledgerName: '日常',
    now: now ?? DateTime(2026, 10, 21, 18, 30),
  );
}

void main() {
  group('MoneyWidgetSnapshot', () {
    test('有流水时给金额、笔数与收入', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 12850, incomeMinor: 2000, count: 3),
      );

      expect(snapshot.label, '今日支出');
      expect(snapshot.amount, '¥128.50');
      expect(snapshot.meta, '3 笔 · 收入 ¥20.00');
    });

    test('没有收入时副文案不塞一个 ¥0.00', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 3200, count: 1),
      );

      expect(snapshot.amount, '¥32.00');
      expect(snapshot.meta, '1 笔');
    });

    test('今天还没记账：说没记，而不是只丢一个 0', () {
      final snapshot = _snapshot();

      expect(snapshot.amount, '¥0.00');
      expect(snapshot.meta, '今天还没记账');
    });

    test('遮罩开启：金额变 ••••，并说明是被隐藏而不是坏了', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 12850, incomeMinor: 2000, count: 3),
        masked: true,
      );

      expect(snapshot.amount, '••••');
      expect(snapshot.meta, '3 笔 · 金额已隐藏');
      // 收入同样不能露：遮罩遮的是钱，不是某一种钱。
      expect(snapshot.meta.contains('20.00'), isFalse);
    });

    test('遮罩开启且今天没流水：引导去记一笔', () {
      final snapshot = _snapshot(masked: true);

      expect(snapshot.amount, '••••');
      expect(snapshot.meta, '点开记一笔');
    });

    test('应用锁着：连「今天花了多少」都不出现在桌面', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 12850, count: 3),
        unlocked: false,
      );

      expect(snapshot.label, '记账');
      expect(snapshot.amount, '••••');
      expect(snapshot.meta, '点开解锁');
    });

    test('日期按本地时区补零，供原生判断是否跨天', () {
      expect(_snapshot(now: DateTime(2026, 1, 5)).dateKey, '2026-01-05');
      expect(
        _snapshot(now: DateTime(2026, 12, 31, 23, 59)).dateKey,
        '2026-12-31',
      );
    });

    test('写进 SharedPreferences 的键与 Kotlin 侧一致', () {
      final data = _snapshot(
        summary: _summary(expenseMinor: 100, count: 1),
      ).toWidgetData();

      expect(
        data.keys,
        containsAll(<String>[
          'mw_label',
          'mw_amount',
          'mw_meta',
          'mw_week',
          'mw_month',
          'mw_daily',
          'mw_date',
          'mw_ledger',
        ]),
      );
      expect(data['mw_date'], '2026-10-21');
      expect(data['mw_ledger'], '日常');
    });

    test('底部的本周 / 本月 / 日均用 compact 格式，避免窄列里被截断', () {
      final snapshot = _snapshot(
        summary: _summary(
          expenseMinor: 12850,
          count: 2,
          weekMinor: 234560,
          monthMinor: 8900000,
          dailyMinor: 4520,
        ),
      );

      // 今日仍是精确到分的完整格式，它是这张卡的主数字。
      expect(snapshot.amount, '¥128.50');
      expect(snapshot.weekExpense, '¥2.3k');
      expect(snapshot.monthExpense, '¥8.9w');
      expect(snapshot.dailyExpense, '¥45.20');
    });

    test('小额时不强行缩写：千位以下仍然是完整金额', () {
      final snapshot = _snapshot(
        summary: _summary(
          expenseMinor: 500,
          weekMinor: 96000,
          monthMinor: 1,
          dailyMinor: 120,
        ),
      );

      expect(snapshot.weekExpense, '¥960.00');
      expect(snapshot.monthExpense, '¥0.01');
      expect(snapshot.dailyExpense, '¥1.20');
    });

    test('遮罩开启时底部三个周期数同样变 ••••', () {
      final snapshot = _snapshot(
        summary: _summary(
          expenseMinor: 12850,
          count: 3,
          weekMinor: 234560,
          monthMinor: 8900000,
          dailyMinor: 4520,
        ),
        masked: true,
      );

      expect(snapshot.weekExpense, '••••');
      expect(snapshot.monthExpense, '••••');
      expect(snapshot.dailyExpense, '••••');
    });

    test('应用锁着时底部也不泄露周 / 月 / 日均支出', () {
      final snapshot = _snapshot(
        summary: _summary(
          expenseMinor: 12850,
          count: 3,
          weekMinor: 234560,
          monthMinor: 8900000,
          dailyMinor: 4520,
        ),
        unlocked: false,
      );

      expect(snapshot.weekExpense, '••••');
      expect(snapshot.monthExpense, '••••');
      expect(snapshot.dailyExpense, '••••');
    });

    test('Receiver 名必须是全限定名，否则 ClassNotFoundException 会让卡面永不刷新', () {
      // home_widget 直接把这个字符串交给 Class.forName，不做任何补全；
      // 写成裸类名就会被拼成 com.mcgeq.miji.MoneyWidgetProvider（不存在），
      // 插件报错又被 push 的 catch 吞掉 —— 表现为「记完账小组件不动」。
      expect(MoneyWidgetSnapshot.androidProviderName, contains('.'));
      expect(
        MoneyWidgetSnapshot.androidProviderName,
        endsWith('.widget.MoneyWidgetProvider'),
      );
    });
  });
}
