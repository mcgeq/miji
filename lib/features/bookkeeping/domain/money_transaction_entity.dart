import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

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
    this.status = MoneyTransactionStatus.completed,
  });

  final MoneyTransactionType type;

  /// 初始状态；待处理（pending）不占用账户余额、不计入统计。
  final MoneyTransactionStatus status;
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
    this.description,
  });

  final String id;
  final MoneyTransactionType type;
  final DateTime transactionAt;
  final int amountMinor;
  final String currencyCode;

  /// 用户给这笔账起的名字（如「和老王吃饭」）。
  ///
  /// 为空时仓储会回退到类型名，保持与旧数据一致的兜底行为。
  /// 独立成字段是为了让同步冲突合并也能带上它，否则远端一次更新就会把名字抹掉。
  final String? description;
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

/// 批量修改流水时的「部分字段」补丁。
///
/// 每个字段为 null 表示**不动**这一项——批量操作里用户往往只想改分类，
/// 其余字段必须保持原样，所以不能复用要求全字段的 [MoneyTransactionUpdate]。
///
/// 分类要成对给：`categoryId` 非空时 `subCategoryId` 为 null 表示「只记到
/// 父分类」（会把原有子分类清掉），这正是分类叶子选择器的语义。
class MoneyTransactionBatchUpdate {
  const MoneyTransactionBatchUpdate({
    this.categoryId,
    this.subCategoryId,
    this.accountId,
    this.tagsToAdd = const <String>[],
    this.tagsToRemove = const <String>[],
  });

  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
  final List<String> tagsToAdd;
  final List<String> tagsToRemove;

  bool get isEmpty {
    return categoryId == null &&
        accountId == null &&
        tagsToAdd.isEmpty &&
        tagsToRemove.isEmpty;
  }
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

/// 流水列表的排序字段。
enum MoneyTransactionSortField {
  transactionAt,
  amount;

  String get label {
    return switch (this) {
      MoneyTransactionSortField.transactionAt => '时间',
      MoneyTransactionSortField.amount => '金额',
    };
  }
}

class MoneyTransactionQuery {
  const MoneyTransactionQuery({
    this.page = 1,
    this.pageSize = 20,
    this.type,
    this.status,
    this.accountId,
    this.accountType,
    this.categoryId,
    this.subCategoryId,
    this.paymentMethod,
    this.merchant,
    this.customPaymentMethodName,
    this.dateStart,
    this.dateEnd,
    this.keyword,
    this.ledgerId,
    this.budgetId,
    this.tags = const <String>[],
    this.sortField = MoneyTransactionSortField.transactionAt,
    this.sortAscending = false,
  });

  final int page;
  final int pageSize;
  final MoneyTransactionType? type;

  /// 流水状态筛选；`null` 表示不限制（已完成 / 待确认 / 已作废都算）。
  ///
  /// 待确认流水不占余额、不计入统计，但没有这个字段就查不出来，
  /// 记完一笔 pending 之后等于丢进了黑洞。
  final MoneyTransactionStatus? status;
  final String? accountId;
  final MoneyAccountType? accountType;
  final String? categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod? paymentMethod;
  final String? merchant;
  final String? customPaymentMethodName;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String? keyword;
  final String? ledgerId;
  final String? budgetId;

  /// 标签筛选：命中任意一个即算匹配（OR 语义）。
  ///
  /// 标签一直是只能看不能筛的字段——标签排行就在统计页上，点下去却没有任何
  /// 反应。这里补上后排行可以下钻，也顺带给未来的标签筛选入口留了口子。
  final List<String> tags;
  final MoneyTransactionSortField sortField;
  final bool sortAscending;

  MoneyTransactionQuery copyWith({
    int? page,
    int? pageSize,
    MoneyTransactionType? type,
    MoneyTransactionStatus? status,
    String? accountId,
    MoneyAccountType? accountType,
    String? categoryId,
    String? subCategoryId,
    MoneyPaymentMethod? paymentMethod,
    String? merchant,
    String? customPaymentMethodName,
    DateTime? dateStart,
    DateTime? dateEnd,
    String? keyword,
    String? ledgerId,
    String? budgetId,
    List<String>? tags,
    MoneyTransactionSortField? sortField,
    bool? sortAscending,
    bool clearStatus = false,
    bool clearTags = false,
  }) {
    return MoneyTransactionQuery(
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      type: type ?? this.type,
      status: clearStatus ? null : (status ?? this.status),
      accountId: accountId ?? this.accountId,
      accountType: accountType ?? this.accountType,
      categoryId: categoryId ?? this.categoryId,
      subCategoryId: subCategoryId ?? this.subCategoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchant: merchant ?? this.merchant,
      customPaymentMethodName:
          customPaymentMethodName ?? this.customPaymentMethodName,
      dateStart: dateStart ?? this.dateStart,
      dateEnd: dateEnd ?? this.dateEnd,
      keyword: keyword ?? this.keyword,
      ledgerId: ledgerId ?? this.ledgerId,
      budgetId: budgetId ?? this.budgetId,
      tags: clearTags ? const <String>[] : (tags ?? this.tags),
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoneyTransactionQuery &&
            page == other.page &&
            pageSize == other.pageSize &&
            type == other.type &&
            status == other.status &&
            accountId == other.accountId &&
            accountType == other.accountType &&
            categoryId == other.categoryId &&
            subCategoryId == other.subCategoryId &&
            paymentMethod == other.paymentMethod &&
            merchant == other.merchant &&
            customPaymentMethodName == other.customPaymentMethodName &&
            dateStart == other.dateStart &&
            dateEnd == other.dateEnd &&
            keyword == other.keyword &&
            ledgerId == other.ledgerId &&
            budgetId == other.budgetId &&
            _listEquals(tags, other.tags) &&
            sortField == other.sortField &&
            sortAscending == other.sortAscending;
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      page,
      pageSize,
      type,
      status,
      accountId,
      accountType,
      categoryId,
      subCategoryId,
      paymentMethod,
      merchant,
      customPaymentMethodName,
      dateStart,
      dateEnd,
      keyword,
      ledgerId,
      budgetId,
      Object.hashAll(tags),
      sortField,
      sortAscending,
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
