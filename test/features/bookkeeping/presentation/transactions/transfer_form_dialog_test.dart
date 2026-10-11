import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';

/// 转账表单与记一笔表单的对齐口径（P1-7）：
///
/// ① 新建时金额框自动聚焦（`autofocus: !_isEditing`）；
/// ② 只有传了 `onSubmit` 才有「保存并继续」——它要求表单自己完成写入，
///    结果 pop 给调用方的那种用法没法「继续」；
/// ③ 编辑态两者都没有：改一笔旧账不该抢焦点，也没有「再来一笔」的语义。
void main() {
  testWidgets(
    'create mode autofocuses the amount and offers save-and-continue',
    (tester) async {
      await _pump(tester, onSubmit: (draft) async => null);

      expect(_amountField(tester).autofocus, isTrue);
      expect(find.byTooltip('保存并继续'), findsOneWidget);
      expect(find.byTooltip('创建'), findsOneWidget);
    },
  );

  testWidgets('no save-and-continue when the caller keeps the pop contract', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byTooltip('保存并继续'), findsNothing);
    expect(find.byTooltip('创建'), findsOneWidget);
  });

  testWidgets('edit mode neither autofocuses nor offers save-and-continue', (
    tester,
  ) async {
    await _pump(
      tester,
      transaction: _transferTransaction,
      onSubmit: (draft) async => null,
    );

    expect(_amountField(tester).autofocus, isFalse);
    expect(find.byTooltip('保存并继续'), findsNothing);
    expect(find.byTooltip('保存'), findsOneWidget);
  });
}

AppAmountField _amountField(WidgetTester tester) =>
    tester.widget<AppAmountField>(find.byType(AppAmountField));

Future<void> _pump(
  WidgetTester tester, {
  MoneyTransactionEntity? transaction,
  TransferFormSubmit? onSubmit,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserCurrentLedgerValueProvider.overrideWithValue(_ledger),
        currentUserMoneyTransferAccountsProvider.overrideWith(
          (ref, ledgerId) => Stream.value([_cashAccount, _savingAccount]),
        ),
        currentUserCategoryCatalogProvider.overrideWith(
          (ref, kind) => Stream.value(_catalog),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransferFormDialog(
            transaction: transaction,
            onSubmit: onSubmit,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _createdAt = DateTime(2026, 1, 1);

final _ledger = MoneyLedgerEntity(
  id: 'ledger-1',
  userId: 'user-1',
  name: '日常账本',
  ledgerType: 'personal',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

final _cashAccount = MoneyAccountEntity(
  id: 'cash-1',
  userId: 'user-1',
  name: '现金',
  type: MoneyAccountType.cash,
  balanceMinor: 100000,
  initialBalanceMinor: 100000,
  creditLimitMinor: null,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: null,
  budgetCycleStartDay: 1,
  repaymentDay: null,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

final _savingAccount = MoneyAccountEntity(
  id: 'saving-1',
  userId: 'user-1',
  name: '招商银行储蓄卡',
  type: MoneyAccountType.saving,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: null,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: null,
  budgetCycleStartDay: 1,
  repaymentDay: null,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

final _transferTransaction = MoneyTransactionEntity(
  id: 'transfer-1',
  userId: 'user-1',
  type: MoneyTransactionType.transfer,
  status: MoneyTransactionStatus.completed,
  transactionAt: _createdAt,
  amountMinor: 20000,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '转账',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'cash-1',
  toAccountId: 'saving-1',
  categoryId: 'system_transfer',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.bankTransfer,
  customPaymentMethodName: null,
  actualPayerAccount: 'transfer_out',
  relatedTransactionId: null,
  installmentPlanId: null,
  sourceTemplateRunId: null,
  interestRateBasisPoints: null,
  totalInterestMinor: 0,
  calcMethod: null,
  tags: const [],
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

const _catalog = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'system_transfer',
      userId: 'user-1',
      name: '转账',
      kind: MoneyCategoryKind.expense,
      color: '#4F7DD9',
      icon: 'swap_horiz',
      isSystem: true,
    ),
  ],
  subCategories: [],
);
