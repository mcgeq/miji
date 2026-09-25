/// 分析报表的周期选项与区间计算。
///
/// 报表按账本 + 周期生成，周期使用稳定的字符串键（weekly / monthly /
/// quarterly / yearly），与数据库中的 `report_period` 保持一致。
library;

class MoneyReportPeriodOption {
  const MoneyReportPeriodOption(this.value, this.label);

  final String value;
  final String label;

  static const weekly = MoneyReportPeriodOption('weekly', '周报');
  static const monthly = MoneyReportPeriodOption('monthly', '月报');
  static const quarterly = MoneyReportPeriodOption('quarterly', '季报');
  static const yearly = MoneyReportPeriodOption('yearly', '年报');

  static const values = <MoneyReportPeriodOption>[
    weekly,
    monthly,
    quarterly,
    yearly,
  ];

  static MoneyReportPeriodOption fromValue(String value) {
    for (final option in values) {
      if (option.value == value) {
        return option;
      }
    }
    return monthly;
  }
}

class MoneyReportPeriodRange {
  const MoneyReportPeriodRange({
    required this.start,
    required this.endExclusive,
  });

  final DateTime start;
  final DateTime endExclusive;
}

/// 计算 [reportPeriod] 在 [anchor] 所在周期的起止（左闭右开）。
MoneyReportPeriodRange resolveMoneyReportPeriodRange(
  String reportPeriod,
  DateTime anchor,
) {
  final local = DateTime(anchor.year, anchor.month, anchor.day);
  switch (reportPeriod) {
    case 'weekly':
      final monday = local.subtract(Duration(days: local.weekday - 1));
      return MoneyReportPeriodRange(
        start: monday,
        endExclusive: monday.add(const Duration(days: 7)),
      );
    case 'quarterly':
      final quarterStartMonth = ((local.month - 1) ~/ 3) * 3 + 1;
      return MoneyReportPeriodRange(
        start: DateTime(local.year, quarterStartMonth),
        endExclusive: DateTime(local.year, quarterStartMonth + 3),
      );
    case 'yearly':
      return MoneyReportPeriodRange(
        start: DateTime(local.year),
        endExclusive: DateTime(local.year + 1),
      );
    case 'monthly':
    default:
      return MoneyReportPeriodRange(
        start: DateTime(local.year, local.month),
        endExclusive: DateTime(local.year, local.month + 1),
      );
  }
}
