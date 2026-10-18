/// 记账输入建议：从历史流水提炼的常用商户与自定义支付方式名，
/// 用于交易表单的自动完成与快捷选择。
class MoneyEntrySuggestions {
  const MoneyEntrySuggestions({
    this.merchants = const <String>[],
    this.customPaymentMethods = const <String>[],
  });

  const MoneyEntrySuggestions.empty()
    : merchants = const <String>[],
      customPaymentMethods = const <String>[];

  /// 历史商户名（按最近使用排序，已去重）。
  final List<String> merchants;

  /// 历史自定义支付方式名（如“美团月付”“京东支付”，按最近使用排序，已去重）。
  final List<String> customPaymentMethods;

  bool get isEmpty => merchants.isEmpty && customPaymentMethods.isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is MoneyEntrySuggestions &&
        _listEquals(other.merchants, merchants) &&
        _listEquals(other.customPaymentMethods, customPaymentMethods);
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAll(merchants),
    Object.hashAll(customPaymentMethods),
  );

  static bool _listEquals(List<String> a, List<String> b) {
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
}
