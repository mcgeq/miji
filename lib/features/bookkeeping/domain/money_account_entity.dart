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

/// 账户卡片的背景样式。
enum MoneyAccountBackgroundStyle {
  /// 跟随主题的默认卡片外观。
  defaultStyle,

  /// 纯色 / 渐变背景，颜色取自 backgroundColor。
  color,

  /// 图片背景，路径取自 backgroundImage。
  image;

  static MoneyAccountBackgroundStyle fromStorageValue(String? value) {
    return switch (value) {
      'color' || 'solid' => MoneyAccountBackgroundStyle.color,
      'image' => MoneyAccountBackgroundStyle.image,
      _ => MoneyAccountBackgroundStyle.defaultStyle,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyAccountBackgroundStyle.defaultStyle => 'default',
      MoneyAccountBackgroundStyle.color => 'color',
      MoneyAccountBackgroundStyle.image => 'image',
    };
  }
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
    this.backgroundStyle,
    this.backgroundColor,
    this.backgroundImage,
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

  /// 卡片背景样式：`default` / `color` / `image`；null 视同 default。
  final String? backgroundStyle;

  /// 卡片背景色（hex），[backgroundStyle] 为 `color` 时生效。
  final String? backgroundColor;

  /// 卡片背景图相对路径（AttachmentStore）；文件不参与同步，跨端需降级。
  final String? backgroundImage;

  /// 解析后的背景样式；非法存储值一律回退 default。
  MoneyAccountBackgroundStyle get resolvedBackgroundStyle {
    return MoneyAccountBackgroundStyle.fromStorageValue(backgroundStyle);
  }

  /// 有效的背景渲染样式：style 声明了但对应素材缺失时自动降级。
  ///
  /// 背景图只在本机落盘（附件不参与同步），另一台设备拿着路径也读不到
  /// 文件 —— 那就退回背景色，再不行退回默认外观，而不是渲染一张破图。
  MoneyAccountBackgroundStyle effectiveBackgroundStyle({
    bool backgroundImageExists = true,
  }) {
    final style = resolvedBackgroundStyle;
    if (style == MoneyAccountBackgroundStyle.image &&
        (backgroundImage == null || !backgroundImageExists)) {
      if (backgroundColor != null) {
        return MoneyAccountBackgroundStyle.color;
      }
      return MoneyAccountBackgroundStyle.defaultStyle;
    }
    if (style == MoneyAccountBackgroundStyle.color && backgroundColor == null) {
      return MoneyAccountBackgroundStyle.defaultStyle;
    }
    return style;
  }

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
    this.backgroundStyle,
    this.backgroundColor,
    this.backgroundImage,
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
  final MoneyAccountBackgroundStyle? backgroundStyle;
  final String? backgroundColor;
  final String? backgroundImage;
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
    this.backgroundStyle,
    this.backgroundColor,
    this.backgroundImage,
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
  final MoneyAccountBackgroundStyle? backgroundStyle;
  final String? backgroundColor;
  final String? backgroundImage;
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

/// 账户在一个时间区间里的收入 / 支出合计（余额对账用）。
///
/// 口径与账户余额一致：只算已完成、非转账的交易；退款按净额。
class MoneyAccountPeriodFlows {
  const MoneyAccountPeriodFlows({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  const MoneyAccountPeriodFlows.empty() : incomeMinor = 0, expenseMinor = 0;

  final int incomeMinor;
  final int expenseMinor;

  int get netMinor => incomeMinor - expenseMinor;

  bool get isEmpty => incomeMinor == 0 && expenseMinor == 0;
}
