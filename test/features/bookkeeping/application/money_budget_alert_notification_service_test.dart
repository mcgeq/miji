import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_budget_alert_notification_service.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('notifies 80 percent stage once per day', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 8000)],
    );
    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 9000)],
    );

    expect(notifications.budgetAlerts, hasLength(1));
    expect(notifications.budgetAlerts.single.title, contains('80%'));
  });

  test('notifies again on the next day for the same stage', () async {
    final notifications = _FakeNotificationService();

    await MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    ).scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 8000)],
    );
    await MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 20, 10),
    ).scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 8500)],
    );

    expect(notifications.budgetAlerts, hasLength(2));
  });

  test('notifies 100 percent stage after 80 percent stage', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 8000)],
    );
    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 10000)],
    );

    expect(notifications.budgetAlerts, hasLength(2));
    expect(notifications.budgetAlerts.last.title, contains('100%'));
  });

  test('does not notify disabled or below-threshold budgets', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [
        _budget(id: 'disabled', usedAmountMinor: 10000, alertEnabled: false),
        _budget(id: 'below', usedAmountMinor: 7900),
      ],
    );

    expect(notifications.budgetAlerts, isEmpty);
  });

  test('snoozes budget alert until selected date', () async {
    final notifications = _FakeNotificationService();
    final service = MoneyBudgetAlertNotificationService(
      notificationService: notifications,
      now: () => DateTime(2026, 7, 19, 10),
    );

    await service.snoozeBudgetAlert(
      userId: 'user-1',
      budgetId: 'budget-1',
      until: DateTime(2026, 7, 21),
    );
    await service.scanAndNotify(
      userId: 'user-1',
      budgets: [_budget(usedAmountMinor: 10000)],
    );

    expect(notifications.budgetAlerts, isEmpty);
  });
}

MoneyBudgetEntity _budget({
  String id = 'budget-1',
  int amountMinor = 10000,
  required int usedAmountMinor,
  bool alertEnabled = true,
}) {
  return MoneyBudgetEntity(
    id: id,
    userId: 'user-1',
    ledgerId: 'ledger-1',
    scopeType: MoneyBudgetScopeType.all,
    name: '月度支出',
    trackingType: MoneyBudgetTrackingType.expenseLimit,
    periodType: MoneyBudgetPeriodType.monthly,
    repeatInterval: 1,
    amountMinor: amountMinor,
    currencyCode: 'CNY',
    periodStart: DateTime(2026, 7),
    periodEnd: DateTime(2026, 7, 31, 23, 59, 59, 999),
    categoryId: null,
    subCategoryId: null,
    usedAmountMinor: usedAmountMinor,
    isActive: true,
    alertEnabled: alertEnabled,
    alertThresholdPercent: 80,
    createdAt: DateTime(2026, 7),
    updatedAt: DateTime(2026, 7),
  );
}

class _FakeNotificationService extends AppNotificationService {
  final List<_BudgetAlertCall> budgetAlerts = [];

  @override
  Future<bool> showBudgetAlert({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    budgetAlerts.add(
      _BudgetAlertCall(id: id, title: title, body: body, payload: payload),
    );
    return true;
  }
}

class _BudgetAlertCall {
  const _BudgetAlertCall({
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
