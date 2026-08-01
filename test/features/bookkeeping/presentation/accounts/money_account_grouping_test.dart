import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_account_grouping.dart';

void main() {
  test(
    'groups active assets, credit debts, and inactive accounts separately',
    () {
      final groups = buildMoneyAccountDisplayGroups([
        _account(id: 'bank', name: '储蓄卡', type: MoneyAccountType.bank),
        _account(id: 'credit', name: '信用卡', type: MoneyAccountType.creditCard),
        _account(
          id: 'cash',
          name: '现金',
          type: MoneyAccountType.cash,
          isActive: false,
        ),
      ]);

      expect(groups.map((group) => group.kind), [
        MoneyAccountDisplayGroupKind.assets,
        MoneyAccountDisplayGroupKind.creditAndDebt,
        MoneyAccountDisplayGroupKind.inactive,
      ]);
      expect(groups[0].accounts.map((account) => account.id), ['bank']);
      expect(groups[1].accounts.map((account) => account.id), ['credit']);
      expect(groups[2].accounts.map((account) => account.id), ['cash']);
    },
  );

  test('summarizes credit statement amount due and available credit', () {
    final summary = summarizeCreditAccountStatements([
      _statement(
        accountId: 'credit-1',
        amountDueMinor: 120000,
        availableCreditMinor: 880000,
        state: MoneyCreditCardStatementState.dueSoon,
      ),
      _statement(
        accountId: 'credit-2',
        amountDueMinor: 50000,
        availableCreditMinor: 450000,
        state: MoneyCreditCardStatementState.overdue,
      ),
    ]);

    expect(summary.amountDueByCurrency, {'CNY': 170000});
    expect(summary.availableCreditByCurrency, {'CNY': 1330000});
    expect(summary.dueSoonCount, 1);
    expect(summary.overdueCount, 1);
  });
}

final _now = DateTime(2026, 7, 20, 12);

MoneyAccountEntity _account({
  required String id,
  required String name,
  required MoneyAccountType type,
  bool isActive = true,
}) {
  return MoneyAccountEntity(
    id: id,
    userId: 'user-1',
    name: name,
    type: type,
    balanceMinor: 100000,
    initialBalanceMinor: 100000,
    creditLimitMinor: type.isCreditLike ? 1000000 : null,
    postedDebtMinor: type.isCreditLike ? 0 : null,
    frozenCreditMinor: type.isCreditLike ? 0 : null,
    statementDay: type.isCreditLike ? 17 : null,
    budgetCycleStartDay: type.isCreditLike ? 16 : null,
    repaymentDay: type.isCreditLike ? 10 : null,
    autoRepaymentReminderEnabled: type.isCreditLike,
    currencyCode: 'CNY',
    isShared: false,
    isVirtual: false,
    isActive: isActive,
    isDeleted: false,
    createdAt: _now,
    updatedAt: _now,
  );
}

MoneyCreditCardStatement _statement({
  required String accountId,
  required int amountDueMinor,
  required int availableCreditMinor,
  required MoneyCreditCardStatementState state,
}) {
  return MoneyCreditCardStatement(
    accountId: accountId,
    currencyCode: 'CNY',
    periodStart: DateTime(2026, 6, 16),
    periodEndExclusive: DateTime(2026, 7, 16),
    repaymentDate: DateTime(2026, 8, 10),
    purchaseAmountMinor: amountDueMinor,
    repaymentAmountMinor: 0,
    amountDueMinor: amountDueMinor,
    availableCreditMinor: availableCreditMinor,
    postedDebtMinor: amountDueMinor,
    state: state,
  );
}
