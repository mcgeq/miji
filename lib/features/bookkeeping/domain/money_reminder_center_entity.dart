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
    this.categoryId,
    this.remindBeforeDays = 0,
    this.isBudgetExceeded = false,
    this.isRepeatable = false,
    this.isAutoManaged = false,
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

  /// 源头提醒自带的分类。
  ///
  /// 只在生成待处理项时有效（不入 processing 表），用途是给「记账」表单预填，
  /// 免得用户还要重新选一遍分类——账单提醒的分类本来就是用户建提醒时选的。
  final String? categoryId;

  final int remindBeforeDays;
  final bool isBudgetExceeded;

  /// 源头是否为周期性提醒。
  ///
  /// 周期性提醒被处理时**不能**把源头置为终态（否则下一期不再出现），
  /// 它在下一期会因为有新的 dueDate 而生成新的 itemKey、重新进入待处理。
  final bool isRepeatable;

  /// 源头是否为自动托管的还款提醒。
  ///
  /// 这类提醒的状态由 `_syncCreditAccountRepaymentReminder` 独占管理：
  /// 每次写流水都会把 status 改回 pending、把 relatedTransactionId 清成 null。
  /// 外部写入会与它互踢（version 无意义递增），必须整体跳过。
  final bool isAutoManaged;

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

  /// 分期提醒对应的明细 id。
  ///
  /// 分期提醒的 [sourceId] 形如 `planId:detailId`（见
  /// `_installmentReminderCenterItems`）——保留这个复合 key 是为了不让历史
  /// 处理记录失配，所以这里只做解析，不改动 [sourceId] 本身。
  /// 拿到 detailId 后「记账」就能直接走 `postInstallmentDetail`，由它统一
  /// 负责落流水、推进明细状态与刷新预算。
  String? get installmentDetailId {
    if (sourceType != MoneyReminderCenterSourceType.installment) {
      return null;
    }
    final separator = sourceId.indexOf(':');
    if (separator < 0 || separator == sourceId.length - 1) {
      return null;
    }
    return sourceId.substring(separator + 1);
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
    String? categoryId,
    int? remindBeforeDays,
    bool? isBudgetExceeded,
    bool? isRepeatable,
    bool? isAutoManaged,
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
      categoryId: categoryId ?? this.categoryId,
      remindBeforeDays: remindBeforeDays ?? this.remindBeforeDays,
      isBudgetExceeded: isBudgetExceeded ?? this.isBudgetExceeded,
      isRepeatable: isRepeatable ?? this.isRepeatable,
      isAutoManaged: isAutoManaged ?? this.isAutoManaged,
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
