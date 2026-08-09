enum MoneyBudgetTrackingType {
  expenseLimit('expense_limit'),
  incomeTarget('income_target');

  const MoneyBudgetTrackingType(this.storageValue);

  final String storageValue;

  static MoneyBudgetTrackingType fromStorageValue(String value) {
    return MoneyBudgetTrackingType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MoneyBudgetTrackingType.expenseLimit,
    );
  }
}

enum MoneyBudgetPeriodType {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  billingCycle('billing_cycle'),
  yearly('yearly');

  const MoneyBudgetPeriodType(this.storageValue);

  final String storageValue;

  static MoneyBudgetPeriodType fromStorageValue(String value) {
    return MoneyBudgetPeriodType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MoneyBudgetPeriodType.monthly,
    );
  }

  String get label {
    return switch (this) {
      MoneyBudgetPeriodType.daily => '每天',
      MoneyBudgetPeriodType.weekly => '每周',
      MoneyBudgetPeriodType.monthly => '每月',
      MoneyBudgetPeriodType.billingCycle => '账单周期',
      MoneyBudgetPeriodType.yearly => '每年',
    };
  }
}

enum MoneyBudgetScopeType {
  all('all'),
  category('category'),
  account('account'),
  categoryAccount('category_account');

  const MoneyBudgetScopeType(this.storageValue);

  final String storageValue;

  static MoneyBudgetScopeType fromStorageValue(String value) {
    return MoneyBudgetScopeType.values.firstWhere(
      (type) => type.storageValue == value,
      orElse: () => MoneyBudgetScopeType.all,
    );
  }
}

class MoneyBudgetEntity {
  const MoneyBudgetEntity({
    required this.id,
    required this.userId,
    required this.ledgerId,
    required this.scopeType,
    required this.name,
    required this.trackingType,
    required this.periodType,
    required this.repeatInterval,
    required this.amountMinor,
    required this.currencyCode,
    required this.periodStart,
    required this.periodEnd,
    required this.categoryId,
    required this.subCategoryId,
    required this.usedAmountMinor,
    required this.isActive,
    required this.alertEnabled,
    required this.alertThresholdPercent,
    required this.createdAt,
    required this.updatedAt,
    this.autoRollover = false,
    this.description,
    this.accountId,
    this.color,
  });

  final String id;
  final String userId;
  final String ledgerId;
  final MoneyBudgetScopeType scopeType;
  final String name;
  final String? description;
  final MoneyBudgetTrackingType trackingType;
  final MoneyBudgetPeriodType periodType;
  final int repeatInterval;
  final int amountMinor;
  final String currencyCode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
  final int usedAmountMinor;
  final bool isActive;
  final bool alertEnabled;
  final int? alertThresholdPercent;
  final bool autoRollover;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get remainingAmountMinor => amountMinor - usedAmountMinor;

  double get progress {
    if (amountMinor <= 0) {
      return 0;
    }
    return usedAmountMinor / amountMinor;
  }

  bool get isExpenseLimit {
    return trackingType == MoneyBudgetTrackingType.expenseLimit;
  }

  bool get isIncomeTarget {
    return trackingType == MoneyBudgetTrackingType.incomeTarget;
  }

  bool get isAllScope => scopeType == MoneyBudgetScopeType.all;

  bool get isOverspent => isExpenseLimit && usedAmountMinor > amountMinor;

  bool get isCompleted => isIncomeTarget && usedAmountMinor >= amountMinor;

  bool get shouldAlert {
    final threshold = alertThresholdPercent;
    if (!alertEnabled || threshold == null || amountMinor <= 0) {
      return false;
    }
    return progress * 100 >= threshold;
  }
}

class MoneyBudgetDraft {
  const MoneyBudgetDraft({
    required this.name,
    required this.amountMinor,
    this.ledgerId,
    this.scopeType,
    this.trackingType = MoneyBudgetTrackingType.expenseLimit,
    this.periodType = MoneyBudgetPeriodType.monthly,
    this.repeatInterval = 1,
    this.categoryId,
    this.subCategoryId,
    this.accountId,
    this.description,
    this.currencyCode = 'CNY',
    this.alertEnabled = false,
    this.alertThresholdPercent,
    this.autoRollover = false,
    this.color,
  });

  final String name;
  final String? ledgerId;
  final MoneyBudgetScopeType? scopeType;
  final String? description;
  final MoneyBudgetTrackingType trackingType;
  final MoneyBudgetPeriodType periodType;
  final int repeatInterval;
  final int amountMinor;
  final String currencyCode;
  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
  final bool autoRollover;
  final bool alertEnabled;
  final int? alertThresholdPercent;
  final String? color;
}

