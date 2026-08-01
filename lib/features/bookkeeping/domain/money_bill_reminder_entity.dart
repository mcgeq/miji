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
