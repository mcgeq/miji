import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_bill_reminder_notification_service.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  MoneyBillReminderEntity reminder({
    String id = 'reminder-1',
    MoneyBillReminderAmountSource amountSource =
        MoneyBillReminderAmountSource.staticAmount,
    MoneyBillReminderRepeatPeriodType? repeatPeriodType,
    int? repeatInterval,
    int remindBeforeDays = 0,
    DateTime? dueDate,
  }) {
    return MoneyBillReminderEntity(
      id: id,
      userId: 'user-1',
      name: '信用卡账单',
      amountMinor: 10000,
      currencyCode: 'CNY',
      dueDate: dueDate ?? DateTime(2026, 7, 19),
      remindBeforeDays: remindBeforeDays,
      repeatPeriodType: repeatPeriodType,
      repeatInterval: repeatInterval,
      accountId: 'account-1',
      status: MoneyBillReminderStatus.pending,
      sourceType: MoneyBillReminderSourceType.manual,
      amountSource: amountSource,
      autoManaged: false,
      version: 1,
      isDeleted: false,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    );
  }

  test('overdue reminder is re-pushed on each following day', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBillReminderNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 20, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [reminder(dueDate: DateTime(2026, 7, 19))],
    );
    // 同一天再次扫描不重复提醒。
    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [reminder(dueDate: DateTime(2026, 7, 19))],
    );
    expect(notifications.billReminders, hasLength(1));
    expect(notifications.billReminders.single.body, contains('已逾期 1 天'));

    // 第二天逾期天数变化，必须重新提醒。
    await MoneyBillReminderNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 21, 10),
    ).scanAndNotify(
      userId: 'user-1',
      reminders: [reminder(dueDate: DateTime(2026, 7, 19))],
    );

    expect(notifications.billReminders, hasLength(2));
    expect(notifications.billReminders.last.body, contains('已逾期 2 天'));
  });

  test('in-window reminder is shown once per due cycle', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBillReminderNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(dueDate: DateTime(2026, 7, 22), remindBeforeDays: 3),
      ],
    );
    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(dueDate: DateTime(2026, 7, 22), remindBeforeDays: 3),
      ],
    );

    expect(notifications.billReminders, hasLength(1));
    expect(notifications.billReminders.single.body, contains('3 天后到期'));
  });

  test('repeating reminder rolls due date forward and reminds once', () async {
    final notifications = _FakeNotificationService();
    var now = DateTime(2026, 8, 10, 10);
    final service = MoneyBillReminderNotificationService(
      notificationService: notifications,
      now: () => now,
    );

    // 逾期且未到下个提醒窗口（8/15 - 3 天 = 8/12 还没到）时不打扰。
    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(
          dueDate: DateTime(2026, 7, 15),
          remindBeforeDays: 3,
          repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
          repeatInterval: 1,
        ),
        reminder(
          id: 'reminder-2',
          dueDate: DateTime(2026, 8, 17),
          remindBeforeDays: 3,
        ),
      ],
    );
    expect(notifications.billReminders, isEmpty);

    // 下个周期进入提醒窗口：按月顺延到 8/15，提醒一次。
    now = DateTime(2026, 8, 13, 10);
    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(
          dueDate: DateTime(2026, 7, 15),
          remindBeforeDays: 3,
          repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
          repeatInterval: 1,
        ),
        reminder(
          id: 'reminder-2',
          dueDate: DateTime(2026, 8, 17),
          remindBeforeDays: 3,
        ),
      ],
    );

    expect(notifications.billReminders, hasLength(1));
    expect(notifications.billReminders.single.body, contains('2 天后到期'));

    // 同日重复扫描不重复推送。
    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(
          dueDate: DateTime(2026, 7, 15),
          remindBeforeDays: 3,
          repeatPeriodType: MoneyBillReminderRepeatPeriodType.monthly,
          repeatInterval: 1,
        ),
        reminder(
          id: 'reminder-2',
          dueDate: DateTime(2026, 8, 17),
          remindBeforeDays: 3,
        ),
      ],
    );
    expect(notifications.billReminders, hasLength(1));
  });

  test('credit debt reminder skips when debt is zero', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBillReminderNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      reminders: [
        reminder(
          dueDate: DateTime(2026, 7, 19),
          amountSource: MoneyBillReminderAmountSource.creditAccountDebt,
        ),
      ],
      accountsById: {
        'account-1': MoneyAccountEntity(
          id: 'account-1',
          userId: 'user-1',
          name: '信用卡',
          type: MoneyAccountType.creditCard,
          balanceMinor: 0,
          initialBalanceMinor: 50000,
          creditLimitMinor: 50000,
          postedDebtMinor: 0,
          frozenCreditMinor: 0,
          statementDay: null,
          budgetCycleStartDay: null,
          repaymentDay: null,
          autoRepaymentReminderEnabled: false,
          currencyCode: 'CNY',
          isShared: false,
          isVirtual: false,
          isActive: true,
          isDeleted: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      },
    );

    expect(notifications.billReminders, isEmpty);
  });
}

class _FakeNotificationService extends AppNotificationService {
  final List<_BillReminderCall> billReminders = [];

  @override
  Future<bool> showBillReminder({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    billReminders.add(
      _BillReminderCall(id: id, title: title, body: body, payload: payload),
    );
    return true;
  }
}

class _BillReminderCall {
  const _BillReminderCall({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final String title;
  final String body;
  final String? payload;
}
