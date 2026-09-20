import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_category_structure_panel.dart';

/// 等额两笔：扇区各占 180°，正左方必定落在第二段，点击测试不依赖角度换算。
const _evenItems = [
  HomeCategorySpendingItem(
    categoryId: 'food',
    categoryName: '餐饮',
    amountMinor: 100000,
    currencyCode: 'CNY',
    ratio: 0.5,
  ),
  HomeCategorySpendingItem(
    categoryId: 'transport',
    categoryName: '交通',
    amountMinor: 100000,
    currencyCode: 'CNY',
    ratio: 0.5,
  ),
];

/// 长名字 + 大金额：用来验证不会被截断、也不会把行撑破。
const _longItems = [
  HomeCategorySpendingItem(
    categoryId: 'social',
    categoryName: '日常饮食开销',
    amountMinor: 1234567,
    currencyCode: 'CNY',
    ratio: 0.75,
  ),
  HomeCategorySpendingItem(
    categoryId: 'transport',
    categoryName: '交通',
    amountMinor: 400000,
    currencyCode: 'CNY',
    ratio: 0.25,
  ),
];

Widget _host(
  List<HomeCategorySpendingItem> items, {
  double width = 420,
}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(
            width: width,
            child: HomeCategoryStructurePanel(
              type: HomeCategoryStructureType.expense,
              onTypeChanged: (_) {},
              isLoading: false,
              items: items,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('selects donut slice and highlights matching category row', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_evenItems, width: 720));
    await tester.pumpAndSettle();

    expect(_selectedSummaryText(tester), contains('餐饮'));
    expect(_rowBorderColor(tester, 'transport'), Colors.transparent);

    // 半径 64、内圈 40、扇区 15~19：中心左侧 47px 处必定落在扇区上。
    final chartRect = tester.getRect(find.byType(PieChart));
    await tester.tapAt(chartRect.center + const Offset(-47, 0));
    await tester.pumpAndSettle();

    expect(_selectedSummaryText(tester), contains('交通'));
    expect(_selectedSummaryText(tester), isNot(contains('餐饮')));
    expect(_rowBorderColor(tester, 'transport'), isNot(Colors.transparent));
  });

  testWidgets('selecting a legend row updates the donut summary', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_evenItems, width: 720));
    await tester.pumpAndSettle();

    expect(_selectedSummaryText(tester), contains('餐饮'));

    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('home-category-row-transport')),
        matching: find.text('交通'),
      ),
    );
    await tester.pumpAndSettle();

    expect(_selectedSummaryText(tester), contains('交通'));
  });

  testWidgets('shows the full category name at phone width', (tester) async {
    // 窄宽度下环形图与图例必须上下排，否则图例列会被压到放不下分类名。
    await tester.pumpWidget(_host(_longItems, width: 326));
    await tester.pumpAndSettle();

    _expectRowTextNotTruncated(tester, 'social', '日常饮食开销');
    _expectRowTextNotTruncated(tester, 'transport', '交通');
    _expectRowTextNotTruncated(tester, 'social', '¥12,345.67');
  });

  testWidgets('lays the donut beside the legend when width allows', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_longItems, width: 720));
    await tester.pumpAndSettle();

    final donut = tester.getRect(find.byType(PieChart));
    final panel = tester.getRect(find.byType(HomeCategoryStructurePanel));
    expect(donut.center.dx, lessThan(panel.center.dx));
  });

  testWidgets('legend rows never overflow at narrow widths', (tester) async {
    // 旧实现里金额与百分比是非弹性子项：它们的固有宽度一旦超过行宽，
    // 整行就会溢出，同时把 Expanded 的名字挤成 0 宽。
    for (final width in [280.0, 326.0, 400.0, 520.0, 720.0]) {
      await tester.pumpWidget(_host(_longItems, width: width));
      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: '宽度 $width 时不应出现溢出',
      );
    }
  });

  testWidgets('renders the empty state when there is no data', (tester) async {
    await tester.pumpWidget(_host(const []));
    await tester.pumpAndSettle();

    expect(
      find.text(HomeCategoryStructureType.expense.emptyText),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

String _selectedSummaryText(WidgetTester tester) {
  return tester
      .widgetList<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('home-category-selected-summary')),
          matching: find.byType(Text),
        ),
      )
      .map((text) => text.data ?? '')
      .join('|');
}

Color _rowBorderColor(WidgetTester tester, String categoryId) {
  final row = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('home-category-row-$categoryId')),
  );
  final decoration = row.decoration as BoxDecoration;
  final border = decoration.border as Border;
  return border.top.color;
}

/// 断言图例里的文本没有被省略号截断：实际渲染宽度要不小于文本自身需要的宽度。
void _expectRowTextNotTruncated(
  WidgetTester tester,
  String categoryId,
  String text,
) {
  final finder = find.descendant(
    of: find.byKey(ValueKey('home-category-row-$categoryId')),
    matching: find.text(text),
  );
  expect(finder, findsOneWidget, reason: '图例 $categoryId 应包含「$text」');

  final widget = tester.widget<Text>(finder);
  final painter = TextPainter(
    text: TextSpan(text: text, style: widget.style),
    textDirection: TextDirection.ltr,
  )..layout();

  final rendered = tester.getSize(finder);
  expect(
    rendered.width,
    greaterThanOrEqualTo(painter.width - 0.5),
    reason: '「$text」被截断了（渲染 ${rendered.width} < 需要 ${painter.width}）',
  );
}
