class MoneyAnalysisReportEntity {
  const MoneyAnalysisReportEntity({
    required this.id,
    required this.userId,
    required this.scopeType,
    required this.reportPeriod,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.reportDataJson,
    required this.createdAt,
    required this.updatedAt,
    this.ledgerId,
    this.generationStartedAt,
    this.generationCompletedAt,
    this.errorMessage,
  });

  final String id;
  final String userId;
  final String scopeType;
  final String? ledgerId;
  final String reportPeriod;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final String reportDataJson;
  final DateTime? generationStartedAt;
  final DateTime? generationCompletedAt;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isGenerating => status == 'generation_started';
}

class MoneyAnalysisReportSnapshot {
  const MoneyAnalysisReportSnapshot({
    required this.incomeMinor,
    required this.expenseMinor,
    required this.netMinor,
    required this.expenseByCategory,
    required this.topMerchants,
    required this.installmentMinor,
    required this.autoPostingMinor,
    required this.budgetUsageRate,
    required this.overspentBudgetCount,
    required this.currencyCode,
  });

  factory MoneyAnalysisReportSnapshot.fromJson(Map<String, dynamic> json) {
    return MoneyAnalysisReportSnapshot(
      incomeMinor: (json['incomeMinor'] as num?)?.toInt() ?? 0,
      expenseMinor: (json['expenseMinor'] as num?)?.toInt() ?? 0,
      netMinor: (json['netMinor'] as num?)?.toInt() ?? 0,
      expenseByCategory:
          (json['expenseByCategory'] as List<dynamic>?)
              ?.map(
                (e) => MoneyCategoryAmount(
                  categoryName:
                      (e as Map<String, dynamic>)['categoryName'] as String? ??
                      '',
                  amountMinor: (e['amountMinor'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList() ??
          const <MoneyCategoryAmount>[],
      topMerchants:
          (json['topMerchants'] as List<dynamic>?)
              ?.map(
                (e) => MoneyCategoryAmount(
                  categoryName:
                      (e as Map<String, dynamic>)['name'] as String? ?? '',
                  amountMinor: (e['amountMinor'] as num?)?.toInt() ?? 0,
                ),
              )
              .toList() ??
          const <MoneyCategoryAmount>[],
      installmentMinor: (json['installmentMinor'] as num?)?.toInt() ?? 0,
      autoPostingMinor: (json['autoPostingMinor'] as num?)?.toInt() ?? 0,
      budgetUsageRate: (json['budgetUsageRate'] as num?)?.toDouble() ?? 0.0,
      overspentBudgetCount:
          (json['overspentBudgetCount'] as num?)?.toInt() ?? 0,
      currencyCode: (json['currencyCode'] as String?) ?? 'CNY',
    );
  }

  final int incomeMinor;
  final int expenseMinor;
  final int netMinor;
  final List<MoneyCategoryAmount> expenseByCategory;
  final List<MoneyCategoryAmount> topMerchants;
  final int installmentMinor;
  final int autoPostingMinor;
  final double budgetUsageRate;
  final int overspentBudgetCount;
  final String currencyCode;

  Map<String, dynamic> toJson() {
    return {
      'incomeMinor': incomeMinor,
      'expenseMinor': expenseMinor,
      'netMinor': netMinor,
      'expenseByCategory': expenseByCategory
          .map(
            (e) => {
              'categoryName': e.categoryName,
              'amountMinor': e.amountMinor,
            },
          )
          .toList(),
      'topMerchants': topMerchants
          .map((e) => {'name': e.categoryName, 'amountMinor': e.amountMinor})
          .toList(),
      'installmentMinor': installmentMinor,
      'autoPostingMinor': autoPostingMinor,
      'budgetUsageRate': budgetUsageRate,
      'overspentBudgetCount': overspentBudgetCount,
      'currencyCode': currencyCode,
    };
  }
}

class MoneyCategoryAmount {
  const MoneyCategoryAmount({
    required this.categoryName,
    required this.amountMinor,
  });

  final String categoryName;
  final int amountMinor;
}

class MoneyAnalysisReportRequest {
  const MoneyAnalysisReportRequest({
    required this.ledgerId,
    required this.reportPeriod,
    required this.periodStart,
    required this.periodEnd,
  });

  final String ledgerId;
  final String reportPeriod;
  final DateTime periodStart;
  final DateTime periodEnd;
}

class MoneyReportGenerationConfigEntity {
  const MoneyReportGenerationConfigEntity({
    required this.userId,
    required this.ledgerId,
    required this.autoGenerateWeekly,
    required this.autoGenerateMonthly,
    required this.autoGenerateQuarterly,
    required this.autoGenerateYearly,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MoneyReportGenerationConfigEntity.defaults({
    required String userId,
    required String ledgerId,
  }) {
    final now = DateTime.now();
    return MoneyReportGenerationConfigEntity(
      userId: userId,
      ledgerId: ledgerId,
      autoGenerateWeekly: false,
      autoGenerateMonthly: true,
      autoGenerateQuarterly: false,
      autoGenerateYearly: false,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String userId;
  final String ledgerId;
  final bool autoGenerateWeekly;
  final bool autoGenerateMonthly;
  final bool autoGenerateQuarterly;
  final bool autoGenerateYearly;
  final DateTime createdAt;
  final DateTime updatedAt;
}
