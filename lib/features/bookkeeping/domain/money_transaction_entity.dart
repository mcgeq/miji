enum MoneyTransactionType {
  income,
  expense,
  transfer;

  static MoneyTransactionType fromStorageValue(String value) {
    return switch (value) {
      'income' || 'Income' => MoneyTransactionType.income,
      'expense' || 'Expense' => MoneyTransactionType.expense,
      'transfer' || 'Transfer' => MoneyTransactionType.transfer,
      _ => MoneyTransactionType.expense,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyTransactionType.income => 'income',
      MoneyTransactionType.expense => 'expense',
      MoneyTransactionType.transfer => 'transfer',
    };
  }

  String get label {
    return switch (this) {
      MoneyTransactionType.income => '收入',
      MoneyTransactionType.expense => '支出',
      MoneyTransactionType.transfer => '转账',
    };
  }
}

enum MoneyTransactionStatus {
  completed,
  pending,
  voided;

  static MoneyTransactionStatus fromStorageValue(String value) {
    return switch (value) {
      'completed' || 'Completed' => MoneyTransactionStatus.completed,
      'pending' || 'Pending' => MoneyTransactionStatus.pending,
      'voided' || 'Void' || 'Reversed' => MoneyTransactionStatus.voided,
      _ => MoneyTransactionStatus.completed,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyTransactionStatus.completed => 'completed',
      MoneyTransactionStatus.pending => 'pending',
      MoneyTransactionStatus.voided => 'voided',
    };
  }
}

enum MoneyPaymentMethod {
  cash,
  bankCard,
  creditCard,
  alipay,
  wechatPay,
  huabei,
  baitiao,
  digitalRmb,
  bankTransfer,
  unionPay,
  onlinePayment,
  thirdParty,
  other;

  static MoneyPaymentMethod fromStorageValue(String value) {
    return switch (value) {
      'cash' || 'Cash' => MoneyPaymentMethod.cash,
      'bank_card' || 'BankCard' => MoneyPaymentMethod.bankCard,
      'credit_card' || 'CreditCard' => MoneyPaymentMethod.creditCard,
      'alipay' || 'Alipay' => MoneyPaymentMethod.alipay,
      'wechat_pay' || 'WeChatPay' => MoneyPaymentMethod.wechatPay,
      'huabei' || 'Huabei' => MoneyPaymentMethod.huabei,
      'baitiao' || 'Baitiao' => MoneyPaymentMethod.baitiao,
      'digital_rmb' || 'DigitalRMB' => MoneyPaymentMethod.digitalRmb,
      'bank_transfer' || 'BankTransfer' => MoneyPaymentMethod.bankTransfer,
      'union_pay' || 'UnionPay' => MoneyPaymentMethod.unionPay,
      'online_payment' || 'OnlinePayment' => MoneyPaymentMethod.onlinePayment,
      'third_party' || 'ThirdParty' => MoneyPaymentMethod.thirdParty,
      'other' || 'Other' => MoneyPaymentMethod.other,
      _ => MoneyPaymentMethod.cash,
    };
  }

  String get storageValue {
    return switch (this) {
      MoneyPaymentMethod.cash => 'cash',
      MoneyPaymentMethod.bankCard => 'bank_card',
      MoneyPaymentMethod.creditCard => 'credit_card',
      MoneyPaymentMethod.alipay => 'alipay',
      MoneyPaymentMethod.wechatPay => 'wechat_pay',
      MoneyPaymentMethod.huabei => 'huabei',
      MoneyPaymentMethod.baitiao => 'baitiao',
      MoneyPaymentMethod.digitalRmb => 'digital_rmb',
      MoneyPaymentMethod.bankTransfer => 'bank_transfer',
      MoneyPaymentMethod.unionPay => 'union_pay',
      MoneyPaymentMethod.onlinePayment => 'online_payment',
      MoneyPaymentMethod.thirdParty => 'third_party',
      MoneyPaymentMethod.other => 'other',
    };
  }

  String get label {
    return switch (this) {
      MoneyPaymentMethod.cash => '现金',
      MoneyPaymentMethod.bankCard => '银行卡',
      MoneyPaymentMethod.creditCard => '信用卡',
      MoneyPaymentMethod.alipay => '支付宝',
      MoneyPaymentMethod.wechatPay => '微信支付',
      MoneyPaymentMethod.huabei => '花呗',
      MoneyPaymentMethod.baitiao => '白条',
      MoneyPaymentMethod.digitalRmb => '数字人民币',
      MoneyPaymentMethod.bankTransfer => '银行转账',
      MoneyPaymentMethod.unionPay => '云闪付',
      MoneyPaymentMethod.onlinePayment => '在线支付',
      MoneyPaymentMethod.thirdParty => '第三方',
      MoneyPaymentMethod.other => '其他',
    };
  }
}

