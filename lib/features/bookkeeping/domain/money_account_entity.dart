enum MoneyAccountType {
  cash,
  bank,
  creditCard,
  huabei,
  baitiao,
  meituanCredit,
  otherCredit,
  saving,
  investment,
  loan,
  alipay,
  wechat,
  cloudQuickPass,
  prepaidCard,
  other,
  internal;

  static MoneyAccountType fromStorageValue(String value) {
    return switch (value) {
      'Cash' || 'cash' => MoneyAccountType.cash,
      'Bank' ||
      'BankAccount' ||
      'bank' ||
      'bank_account' => MoneyAccountType.bank,
      'CreditCard' || 'credit_card' || 'credit' => MoneyAccountType.creditCard,
      'Huabei' || 'huabei' => MoneyAccountType.huabei,
      'Baitiao' || 'baitiao' => MoneyAccountType.baitiao,
      'MeituanCredit' || 'meituan_credit' => MoneyAccountType.meituanCredit,
      'OtherCredit' || 'other_credit' => MoneyAccountType.otherCredit,
      'Savings' || 'saving' || 'savings' => MoneyAccountType.saving,
      'Investment' || 'investment' => MoneyAccountType.investment,
      'Loan' || 'loan' => MoneyAccountType.loan,
      'Alipay' || 'alipay' => MoneyAccountType.alipay,
      'WeChat' || 'wechat' => MoneyAccountType.wechat,
      'CloudQuickPass' || 'cloud_quick_pass' => MoneyAccountType.cloudQuickPass,
      'PrepaidCard' || 'prepaid_card' => MoneyAccountType.prepaidCard,
      'Other' || 'other' => MoneyAccountType.other,
      'Internal' || 'internal' => MoneyAccountType.internal,
      _ => MoneyAccountType.cash,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyAccountType.cash => 'cash',
      MoneyAccountType.bank => 'bank',
      MoneyAccountType.creditCard => 'credit_card',
      MoneyAccountType.huabei => 'huabei',
      MoneyAccountType.baitiao => 'baitiao',
      MoneyAccountType.meituanCredit => 'meituan_credit',
      MoneyAccountType.otherCredit => 'other_credit',
      MoneyAccountType.saving => 'saving',
      MoneyAccountType.investment => 'investment',
      MoneyAccountType.loan => 'loan',
      MoneyAccountType.alipay => 'alipay',
      MoneyAccountType.wechat => 'wechat',
      MoneyAccountType.cloudQuickPass => 'cloud_quick_pass',
      MoneyAccountType.prepaidCard => 'prepaid_card',
      MoneyAccountType.other => 'other',
      MoneyAccountType.internal => 'internal',
    };
  }

  String get label {
    return switch (this) {
      MoneyAccountType.cash => '现金',
      MoneyAccountType.bank => '银行账户',
      MoneyAccountType.creditCard => '信用卡',
      MoneyAccountType.huabei => '花呗',
      MoneyAccountType.baitiao => '白条',
      MoneyAccountType.meituanCredit => '美团月付',
      MoneyAccountType.otherCredit => '其他信用账户',
      MoneyAccountType.saving => '储蓄账户',
      MoneyAccountType.investment => '投资账户',
      MoneyAccountType.loan => '贷款账户',
      MoneyAccountType.alipay => '支付宝',
      MoneyAccountType.wechat => '微信',
      MoneyAccountType.cloudQuickPass => '云闪付',
      MoneyAccountType.prepaidCard => '预付卡',
      MoneyAccountType.other => '其他',
      MoneyAccountType.internal => '内部账户',
    };
  }

  bool get isCreditLike {
    return switch (this) {
      MoneyAccountType.creditCard ||
      MoneyAccountType.huabei ||
      MoneyAccountType.baitiao ||
      MoneyAccountType.meituanCredit ||
      MoneyAccountType.otherCredit => true,
      _ => false,
    };
  }

  bool get isDebtLike {
    return isCreditLike || this == MoneyAccountType.loan;
  }

  bool get isWalletLike {
    return switch (this) {
      MoneyAccountType.alipay ||
      MoneyAccountType.wechat ||
      MoneyAccountType.cloudQuickPass => true,
      _ => false,
    };
  }

  bool get isAssetLike {
    return switch (this) {
      MoneyAccountType.cash ||
      MoneyAccountType.bank ||
      MoneyAccountType.saving ||
      MoneyAccountType.investment ||
      MoneyAccountType.alipay ||
      MoneyAccountType.wechat ||
      MoneyAccountType.cloudQuickPass ||
      MoneyAccountType.prepaidCard ||
      MoneyAccountType.other => true,
      _ => false,
    };
  }

  bool get isInternal => this == MoneyAccountType.internal;
}

