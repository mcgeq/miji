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

HomeMonthBudgetSummary _budget({
  int totalMinor = 300000,
  int usedMinor = 100000,
  int committedMinor = 0,
}) {
  return HomeMonthBudgetSummary(
    hasBudget: true,
    currencyCode: 'CNY',
    budgetId: 'b1',
    budgetName: '日常',
    totalMinor: totalMinor,
    usedMinor: usedMinor,
    remainingMinor: totalMinor - usedMinor,
    committedMinor: committedMinor,
    progress: totalMinor <= 0 ? 0 : usedMinor / totalMinor,
    periodProgress: 0.5,
    paceRatio: 1,
    paceLabel: '正常',
    remainingDays: 10,
  );
}

MoneyWidgetSnapshot _snapshot({
  HomeTodaySpendingSummary? summary,
  HomeMonthBudgetSummary? budget,
  bool masked = false,
  bool unlocked = true,
  DateTime? now,
}) {
  return MoneyWidgetSnapshot.fromTodaySummary(
    summary: summary ?? _summary(),
    budget: budget,
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
          'mw_budget_visible',
          'mw_budget_text',
          'mw_budget_total',
          'mw_budget_percent',
          'mw_budget_alert',
          'mw_date',
          'mw_ledger',
        ]),
      );
      expect(data['mw_date'], '2026-10-21');
      expect(data['mw_ledger'], '日常');
    });

    test('预算布尔与百分比都写成字符串，避免 Kotlin 侧 getString 抛类型转换', () {
      final data = _snapshot(budget: _budget()).toWidgetData();

      expect(data['mw_budget_visible'], '1');
      expect(data['mw_budget_alert'], '0');
      expect(data['mw_budget_percent'], '33');
      expect(data['mw_budget_percent'], isA<String>());
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

  group('MoneyWidgetSnapshot 预算', () {
    test('没配预算：整块不出现，卡面退回今日支出', () {
      final snapshot = _snapshot(summary: _summary(expenseMinor: 12850));

      expect(snapshot.budgetVisible, isFalse);
      expect(snapshot.budgetText, '');
      expect(snapshot.budgetPercent, 0);
    });

    test('正常预算：给「还剩多少」和总量，进度按占用算', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 12850, count: 1),
        budget: _budget(totalMinor: 300000, usedMinor: 100000),
      );

      expect(snapshot.budgetVisible, isTrue);
      expect(snapshot.budgetText, '预算剩 ¥2,000.00');
      expect(snapshot.budgetTotal, '/ ¥3,000.00');
      expect(snapshot.budgetPercent, 33);
      expect(snapshot.budgetAlert, isFalse);
    });

    test('已花超：说的是「超支多少」而不是负数的「还剩」', () {
      final snapshot = _snapshot(
        budget: _budget(totalMinor: 300000, usedMinor: 320000),
      );

      expect(snapshot.budgetText, '预算超支 ¥200.00');
      expect(snapshot.budgetAlert, isTrue);
      // 进度条封顶 100，不会画出 106% 这种溢出宽度。
      expect(snapshot.budgetPercent, 100);
    });

    test('已用没超、但预留把额度占满，同样算破预算', () {
      // 与首页预算卡同一判据（占用 = 已用 + 已预留）：未来义务占满额度时，
      // 「还能花多少」和真超支没有区别。
      final snapshot = _snapshot(
        budget: _budget(
          totalMinor: 300000,
          usedMinor: 120000,
          committedMinor: 200000,
        ),
      );

      expect(snapshot.budgetText, '预算超支 ¥200.00');
      expect(snapshot.budgetAlert, isTrue);
    });

    test('遮罩开启：预算只打码，不改变这块的可见性', () {
      final snapshot = _snapshot(
        summary: _summary(expenseMinor: 12850, count: 3),
        budget: _budget(totalMinor: 300000, usedMinor: 100000),
        masked: true,
      );

      expect(snapshot.budgetVisible, isTrue);
      expect(snapshot.budgetText, '预算 ••••');
      expect(snapshot.budgetTotal, '••••');
      expect(snapshot.budgetText.contains('2,000'), isFalse);
    });

    test('应用锁着：连「有没有预算」都不暴露', () {
      final snapshot = _snapshot(
        budget: _budget(totalMinor: 300000, usedMinor: 100000),
        unlocked: false,
      );

      expect(snapshot.budgetVisible, isFalse);
      expect(snapshot.budgetText, '');
    });
  });
}
