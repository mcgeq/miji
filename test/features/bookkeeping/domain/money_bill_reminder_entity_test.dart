import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';

void main() {
  group('effectiveBillReminderDueDate', () {
    test('keeps the original date when it is still in the future', () {
      final reminder = _reminder(dueDate: DateTime(2026, 9, 20));
      final today = DateTime(2026, 9, 18);

      expect(
        effectiveBillReminderDueDate(reminder, today),
        DateTime(2026, 9, 20),
      );
    });

    test('keeps the original date when the reminder does not repeat', () {
      final reminder = _reminder(dueDate: DateTime(2026, 1, 5));
      final today = DateTime(2026, 9, 18);

      expect(
        effectiveBillReminderDueDate(reminder, today),
        DateTime(2026, 1, 5),
      );
    });

    test('rolls a monthly reminder forward to the next occurrence', () {
      final reminder = _reminder(
        dueDate: DateTime(2026, 1, 5),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
      );

      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 9, 18)),
        DateTime(2026, 10, 5),
      );
    });

    test('rolls a weekly reminder forward to the next occurrence', () {
      final reminder = _reminder(
        dueDate: DateTime(2026, 9, 1),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.weekly,
      );

      // 09-01 起每 7 天 → 09-15、09-22。
      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 9, 18)),
        DateTime(2026, 9, 22),
      );
    });

    test('clamps the day of month to the last day of a short month', () {
      final reminder = _reminder(
        dueDate: DateTime(2026, 1, 31),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
      );

      // 2 月没有 31 日 → 收到 02-28。
      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 2, 1)),
        DateTime(2026, 2, 28),
      );
    });

    test('respects the repeat interval', () {
      final reminder = _reminder(
        dueDate: DateTime(2026, 1, 5),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
        repeatInterval: 3,
      );

      // 01-05 + 3 个月 → 04-05、07-05、10-05。
      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 9, 18)),
        DateTime(2026, 10, 5),
      );
    });

    test('rolls a yearly reminder forward', () {
      final reminder = _reminder(
        dueDate: DateTime(2020, 3, 10),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.yearly,
      );

      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 9, 18)),
        DateTime(2027, 3, 10),
      );
    });

    test('treats a due date of today as due today', () {
      final reminder = _reminder(
        dueDate: DateTime(2026, 9, 18),
        repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
      );

      expect(
        effectiveBillReminderDueDate(reminder, DateTime(2026, 9, 18)),
        DateTime(2026, 9, 18),
      );
    });
  });
}

MoneyBillReminderEntity _reminder({
  required DateTime dueDate,
  MoneyBillReminderRepeatPeriodType? repeatPeriodType,
  int? repeatInterval,
}) {
  return MoneyBillReminderEntity(
    id: 'reminder-1',
    userId: 'user-1',
    name: '房租',
    version: 1,
    isDeleted: false,
    amountMinor: 320000,
    dueDate: dueDate,
    remindBeforeDays: 1,
    repeatPeriodType: repeatPeriodType,
    repeatInterval: repeatInterval,
    accountId: null,
    ledgerId: null,
    categoryId: null,
    relatedTransactionId: null,
    sourceType: MoneyBillReminderSourceType.manual,
    sourceKey: null,
    amountSource: MoneyBillReminderAmountSource.staticAmount,
    autoManaged: false,
    currencyCode: 'CNY',
    status: MoneyBillReminderStatus.pending,
    notes: null,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}
