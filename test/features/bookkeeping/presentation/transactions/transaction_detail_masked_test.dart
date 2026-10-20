import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 流水详情弹窗的金额遮罩。
///
/// 这条链原来只有一个漏点：详情弹窗挂在**根导航器**上，而
/// `MoneyPrivacyScope` 当时挂在 `AppShellPage` 里，`MoneyPrivacy.of` 读不到
/// 就退回 `false` —— 于是卡面 ••••、账户弹窗 ••••，点开某一笔流水却全露。
/// 现在作用域提到了 `ProviderScope` 正下方，另加一个显式参数兜住
/// 「单账户被显式隐藏」这种只有卡片知道的状态。
void main() {
  testWidgets('显式传入遮罩时，详情金额不露出', (tester) async {
    await tester.pumpWidget(_harness(amountHidden: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    expect(find.text('流水详情'), findsOneWidget);
    expect(find.textContaining('28.00'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets('未传参时跟随全局遮罩（作用域在 MaterialApp 之外也读得到）', (tester) async {
    await tester.pumpWidget(_harness(masked: true));
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    expect(find.text('流水详情'), findsOneWidget);
    // 关键：弹窗挂在根导航器上，如果作用域仍在 Shell 里，这里会露金额。
    expect(find.textContaining('28.00'), findsNothing);
    expect(find.text('••••'), findsOneWidget);
  });

  testWidgets('未遮罩时正常显示金额', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开详情'));
    await tester.pumpAndSettle();

    expect(find.text('-¥28.00'), findsOneWidget);
    expect(find.text('••••'), findsNothing);
  });
}

Widget _harness({bool masked = false, bool? amountHidden}) {
  return ProviderScope(
    overrides: [
      currentUserPreferencesProvider.overrideWith(
        (ref) async => _preferences(maskMoneyAmounts: masked),
      ),
      currentUserVisibleAccountsProvider.overrideWith(
        (ref) => Stream.value([_account]),
      ),
      currentUserCategoryCatalogProvider(
        MoneyCategoryKind.expense,
      ).overrideWith((ref) => Stream.value(_expenseCatalog)),
      currentUserCategoryCatalogProvider(
        MoneyCategoryKind.income,
      ).overrideWith((ref) => Stream.value(const MoneyCategoryCatalog.empty())),
      currentUserSplitRecordsForTransactionProvider(
        _expense.id,
      ).overrideWith((ref) => Stream.value(const <MoneySplitRecordEntity>[])),
      currentUserTransactionLedgersProvider(
        _expense.id,
      ).overrideWith((ref) => Stream.value(const <MoneyLedgerEntity>[])),
      currentUserInstallmentPlansProvider.overrideWith(
        (ref) => Stream.value(const <MoneyInstallmentPlanEntity>[]),
      ),
    ],
    // 作用域故意包在 MaterialApp **外面**：与 main.dart 的真实结构一致。
    // 包在 home 里的话，对话框拿不到作用域，这个测试反而会「通过」不了。
    child: MoneyPrivacyScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showTransactionDetailProviderDialog(
                  context: context,
                  transaction: _expense,
                  isAmountHidden: amountHidden,
                ),
                child: const Text('打开详情'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

final _now = DateTime(2026, 10, 20);

final _account = MoneyAccountEntity(
  id: 'bank-1',
  userId: 'user-1',
  name: '储蓄卡',
  type: MoneyAccountType.bank,
  balanceMinor: 1234567,
  initialBalanceMinor: 1234567,
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

final _expense = MoneyTransactionEntity(
  id: 'transaction-1',
  userId: 'user-1',
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  transactionAt: DateTime(2026, 10, 20, 9, 12),
  amountMinor: 2800,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '瑞幸咖啡',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'bank-1',
  toAccountId: null,
  categoryId: 'category-food',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.onlinePayment,
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

const _expenseCatalog = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'category-food',
      userId: null,
      name: '餐饮',
      kind: MoneyCategoryKind.expense,
      color: '#F97316',
      icon: 'restaurant',
      isSystem: true,
    ),
  ],
  subCategories: <MoneySubCategoryEntity>[],
);

UserPreferencesEntity _preferences({required bool maskMoneyAmounts}) {
  final now = DateTime(2026, 1, 1);
  return UserPreferencesEntity(
    userId: 'user-1',
    themeMode: AppThemeModePreference.system,
    sensitiveAccessTtl: SensitiveAccessTtlOption.defaultOption,
    currencyCode: 'CNY',
    maskMoneyAmounts: maskMoneyAmounts,
    createdAt: now,
    updatedAt: now,
  );
}
