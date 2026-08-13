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
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

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

    expect(find.textContaining(_sharedCashAccount.name), findsNWidgets(2));
    expect(find.textContaining(_foodCategory.name), findsOneWidget);

    await tester.tap(find.text(_familyLedgerA.name));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(_familyLedgerB.name).last);
    await tester.pumpAndSettle();

    expect(find.textContaining(_sharedCashAccount.name), findsNWidgets(2));
    expect(find.textContaining(_foodCategory.name), findsOneWidget);
  });

  testWidgets('paid-by-others checkbox hides account selector and submits '
      'with the internal account', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Object? popResult;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith((ref) async* {
            yield const <MoneyLedgerEntity>[];
          }),
          currentUserVisibleAccountsProvider.overrideWith((ref) async* {
            yield [_sharedCashAccount];
          }),
          currentUserMoneyInternalAccountsProvider.overrideWith((ref) async* {
            yield [_internalAccount];
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
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () async {
                    popResult = await Navigator.of(context).push<Object?>(
                      MaterialPageRoute<Object?>(
                        builder: (_) => TransactionFormDialog(
                          type: MoneyTransactionType.expense,
                        ),
                      ),
                    );
                  },
                  child: const Text('打开记账弹窗'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开记账弹窗'));
    await tester.pumpAndSettle();

    // 默认显示账户选择器。
    expect(find.text('账户'), findsOneWidget);

    // 输入金额。
    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pumpAndSettle();

    // 勾选"他人代付"。
    await tester.tap(find.text('他人代付'));
    await tester.pumpAndSettle();

    // 账户选择器隐藏，提示内部账户。
    expect(find.text('账户'), findsNothing);
    expect(find.text('他人代付：保存后将自动记入系统内部账户'), findsOneWidget);

    // 选择分类。
    await tester.tap(find.text('分类'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining(_foodCategory.name).last);
    await tester.pumpAndSettle();

    // 提交。
    await tester.tap(find.byTooltip('创建'));
    await tester.pumpAndSettle();

    expect(popResult, isA<TransactionCreateFormResult>());
    final result = popResult! as TransactionCreateFormResult;
    expect(result.draft.accountId, _internalAccount.id);
    expect(result.draft.amountMinor, 10000);
  });

  testWidgets(
    'editing a paid-by-others transaction keeps the checkbox checked',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      Object? popResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserMoneyLedgersProvider.overrideWith((ref) async* {
              yield const <MoneyLedgerEntity>[];
            }),
            currentUserVisibleAccountsProvider.overrideWith((ref) async* {
              yield [_sharedCashAccount];
            }),
            currentUserMoneyInternalAccountsProvider.overrideWith((ref) async* {
              yield [_internalAccount];
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
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () async {
                      popResult = await Navigator.of(context).push<Object?>(
                        MaterialPageRoute<Object?>(
                          builder: (_) => TransactionFormDialog(
                            type: MoneyTransactionType.expense,
                            transaction: _paidByOtherTransaction,
                          ),
                        ),
                      );
                    },
                    child: const Text('打开记账弹窗'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('打开记账弹窗'));
      await tester.pumpAndSettle();

      // 编辑他人代付交易：复选框默认勾选、账户选择器隐藏。
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(find.text('账户'), findsNothing);

      // 去掉勾选后账户选择器恢复显示。
      await tester.tap(find.text('他人代付'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(find.text('账户'), findsOneWidget);

      // 重新勾选并保存，账户仍为内部账户。
      await tester.tap(find.text('他人代付'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('保存'));
      await tester.pumpAndSettle();

      expect(popResult, isA<MoneyTransactionUpdate>());
      final update = popResult! as MoneyTransactionUpdate;
      expect(update.accountId, _internalAccount.id);
    },
  );
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

final _internalAccount = MoneyAccountEntity(
  id: 'internal-account-user-1',
  userId: 'user-1',
  name: '内部账户',
  type: MoneyAccountType.internal,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: null,
  postedDebtMinor: null,
  frozenCreditMinor: null,
  statementDay: null,
  budgetCycleStartDay: null,
  repaymentDay: null,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: true,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _paidByOtherTransaction = MoneyTransactionEntity(
  id: 'tx-paid-by-others',
  userId: 'user-1',
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  transactionAt: _now,
  amountMinor: 5000,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '支出',
  notes: null,
  merchant: null,
  location: null,
  accountId: _internalAccount.id,
  toAccountId: null,
  categoryId: _foodCategory.id,
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.other,
  customPaymentMethodName: null,
  actualPayerAccount: 'default',
  relatedTransactionId: null,
  installmentPlanId: null,
  sourceTemplateRunId: null,
  interestRateBasisPoints: null,
  totalInterestMinor: 0,
  calcMethod: null,
  tags: const [],
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
