import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_balance_hero_card.dart';

HomeMonthBudgetSummary _budget({
  double progress = 0.57,
  int remainingMinor = 342050,
}) {
  return HomeMonthBudgetSummary(
    hasBudget: true,
    currencyCode: 'CNY',
    budgetId: 'budget-1',
    budgetName: '本月预算',
    totalMinor: 800000,
    usedMinor: 800000 - remainingMinor,
    remainingMinor: remainingMinor,
    progress: progress,
    periodProgress: 0.52,
    paceRatio: 1.1,
    paceLabel: '节奏正常',
    remainingDays: 15,
  );
}

const _spending = HomeTodaySpendingSummary(
  currencyCode: 'CNY',
  todayExpenseMinor: 5800,
  todayIncomeMinor: 0,
  weekExpenseMinor: 107100,
  monthExpenseMinor: 657900,
  monthIncomeMinor: 1000000,
  monthExpenseTransactionCount: 16,
  todayTransactionCount: 2,
  dailyAverageExpenseMinor: 21200,
);

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('renders remaining budget as the hero number', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月还可花'), findsOneWidget);
    expect(find.textContaining('3,420'), findsOneWidget);
    expect(find.text('57%'), findsOneWidget);
    expect(find.text('时间进度 52%'), findsOneWidget);
    expect(find.text('花费进度 57%'), findsOneWidget);
  });

  testWidgets('falls back to monthly net when there is no budget', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: const HomeMonthBudgetSummary.empty(
            currencyCode: 'CNY',
            remainingDays: 15,
          ),
          today: _spending,
          categoryBudgets: null,
          isLoading: false,
          masked: false,
          onTapBudget: () => tapped = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月结余'), findsOneWidget);
    expect(find.text('本月还可花'), findsNothing);
    expect(find.text('设置本月预算'), findsOneWidget);

    await tester.tap(find.text('设置本月预算'));
    expect(tapped, isTrue);
  });

  testWidgets('masks every amount when privacy mode is on', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('3,420'), findsNothing);
    expect(find.text('金额已隐藏'), findsOneWidget);
    expect(find.text('••••'), findsWidgets);
  });

  testWidgets('renders category budget rows and the near-limit count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary(
            totalCount: 3,
            nearLimitCount: 2,
            items: [
              HomeCategoryBudgetProgress(
                budgetId: 'b1',
                name: '餐饮',
                amountMinor: 200000,
                usedMinor: 156000,
                currencyCode: 'CNY',
              ),
              HomeCategoryBudgetProgress(
                budgetId: 'b2',
                name: '购物',
                amountMinor: 150000,
                usedMinor: 67500,
                currencyCode: 'CNY',
              ),
            ],
          ),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分类预算'), findsOneWidget);
    expect(find.text('2 项接近上限'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('购物'), findsOneWidget);
  });

  testWidgets('shows an overspent label when the budget is exceeded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(progress: 1.08, remainingMinor: -64000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月已超支'), findsOneWidget);
    expect(find.text('本月还可花'), findsNothing);
  });

  testWidgets('renders the hero amount at display size', (tester) async {
    // 回归：_HeroAmount 曾把 style 只挂在子 TextSpan 上，整数部分回退到
    // 默认 bodyMedium(14px)，主角数字被缩成小字。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectHeroAmountIsLarge(tester, expected: '3,420');
  });

  testWidgets('renders the overspent amount at display size', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(progress: 1.04, remainingMinor: -20000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectHeroAmountIsLarge(tester, expected: '200');
    // 超支时不再在标题行重复一个「已超支」胶囊。
    expect(find.text('已超支'), findsNothing);
    expect(find.text('本月已超支'), findsOneWidget);
  });

  testWidgets('breaks the budget detail into one row per metric', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final labels = ['预算', '已用', '日均可花'];
    final tops = <double>[];
    for (final label in labels) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: '应单独展示「$label」');
      tops.add(tester.getRect(finder).center.dy);
    }

    // 三行垂直排列、互不重叠。
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
  });

  testWidgets('does not merge detail metrics into one line', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('预算 ¥'), findsNothing);
    expect(find.textContaining(' · '), findsNothing);
  });
  testWidgets('标题行不再重复「本月预算」，只留节奏状态', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 「本月预算」现在是卡上方 tab 的名字，卡内不再写第二遍。
    expect(find.text('本月预算'), findsNothing);
    expect(find.text('节奏正常'), findsOneWidget);
  });

  testWidgets('无预算时也不显示「本月概览」胶囊', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: null,
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月概览'), findsNothing);
    // 空态信息由正文承担：本月结余 + 设置预算入口。
    expect(find.text('本月结余'), findsOneWidget);
    expect(find.text('设置本月预算'), findsOneWidget);
  });
}

/// 断言主角金额按 displaySmall 渲染，而不是回退到默认正文字号。
void _expectHeroAmountIsLarge(WidgetTester tester, {required String expected}) {
  final finder = find.byKey(const ValueKey('home-hero-amount'));
  expect(finder, findsOneWidget);

  final amountText = tester
      .widgetList<Text>(
        find.descendant(of: finder, matching: find.byType(Text)),
      )
      .first;
  final plain = amountText.data ?? amountText.textSpan?.toPlainText() ?? '';
  expect(plain, contains(expected), reason: '主角金额应为「$expected」，实际「$plain」');

  final fontSize =
      amountText.style?.fontSize ?? amountText.textSpan?.style?.fontSize;
  expect(fontSize, isNotNull, reason: '根 TextSpan 必须带样式');
  expect(
    fontSize!,
    greaterThanOrEqualTo(32),
    reason: '主角金额字号应为 displaySmall（36），实际 $fontSize',
  );

  final height = tester.getSize(finder).height;
  expect(height, greaterThan(30), reason: '渲染高度 $height 说明字号被缩小了');
}
