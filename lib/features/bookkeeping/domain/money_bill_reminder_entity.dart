enum MoneyBillReminderStatus {
  pending('pending'),
  done('done'),
  cancelled('cancelled');

  const MoneyBillReminderStatus(this.storageValue);

  final String storageValue;

  static MoneyBillReminderStatus fromStorageValue(String value) {
    return MoneyBillReminderStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => MoneyBillReminderStatus.pending,
    );
  }
}

enum MoneyBillReminderRepeatPeriodType {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const MoneyBillReminderRepeatPeriodType(this.storageValue);

  final String storageValue;

  static MoneyBillReminderRepeatPeriodType fromStorageValue(String value) {
    return MoneyBillReminderRepeatPeriodType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MoneyBillReminderRepeatPeriodType.monthly,
    );
  }
}

enum MoneyBillReminderSourceType {
  manual('manual'),
  creditRepayment('credit_repayment');

  const MoneyBillReminderSourceType(this.storageValue);

  final String storageValue;

  static MoneyBillReminderSourceType fromStorageValue(String value) {
    return MoneyBillReminderSourceType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MoneyBillReminderSourceType.manual,
    );
  }
}

enum MoneyBillReminderAmountSource {
  staticAmount('static'),
  creditAccountDebt('credit_account_debt');

  const MoneyBillReminderAmountSource(this.storageValue);

  final String storageValue;

  static MoneyBillReminderAmountSource fromStorageValue(String value) {
    return MoneyBillReminderAmountSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => MoneyBillReminderAmountSource.staticAmount,
    );
  }
}

class MoneyBillReminderEntity {
  const MoneyBillReminderEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountMinor,
    required this.currencyCode,
    required this.dueDate,
    required this.remindBeforeDays,
    required this.status,
    required this.sourceType,
    required this.amountSource,
    required this.autoManaged,
    required this.version,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.repeatPeriodType,
    this.repeatInterval,
    this.accountId,
    this.ledgerId,
    this.categoryId,
    this.relatedTransactionId,
    this.sourceKey,
    this.notes,
    this.deviceId,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String name;
  final int amountMinor;
  final String currencyCode;
  final DateTime dueDate;
  final int remindBeforeDays;
  final MoneyBillReminderRepeatPeriodType? repeatPeriodType;
  final int? repeatInterval;
  final String? accountId;
  final String? ledgerId;
  final String? categoryId;
  final String? relatedTransactionId;
  final MoneyBillReminderStatus status;
  final MoneyBillReminderSourceType sourceType;
  final String? sourceKey;
  final MoneyBillReminderAmountSource amountSource;
  final bool autoManaged;
  final String? notes;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isActive => !isDeleted && status == MoneyBillReminderStatus.pending;

  bool get isCreditRepayment =>
      sourceType == MoneyBillReminderSourceType.creditRepayment;
}

class MoneyBillReminderDraft {
  const MoneyBillReminderDraft({
    required this.name,
    required this.amountMinor,
    required this.dueDate,
    this.remindBeforeDays = 1,
    this.repeatPeriodType,
    this.repeatInterval,
    this.accountId,
    this.ledgerId,
    this.categoryId,
    this.relatedTransactionId,
    this.sourceType = MoneyBillReminderSourceType.manual,
    this.sourceKey,
    this.amountSource = MoneyBillReminderAmountSource.staticAmount,
    this.autoManaged = false,
    this.currencyCode = 'CNY',
    this.notes,
  });

  final String name;
  final int amountMinor;
  final DateTime dueDate;
  final int remindBeforeDays;
  final MoneyBillReminderRepeatPeriodType? repeatPeriodType;
  final int? repeatInterval;
  final String? accountId;
  final String? ledgerId;
  final String? categoryId;
  final String? relatedTransactionId;
  final MoneyBillReminderSourceType sourceType;
  final String? sourceKey;
  final MoneyBillReminderAmountSource amountSource;
  final bool autoManaged;
  final String currencyCode;
  final String? notes;
}

