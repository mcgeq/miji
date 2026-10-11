import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_filter_strip.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
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

  testWidgets('groups pending reminders by urgency', (tester) async {
    final today = DateTime.now();
    await _pumpSection(
      tester,
      pending: [
        _item(
          title: '逾期账单',
          state: MoneyReminderCenterState.pending,
          dueDate: today.subtract(const Duration(days: 3)),
        ),
        _item(
          title: '今天到期',
          state: MoneyReminderCenterState.pending,
          dueDate: today,
        ),
        _item(
          title: '以后再说',
          state: MoneyReminderCenterState.pending,
          dueDate: today.add(const Duration(days: 20)),
        ),
      ],
      history: const [],
    );

    // 原来是一条平铺列表，逾期项会被埋在十几条里。
    expect(find.text('已逾期'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
    expect(find.text('以后'), findsOneWidget);
    expect(find.text('逾期账单'), findsOneWidget);
    expect(find.text('今天到期'), findsOneWidget);
    expect(find.text('以后再说'), findsOneWidget);
  });

  testWidgets('offers a create entry point and an inline record action', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      pending: [_item(title: '信用卡还款', state: MoneyReminderCenterState.pending)],
      history: const [],
    );

    // 提醒中心以前只能「完成/延后/忽略」，无法新建账单提醒。
    expect(find.byTooltip('新增提醒'), findsOneWidget);
    // 行内按钮从「标记完成」改成「记账」：处理必须落到一笔流水上。
    expect(find.byTooltip('记账'), findsWidgets);
    expect(find.text('标记完成'), findsNothing);
  });

  testWidgets('budget reminders cannot be recorded', (tester) async {
    await _pumpSection(
      tester,
      pending: [
        _item(
          title: '餐饮预算',
          state: MoneyReminderCenterState.pending,
          actionType: MoneyReminderCenterActionType.viewBudget,
          sourceType: MoneyReminderCenterSourceType.budget,
        ),
      ],
      history: const [],
    );

    // 预算超支是结果不是待办，没有可以「结清」的动作。
    expect(find.byTooltip('记账'), findsNothing);
    expect(find.byTooltip('忽略'), findsOneWidget);
  });

  testWidgets('long press enters selection mode with a bulk action bar', (
    tester,
  ) async {
    await _pumpSection(
      tester,
      pending: [
        _item(title: '房租提醒', state: MoneyReminderCenterState.pending),
        _item(title: '信用卡还款', state: MoneyReminderCenterState.pending),
      ],
      history: const [],
    );

    await tester.longPress(find.text('房租提醒'));
    await tester.pumpAndSettle();

    expect(find.text('已选 1 项'), findsOneWidget);
    // 批量条只留「延后 / 忽略」：完成必然要走一次记账，连弹 N 个表单不成立。
    // 所以要明说「忽略不产生流水」，否则用户会把它读成「稍后自己补记」。
    expect(find.text('记账请逐条操作，忽略不会产生流水'), findsOneWidget);
    expect(find.text('延后'), findsOneWidget);
    expect(find.text('忽略'), findsOneWidget);
    expect(find.text('完成'), findsNothing);

    // 多选模式下点另一条继续勾选。
    await tester.tap(find.text('信用卡还款'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsOneWidget);

    // 退出多选。
    await tester.tap(find.byTooltip('退出多选'));
    await tester.pumpAndSettle();
    expect(find.text('已选 2 项'), findsNothing);
  });

  testWidgets('bulk ignore dismisses every selected reminder', (tester) async {
    final ignored = <String>[];
    await _pumpSection(
      tester,
      pending: [
        _item(title: '房租提醒', state: MoneyReminderCenterState.pending),
        _item(title: '信用卡还款', state: MoneyReminderCenterState.pending),
      ],
      history: const [],
      onIgnore: (item) => ignored.add(item.title),
    );

    await tester.longPress(find.text('房租提醒'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('信用卡还款'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('忽略'));
    await tester.pumpAndSettle();
    // 批量操作后会弹 toast，等它的定时器走完，避免 teardown 报 pending timer。
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    expect(ignored, containsAll(<String>['房租提醒', '信用卡还款']));
    expect(find.text('已选 2 项'), findsNothing);
  });
  testWidgets('exposes an edit entry point only for bill reminders', (
    tester,
  ) async {
    // 删掉不可达的 openReminder 分支后卡片点击变成了「记账」，
    // 编辑只能从标题行的菜单进——预算/分期等派生提醒没有自己的表单，
    // 不该给出这个入口，否则点了会弹空的编辑框。
    await _pumpSection(
      tester,
      pending: [
        _item(
          title: '房租提醒',
          state: MoneyReminderCenterState.pending,
          sourceType: MoneyReminderCenterSourceType.billReminder,
          actionType: MoneyReminderCenterActionType.recordTransaction,
        ),
        _item(title: '信用卡还款', state: MoneyReminderCenterState.pending),
      ],
      history: const [],
      reminders: [_editableBillReminder],
    );

    expect(find.byTooltip('更多'), findsOneWidget);

    await tester.tap(find.byTooltip('更多'));
    await tester.pumpAndSettle();
    expect(find.text('编辑提醒'), findsOneWidget);
  });
}

Future<void> _pumpSection(
  WidgetTester tester, {
  required List<MoneyReminderCenterItem> pending,
  required List<MoneyReminderCenterItem> history,
  List<MoneyBillReminderEntity> reminders = const [],
  void Function(MoneyReminderCenterItem item)? onComplete,
  void Function(MoneyReminderCenterItem item)? onIgnore,
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
        currentUserBillRemindersProvider.overrideWith((ref) async* {
          yield reminders;
        }),
        if (onComplete != null || onIgnore != null)
          currentUserReminderCenterActionsProvider.overrideWith((ref) {
            return _FakeReminderActions(
              onComplete: onComplete,
              onIgnore: onIgnore,
            );
          }),
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
  MoneyReminderCenterActionType actionType =
      MoneyReminderCenterActionType.repay,
  MoneyReminderCenterSourceType sourceType =
      MoneyReminderCenterSourceType.creditCardBill,
}) {
  return MoneyReminderCenterItem(
    sourceType: sourceType,
    sourceId: 'src-$title',
    title: title,
    dueDate: dueDate ?? DateTime(2026, 9, 1),
    amountMinor: 10000,
    currencyCode: 'CNY',
    actionType: actionType,
    state: state,
    snoozedUntil: snoozedUntil,
    processedAt: processedAt,
  );
}

/// 与 `_item(sourceType: billReminder)` 配对的源头提醒：
/// sourceId 是 `src-<title>`，只有 id 对得上，卡片才会给出「编辑提醒」。
final MoneyBillReminderEntity _editableBillReminder = MoneyBillReminderEntity(
  id: 'src-房租提醒',
  userId: 'user-1',
  name: '房租',
  amountMinor: 10000,
  currencyCode: 'CNY',
  dueDate: DateTime(2026, 9, 1),
  remindBeforeDays: 0,
  status: MoneyBillReminderStatus.pending,
  sourceType: MoneyBillReminderSourceType.manual,
  amountSource: MoneyBillReminderAmountSource.staticAmount,
  autoManaged: false,
  version: 1,
  isDeleted: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// 只关心「完成 / 忽略」写入了哪些项，其余动作留空。
class _FakeReminderActions implements CurrentUserReminderCenterActions {
  _FakeReminderActions({this.onComplete, this.onIgnore});

  final void Function(MoneyReminderCenterItem item)? onComplete;
  final void Function(MoneyReminderCenterItem item)? onIgnore;

  @override
  Future<void> complete(
    MoneyReminderCenterItem item, {
    String? transactionId,
  }) async {
    onComplete?.call(item);
  }

  @override
  Future<void> ignore(MoneyReminderCenterItem item) async {
    onIgnore?.call(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
