enum MoneyReminderCenterSourceType {
  budget('budget'),
  creditCardBill('credit_card_bill'),
  installment('installment'),
  recurringExpense('recurring_expense'),
  billReminder('bill_reminder');

  const MoneyReminderCenterSourceType(this.storageValue);

  final String storageValue;

  static MoneyReminderCenterSourceType fromStorageValue(String value) {
    return values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => MoneyReminderCenterSourceType.billReminder,
    );
  }
}

enum MoneyReminderCenterPriority {
  overdue,
  dueWithinThreeDays,
  budgetExceeded,
  normal,
}

enum MoneyReminderCenterState {
  pending('pending'),
  completed('completed'),
  snoozed('snoozed'),
  ignored('ignored');

  const MoneyReminderCenterState(this.storageValue);

  final String storageValue;

  static MoneyReminderCenterState fromStorageValue(String value) {
    return values.firstWhere(
      (state) => state.storageValue == value,
      orElse: () => MoneyReminderCenterState.pending,
    );
  }
}

enum MoneyReminderCenterActionType {
  repay('repay'),
  viewBudget('view_budget'),
  recordTransaction('record_transaction'),
  openReminder('open_reminder'),
  openInstallment('open_installment');

  const MoneyReminderCenterActionType(this.storageValue);

  final String storageValue;

  static MoneyReminderCenterActionType fromStorageValue(String value) {
    return values.firstWhere(
      (action) => action.storageValue == value,
      orElse: () => MoneyReminderCenterActionType.openReminder,
    );
  }
}

class MoneyReminderCenterItem {
  const MoneyReminderCenterItem({
    required this.sourceType,
    required this.sourceId,
    required this.title,
    required this.dueDate,
    required this.amountMinor,
    required this.currencyCode,
    required this.actionType,
    this.ledgerId,
    this.accountId,
    this.remindBeforeDays = 0,
    this.isBudgetExceeded = false,
    this.state = MoneyReminderCenterState.pending,
    this.snoozedUntil,
    this.processedAt,
  });

  final MoneyReminderCenterSourceType sourceType;
  final String sourceId;
  final String title;
  final DateTime dueDate;
  final int amountMinor;
  final String currencyCode;
  final MoneyReminderCenterActionType actionType;
  final String? ledgerId;
  final String? accountId;
  final int remindBeforeDays;
  final bool isBudgetExceeded;
  final MoneyReminderCenterState state;
  final DateTime? snoozedUntil;
  final DateTime? processedAt;

  String get itemKey {
    final date = _dateOnly(dueDate);
    return '${sourceType.storageValue}:$sourceId:'
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool isPending({required DateTime today}) {
    final current = _dateOnly(today);
    final visibleFrom = _dateOnly(
      dueDate,
    ).subtract(Duration(days: remindBeforeDays));
    if (state == MoneyReminderCenterState.pending) {
      if (isBudgetExceeded) {
        return true;
      }
      return !current.isBefore(visibleFrom);
    }
    if (state != MoneyReminderCenterState.snoozed || snoozedUntil == null) {
      return false;
    }
    return !current.isBefore(_dateOnly(snoozedUntil!));
  }

  MoneyReminderCenterPriority priority({required DateTime today}) {
    final current = _dateOnly(today);
    final due = _dateOnly(dueDate);
    if (due.isBefore(current)) {
      return MoneyReminderCenterPriority.overdue;
    }
    if (!due.isAfter(current.add(const Duration(days: 3)))) {
      return MoneyReminderCenterPriority.dueWithinThreeDays;
    }
    if (isBudgetExceeded) {
      return MoneyReminderCenterPriority.budgetExceeded;
    }
    return MoneyReminderCenterPriority.normal;
  }

  int comparePriorityTo(
    MoneyReminderCenterItem other, {
    required DateTime today,
  }) {
    final priorityResult = priority(
      today: today,
    ).index.compareTo(other.priority(today: today).index);
    if (priorityResult != 0) {
      return priorityResult;
    }

    final dueDateResult = _dateOnly(
      dueDate,
    ).compareTo(_dateOnly(other.dueDate));
    if (dueDateResult != 0) {
      return dueDateResult;
    }

    final amountResult = other.amountMinor.compareTo(amountMinor);
    if (amountResult != 0) {
      return amountResult;
    }
    return title.compareTo(other.title);
  }

  MoneyReminderCenterItem snooze({required DateTime until}) {
    return copyWith(
      state: MoneyReminderCenterState.snoozed,
      snoozedUntil: _dateOnly(until),
      processedAt: null,
    );
  }

  MoneyReminderCenterItem complete({required DateTime at}) {
    return copyWith(
      state: MoneyReminderCenterState.completed,
      snoozedUntil: null,
      processedAt: at,
    );
  }

  MoneyReminderCenterItem ignore({required DateTime at}) {
    return copyWith(
      state: MoneyReminderCenterState.ignored,
      snoozedUntil: null,
      processedAt: at,
    );
  }

  MoneyReminderCenterItem restorePending() {
    return copyWith(
      state: MoneyReminderCenterState.pending,
      snoozedUntil: null,
      processedAt: null,
    );
  }

  MoneyReminderCenterItem copyWith({
    MoneyReminderCenterSourceType? sourceType,
    String? sourceId,
    String? title,
    DateTime? dueDate,
    int? amountMinor,
    String? currencyCode,
    MoneyReminderCenterActionType? actionType,
    String? ledgerId,
    String? accountId,
    int? remindBeforeDays,
    bool? isBudgetExceeded,
    MoneyReminderCenterState? state,
    DateTime? snoozedUntil,
    DateTime? processedAt,
  }) {
    return MoneyReminderCenterItem(
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      title: title ?? this.title,
      dueDate: dueDate ?? this.dueDate,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      actionType: actionType ?? this.actionType,
      ledgerId: ledgerId ?? this.ledgerId,
      accountId: accountId ?? this.accountId,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      isBudgetExceeded: isBudgetExceeded ?? this.isBudgetExceeded,
      state: state ?? this.state,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      processedAt: processedAt ?? this.processedAt,
    );
  }
}

class MoneyReminderCenterProcessingRecord {
  const MoneyReminderCenterProcessingRecord({
    required this.id,
    required this.userId,
    required this.itemKey,
    required this.item,
    required this.state,
    required this.version,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String userId;
  final String itemKey;
  final MoneyReminderCenterItem item;
  final MoneyReminderCenterState state;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