class MoneyTransactionEntity {
  const MoneyTransactionEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.transactionAt,
    required this.amountMinor,
    required this.refundAmountMinor,
    required this.currencyCode,
    required this.description,
    required this.notes,
    required this.merchant,
    required this.location,
    required this.accountId,
    required this.toAccountId,
    required this.categoryId,
    required this.subCategoryId,
    required this.paymentMethod,
    required this.customPaymentMethodName,
    required this.actualPayerAccount,
    required this.relatedTransactionId,
    required this.installmentPlanId,
    required this.sourceTemplateRunId,
    required this.interestRateBasisPoints,
    required this.totalInterestMinor,
    required this.calcMethod,
    required this.tags,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final MoneyTransactionType type;
  final MoneyTransactionStatus status;
  final DateTime transactionAt;
  final int amountMinor;
  final int refundAmountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String? location;
  final String accountId;
  final String? toAccountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String actualPayerAccount;
  final String? relatedTransactionId;
  final String? installmentPlanId;
  final String? sourceTemplateRunId;
  final int? interestRateBasisPoints;
  final int totalInterestMinor;
  final String? calcMethod;
  final List<String> tags;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isInstallmentPosting => isInstallmentPostingRecord(
    actualPayerAccount: actualPayerAccount,
    installmentPlanId: installmentPlanId,
  );

  static bool isInstallmentPostingRecord({
    required String actualPayerAccount,
    required String? installmentPlanId,
  }) {
    return actualPayerAccount == 'installment' ||
        (installmentPlanId?.trim().isNotEmpty ?? false);
  }
}

class MoneyTransactionDraft {
  const MoneyTransactionDraft({
    required this.type,
    required this.transactionAt,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    this.notes,
    this.merchant,
    this.location,
    required this.accountId,
    required this.categoryId,
    this.subCategoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    this.actualPayerAccount = 'default',
    this.ledgerId,
    this.sourceTemplateRunId,
    this.tags = const <String>[],
  });

  final MoneyTransactionType type;
  final DateTime transactionAt;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String? merchant;
  final String? location;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String actualPayerAccount;
  final String? ledgerId;
  final String? sourceTemplateRunId;
  final List<String> tags;
}

class MoneyTransactionUpdate {
  const MoneyTransactionUpdate({
    required this.id,
    required this.type,
    required this.transactionAt,
    required this.amountMinor,
    required this.currencyCode,
    required this.notes,
    this.merchant,
    this.location,
    required this.accountId,
    required this.categoryId,
    this.subCategoryId,
    required this.paymentMethod,
    this.customPaymentMethodName,
    this.tags = const <String>[],
  });

  final String id;
  final MoneyTransactionType type;
  final DateTime transactionAt;
  final int amountMinor;
  final String currencyCode;
  final String? notes;
  final String? merchant;
  final String? location;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final List<String> tags;
}

class MoneyTransferDraft {
  const MoneyTransferDraft({
    required this.transactionAt,
    required this.amountMinor,
    required this.currencyCode,
    required this.description,
    this.notes,
    required this.fromAccountId,
    required this.toAccountId,
    this.subCategoryId,
    this.paymentMethod = MoneyPaymentMethod.bankTransfer,
    this.customPaymentMethodName,
    this.ledgerId,
  });

  final DateTime transactionAt;
  final int amountMinor;
  final String currencyCode;
  final String description;
  final String? notes;
  final String fromAccountId;
  final String toAccountId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
  final String? ledgerId;
}

class MoneyTransferUpdate {
  const MoneyTransferUpdate({
    required this.id,
    required this.transactionAt,
    required this.amountMinor,
    required this.currencyCode,
    required this.notes,
    required this.fromAccountId,
    required this.toAccountId,
    this.subCategoryId,
    this.paymentMethod = MoneyPaymentMethod.bankTransfer,
    this.customPaymentMethodName,
  });

  final String id;
  final DateTime transactionAt;
  final int amountMinor;
  final String currencyCode;
  final String? notes;
  final String fromAccountId;
  final String toAccountId;
  final String? subCategoryId;
  final MoneyPaymentMethod paymentMethod;
  final String? customPaymentMethodName;
}

class MoneyTransferResult {
  const MoneyTransferResult({required this.outgoing, required this.incoming});

  final MoneyTransactionEntity outgoing;
  final MoneyTransactionEntity incoming;
}

class MoneyTransactionQuery {
  const MoneyTransactionQuery({
    this.page = 1,
    this.pageSize = 20,
    this.type,
    this.accountId,
    this.categoryId,
    this.subCategoryId,
    this.paymentMethod,
    this.merchant,
    this.dateStart,
    this.dateEnd,
    this.keyword,
    this.ledgerId,
    this.budgetId,
  });

  final int page;
  final int pageSize;
  final MoneyTransactionType? type;
  final String? accountId;
  final String? categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod? paymentMethod;
  final String? merchant;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String? keyword;
  final String? ledgerId;
  final String? budgetId;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoneyTransactionQuery &&
            page == other.page &&
            pageSize == other.pageSize &&
            type == other.type &&
            accountId == other.accountId &&
            categoryId == other.categoryId &&
            subCategoryId == other.subCategoryId &&
            paymentMethod == other.paymentMethod &&
            merchant == other.merchant &&
            dateStart == other.dateStart &&
            dateEnd == other.dateEnd &&
            keyword == other.keyword &&
            ledgerId == other.ledgerId &&
            budgetId == other.budgetId;
  }

  @override
  int get hashCode {
    return Object.hash(
      page,
      pageSize,
      type,
      accountId,
      categoryId,
      subCategoryId,
      paymentMethod,
      merchant,
      dateStart,
      dateEnd,
      keyword,
      ledgerId,
      budgetId,
    );
  }
}

class MoneyTransactionPage {
  const MoneyTransactionPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.total,
  });

  final List<MoneyTransactionEntity> items;
  final int page;
  final int pageSize;
  final bool hasMore;
  final int total;
}
