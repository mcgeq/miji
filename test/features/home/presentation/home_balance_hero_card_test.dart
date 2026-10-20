import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_balance_hero_card.dart';

HomeMonthBudgetSummary _budget({
  // 与下面的金额保持自洽：默认不留「未来义务」，占用进度 == 已用进度，
  // 卡片才会走「花费进度」而不是「已用+预留」分支。
  double progress = (800000 - 342050) / 800000,
  int remainingMinor = 342050,
  int committedMinor = 0,
  String paceLabel = '节奏正常',
}) {
  return HomeMonthBudgetSummary(
    hasBudget: true,
    currencyCode: 'CNY',
    budgetId: 'budget-1',
    budgetName: '本月预算',
    totalMinor: 800000,
    usedMinor: 800000 - remainingMinor,
    remainingMinor: remainingMinor,
    committedMinor: committedMinor,
    progress: progress,
    periodProgress: 0.52,
    paceRatio: 1.1,
    paceLabel: paceLabel,
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

/// 胶囊左侧那颗 6×6 圆点的颜色。整张卡里只有它是这个尺寸。
Color _chipDotColor(WidgetTester tester) {
  final dot = tester.widget<Container>(
    find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints ==
              const BoxConstraints.tightFor(width: 6, height: 6),
    ),
  );
  return (dot.decoration! as BoxDecoration).color!;
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
    // 遮罩时保留同样的明细行（只把金额换成圆点），
    // 否则 Hero 会矮 20dp、整卡跟着变 → 看起来像间距被拉开。
    expect(find.text('预算'), findsOneWidget);
    expect(find.text('已用'), findsOneWidget);
    expect(find.text('日均可花'), findsOneWidget);
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
            exceededCount: 0,
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

  testWidgets('已超支是周期内终态：继续超支不改变背景渐变', (tester) async {
    Future<LinearGradient> gradientFor(
      double progress,
      int remainingMinor,
    ) async {
      await tester.pumpWidget(
        _host(
          HomeBalanceHeroCard(
            budget: _budget(progress: progress, remainingMinor: remainingMinor),
            today: _spending,
            categoryBudgets: const HomeCategoryBudgetSummary.empty(),
            isLoading: false,
            masked: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(HomeBalanceHeroCard),
              matching: find.byType(Container),
            )
            .first,
      );
      return (container.decoration! as BoxDecoration).gradient!
          as LinearGradient;
    }

    final exceeded = await gradientFor(1.08, -64000);
    final moreExceeded = await gradientFor(1.52, -416000);
    // 已超支后继续超支，背景渐变不应变化。
    expect(moreExceeded.colors, exceeded.colors);

    final underBudget = await gradientFor(0.92, 64000);
    // 跨过 100% 边界才切换到 danger。
    expect(underBudget.colors, isNot(exceeded.colors));
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
    expect(find.text('本月已超支'), findsOneWidget);
    // 「已超支」出现两处：标题行的告警胶囊 + 环中心的状态小字。
    expect(find.text('已超支'), findsNWidgets(2));
    // 明细行换成「超出」，不再留一句恒为 0 的「日均可花」。
    expect(find.text('超出'), findsOneWidget);
    expect(find.text('日均可花'), findsNothing);
    // 环中心的小字不再写「已占用」。
    expect(find.text('已占用'), findsNothing);
  });

  testWidgets('超支时环中心读出真实百分比，不再被 clamp 到 100%', (tester) async {
    // 预算 800,000，已用 1,040,000（130%）。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(progress: 1.3, remainingMinor: -240000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('130%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);
  });

  testWidgets('未超支时保留节奏胶囊与「日均可花」', (tester) async {
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

    expect(find.text('已超支'), findsNothing);
    expect(find.text('超出'), findsNothing);
    expect(find.text('日均可花'), findsOneWidget);
    expect(find.text('已占用'), findsOneWidget);
  });

  testWidgets('占用恰好等于预算：不算超支，主值读「还可花 ¥0.00」', (tester) async {
    // 预算 8,000 / 已用 4,800 / 已预留 3,200 → 占用 8,000，一分不剩但不欠。
    // 超支是「破了」这个终态，只能由严格大于触发；边界上写「已超支 ¥0.00」
    // 既没信息量，也会让用户怀疑算错了。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(
            remainingMinor: 320000,
            committedMinor: 320000,
            progress: 0.6,
          ),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月还可花'), findsOneWidget);
    expect(find.text('本月已超支'), findsNothing);
    expect(find.text('超出'), findsNothing);
    expect(find.text('超出（含预留）'), findsNothing);
    // 未超支 → 仍保留「日均可花」行，只是值是 0。
    expect(find.text('日均可花'), findsOneWidget);
    expect(find.text('已预留'), findsOneWidget);
    // 环画满 100%，中心如实读出 100%（不是超支，也不 clamp 成一个假数字）。
    expect(find.text('100%'), findsOneWidget);
    // 主值与「日均可花」各一处 ¥0.00。
    expect(
      find.textContaining('¥0.00', findRichText: true),
      findsNWidgets(2),
    );
  });

  testWidgets('已预留吃穿额度：也算超支，明细标明「含预留」', (tester) async {
    // 预算 8,000 / 已用 4,800 / 已预留 3,500 → 占用 8,300，超出 300。
    // 这是用户报的那个场景：首页记账卡写着「本月已超支」，Hero 却写
    // 「还可花 ¥0.00」。两处必须共用「占用」这一个判据。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(remainingMinor: 320000, committedMinor: 350000),
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
    // 已用只有 4,800（预算 8,000），不加「含预留」三个字就自相矛盾。
    expect(find.text('超出（含预留）'), findsOneWidget);
    // 占用 8,300 - 预算 8,000 = 300。主值与明细行各一处。
    expect(find.textContaining('300.00'), findsNWidgets(2));
    // 「日均可花」在这里恒为 0，换掉。
    expect(find.text('日均可花'), findsNothing);
  });

  testWidgets('预算已用与本月支出口径不同时，把全量数字摆出来', (tester) async {
    // 分类预算 / 账单周期 / 转账不计入 → 预算「已用」会小于首页「本月支出」。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(remainingMinor: 320000, committedMinor: 0),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 预算已用 4,800，本月支出 6,579（_spending.monthExpenseMinor）。
    expect(find.text('本月实际支出'), findsOneWidget);
    expect(find.textContaining('6,579.00'), findsOneWidget);
  });

  testWidgets('两个口径一致时不加「本月实际支出」行，卡片不变高', (tester) async {
    // usedMinor = 800000 - 142100 = 657900，与 _spending.monthExpenseMinor 相等。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(remainingMinor: 142100),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('本月实际支出'), findsNothing);
  });

  testWidgets('分类预算超支与「接近上限」分开报', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary(
            totalCount: 3,
            nearLimitCount: 2,
            exceededCount: 1,
            items: [
              HomeCategoryBudgetProgress(
                budgetId: 'b1',
                name: '餐饮',
                amountMinor: 200000,
                usedMinor: 240000,
                currencyCode: 'CNY',
              ),
              HomeCategoryBudgetProgress(
                budgetId: 'b2',
                name: '购物',
                amountMinor: 150000,
                usedMinor: 130000,
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

    // 超支是终态，不能被「接近上限」这句话含过去。
    expect(find.text('1 项已超支'), findsOneWidget);
    expect(find.text('2 项接近上限'), findsNothing);
    // 超支的那条在金额后带「超」标记，未超支的没有。
    expect(find.textContaining('2,000.00 超'), findsOneWidget);
    expect(find.textContaining('1,500.00 超'), findsNothing);
  });

  testWidgets('进度算上「已预留」：环画到占用位置，而不是只画已用', (tester) async {
    // 已用 457,950（57%）+ 已预留 300,000 → 占用 757,950（95%）。
    // 只画已用的话，环还空着 43%，同一张卡却写着「还可花 ¥420.50」。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(committedMinor: 300000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('95%'), findsOneWidget);
    expect(find.text('已占用'), findsOneWidget);
    expect(find.text('已用+预留 95%'), findsOneWidget);
    expect(find.text('已预留'), findsOneWidget);
    // 环的中心数字不再是「已用占比」。
    expect(find.text('57%'), findsNothing);
    // 还有 5% 没被占，不算超支。
    expect(find.text('本月已超支'), findsNothing);
    expect(find.textContaining('420'), findsOneWidget);
  });

  testWidgets('预留把额度占到 101%：环满格，标题也转「已超支」', (tester) async {
    // 已预留 350,000 → 占用 807,950（101%），已用只有 57%。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(committedMinor: 350000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('101%'), findsOneWidget);
    expect(find.text('本月已超支'), findsOneWidget);
    expect(find.text('本月还可花'), findsNothing);
    // 超出 = 807,950 - 800,000 = 7.95。
    expect(find.text('超出（含预留）'), findsOneWidget);
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

  testWidgets('额度大半被预留时，胶囊说占用、圆点转告警色', (tester) async {
    // 占用 95%、日均可花只剩一点的时候，胶囊还说「节奏正常」会自相矛盾。
    // 必须留在 100% 以内：占用一过线就转「已超支」，这一档就不存在了。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(committedMinor: 300000, paceLabel: '额度大半已被预留'),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('额度大半已被预留'), findsOneWidget);
    // 圆点不能仍是那颗「一切正常」的薄荷绿。
    final theme = Theme.of(tester.element(find.byType(HomeBalanceHeroCard)));
    expect(_chipDotColor(tester), theme.heroGradients.amber);
  });

  testWidgets('节奏偏慢的圆点不再是正常的薄荷绿', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(paceLabel: '节奏偏慢'),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('节奏偏慢'), findsOneWidget);
    expect(_chipDotColor(tester), isNot(const Color(0xFF9BF5D4)));
  });

  testWidgets('占用过线时，环 / 进度条 / 圆点同时转告警色', (tester) async {
    // 已用 50% + 已预留 35% → 占用 85%，还没超支。
    // 旧实现：环按 80% 变琥珀，进度条只在**超支**时才变，圆点恒为薄荷绿，
    // 于是同一张卡上三个信号各说各的。
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(
            progress: 0.5,
            remainingMinor: 400000,
            committedMinor: 280000,
          ),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(HomeBalanceHeroCard)));
    final amber = theme.heroGradients.amber;

    // 环：有预留时两个 CircularProgressIndicator，已用段后画、在最上层。
    final rings = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    expect(rings, hasLength(2));
    expect(rings.last.valueColor!.value, amber, reason: '环的已用段要变琥珀');

    // 进度条：已用段同样变琥珀。
    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('home-budget-used-bar')),
    );
    expect(
      (bar.decoration! as BoxDecoration).color,
      amber,
      reason: '进度条的已用段必须与环同步',
    );
    // 预留段也要跟着换色：环那边整圈（含 52% 淡琥珀的预留段）都黄了，
    // 条这边若还是灰白，「已用+预留 96%」这条仍读成「大半是灰的」。
    final committedBar = tester.widget<Container>(
      find.byKey(const ValueKey('home-budget-committed-bar')),
    );
    expect(
      (committedBar.decoration! as BoxDecoration).color,
      amber.withValues(alpha: 0.52),
      reason: '预留段与环的预留弧同色',
    );

    // 圆点：文案还是「节奏正常」（过去确实花得不快），但占用过线也要转告警。
    expect(find.text('节奏正常'), findsOneWidget);
    expect(_chipDotColor(tester), amber);
  });

  testWidgets('占用不高时环、进度条、圆点都不告警', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBalanceHeroCard(
          budget: _budget(progress: 0.5, remainingMinor: 400000),
          today: _spending,
          categoryBudgets: const HomeCategoryBudgetSummary.empty(),
          isLoading: false,
          masked: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(HomeBalanceHeroCard)));

    final rings = tester
        .widgetList<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        )
        .toList();
    final usedRing = rings.last.valueColor!.value;
    expect(usedRing, Colors.white);
    expect(usedRing, isNot(theme.heroGradients.amber));

    final bar = tester.widget<Container>(
      find.byKey(const ValueKey('home-budget-used-bar')),
    );
    expect((bar.decoration! as BoxDecoration).color, Colors.white);
    expect(_chipDotColor(tester), isNot(theme.heroGradients.amber));
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