class MoneyBudgetUpdate {
  const MoneyBudgetUpdate({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.ledgerId,
    this.scopeType,
    this.trackingType = MoneyBudgetTrackingType.expenseLimit,
    this.periodType = MoneyBudgetPeriodType.monthly,
    this.repeatInterval = 1,
    this.categoryId,
    this.subCategoryId,
    this.accountId,
    this.description,
    this.currencyCode = 'CNY',
    this.isActive = true,
    this.alertEnabled = false,
    this.alertThresholdPercent,
    this.autoRollover = false,
    this.color,
  });

  final String id;
  final String name;
  final String ledgerId;
  final MoneyBudgetScopeType? scopeType;
  final String? description;
  final MoneyBudgetTrackingType trackingType;
  final MoneyBudgetPeriodType periodType;
  final int repeatInterval;
  final int amountMinor;
  final String currencyCode;
  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
  final bool isActive;
  final bool alertEnabled;
  final int? alertThresholdPercent;
  final bool autoRollover;
  final String? color;
}

enum MoneyBudgetAllocationStatus {
  active('active'),
  inactive('inactive');

  const MoneyBudgetAllocationStatus(this.storageValue);

  final String storageValue;

  static MoneyBudgetAllocationStatus fromStorageValue(String value) {
    return MoneyBudgetAllocationStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => MoneyBudgetAllocationStatus.active,
    );
  }
}

class MoneyBudgetAllocationEntity {
  const MoneyBudgetAllocationEntity({
    required this.id,
    required this.userId,
    required this.budgetId,
    required this.allocatedAmountMinor,
    required this.usedAmountMinor,
    required this.remainingAmountMinor,
    required this.allocationType,
    required this.alertEnabled,
    required this.alertThresholdPercent,
    required this.priority,
    required this.isMandatory,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.memberId,
    this.percentageBasisPoints,
    this.ruleConfigJson,
    this.allowOverspend = false,
    this.overspendLimitType,
    this.overspendLimitMinor,
    this.alertConfigJson,
    this.notes,
  });

  final String id;
  final String userId;
  final String budgetId;
  final String? categoryId;
  final String? memberId;
  final int allocatedAmountMinor;
  final int usedAmountMinor;
  final int remainingAmountMinor;
  final int? percentageBasisPoints;
  final String allocationType;
  final String? ruleConfigJson;
  final bool allowOverspend;
  final String? overspendLimitType;
  final int? overspendLimitMinor;
  final bool alertEnabled;
  final int alertThresholdPercent;
  final String? alertConfigJson;
  final int priority;
  final bool isMandatory;
  final MoneyBudgetAllocationStatus status;
  final String? notes;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyBudgetAllocationDraft {
  const MoneyBudgetAllocationDraft({
    required this.budgetId,
    required this.allocatedAmountMinor,
    this.categoryId,
    this.memberId,
    this.percentageBasisPoints,
    this.allocationType = 'fixed',
    this.ruleConfigJson,
    this.allowOverspend = false,
    this.overspendLimitType,
    this.overspendLimitMinor,
    this.alertEnabled = false,
    this.alertThresholdPercent = 80,
    this.alertConfigJson,
    this.priority = 0,
    this.isMandatory = false,
    this.notes,
  });

  final String budgetId;
  final String? categoryId;
  final String? memberId;
  final int allocatedAmountMinor;
  final int? percentageBasisPoints;
  final String allocationType;
  final String? ruleConfigJson;
  final bool allowOverspend;
  final String? overspendLimitType;
  final int? overspendLimitMinor;
  final bool alertEnabled;
  final int alertThresholdPercent;
  final String? alertConfigJson;
  final int priority;
  final bool isMandatory;
  final String? notes;
}

class MoneyBudgetAllocationUpdate {
  const MoneyBudgetAllocationUpdate({
    required this.id,
    required this.allocatedAmountMinor,
    this.categoryId,
    this.memberId,
    this.percentageBasisPoints,
    this.allocationType = 'fixed',
    this.ruleConfigJson,
    this.allowOverspend = false,
    this.overspendLimitType,
    this.overspendLimitMinor,
    this.alertEnabled = false,
    this.alertThresholdPercent = 80,
    this.alertConfigJson,
    this.priority = 0,
    this.isMandatory = false,
    this.status = MoneyBudgetAllocationStatus.active,
    this.notes,
  });

  final String id;
  final String? categoryId;
  final String? memberId;
  final int allocatedAmountMinor;
  final int? percentageBasisPoints;
  final String allocationType;
  final String? ruleConfigJson;
  final bool allowOverspend;
  final String? overspendLimitType;
  final int? overspendLimitMinor;
  final bool alertEnabled;
  final int alertThresholdPercent;
  final String? alertConfigJson;
  final int priority;
  final bool isMandatory;
  final MoneyBudgetAllocationStatus status;
  final String? notes;
}