class MoneyBillReminderUpdate {
  const MoneyBillReminderUpdate({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.dueDate,
    required this.remindBeforeDays,
    this.repeatPeriodType,
    this.repeatInterval,
    this.accountId,
    this.ledgerId,
    this.categoryId,
    this.relatedTransactionId,
    this.sourceType = MoneyBillReminderSourceType.manual,
    this.sourceKey,
    this.amountSource = MoneyBillReminderAmountSource.staticAmount,
    this.autoManaged = false,
    this.currencyCode = 'CNY',
    this.status = MoneyBillReminderStatus.pending,
    this.notes,
  });

  final String id;
  final String name;
  final int amountMinor;
  final DateTime dueDate;
  final int remindBeforeDays;
  final MoneyBillReminderRepeatPeriodType? repeatPeriodType;
  final int? repeatInterval;
  final String? accountId;
  final String? ledgerId;
  final String? categoryId;
  final String? relatedTransactionId;
  final MoneyBillReminderSourceType sourceType;
  final String? sourceKey;
  final MoneyBillReminderAmountSource amountSource;
  final bool autoManaged;
  final String currencyCode;
  final MoneyBillReminderStatus status;
  final String? notes;
}

/// 账单提醒的「生效到期日」。
///
/// 重复提醒（每天/每周/每月/每年）的 `dueDate` 是首次到期日，早于今天就说明已经
/// 滚过了若干周期。把所有已过的周期推到下一次。
///
/// 通知服务、统计页「待付账单」都走这一个口径，避免同一件事两处算法不一致
/// （此前统计卡片直接用原始 `dueDate`，重复提醒会算错窗口）。
DateTime effectiveBillReminderDueDate(
  MoneyBillReminderEntity reminder,
  DateTime today,
) {
  final dueDate = _billReminderDateOnly(reminder.dueDate);
  final repeatType = reminder.repeatPeriodType;
  final interval = reminder.repeatInterval ?? 1;
  final current = _billReminderDateOnly(today);
  if (repeatType == null || interval <= 0 || !dueDate.isBefore(current)) {
    return dueDate;
  }

  return switch (repeatType) {
    MoneyBillReminderRepeatPeriodType.daily => dueDate.add(
      Duration(
        days: _billReminderRepeatSteps(dueDate, current, interval) * interval,
      ),
    ),
    MoneyBillReminderRepeatPeriodType.weekly => dueDate.add(
      Duration(
        days:
            _billReminderRepeatSteps(dueDate, current, interval * 7) *
            interval *
            7,
      ),
    ),
    MoneyBillReminderRepeatPeriodType.monthly => _billReminderNextMonthly(
      dueDate,
      current,
      interval,
    ),
    MoneyBillReminderRepeatPeriodType.yearly => _billReminderNextYearly(
      dueDate,
      current,
      interval,
    ),
  };
}

DateTime _billReminderDateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

int _billReminderRepeatSteps(DateTime start, DateTime today, int intervalDays) {
  final days = today.difference(start).inDays;
  return (days / intervalDays).ceil();
}

DateTime _billReminderNextMonthly(
  DateTime start,
  DateTime today,
  int interval,
) {
  var cursor = DateTime(start.year, start.month, start.day);
  while (cursor.isBefore(today)) {
    cursor = _billReminderDayInMonth(
      cursor.year,
      cursor.month + interval,
      start.day,
    );
  }
  return cursor;
}

DateTime _billReminderNextYearly(DateTime start, DateTime today, int interval) {
  var cursor = DateTime(start.year, start.month, start.day);
  while (cursor.isBefore(today)) {
    cursor = _billReminderDayInMonth(
      cursor.year + interval,
      cursor.month,
      start.day,
    );
  }
  return cursor;
}

DateTime _billReminderDayInMonth(int year, int month, int day) {
  final monthStart = DateTime(year, month);
  final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
  return DateTime(
    monthStart.year,
    monthStart.month,
    day > lastDay ? lastDay : day,
  );
}
