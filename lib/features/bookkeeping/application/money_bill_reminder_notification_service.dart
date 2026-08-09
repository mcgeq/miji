import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';

class MoneyBillReminderNotificationService {
  const MoneyBillReminderNotificationService({
    required this.notificationService,
    this._now,
  });

  final AppNotificationService notificationService;
  final DateTime Function()? _now;

  Future<void> scanAndNotify({
    required String userId,
    required List<MoneyBillReminderEntity> reminders,
    Map<String, MoneyAccountEntity> accountsById = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dateOnly((_now ?? DateTime.now)());
    for (final reminder in reminders) {
      final storageKey = _storageKey(userId, reminder.id);
      if (!reminder.isActive) {
        await prefs.remove(storageKey);
        continue;
      }

      final amountMinor = _amountMinorFor(reminder, accountsById);
      if (reminder.amountSource ==
              MoneyBillReminderAmountSource.creditAccountDebt &&
          amountMinor <= 0) {
        await prefs.remove(storageKey);
        continue;
      }

      final alert = _alertFor(reminder, today, amountMinor);
      if (alert == null) {
        await prefs.remove(storageKey);
        continue;
      }

      final token = _alertToken(reminder, alert);
      if (prefs.getString(storageKey) == token) {
        continue;
      }

      final shown = await notificationService.showBillReminder(
        id: _notificationId(userId, reminder.id),
        title: alert.title,
        body: alert.body,
        payload: reminder.id,
      );
      if (shown) {
        await prefs.setString(storageKey, token);
      }
    }
  }

  _BillReminderAlert? _alertFor(
    MoneyBillReminderEntity reminder,
    DateTime today,
    int amountMinor,
  ) {
    final dueDate = _effectiveDueDate(reminder, today);
    final remindFrom = dueDate.subtract(
      Duration(days: reminder.remindBeforeDays),
    );
    if (today.isBefore(remindFrom)) {
      return null;
    }

    final dayDelta = dueDate.difference(today).inDays;
    final dueText = switch (dayDelta) {
      0 => '今天到期',
      > 0 => '$dayDelta 天后到期',
      _ => '已逾期 ${-dayDelta} 天',
    };
    return _BillReminderAlert(
      title: '账单提醒',
      body:
          '${reminder.name} $dueText，金额 '
          '${formatMoneyMinor(amountMinor, reminder.currencyCode)}。',
      dueDate: dueDate,
      overdueDays: dayDelta < 0 ? -dayDelta : 0,
    );
  }

  int _amountMinorFor(
    MoneyBillReminderEntity reminder,
    Map<String, MoneyAccountEntity> accountsById,
  ) {
    if (reminder.amountSource ==
        MoneyBillReminderAmountSource.creditAccountDebt) {
      final account = accountsById[reminder.accountId];
      return account?.effectivePostedDebtMinor ?? 0;
    }
    return reminder.amountMinor;
  }

  String _alertToken(
    MoneyBillReminderEntity reminder,
    _BillReminderAlert alert,
  ) {
    final overdue = alert.overdueDays;
    // 逾期阶段纳入 token：随逾期天数增长变化，实现"逾期逐日复推"，
    // 直到用户处理（status）或到期日（dueDate）变化。
    return '${alert.dueDate.millisecondsSinceEpoch}'
        ':${reminder.status.storageValue}'
        '${overdue > 0 ? ':od$overdue' : ''}';
  }

  String _storageKey(String userId, String reminderId) {
    return 'bill_reminder_alert::$userId::$reminderId';
  }

  int _notificationId(String userId, String reminderId) {
    var value = 29;
    for (final codeUnit in '$userId::$reminderId'.codeUnits) {
      value = 37 * value + codeUnit;
    }
    return value & 0x7fffffff;
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  DateTime _effectiveDueDate(MoneyBillReminderEntity reminder, DateTime today) {
    final dueDate = _dateOnly(reminder.dueDate);
    final repeatType = reminder.repeatPeriodType;
    final interval = reminder.repeatInterval ?? 1;
    if (repeatType == null || interval <= 0 || !dueDate.isBefore(today)) {
      return dueDate;
    }

    return switch (repeatType) {
      MoneyBillReminderRepeatPeriodType.daily => dueDate.add(
        Duration(days: _repeatSteps(dueDate, today, interval) * interval),
      ),
      MoneyBillReminderRepeatPeriodType.weekly => dueDate.add(
        Duration(
          days: _repeatSteps(dueDate, today, interval * 7) * interval * 7,
        ),
      ),
      MoneyBillReminderRepeatPeriodType.monthly => _nextMonthlyDueDate(
        dueDate,
        today,
        interval,
      ),
      MoneyBillReminderRepeatPeriodType.yearly => _nextYearlyDueDate(
        dueDate,
        today,
        interval,
      ),
    };
  }

  int _repeatSteps(DateTime start, DateTime today, int intervalDays) {
    final days = today.difference(start).inDays;
    return (days / intervalDays).ceil();
  }

  DateTime _nextMonthlyDueDate(DateTime start, DateTime today, int interval) {
    var cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(today)) {
      cursor = _dayInMonth(cursor.year, cursor.month + interval, start.day);
    }
    return cursor;
  }

  DateTime _nextYearlyDueDate(DateTime start, DateTime today, int interval) {
    var cursor = DateTime(start.year, start.month, start.day);
    while (cursor.isBefore(today)) {
      cursor = _dayInMonth(cursor.year + interval, start.month, start.day);
    }
    return cursor;
  }

  DateTime _dayInMonth(int year, int month, int day) {
    final monthStart = DateTime(year, month);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return DateTime(
      monthStart.year,
      monthStart.month,
      day > lastDay ? lastDay : day,
    );
  }
}

class _BillReminderAlert {
  const _BillReminderAlert({
    required this.title,
    required this.body,
    required this.dueDate,
    this.overdueDays = 0,
  });

  final String title;
  final String body;
  final DateTime dueDate;
  final int overdueDays;
}
