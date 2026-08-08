import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_filter_strip.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  testWidgets('shows pending view with count by default', (tester) async {
    await _pumpSection(
      tester,
      pending: [_item(title: '信用卡还款', state: MoneyReminderCenterState.pending)],
      history: const [],
    );

    expect(find.text('待处理 1'), findsOneWidget);
    expect(find.text('处理历史'), findsOneWidget);
    expect(find.text('信用卡还款'), findsOneWidget);
    expect(find.byType(AppSwipeActionTile), findsOneWidget);
  });

  testWidgets('pending card shows snoozed info', (tester) async {
    await _pumpSection(
      tester,
      pending: [
        _item(
          title: '分期还款',
          state: MoneyReminderCenterState.snoozed,
          snoozedUntil: DateTime(2026, 9, 10),
        ),
      ],
      history: const [],
    );

    expect(find.text('已延后至 09-10'), findsOneWidget);
  });

  testWidgets('history view shows result badge and processed time', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      pending: const [],
      history: [
        _item(
          title: '餐饮预算',
          state: MoneyReminderCenterState.completed,
          processedAt: DateTime(2026, 8, 8, 9, 30),
        ),
      ],
    );

    await tester.tap(find.text('处理历史'));
    await tester.pumpAndSettle();

    expect(find.text('餐饮预算'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBadge), matching: find.text('已完成')),
      findsOneWidget,
    );
    expect(find.text('处理于 08-08 09:30'), findsOneWidget);
    expect(find.byType(AppSwipeActionTile), findsNothing);
  });

  testWidgets('history filters by result state', (tester) async {
    await _pumpSection(
      tester,
      pending: const [],
      history: [
        _item(title: '餐饮预算', state: MoneyReminderCenterState.completed),
        _item(title: '房租提醒', state: MoneyReminderCenterState.ignored),
      ],
    );

    await tester.tap(find.text('处理历史'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮预算'), findsOneWidget);
    expect(find.text('房租提醒'), findsOneWidget);

    await tester.tap(_filterChip('已忽略'));
    await tester.pumpAndSettle();
    expect(find.text('房租提醒'), findsOneWidget);
    expect(find.text('餐饮预算'), findsNothing);

    await tester.tap(_filterChip('已完成'));
    await tester.pumpAndSettle();
    expect(find.text('餐饮预算'), findsOneWidget);
    expect(find.text('房租提醒'), findsNothing);
  });

  testWidgets('shows empty states per view', (tester) async {
    await _pumpSection(tester, pending: const [], history: const []);

    expect(find.text('待处理 0'), findsOneWidget);
    expect(find.text('暂无待处理提醒'), findsOneWidget);

    await tester.tap(find.text('处理历史'));
    await tester.pumpAndSettle();
    expect(find.text('暂无处理历史'), findsOneWidget);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<MoneyReminderCenterItem> pending,
  required List<MoneyReminderCenterItem> history,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserPendingReminderCenterItemsProvider.overrideWith(
          (ref) async => pending,
        ),
        currentUserReminderCenterHistoryProvider.overrideWith(
          (ref) async => history,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: MoneyReminderCenterSection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _filterChip(String label) {
  return find.descendant(
    of: find.byType(AppFilterStrip),
    matching: find.text(label),
  );
}

MoneyReminderCenterItem _item({
  required String title,
  required MoneyReminderCenterState state,
  DateTime? dueDate,
  DateTime? snoozedUntil,
  DateTime? processedAt,
}) {
  return MoneyReminderCenterItem(
    sourceType: MoneyReminderCenterSourceType.creditCardBill,
    sourceId: 'src-$title',
    title: title,
    dueDate: dueDate ?? DateTime(2026, 9, 1),
    amountMinor: 10000,
    currencyCode: 'CNY',
    actionType: MoneyReminderCenterActionType.repay,
    state: state,
    snoozedUntil: snoozedUntil,
    processedAt: processedAt,
  );
}
