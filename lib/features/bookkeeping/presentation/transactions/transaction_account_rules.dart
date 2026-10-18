import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

/// 记账时「哪些账户可选、该用什么支付方式」的判定规则。
///
/// 原来这套规则写在 `TransactionFormDialog` 的 State 里（私有方法）。新增
/// 「一屏记账」界面后如果复制一份，账户可选范围与支付方式锁定这两件事就会
/// 出现两套口径——改一处忘一处，最后表现为「同一个账户在 A 界面可选、在
/// B 界面不可选」。所以抽到这里，两条入口共用。
///
/// 只搬规则、不含界面：函数都是纯函数，可直接单测。

/// 按交易类型过滤可选账户。
///
/// * 收入只能进「资产类且非负债」账户（现金 / 银行 / 支付宝 / 微信…）；
/// * 支出可用资产类、信用类与内部账户（他人代付落内部账户）。
List<MoneyAccountEntity> selectableAccountsForType(
  MoneyTransactionType type,
  List<MoneyAccountEntity> accounts,
) {
  if (type == MoneyTransactionType.income) {
    return accounts
        .where(
          (account) => account.type.isAssetLike && !account.type.isDebtLike,
        )
        .toList();
  }
  if (type == MoneyTransactionType.expense) {
    return accounts
        .where(
          (account) =>
              account.type.isAssetLike ||
              account.type.isCreditLike ||
              account.type.isInternal,
        )
        .toList();
  }
  return accounts;
}

/// 该账户是否**锁死**了支付方式（如支付宝账户必然是支付宝）。
///
/// 返回 null 表示不锁定，用户可自选。
MoneyPaymentMethod? lockedPaymentMethodForAccount(MoneyAccountEntity? account) {
  return switch (account?.type) {
    MoneyAccountType.cash => MoneyPaymentMethod.cash,
    MoneyAccountType.huabei => MoneyPaymentMethod.huabei,
    MoneyAccountType.baitiao => MoneyPaymentMethod.baitiao,
    MoneyAccountType.alipay => MoneyPaymentMethod.alipay,
    MoneyAccountType.wechat => MoneyPaymentMethod.wechatPay,
    MoneyAccountType.cloudQuickPass => MoneyPaymentMethod.unionPay,
    _ => null,
  };
}

/// 该账户下可选的支付方式。
List<MoneyPaymentMethod> availablePaymentMethodsForAccount(
  MoneyAccountEntity? account,
) {
  final lockedMethod = lockedPaymentMethodForAccount(account);
  if (lockedMethod != null) {
    return [lockedMethod];
  }
  return switch (account?.type) {
    MoneyAccountType.creditCard => const [
      MoneyPaymentMethod.creditCard,
      MoneyPaymentMethod.bankTransfer,
      MoneyPaymentMethod.alipay,
      MoneyPaymentMethod.wechatPay,
      MoneyPaymentMethod.unionPay,
      MoneyPaymentMethod.onlinePayment,
      MoneyPaymentMethod.thirdParty,
      MoneyPaymentMethod.other,
    ],
    MoneyAccountType.meituanCredit || MoneyAccountType.otherCredit => const [
      MoneyPaymentMethod.onlinePayment,
      MoneyPaymentMethod.thirdParty,
      MoneyPaymentMethod.alipay,
      MoneyPaymentMethod.wechatPay,
      MoneyPaymentMethod.bankTransfer,
      MoneyPaymentMethod.other,
    ],
    _ => MoneyPaymentMethod.values,
  };
}

/// 落库时真正写入的支付方式：账户锁定优先，否则保留用户当前选择
/// （当前选择不在可选集合里时退回第一个）。
MoneyPaymentMethod effectivePaymentMethodForAccount(
  MoneyAccountEntity? account,
  MoneyPaymentMethod preferred,
) {
  final lockedMethod = lockedPaymentMethodForAccount(account);
  if (lockedMethod != null) {
    return lockedMethod;
  }
  final methods = availablePaymentMethodsForAccount(account);
  if (methods.contains(preferred)) {
    return preferred;
  }
  return methods.first;
}
