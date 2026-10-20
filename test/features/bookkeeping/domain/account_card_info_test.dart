import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/account_card_info.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';

void main() {
  group('语义分组', () {
    test('每种账户类型都落到唯一一个语义组', () {
      expect(_semantic(MoneyAccountType.cash), AccountCardSemantic.spendable);
      expect(_semantic(MoneyAccountType.bank), AccountCardSemantic.spendable);
      expect(_semantic(MoneyAccountType.saving), AccountCardSemantic.spendable);
      expect(_semantic(MoneyAccountType.alipay), AccountCardSemantic.spendable);
      expect(_semantic(MoneyAccountType.wechat), AccountCardSemantic.spendable);
      expect(
        _semantic(MoneyAccountType.cloudQuickPass),
        AccountCardSemantic.spendable,
      );
      expect(_semantic(MoneyAccountType.other), AccountCardSemantic.spendable);

      expect(
        _semantic(MoneyAccountType.prepaidCard),
        AccountCardSemantic.prepaid,
      );

      expect(
        _semantic(MoneyAccountType.creditCard),
        AccountCardSemantic.credit,
      );
      expect(_semantic(MoneyAccountType.huabei), AccountCardSemantic.credit);
      expect(_semantic(MoneyAccountType.baitiao), AccountCardSemantic.credit);
      expect(
        _semantic(MoneyAccountType.meituanCredit),
        AccountCardSemantic.credit,
      );
      expect(
        _semantic(MoneyAccountType.otherCredit),
        AccountCardSemantic.credit,
      );

      expect(_semantic(MoneyAccountType.loan), AccountCardSemantic.debt);
      expect(
        _semantic(MoneyAccountType.investment),
        AccountCardSemantic.holding,
      );
    });

    /// 分组判据必须和 `buildMoneyAccountDisplayGroups` 一致：授信 + 负债
    /// 都进「信用/负债」组。曾出现过贷款卡被渲染成资产卡（显示负余额）。
    test('授信与负债组恰好是 isCreditLike || isDebtLike', () {
      for (final type in MoneyAccountType.values) {
        final isCreditOrDebt =
            accountCardSemanticOf(_account(type)) ==
                AccountCardSemantic.credit ||
            accountCardSemanticOf(_account(type)) == AccountCardSemantic.debt;
        expect(
          isCreditOrDebt,
          type.isCreditLike || type.isDebtLike,
          reason: '${type.label} 的语义分组与列表分组不一致',
        );
      }
    });

    test('只有授信与负债画进度条', () {
      expect(AccountCardSemantic.credit.hasProgressBar, isTrue);
      expect(AccountCardSemantic.debt.hasProgressBar, isTrue);
      expect(AccountCardSemantic.spendable.hasProgressBar, isFalse);
      expect(AccountCardSemantic.prepaid.hasProgressBar, isFalse);
      expect(AccountCardSemantic.holding.hasProgressBar, isFalse);
    });
  });

  group('主值', () {
    test('资产账户取余额', () {
      final account = _account(MoneyAccountType.bank);
      expect(accountCardPrimaryAmountMinor(account), 123456);
    });

    test('授信账户取可用额度而不是余额', () {
      final account = _account(
        MoneyAccountType.creditCard,
        balanceMinor: 0,
        initialBalanceMinor: 1000000,
        creditLimitMinor: 1000000,
        postedDebtMinor: 100000,
      );
      expect(accountCardPrimaryAmountMinor(account), 900000);
    });

    test('贷款账户取绝对值：卡面写「剩余欠款」不能是负数', () {
      final account = _account(
        MoneyAccountType.loan,
        balanceMinor: -48620000,
        initialBalanceMinor: -60000000,
      );
      expect(accountCardPrimaryAmountMinor(account), 48620000);
    });
  });

  group('授信额度使用率', () {
    test('未设额度不画条也不报危险', () {
      final usage = accountCreditUsageOf(
        _account(MoneyAccountType.creditCard, creditLimitMinor: 0),
      );
      expect(usage.hasLimit, isFalse);
      expect(usage.ratio, 0);
      expect(usage.level, AccountCreditUsageLevel.normal);
    });

    test('80% / 90% 是两档告警边界', () {
      expect(_usageLevel(7900, 10000), AccountCreditUsageLevel.normal);
      expect(_usageLevel(8000, 10000), AccountCreditUsageLevel.warning);
      expect(_usageLevel(8900, 10000), AccountCreditUsageLevel.warning);
      expect(_usageLevel(9000, 10000), AccountCreditUsageLevel.critical);
    });

    test('超额时条画满但真实比例保留，用于「已用 118%」文案', () {
      final usage = accountCreditUsageOf(
        _account(
          MoneyAccountType.creditCard,
          creditLimitMinor: 100000,
          postedDebtMinor: 118000,
        ),
      );
      expect(usage.ratio, 1.0);
      expect(usage.rawRatio, closeTo(1.18, 1e-9));
      expect(usage.level, AccountCreditUsageLevel.critical);
    });
  });

  group('负债还款进度', () {
    test('按建账本金反推已还金额与比例', () {
      final progress = accountDebtProgressOf(
        _account(
          MoneyAccountType.loan,
          balanceMinor: -48620000,
          initialBalanceMinor: -60000000,
        ),
      );
      expect(progress.outstandingMinor, 48620000);
      expect(progress.principalMinor, 60000000);
      expect(progress.repaidMinor, 11380000);
      expect(progress.ratio, closeTo(0.1896666, 1e-6));
      expect(progress.hasProgress, isTrue);
    });

    test('没有建账本金时不画进度', () {
      final progress = accountDebtProgressOf(
        _account(
          MoneyAccountType.loan,
          balanceMinor: -100000,
          initialBalanceMinor: 0,
        ),
      );
      expect(progress.hasProgress, isFalse);
      expect(progress.ratio, 0);
    });

    test('余额比建账时更负（又借了）时已还为负，比例夹到 0', () {
      final progress = accountDebtProgressOf(
        _account(
          MoneyAccountType.loan,
          balanceMinor: -120000,
          initialBalanceMinor: -100000,
        ),
      );
      expect(progress.repaidMinor, -20000);
      expect(progress.ratio, 0);
    });

    test('还清时比例为 100%', () {
      final progress = accountDebtProgressOf(
        _account(
          MoneyAccountType.loan,
          balanceMinor: 0,
          initialBalanceMinor: -100000,
        ),
      );
      expect(progress.outstandingMinor, 0);
      expect(progress.ratio, 1.0);
    });
  });
}