class MoneyAccountEntity {
  const MoneyAccountEntity({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balanceMinor,
    required this.initialBalanceMinor,
    required this.creditLimitMinor,
    required this.postedDebtMinor,
    required this.frozenCreditMinor,
    required this.statementDay,
    required this.budgetCycleStartDay,
    required this.repaymentDay,
    required this.autoRepaymentReminderEnabled,
    required this.currencyCode,
    required this.isShared,
    required this.isVirtual,
    required this.isActive,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.color,
    this.icon,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final MoneyAccountType type;
  final int balanceMinor;
  final int initialBalanceMinor;
  final int? creditLimitMinor;
  final int? postedDebtMinor;
  final int? frozenCreditMinor;
  final int? statementDay;
  final int? budgetCycleStartDay;
  final int? repaymentDay;
  final bool autoRepaymentReminderEnabled;
  final String currencyCode;
  final bool isShared;
  final bool isVirtual;
  final String? color;
  final String? icon;
  final bool isActive;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get effectiveCreditLimitMinor {
    return creditLimitMinor ?? initialBalanceMinor;
  }

  int get effectivePostedDebtMinor {
    return postedDebtMinor ?? 0;
  }

  int get effectiveFrozenCreditMinor {
    return frozenCreditMinor ?? 0;
  }

  int get usedCreditMinor {
    if (!type.isCreditLike) {
      return 0;
    }
    return effectivePostedDebtMinor + effectiveFrozenCreditMinor;
  }

  int get availableCreditMinor {
    if (!type.isCreditLike) {
      return 0;
    }
    return effectiveCreditLimitMinor - usedCreditMinor;
  }

  int get displayBalanceMinor {
    return type.isCreditLike ? availableCreditMinor : balanceMinor;
  }

  bool get hasBillingCycle {
    return type.isCreditLike && statementDay != null && repaymentDay != null;
  }
}

class MoneyAccountDraft {
  const MoneyAccountDraft({
    required this.name,
    required this.type,
    required this.initialBalanceMinor,
    this.description,
    this.currencyCode = 'CNY',
    this.color,
    this.icon,
    this.statementDay,
    this.budgetCycleStartDay,
    this.repaymentDay,
    this.autoRepaymentReminderEnabled = true,
  });

  final String name;
  final String? description;
  final MoneyAccountType type;
  final int initialBalanceMinor;
  final String currencyCode;
  final String? color;
  final String? icon;
  final int? statementDay;
  final int? budgetCycleStartDay;
  final int? repaymentDay;
  final bool autoRepaymentReminderEnabled;
}

class MoneyAccountUpdate {
  const MoneyAccountUpdate({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.initialBalanceMinor,
    this.description,
    this.color,
    this.icon,
    this.statementDay,
    this.budgetCycleStartDay,
    this.repaymentDay,
    this.autoRepaymentReminderEnabled = true,
  });

  final String id;
  final String name;
  final String? description;
  final MoneyAccountType type;
  final String currencyCode;
  final int initialBalanceMinor;
  final String? color;
  final String? icon;
  final int? statementDay;
  final int? budgetCycleStartDay;
  final int? repaymentDay;
  final bool autoRepaymentReminderEnabled;
}

class MoneyAccountMonthlySummary {
  const MoneyAccountMonthlySummary({
    required this.accountId,
    required this.currentIncomeMinor,
    required this.currentExpenseMinor,
    required this.previousIncomeMinor,
    required this.previousExpenseMinor,
  });

  const MoneyAccountMonthlySummary.empty(this.accountId)
    : currentIncomeMinor = 0,
      currentExpenseMinor = 0,
      previousIncomeMinor = 0,
      previousExpenseMinor = 0;

  final String accountId;
  final int currentIncomeMinor;
  final int currentExpenseMinor;
  final int previousIncomeMinor;
  final int previousExpenseMinor;

  int get currentNetMinor => currentIncomeMinor - currentExpenseMinor;

  int get previousNetMinor => previousIncomeMinor - previousExpenseMinor;

  int get netChangeMinor => currentNetMinor - previousNetMinor;

  int get expenseChangeMinor => currentExpenseMinor - previousExpenseMinor;

  bool get hasCurrentExpense {
    return currentExpenseMinor != 0;
  }

  bool get hasPreviousExpense {
    return previousExpenseMinor != 0;
  }

  bool get hasCurrentActivity {
    return currentIncomeMinor != 0 || currentExpenseMinor != 0;
  }

  bool get hasPreviousActivity {
    return previousIncomeMinor != 0 || previousExpenseMinor != 0;
  }
}
