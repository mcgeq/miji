/// 一组筛选条件下的流水汇总。
///
/// 列表是分页的，用户看到的只是「已加载的 N 笔」；而「这段时间一共花了多少」
/// 需要的是全量结果，所以单独走一次聚合查询。
class MoneyTransactionSummary {
  const MoneyTransactionSummary({
    required this.count,
    required this.expenseMinor,
    required this.incomeMinor,
  });

  const MoneyTransactionSummary.empty()
    : count = 0,
      expenseMinor = 0,
      incomeMinor = 0;

  /// 符合条件的**收支**笔数（仅 `expense` / `income`，**不含转账**）。
  ///
  /// 与 [expenseMinor] / [incomeMinor] 同口径，不随列表分页变化。
  final int count;

  /// 支出合计（仅 `type = expense`，已扣除退款，**不含转账**）。
  final int expenseMinor;

  /// 收入合计（仅 `type = income`，已扣除退款，**不含转账**）。
  final int incomeMinor;

  int get netMinor => incomeMinor - expenseMinor;
}