AccountCardSemantic _semantic(MoneyAccountType type) {
  return accountCardSemanticOf(_account(type));
}

AccountCreditUsageLevel _usageLevel(int usedMinor, int limitMinor) {
  return accountCreditUsageOf(
    _account(
      MoneyAccountType.creditCard,
      creditLimitMinor: limitMinor,
      postedDebtMinor: usedMinor,
    ),
  ).level;
}

final _now = DateTime(2026, 10, 20);

MoneyAccountEntity _account(
  MoneyAccountType type, {
  int balanceMinor = 123456,
  int initialBalanceMinor = 123456,
  int? creditLimitMinor,
  int? postedDebtMinor,
}) {
  return MoneyAccountEntity(
    id: 'account-${type.storageValue}',
    userId: 'user-1',
    name: type.label,
    type: type,
    balanceMinor: balanceMinor,
    initialBalanceMinor: initialBalanceMinor,
    creditLimitMinor: creditLimitMinor,
    postedDebtMinor: postedDebtMinor,
    frozenCreditMinor: 0,
    statementDay: null,
    budgetCycleStartDay: null,
    repaymentDay: null,
    autoRepaymentReminderEnabled: false,
    currencyCode: 'CNY',
    isShared: false,
    isVirtual: false,
    isActive: true,
    isDeleted: false,
    createdAt: _now,
    updatedAt: _now,
  );
}
