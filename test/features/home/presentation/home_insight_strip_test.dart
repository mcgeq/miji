import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_insight_strip.dart';

const _exceeded = HomeInsightItem(
  kind: HomeInsightKind.budgetExceeded,
  tone: HomeInsightTone.danger,
  target: HomeInsightTarget.budgets,
  actionLabel: '看预算',
  segments: [
    HomeInsightSegment('本月预算已超支 '),
    HomeInsightSegment('¥200.00', emphasis: true),
  ],
);

const _topCategory = HomeInsightItem(
  kind: HomeInsightKind.topCategory,
  tone: HomeInsightTone.neutral,
  target: HomeInsightTarget.categories,
  actionLabel: '看分类',
  segments: [
    HomeInsightSegment('贷款还款占本月支出 '),
    HomeInsightSegment('47%', emphasis: true),
  ],
);

const _noSpending = HomeInsightItem(
  kind: HomeInsightKind.noSpendingToday,
  tone: HomeInsightTone.neutral,
  segments: [HomeInsightSegment('今天还没有支出记录')],
);

Widget _host(HomeInsight? insight, {ValueChanged<HomeInsightTarget>? onTap}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: HomeInsightStrip(insight: insight, onSelectTarget: onTap),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('hides itself when there is nothing to say', (tester) async {
    await tester.pumpWidget(_host(null));
    await tester.pumpAndSettle();
    expect(find.byType(InkWell), findsNothing);

    await tester.pumpWidget(_host(const HomeInsight(items: [])));
    await tester.pumpAndSettle();
    expect(find.textContaining('今天'), findsNothing);
  });

  testWidgets('renders one row per insight, not one long sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const HomeInsight(items: [_exceeded, _topCategory, _noSpending])),
    );
    await tester.pumpAndSettle();

    // 三条各自独立成行、字号一致，不会拼成一句。
    for (final item in [_exceeded, _topCategory, _noSpending]) {
      expect(
        find.text(item.plainText, findRichText: true),
        findsOneWidget,
        reason: '「${item.plainText}」应单独渲染',
      );
    }

    final tops = [
      tester
          .getRect(find.text(_exceeded.plainText, findRichText: true))
          .center
          .dy,
      tester
          .getRect(find.text(_topCategory.plainText, findRichText: true))
          .center
          .dy,
      tester
          .getRect(find.text(_noSpending.plainText, findRichText: true))
          .center
          .dy,
    ];
    expect(tops[0], lessThan(tops[1]));
    expect(tops[1], lessThan(tops[2]));
  });

  testWidgets('uses a distinct colour and icon per tone', (tester) async {
    await tester.pumpWidget(
      _host(
        const HomeInsight(
          items: [
            _exceeded,
            HomeInsightItem(
              kind: HomeInsightKind.budgetPace,
              tone: HomeInsightTone.warning,
              segments: [HomeInsightSegment('花得比时间进度快')],
            ),
            HomeInsightItem(
              kind: HomeInsightKind.spendingVsAverage,
              tone: HomeInsightTone.positive,
              segments: [HomeInsightSegment('今天比日均少花 ¥154.00')],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    expect(find.byIcon(Icons.insights_rounded), findsOneWidget);

    final theme = AppTheme.light();
    final icons = tester.widgetList<Icon>(
      find.byWidgetPredicate(
        (widget) => widget is Icon && widget.color != null,
      ),
    );
    final colors = icons.map((icon) => icon.color).toSet();
    // 超支 / 偏快 / 正向三种语气必须是三种不同颜色。
    expect(colors.length, greaterThanOrEqualTo(3));
    expect(colors, contains(theme.colorScheme.error));
  });

  testWidgets('only actionable rows are tappable and report their target', (
    tester,
  ) async {
    final tapped = <HomeInsightTarget>[];
    await tester.pumpWidget(
      _host(
        const HomeInsight(items: [_exceeded, _topCategory, _noSpending]),
        onTap: tapped.add,
      ),
    );
    await tester.pumpAndSettle();

    // 可点击：超支条目
    expect(find.text('看预算'), findsOneWidget);
    expect(find.text('看分类'), findsOneWidget);
    await tester.tap(find.text('看预算'));
    await tester.pump();
    expect(tapped, [HomeInsightTarget.budgets]);

    await tester.tap(find.text('看分类'));
    await tester.pump();
    expect(tapped, [HomeInsightTarget.budgets, HomeInsightTarget.categories]);

    // 不可点击：纯提示条目
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text(_noSpending.plainText, findRichText: true),
          matching: find.byType(InkWell),
        ),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
  });

  testWidgets('does not overflow with long category names', (tester) async {
    await tester.pumpWidget(
      _host(
        const HomeInsight(
          items: [
            HomeInsightItem(
              kind: HomeInsightKind.topCategory,
              tone: HomeInsightTone.neutral,
              target: HomeInsightTarget.categories,
              actionLabel: '看分类',
              segments: [
                HomeInsightSegment('日常饮食开销与外卖配送占本月支出 '),
                HomeInsightSegment('47%', emphasis: true),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
