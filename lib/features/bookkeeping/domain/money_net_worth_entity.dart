/// 净资产概览：只统计账本基准币种。
///
/// 账户页与首页都要用，所以放在记账域里，由各自的表现层再做包装。
class MoneyNetWorthSummary {
  const MoneyNetWorthSummary({
    required this.currencyCode,
    required this.assetMinor,
    required this.liabilityMinor,
  });

  const MoneyNetWorthSummary.empty({this.currencyCode = 'CNY'})
    : assetMinor = 0,
      liabilityMinor = 0;

  final String currencyCode;
  final int assetMinor;
  final int liabilityMinor;

  int get netAssetMinor => assetMinor - liabilityMinor;

  bool get hasAccounts => assetMinor != 0 || liabilityMinor != 0;

  /// 资产占比（0~1），用于占比条。
  double get assetRatio {
    final total = assetMinor + liabilityMinor;
    if (total <= 0) {
      return assetMinor > 0 ? 1 : 0;
    }
    return (assetMinor / total).clamp(0.0, 1.0);
  }
}
