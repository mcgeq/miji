enum MoneyInstallmentPlanStatus {
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const MoneyInstallmentPlanStatus(this.storageValue);

  final String storageValue;

  static MoneyInstallmentPlanStatus fromStorageValue(String value) {
    return MoneyInstallmentPlanStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => MoneyInstallmentPlanStatus.active,
    );
  }

  String get label {
    return switch (this) {
      MoneyInstallmentPlanStatus.active => '进行中',
      MoneyInstallmentPlanStatus.completed => '已完成',
      MoneyInstallmentPlanStatus.cancelled => '已取消',
    };
  }
}

enum MoneyInstallmentCalcMethod {
  flat('flat', '等额平摊'),
  equalInstallment('equal_installment', '等额本息'),
  equalPrincipal('equal_principal', '等额本金');

  const MoneyInstallmentCalcMethod(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static MoneyInstallmentCalcMethod fromStorageValue(String value) {
    return MoneyInstallmentCalcMethod.values.firstWhere(
      (method) => method.storageValue == value,
      orElse: () => MoneyInstallmentCalcMethod.flat,
    );
  }

  /// 是否需要年利率输入（等额本息 / 等额本金）。
  bool get usesInterestRate => this != MoneyInstallmentCalcMethod.flat;
}

enum MoneyInstallmentDetailStatus {
  pending('pending'),
  posted('posted'),
  skipped('skipped');

  const MoneyInstallmentDetailStatus(this.storageValue);

  final String storageValue;

  static MoneyInstallmentDetailStatus fromStorageValue(String value) {
    return MoneyInstallmentDetailStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => MoneyInstallmentDetailStatus.pending,
    );
  }

  String get label {
    return switch (this) {
      MoneyInstallmentDetailStatus.pending => '待入账',
      MoneyInstallmentDetailStatus.posted => '已入账',
      MoneyInstallmentDetailStatus.skipped => '已跳过',
    };
  }
}

class MoneyInstallmentPlanEntity {
  const MoneyInstallmentPlanEntity({
    required this.id,
    required this.userId,
    required this.ledgerId,
    required this.accountId,
    required this.name,
    required this.totalPrincipalMinor,
    required this.totalInterestMinor,
    required this.totalPeriods,
    required this.remainingPeriods,
    required this.periodAmountMinor,
    required this.currencyCode,
    required this.categoryId,
    required this.startDate,
    required this.endDate,
    required this.firstDueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.subCategoryId,
    this.notes,
  });

  final String id;
  final String userId;
  final String ledgerId;
  final String accountId;
  final String name;
  final String? description;
  final int totalPrincipalMinor;
  final int totalInterestMinor;
  final int totalPeriods;
  final int remainingPeriods;
  final int periodAmountMinor;
  final String currencyCode;
  final String categoryId;
  final String? subCategoryId;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime firstDueDate;
  final MoneyInstallmentPlanStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get totalPayableMinor => totalPrincipalMinor + totalInterestMinor;

  bool get isActive => status == MoneyInstallmentPlanStatus.active;
}

class MoneyInstallmentDetailEntity {
  const MoneyInstallmentDetailEntity({
    required this.id,
    required this.userId,
    required this.planId,
    required this.accountId,
    required this.periodNumber,
    required this.amountMinor,
    required this.principalMinor,
    required this.interestMinor,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paidDate,
    this.transactionId,
    this.notes,
  });

  final String id;
  final String userId;
  final String planId;
  final String accountId;
  final int periodNumber;
  final int amountMinor;
  final int principalMinor;
  final int interestMinor;
  final DateTime dueDate;
  final DateTime? paidDate;
  final MoneyInstallmentDetailStatus status;
  final String? transactionId;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class MoneyInstallmentPlanDraft {
  const MoneyInstallmentPlanDraft({
    required this.accountId,
    required this.name,
    required this.categoryId,
    required this.totalPrincipalMinor,
    required this.totalInterestMinor,
    required this.totalPeriods,
    required this.firstDueDate,
    this.ledgerId,
    this.description,
    this.subCategoryId,
    this.currencyCode = 'CNY',
    this.notes,
    this.calcMethod = MoneyInstallmentCalcMethod.flat,
    this.interestRateBasisPoints,
  });

  final String? ledgerId;
  final String accountId;
  final String name;
  final String? description;
  final String categoryId;
  final String? subCategoryId;
  final int totalPrincipalMinor;
  final int totalInterestMinor;
  final int totalPeriods;
  final DateTime firstDueDate;
  final String currencyCode;
  final String? notes;

  /// 计算方式（等额平摊 / 等额本息 / 等额本金）。
  final MoneyInstallmentCalcMethod calcMethod;

  /// 年利率（基础点，如 1200 = 12%）；等额平摊时可忽略。
  final int? interestRateBasisPoints;
}

class MoneyInstallmentExecutionSummary {
  const MoneyInstallmentExecutionSummary({
    required this.postedCount,
    required this.failedCount,
  });

  final int postedCount;
  final int failedCount;

  static const empty = MoneyInstallmentExecutionSummary(
    postedCount: 0,
    failedCount: 0,
  );

  MoneyInstallmentExecutionSummary add({int posted = 0, int failed = 0}) {
    return MoneyInstallmentExecutionSummary(
      postedCount: postedCount + posted,
      failedCount: failedCount + failed,
    );
  }
}
