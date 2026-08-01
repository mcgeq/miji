import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_category_structure_panel.dart';

void main() {
  testWidgets('selects donut slice and highlights matching category row', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              child: HomeCategoryStructurePanel(
                type: HomeCategoryStructureType.expense,
                onTypeChanged: (_) {},
                isLoading: false,
                items: const [
                  HomeCategorySpendingItem(
                    categoryId: 'food',
                    categoryName: '餐饮',
                    amountMinor: 60000,
                    currencyCode: 'CNY',
                    ratio: 0.6,
                  ),
                  HomeCategorySpendingItem(
                    categoryId: 'transport',
                    categoryName: '交通',
                    amountMinor: 40000,
                    currencyCode: 'CNY',
                    ratio: 0.4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(_findSelectedLabel('餐饮'), findsOneWidget);
    expect(_findSelectedLabel('交通'), findsNothing);
    expect(_rowBorderColor(tester, 'transport'), Colors.transparent);

    final chartRect = tester.getRect(find.byType(PieChart));
    await tester.tapAt(chartRect.centerLeft + const Offset(28, 0));
    await tester.pumpAndSettle();

    expect(_findSelectedLabel('餐饮'), findsNothing);
    expect(_findSelectedLabel('交通'), findsOneWidget);
    expect(_rowBorderColor(tester, 'transport'), isNot(Colors.transparent));
  });
}

Finder _findSelectedLabel(String text) {
  return find.descendant(
    of: find.byKey(const ValueKey('home-category-selected-summary')),
    matching: find.text(text),
  );
}

Color _rowBorderColor(WidgetTester tester, String categoryId) {
  final row = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('home-category-row-$categoryId')),
  );
  final decoration = row.decoration as BoxDecoration;
  final border = decoration.border as Border;
  return border.top.color;
}
