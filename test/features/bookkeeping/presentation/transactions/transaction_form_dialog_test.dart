import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  testWidgets('keeps entered transaction fields when switching ledgers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith((ref) async* {
            yield [_familyLedgerA, _familyLedgerB];
          }),
          currentUserMoneyLedgerAccountsProvider(
            _familyLedgerA.id,
          ).overrideWith((ref) async* {
            yield [_sharedCashAccount, _backupCashAccount];
          }),
          currentUserMoneyLedgerAccountsProvider(
            _familyLedgerB.id,
          ).overrideWith((ref) async* {
            yield [_sharedCashAccount, _backupCashAccount];
          }),
          currentUserCategoryCatalogProvider(
            MoneyCategoryKind.expense,
          ).overrideWith((ref) async* {
            yield _expenseCatalog;
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransactionFormDialog(
              type: MoneyTransactionType.expense,
              ledger: _familyLedgerA,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('账户'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(_sharedCashAccount.name).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(_foodCategory.name).last);
    await tester.pumpAndSettle();

    expect(find.textContaining(_sharedCashAccount.name), findsOneWidget);
    expect(find.textContaining(_foodCategory.name), findsOneWidget);

    await tester.tap(find.text(_familyLedgerA.name));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(_familyLedgerB.name).last);
    await tester.pumpAndSettle();

    expect(find.textContaining(_sharedCashAccount.name), findsOneWidget);
    expect(find.textContaining(_foodCategory.name), findsOneWidget);
  });
}

final _now = DateTime(2026, 7, 22, 12);

final _familyLedgerA = MoneyLedgerEntity(
  id: 'ledger-family-a',
  userId: 'user-1',
  name: '家庭账本A',
  ledgerType: 'family',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: _now,
  updatedAt: _now,
);

final _familyLedgerB = MoneyLedgerEntity(
  id: 'ledger-family-b',
  userId: 'user-1',
  name: '家庭账本B',
  ledgerType: 'family',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: _now,
  updatedAt: _now,
);

final _sharedCashAccount = MoneyAccountEntity(
  id: 'shared-cash',
  userId: 'user-1',
  name: '共同现金',
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
  isShared: true,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _backupCashAccount = MoneyAccountEntity(
  id: 'backup-cash',
  userId: 'user-1',
  name: '备用现金',
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
  isShared: true,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

const _foodCategory = MoneyCategoryEntity(
  id: 'category-food',
  userId: 'user-1',
  name: '餐饮',
  kind: MoneyCategoryKind.expense,
  color: null,
  icon: null,
  isSystem: false,
);

const _expenseCatalog = MoneyCategoryCatalog(
  categories: [_foodCategory],
  subCategories: [],
);
