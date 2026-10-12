import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_unified_reminders_providers.dart';
import 'package:miji/features/home/presentation/home_unified_reminders_card.dart';

const _money = HomeReminderItem(
  source: HomeReminderSource.money,
  severity: HomeReminderSeverity.dueSoon,
  title: '信用卡还款',
  subtitle: '10-15 到期',
  amountMinor: 234050,
  currencyCode: 'CNY',
  action: OpenMoneyRemindersAction(),
);

const _health = HomeReminderItem(
  source: HomeReminderSource.health,
  severity: HomeReminderSeverity.dueToday,
  title: '预计今天来经期',
  subtitle: '记得记录',
  action: OpenHealthAction(),
);

Widget host(Widget child) =>
    MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child));

void main() {
  testWidgets('renders items with source labels and amount', (tester) async {
    await tester.pumpWidget(
      host(
        HomeUnifiedRemindersCard(
          items: const [_money, _health],
          isLoading: false,
          onOpenAll: () {},
          onTapItem: (_) {},
        ),
      ),
    );
    expect(find.text('需要关注'), findsOneWidget);
    expect(find.text('信用卡还款'), findsOneWidget);
    expect(find.text('记账'), findsOneWidget);
    expect(find.text('健康'), findsOneWidget);
    expect(find.textContaining('2,340.5'), findsOneWidget);
  });

  testWidgets('tapping a row emits the item', (tester) async {
    HomeReminderItem? tapped;
    await tester.pumpWidget(
      host(
        HomeUnifiedRemindersCard(
          items: const [_health],
          isLoading: false,
          onOpenAll: () {},
          onTapItem: (item) => tapped = item,
        ),
      ),
    );
    await tester.tap(find.text('预计今天来经期'));
    expect(tapped?.source, HomeReminderSource.health);
  });

  testWidgets('hides when empty and not loading', (tester) async {
    await tester.pumpWidget(
      host(
        HomeUnifiedRemindersCard(
          items: const [],
          isLoading: false,
          onOpenAll: () {},
          onTapItem: (_) {},
        ),
      ),
    );
    expect(find.text('需要关注'), findsNothing);
  });
}
