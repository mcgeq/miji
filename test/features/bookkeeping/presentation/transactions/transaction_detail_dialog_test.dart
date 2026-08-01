import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';

void main() {
  testWidgets('detail dialog dismisses itself before edit action', (
    tester,
  ) async {
    var edited = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showTransactionDetailDialog(
                        context: context,
                        transaction: _transaction,
                        accounts: [_account],
                        expenseCatalog: const MoneyCategoryCatalog.empty(),
                        incomeCatalog: const MoneyCategoryCatalog.empty(),
                        onEdit: () => edited = true,
                      );
                    },
                    child: const Text('open detail'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open detail'));
    await tester.pumpAndSettle();

    expect(find.text('流水详情'), findsOneWidget);

    await tester.tap(find.byTooltip('编辑'));
    await tester.pumpAndSettle();

    expect(edited, isTrue);
    expect(find.text('流水详情'), findsNothing);
  });
}

final _now = DateTime(2026, 1, 2, 12, 30);

final _account = MoneyAccountEntity(
  id: 'account-1',
  userId: 'user-1',
  name: '现金账户',
  type: MoneyAccountType.cash,
  balanceMinor: 100000,
  initialBalanceMinor: 100000,
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

final _transaction = MoneyTransactionEntity(
  id: 'transaction-1',
  userId: 'user-1',
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  transactionAt: _now,
  amountMinor: 1234,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '午餐',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'account-1',
  toAccountId: null,
  categoryId: 'category-1',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.cash,
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
