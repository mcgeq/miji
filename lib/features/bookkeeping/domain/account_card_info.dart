import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

/// 账户卡片的语义分组。
///
/// 16 个账户类型不该对应 16 套卡片。用户看一张卡只是在问一个问题，
/// 按问题分组后每组一套固定骨架，组内只有「右侧辅助值 / 状态行」不同，
/// 卡片高度因此可控。
///
/// 分组判据必须与 `buildMoneyAccountDisplayGroups` 一致：
/// 授信与负债都进「信用/负债」组，不能再让贷款账户掉进资产分支。
enum AccountCardSemantic {
  /// 「我现在能花多少」：现金 / 银行 / 储蓄 / 钱包 / 其他。
  spendable,

  /// 「还能刷几次」：预付卡。
  prepaid,

  /// 「我还能刷多少、这期还多少」：信用卡 / 花呗 / 白条 / 美团月付 / 其他信用。
  credit,

  /// 「我还欠多少、还到哪了」：贷款。
  debt,

  /// 「值多少、涨了没」：投资。
  holding;

  /// 主值标签。同一个数字在不同组里含义完全不同，标签必须跟着分组走。
  String get primaryLabel {
    return switch (this) {
      AccountCardSemantic.spendable => '当前余额',
      AccountCardSemantic.prepaid => '余额',
      AccountCardSemantic.credit => '可用额度',
      AccountCardSemantic.debt => '剩余欠款',
      AccountCardSemantic.holding => '当前市值',
    };
  }

  /// 是否画一条进度（授信的额度使用率 / 负债的已还比例）。
  bool get hasProgressBar {
    return this == AccountCardSemantic.credit ||
        this == AccountCardSemantic.debt;
  }
}

AccountCardSemantic accountCardSemanticOf(MoneyAccountEntity account) {
  return switch (account.type) {
    MoneyAccountType.creditCard ||
    MoneyAccountType.huabei ||
    MoneyAccountType.baitiao ||
    MoneyAccountType.meituanCredit ||
    MoneyAccountType.otherCredit => AccountCardSemantic.credit,
    MoneyAccountType.loan => AccountCardSemantic.debt,
    MoneyAccountType.prepaidCard => AccountCardSemantic.prepaid,
    MoneyAccountType.investment => AccountCardSemantic.holding,
    MoneyAccountType.cash ||
    MoneyAccountType.bank ||
    MoneyAccountType.saving ||
    MoneyAccountType.alipay ||
    MoneyAccountType.wechat ||
    MoneyAccountType.cloudQuickPass ||
    MoneyAccountType.other ||
    MoneyAccountType.internal => AccountCardSemantic.spendable,
  };
}

/// 卡片主值（始终是正数）。
///
/// 贷款账户的 `balanceMinor` 存的是负数（欠款方向），直接丢给金额组件
/// 会渲染成「−¥486,200」——一个既不是余额也不是欠款的数。
int accountCardPrimaryAmountMinor(MoneyAccountEntity account) {
  return switch (accountCardSemanticOf(account)) {
    AccountCardSemantic.credit => account.availableCreditMinor,
    // 负债取绝对值并换标签，卡片才回答「还欠多少」。
    AccountCardSemantic.debt => account.balanceMinor.abs(),
    AccountCardSemantic.spendable ||
    AccountCardSemantic.prepaid ||
    AccountCardSemantic.holding => account.balanceMinor,
  };
}

/// 授信额度使用率。
///
/// 额度为 0（未设额度）时不画条，避免除零把整条渲染成满格红色。
class AccountCreditUsage {
  const AccountCreditUsage({required this.usedMinor, required this.limitMinor});

  final int usedMinor;
  final int limitMinor;

  bool get hasLimit => limitMinor > 0;

  /// 0~1，超出额度时封顶 1（条画满，但文案仍显示真实已用金额）。
  double get ratio {
    if (!hasLimit) {
      return 0;
    }
    return (usedMinor / limitMinor).clamp(0.0, 1.0);
  }

  /// 未封顶的真实使用率，用于「额度已用 118%」这类文案。
  double get rawRatio {
    if (!hasLimit) {
      return 0;
    }
    return usedMinor / limitMinor;
  }

  AccountCreditUsageLevel get level {
    if (!hasLimit) {
      return AccountCreditUsageLevel.normal;
    }
    if (rawRatio >= 0.9) {
      return AccountCreditUsageLevel.critical;
    }
    if (rawRatio >= 0.8) {
      return AccountCreditUsageLevel.warning;
    }
    return AccountCreditUsageLevel.normal;
  }
}

enum AccountCreditUsageLevel { normal, warning, critical }

AccountCreditUsage accountCreditUsageOf(MoneyAccountEntity account) {
  return AccountCreditUsage(
    usedMinor: account.usedCreditMinor,
    limitMinor: account.effectiveCreditLimitMinor,
  );
}

/// 负债还款进度。
///
/// 项目里**没有**真实的「贷款本金 / 已还总额」字段，只能拿建账时录入的
/// [MoneyAccountEntity.initialBalanceMinor] 当期初本金反推：
/// `已还 = |本金| − |当前余额|`。所以文案写「本金（建账时录入）」而不是
/// 「贷款总额」，被提前还款或一次性冲账时这个数会偏，但比
/// 「初始 −¥600,000」有用得多。
class AccountDebtProgress {
  const AccountDebtProgress({
    required this.outstandingMinor,
    required this.principalMinor,
  });

  /// 剩余欠款（正数）。
  final int outstandingMinor;

  /// 建账时录入的期初本金（正数）。
  final int principalMinor;

  /// 已还金额：可能为负（余额比建账时更负说明又借了），不做 clamp，
  /// 让「倒借」这件事在文案上暴露，而不是被悄悄显示成 0。
  int get repaidMinor => principalMinor - outstandingMinor;

  bool get hasProgress => principalMinor > 0;

  /// 0~1；本金为 0 或已还为负时按 0 处理。
  double get ratio {
    if (!hasProgress) {
      return 0;
    }
    return (repaidMinor / principalMinor).clamp(0.0, 1.0);
  }
}

AccountDebtProgress accountDebtProgressOf(MoneyAccountEntity account) {
  return AccountDebtProgress(
    outstandingMinor: account.balanceMinor.abs(),
    principalMinor: account.initialBalanceMinor.abs(),
  );
}
