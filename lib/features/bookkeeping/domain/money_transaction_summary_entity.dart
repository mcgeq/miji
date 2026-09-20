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

  /// 符合条件的流水笔数（含转账）。
  final int count;

  /// 支出合计（已扣除退款）。
  final int expenseMinor;

  /// 收入合计（已扣除退款）。
  final int incomeMinor;

  int get netMinor => incomeMinor - expenseMinor;
}
