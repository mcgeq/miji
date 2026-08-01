import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';

void main() {
  final now = DateTime(2026, 7, 19);

  test('orders overdue, due soon, budget exceeded, then normal items', () {
    final items = [
      MoneyReminderCenterItem(
        sourceType: MoneyReminderCenterSourceType.billReminder,
        sourceId: 'normal',
        title: '水电费',
        dueDate: DateTime(2026, 8, 1),
        amountMinor: 12000,
        currencyCode: 'CNY',
        actionType: MoneyReminderCenterActionType.recordTransaction,
      ),
      MoneyReminderCenterItem(
        sourceType: MoneyReminderCenterSourceType.budget,
        sourceId: 'budget',
        title: '餐饮预算',
        dueDate: DateTime(2026, 7, 31),
        amountMinor: 5000,
        currencyCode: 'CNY',
        isBudgetExceeded: true,
        actionType: MoneyReminderCenterActionType.viewBudget,
      ),
      MoneyReminderCenterItem(
        sourceType: MoneyReminderCenterSourceType.billReminder,
        sourceId: 'soon',
        title: '信用卡还款',
        dueDate: DateTime(2026, 7, 21),
        amountMinor: 80000,
        currencyCode: 'CNY',
        actionType: MoneyReminderCenterActionType.repay,
      ),
      MoneyReminderCenterItem(
        sourceType: MoneyReminderCenterSourceType.installment,
        sourceId: 'overdue',
        title: '分期第 2 期',
        dueDate: DateTime(2026, 7, 18),
        amountMinor: 30000,
        currencyCode: 'CNY',
        actionType: MoneyReminderCenterActionType.recordTransaction,
      ),
    ];

    final sorted = [...items]
      ..sort((left, right) => left.comparePriorityTo(right, today: now));

    expect(sorted.map((item) => item.sourceId), [
      'overdue',
      'soon',
      'budget',
      'normal',
    ]);
    expect(
      sorted.first.priority(today: now),
      MoneyReminderCenterPriority.overdue,
    );
    expect(
      sorted[1].priority(today: now),
      MoneyReminderCenterPriority.dueWithinThreeDays,
    );
  });

  test('state transitions retain source links and create stable item keys', () {
    final item = MoneyReminderCenterItem(
      sourceType: MoneyReminderCenterSourceType.creditCardBill,
      sourceId: 'statement-1',
      title: '招商银行还款',
      dueDate: DateTime(2026, 7, 22),
      amountMinor: 120000,
      currencyCode: 'CNY',
      ledgerId: 'ledger-1',
      accountId: 'account-1',
      actionType: MoneyReminderCenterActionType.repay,
    );

    final snoozed = item.snooze(until: DateTime(2026, 7, 21));
    final completed = snoozed.complete(at: DateTime(2026, 7, 20));
    final ignored = completed.ignore(at: DateTime(2026, 7, 21));

    expect(item.itemKey, 'credit_card_bill:statement-1:2026-07-22');
    expect(snoozed.state, MoneyReminderCenterState.snoozed);
    expect(snoozed.snoozedUntil, DateTime(2026, 7, 21));
    expect(completed.state, MoneyReminderCenterState.completed);
    expect(completed.processedAt, DateTime(2026, 7, 20));
    expect(ignored.state, MoneyReminderCenterState.ignored);
    expect(ignored.sourceId, 'statement-1');
    expect(ignored.ledgerId, 'ledger-1');
    expect(ignored.accountId, 'account-1');
    expect(ignored.actionType, MoneyReminderCenterActionType.repay);
  });
}
