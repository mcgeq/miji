import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';
import 'package:miji/features/home/presentation/home_quick_actions_row.dart';

Widget _host(Widget child) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(child: SizedBox(width: 360, child: child)),
    ),
  );
}

void main() {
  testWidgets('renders one icon per action and no text labels', (tester) async {
    const actions = [
      MoneyQuickAction.expense,
      MoneyQuickAction.income,
      MoneyQuickAction.transfer,
      MoneyQuickAction.budget,
    ];

    await tester.pumpWidget(
      _host(HomeQuickActionsRow(actions: actions, onAction: (_) {})),
    );

    for (final action in actions) {
      expect(
        find.byIcon(action.icon),
        findsOneWidget,
        reason: '${action.label} 图标应存在',
      );
      expect(
        find.text(action.label),
        findsNothing,
        reason: '${action.label} 不应再显示文字标签',
      );
    }
  });

  testWidgets('does not draw a border around the button', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeQuickActionsRow(
          actions: const [MoneyQuickAction.expense],
          onAction: (_) {},
        ),
      ),
    );

    // 图标外层只应有一个圆形底色容器，不应再有带边框的卡片。
    final decorated = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .toList();

    expect(decorated, isNotEmpty);
    for (final decoration in decorated) {
      expect(decoration.border, isNull);
      expect(decoration.borderRadius, isNull, reason: '图标底色应为圆形');
      expect(decoration.shape, BoxShape.circle);
    }
  });

  testWidgets('reports the tapped action', (tester) async {
    final tapped = <MoneyQuickAction>[];

    await tester.pumpWidget(
      _host(
        HomeQuickActionsRow(
          actions: const [MoneyQuickAction.expense, MoneyQuickAction.income],
          onAction: tapped.add,
        ),
      ),
    );

    await tester.tap(find.byIcon(MoneyQuickAction.income.icon));
    await tester.pump();

    expect(tapped, [MoneyQuickAction.income]);
  });
}
