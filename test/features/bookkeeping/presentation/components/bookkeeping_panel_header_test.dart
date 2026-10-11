import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/presentation/components/bookkeeping_panel_header.dart';

void main() {
  testWidgets('lays search, toolbar and filters out in a fixed order', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: BookkeepingPanelHeader(
            searchRow: Text('SEARCH'),
            leading: Text('LEADING'),
            actions: [Icon(Icons.add)],
            filtersRow: Text('FILTERS'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final searchY = tester.getTopLeft(find.text('SEARCH')).dy;
    final leadingY = tester.getTopLeft(find.text('LEADING')).dy;
    final filtersY = tester.getTopLeft(find.text('FILTERS')).dy;
    // 搜索在最上，工具行其次，筛选行最后。
    expect(searchY, lessThan(leadingY));
    expect(leadingY, lessThan(filtersY));

    // leading 在左，动作在右。
    final leadingX = tester.getTopLeft(find.text('LEADING')).dx;
    final actionX = tester.getTopLeft(find.byIcon(Icons.add)).dx;
    expect(leadingX, lessThan(actionX));
  });

  testWidgets('renders only the slots it is given', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: BookkeepingPanelHeader(actions: [Icon(Icons.add)]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('search field shows a clear button only when there is text', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var changed = 'seed';
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: BookkeepingPanelSearchField(
            controller: controller,
            hintText: '搜索',
            onChanged: (value) => changed = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('清除搜索'), findsNothing);

    await tester.enterText(find.byType(TextField), 'abc');
    await tester.pumpAndSettle();
    expect(find.byTooltip('清除搜索'), findsOneWidget);

    await tester.tap(find.byTooltip('清除搜索'));
    await tester.pumpAndSettle();
    expect(controller.text, '');
    expect(changed, '');
    expect(find.byTooltip('清除搜索'), findsNothing);
  });
}
