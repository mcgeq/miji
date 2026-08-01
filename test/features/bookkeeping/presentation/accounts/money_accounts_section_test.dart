import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_accounts_section.dart';

void main() {
  testWidgets('shows account group tabs and wraps credit statement details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserVisibleAccountsProvider.overrideWith((ref) async* {
            yield [_assetAccount, _creditAccount, _inactiveAccount];
          }),
          currentUserAccountMonthlySummariesProvider.overrideWith((ref) async {
            return const <String, MoneyAccountMonthlySummary>{};
          }),
          currentUserCreditCardBillViewProvider(
            _creditAccount.id,
          ).overrideWith((ref) async => _bill),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MoneyAccountsSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('资产账户'), findsOneWidget);
    expect(find.text('信用/负债账户'), findsOneWidget);
    expect(find.text('停用账户'), findsOneWidget);

    await tester.tap(find.text('信用/负债账户'));
    await tester.pumpAndSettle();

    expect(find.text('信用卡'), findsWidgets);
    expect(find.text('储蓄卡'), findsNothing);
    expect(find.text('旧账户'), findsNothing);
    expect(find.text('本期应还 ¥1,200.00'), findsOneWidget);
    expect(find.text('8月10日还款'), findsOneWidget);
    expect(find.text('临近还款'), findsOneWidget);
  });
}

final _now = DateTime(2026, 7, 20, 12);

final _assetAccount = MoneyAccountEntity(
  id: 'asset-1',
  userId: 'user-1',
  name: '储蓄卡',
  type: MoneyAccountType.bank,
  balanceMinor: 123456,
  initialBalanceMinor: 123456,
  creditLimitMinor: null,
  postedDebtMinor: null,
  frozenCreditMinor: null,
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

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 1000000,
  postedDebtMinor: 100000,
  frozenCreditMinor: 0,
  statementDay: 17,
  budgetCycleStartDay: 16,
  repaymentDay: 10,
  autoRepaymentReminderEnabled: true,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _inactiveAccount = MoneyAccountEntity(
  id: 'inactive-1',
  userId: 'user-1',
  name: '旧账户',
  type: MoneyAccountType.cash,
  balanceMinor: 5000,
  initialBalanceMinor: 5000,
  creditLimitMinor: null,
  postedDebtMinor: null,
  frozenCreditMinor: null,
  statementDay: null,
  budgetCycleStartDay: null,
  repaymentDay: null,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: false,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _bill = MoneyCreditCardBillView(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  source: MoneyCreditCardBillViewSource.issuedStatement,
  periodStart: DateTime(2026, 6, 16),
  periodEndExclusive: DateTime(2026, 7, 16),
  repaymentDate: DateTime(2026, 8, 10),
  purchaseAmountMinor: 150000,
  repaymentAmountMinor: 30000,
  amountDueMinor: 120000,
  availableCreditMinor: 880000,
  postedDebtMinor: 120000,
  state: MoneyCreditCardStatementState.dueSoon,
);
