import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/shared/widgets/app_amount_field.dart';

/// 回归：曾经的自定义数字键盘会在「点其他输入框拉起系统键盘」时切换布局，
/// 顺便把焦点抢回金额框，导致商家/备注永远输不进去。键盘已整体移除。
void main() {
  testWidgets('typing in the merchant field does not jump back to the amount', (
    tester,
  ) async {
    await _pumpForm(tester);

    // 展开「更多信息」，聚焦商家输入框。
    await _tap(tester, find.text('更多信息'));
    await _tap(tester, _merchantFinder());

    await tester.enterText(_merchantFinder(), '星巴克');
    await tester.pumpAndSettle();

    // 商家内容正常写入，且没有被金额框抢走焦点。
    expect(find.text('星巴克'), findsOneWidget);
    expect(_amountFieldText(tester), '');
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('keeps the amount in the amount field only', (tester) async {
    await _pumpForm(tester);

    await _tap(tester, _amountTextFinder());
    await tester.enterText(_amountTextFinder(), '38.50');
    await tester.pumpAndSettle();

    expect(_amountFieldText(tester), '38.50');
    // 输入商家后金额保持不变（不会被覆盖、也不会互相串）。
    await _tap(tester, find.text('更多信息'));
    await tester.enterText(_merchantFinder(), '星巴克');
    await tester.pumpAndSettle();
    expect(_amountFieldText(tester), '38.50');
  });

  testWidgets('save-and-continue still submits and clears the amount', (
    tester,
  ) async {
    Object? submitted;
    await _pumpForm(
      tester,
      onSubmit: (result) async {
        submitted = result;
        return null;
      },
    );

    await _tap(tester, find.text('现金'));
    await _tap(tester, find.text('午餐'));
    await tester.enterText(_amountTextFinder(), '20');
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('保存并继续'));

    expect(submitted, isA<TransactionCreateFormResult>());
    expect((submitted! as TransactionCreateFormResult).draft.amountMinor, 2000);
    // 表单仍开着，只清空了金额与备注。
    expect(find.byTooltip('保存并继续'), findsOneWidget);
    expect(_amountFieldText(tester), '');
  });

  testWidgets('shows the inline error when submit fails', (tester) async {
    await _pumpForm(tester, onSubmit: (result) async => '账户余额不足');

    await _tap(tester, find.text('现金'));
    await _tap(tester, find.text('午餐'));
    await tester.enterText(_amountTextFinder(), '5');
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('创建'));

    expect(find.text('账户余额不足'), findsOneWidget);
    expect(find.byTooltip('保存并继续'), findsOneWidget);
  });
}

/// 金额输入框里的文本。
String _amountFieldText(WidgetTester tester) {
  final field = tester.widget<AppAmountField>(find.byType(AppAmountField));
  return field.controller?.text ?? '';
}

/// 金额输入框内部的 TextField（用于 enterText）。
Finder _amountTextFinder() => find.descendant(
  of: find.byType(AppAmountField),
  matching: find.byType(TextField),
);

/// 「商家」输入框：按 hintText 认，避免和其他输入框混淆。
Finder _merchantFinder() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && (widget.decoration?.hintText ?? '').contains('京东'),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  final target = finder.first;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _pumpForm(
  WidgetTester tester, {
  TransactionFormSubmit? onSubmit,
}) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserMoneyLedgersProvider.overrideWith(
          (ref) => Stream.value(const <MoneyLedgerEntity>[]),
        ),
        currentUserVisibleAccountsProvider.overrideWith(
          (ref) => Stream.value([_cashAccount]),
        ),
        currentUserMoneyInternalAccountsProvider.overrideWith(
          (ref) => Stream.value(const <MoneyAccountEntity>[]),
        ),
        currentUserCategoryCatalogProvider.overrideWith(
          (ref, kind) => Stream.value(_catalog),
        ),
        currentUserCategoryUsageStatsProvider.overrideWith(
          (ref) async => const MoneyCategoryUsage.empty(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: TransactionFormDialog(
            type: MoneyTransactionType.expense,
            onSubmit: onSubmit,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

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
  statementDay: 1,
  budgetCycleStartDay: 1,
  repaymentDay: 1,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

const _catalog = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'expense_food',
      userId: 'user-1',
      name: '餐饮',
      kind: MoneyCategoryKind.expense,
      color: '#F97316',
      icon: 'restaurant',
      isSystem: true,
    ),
  ],
  subCategories: [
    MoneySubCategoryEntity(
      id: 'expense_food_lunch',
      categoryId: 'expense_food',
      userId: 'user-1',
      name: '午餐',
      kind: MoneyCategoryKind.expense,
      color: '#FDBA74',
      icon: 'lunch_dining',
      isSystem: true,
    ),
  ],
);
