import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/credit_card_statement_reconciliation_sheet.dart';

void main() {
  testWidgets('shows credit card statement summary and transactions', (
    tester,
  ) async {
    var repayTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CreditCardStatementReconciliationSheet(
            account: _creditAccount,
            statement: _statement,
            onRepay: () => repayTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('招商信用卡'), findsWidgets);
    expect(find.text('账单核对'), findsOneWidget);
    expect(find.text('2026.6.16 - 2026.7.15'), findsOneWidget);
    expect(find.text('本期消费'), findsOneWidget);
    expect(find.text('已还款'), findsOneWidget);
    expect(find.text('本期应还'), findsOneWidget);
    expect(find.text('¥1,234.56'), findsWidgets);
    expect(find.text('¥200.00'), findsWidgets);
    expect(find.text('¥1,034.56'), findsOneWidget);
    expect(find.text('超市购物'), findsOneWidget);
    expect(find.text('信用卡还款'), findsOneWidget);

    await tester.tap(find.byTooltip('还款'));
    await tester.pumpAndSettle();

    expect(repayTapped, isTrue);
  });

  testWidgets('shows adjust action only when statement has difference', (
    tester,
  ) async {
    var adjustTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CreditCardStatementReconciliationSheet(
            account: _creditAccount,
            statement: _statement,
            onAdjust: () => adjustTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('待补记差额'), findsNothing);
    expect(find.byTooltip('补记差额'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CreditCardStatementReconciliationSheet(
            account: _creditAccount,
            statement: _statementWithDifference,
            onAdjust: () => adjustTapped = true,
          ),
        ),
      ),
    );

    expect(find.text('待补记差额'), findsOneWidget);
    expect(find.text('¥34.56'), findsOneWidget);

    await tester.tap(find.byTooltip('补记差额'));
    await tester.pumpAndSettle();

    expect(adjustTapped, isTrue);
  });
  testWidgets('hides repay action when statement is settled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CreditCardStatementReconciliationSheet(
            account: _creditAccount,
            statement: _statementSettled,
            onRepay: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip('还款'), findsNothing);
    expect(find.textContaining('已还清'), findsWidgets);
  });
}

final _now = DateTime(2026, 7, 20, 12);

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '招商信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 2000000,
  postedDebtMinor: 103456,
  frozenCreditMinor: 0,
  statementDay: 17,
  budgetCycleStartDay: 16,
  repaymentDay: 5,
  autoRepaymentReminderEnabled: true,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _purchase = MoneyTransactionEntity(
  id: 'transaction-1',
  userId: 'user-1',
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  transactionAt: DateTime(2026, 6, 18, 10),
  amountMinor: 123456,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '超市购物',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'credit-1',
  toAccountId: null,
  categoryId: 'category-1',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.creditCard,
  customPaymentMethodName: null,
  actualPayerAccount: 'default',
  relatedTransactionId: null,
  installmentPlanId: null,
  sourceTemplateRunId: null,
  interestRateBasisPoints: null,
  totalInterestMinor: 0,
  calcMethod: null,
  tags: const <String>[],
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _repayment = MoneyTransactionEntity(
  id: 'transaction-2',
  userId: 'user-1',
  type: MoneyTransactionType.transfer,
  status: MoneyTransactionStatus.completed,
  transactionAt: DateTime(2026, 7, 3, 10),
  amountMinor: 20000,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '信用卡还款',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'bank-1',
  toAccountId: 'credit-1',
  categoryId: 'system_transfer',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.bankTransfer,
  customPaymentMethodName: null,
  actualPayerAccount: 'default',
  relatedTransactionId: null,
  installmentPlanId: null,
  sourceTemplateRunId: null,
  interestRateBasisPoints: null,
  totalInterestMinor: 0,
  calcMethod: null,
  tags: const <String>[],
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _statement = MoneyCreditCardStatement(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  periodStart: DateTime(2026, 6, 16),
  periodEndExclusive: DateTime(2026, 7, 16),
  repaymentDate: DateTime(2026, 8, 5),
  purchaseAmountMinor: 123456,
  repaymentAmountMinor: 20000,
  amountDueMinor: 103456,
  availableCreditMinor: 1896544,
  postedDebtMinor: 103456,
  state: MoneyCreditCardStatementState.dueSoon,
  transactions: [_purchase, _repayment],
);

final _statementWithDifference = MoneyCreditCardStatement(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  periodStart: DateTime(2026, 6, 16),
  periodEndExclusive: DateTime(2026, 7, 16),
  repaymentDate: DateTime(2026, 8, 5),
  purchaseAmountMinor: 123456,
  repaymentAmountMinor: 20000,
  amountDueMinor: 100000,
  availableCreditMinor: 1900000,
  postedDebtMinor: 100000,
  state: MoneyCreditCardStatementState.dueSoon,
  transactions: [_purchase],
);
final _statementSettled = MoneyCreditCardStatement(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  periodStart: DateTime(2026, 6, 16),
  periodEndExclusive: DateTime(2026, 7, 16),
  repaymentDate: DateTime(2026, 8, 5),
  purchaseAmountMinor: 123456,
  repaymentAmountMinor: 123456,
  amountDueMinor: 0,
  availableCreditMinor: 2000000,
  postedDebtMinor: 0,
  state: MoneyCreditCardStatementState.settled,
  transactions: [_purchase, _repayment],
);
