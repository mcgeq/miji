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
import 'package:miji/shared/widgets/money_calculator.dart';
import 'package:miji/features/bookkeeping/presentation/categories/components/category_leaf_selector.dart';
import 'package:miji/shared/widgets/money_keypad.dart';

/// 移动端「记一笔」：图标网格选分类 + 自定义数字键盘（含连算）+ 保存并继续。
void main() {
  testWidgets('keypad enters an amount and supports 38 + 12 =', (tester) async {
    await _pumpForm(tester);

    expect(find.byType(MoneyKeypad), findsOneWidget);

    await _tapKey(tester, '3');
    await _tapKey(tester, '8');
    expect(find.text('38'), findsOneWidget);

    await _tapKey(tester, MoneyKeypadKeys.add);
    // 等待结算时给出提示。
    expect(find.textContaining('等待计算'), findsOneWidget);

    await _tapKey(tester, '1');
    await _tapKey(tester, '2');
    await _tapKey(tester, MoneyKeypadKeys.equals);

    expect(find.text('50.00'), findsOneWidget);
  });

  testWidgets('leaf selector shows sub categories directly', (tester) async {
    await _pumpForm(tester);

    // 摊平到叶子：有子分类的「餐饮」不再单独占一格，直接给出「午餐」；
    // 没有子分类的「交通」自己就是叶子。
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('交通'), findsOneWidget);

    await _tap(tester, find.text('午餐'));
    // 选中的是子分类，父分类由它反推并显示出来。
    expect(find.text('餐饮 · 午餐'), findsOneWidget);

    await _tap(tester, find.text('交通'));
    expect(find.text('已选'), findsOneWidget);
    expect(find.text('交通'), findsWidgets);
  });

  testWidgets('leaf selector orders frequent leaves by usage', (tester) async {
    await _pumpForm(tester, usage: const {'expense_transport': 90000});

    final transport = tester.getTopLeft(find.text('交通'));
    final lunch = tester.getTopLeft(find.text('午餐'));
    // 3 列网格里交通用量高 → 排在午餐前面（同一行比 x，换行比 y）。
    // 注意：有父分类小字的 tile 文字会略微下移，所以行判断给一点容差。
    if ((transport.dy - lunch.dy).abs() < 40) {
      expect(transport.dx, lessThan(lunch.dx));
    } else {
      expect(transport.dy, lessThan(lunch.dy));
    }
  });

  testWidgets('save-and-continue submits, stays open and clears the amount', (
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

    await _tap(tester, find.text('现金').first);
    await _tap(tester, find.text('午餐'));
    await _tapKey(tester, '2');
    await _tapKey(tester, '0');

    await _tap(tester, find.byTooltip('保存并继续'));

    expect(submitted, isA<TransactionCreateFormResult>());
    final draft = (submitted! as TransactionCreateFormResult).draft;
    expect(draft.amountMinor, 2000);
    expect(draft.categoryId, 'expense_food');

    // 表单仍然打开、只清掉了金额（分类保留）。
    expect(find.byTooltip('保存并继续'), findsOneWidget);
    expect(find.text('0.00'), findsOneWidget);
    expect(find.text('餐饮'), findsOneWidget);
  });

  testWidgets('keeps the dialog open and shows the error when submit fails', (
    tester,
  ) async {
    await _pumpForm(tester, onSubmit: (result) async => '账户余额不足');

    await _tap(tester, find.text('现金').first);
    await _tap(tester, find.text('午餐'));
    await _tapKey(tester, '5');
    await _tap(tester, find.byTooltip('创建'));

    expect(find.text('账户余额不足'), findsOneWidget);
    expect(find.byTooltip('保存并继续'), findsOneWidget);
  });

  testWidgets('hides save-and-continue when no submit callback is given', (
    tester,
  ) async {
    await _pumpForm(tester);

    expect(find.byType(MoneyKeypad), findsOneWidget);
    expect(find.byTooltip('保存并继续'), findsNothing);
  });

  testWidgets('editing seeds the amount and the first digit replaces it', (
    tester,
  ) async {
    await _pumpForm(tester, transaction: _existingTransaction);

    // 打开时把已有金额填进计算器。
    expect(find.text('38.00'), findsOneWidget);

    await _tapKey(tester, '5');
    // 金额大字显示为 5（键盘上也有一个 '5' 按键，所以要限定数量为 2）。
    expect(find.text('5'), findsNWidgets(2));

    await _tapKey(tester, '0');
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('keypad is docked at the bottom and does not scroll away', (
    tester,
  ) async {
    await _pumpForm(tester);

    final docked = tester.getTopLeft(find.byType(MoneyKeypad));
    // 一开始就在屏幕下半部分，不需要先滚到底。
    expect(docked.dy, greaterThan(900 * 0.5));

    // 滚动内容区（分类网格/账户等）时，键盘位置不变。
    await tester.drag(find.byType(CategoryLeafSelector), const Offset(0, -160));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(MoneyKeypad)), docked);

    // 键盘贴着底部，操作按钮在它下方，都在屏幕内。
    final keypadRect = tester.getRect(find.byType(MoneyKeypad));
    final confirmRect = tester.getRect(find.byTooltip('创建'));
    expect(confirmRect.top, greaterThanOrEqualTo(keypadRect.bottom - 1));
    expect(confirmRect.bottom, lessThanOrEqualTo(900));
    expect(tester.getRect(find.byType(TextField)).isEmpty, isFalse);
  });

  testWidgets('yields to the system keyboard when it is up', (tester) async {
    // 备注 / 商家 / 标签等输入框会拉起系统键盘，此时隐藏自带键盘。
    await _pumpForm(tester, systemKeyboardInset: 300);
    expect(find.byType(MoneyKeypad), findsNothing);

    await _pumpForm(tester);
    expect(find.byType(MoneyKeypad), findsOneWidget);
  });
}

/// 键盘/网格都在表单下方，测试里先滚动到可见再点。
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) {
  return _tap(tester, find.text(key));
}

Future<void> _pumpForm(
  WidgetTester tester, {
  TransactionFormSubmit? onSubmit,

  /// 子分类 id → 历史使用次数（用于「常用」排序）。
  Map<String, int> usage = const {},
  MoneyTransactionEntity? transaction,
  double systemKeyboardInset = 0,
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
        // 「常用」排序现在走历史次数 + 最近使用。父分类自己作叶子时，
        // 用量落在 categoryStats（与真实用量缓存表的口径一致）。
        currentUserCategoryUsageStatsProvider.overrideWith(
          (ref) async => MoneyCategoryUsage.fromStats(
            categoryStats: {
              for (final entry in usage.entries)
                if (entry.key == 'expense_transport')
                  entry.key: MoneyUsageStat(
                    useCount: entry.value,
                    lastUsedAt: DateTime(2026, 9, 20),
                  ),
            },
            subCategoryStats: {
              for (final entry in usage.entries)
                if (entry.key != 'expense_transport')
                  entry.key: MoneyUsageStat(
                    useCount: entry.value,
                    lastUsedAt: DateTime(2026, 9, 20),
                  ),
            },
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(viewInsets: EdgeInsets.only(bottom: systemKeyboardInset)),
          child: child!,
        ),
        home: Scaffold(
          // 真实弹窗（showDialog/showModalBottomSheet）不在 Scaffold body 里，
          // 能拿到 viewInsets；测试里关掉 resize 才能复现同样条件。
          resizeToAvoidBottomInset: false,
          body: TransactionFormDialog(
            type: MoneyTransactionType.expense,
            transaction: transaction,
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
    MoneyCategoryEntity(
      id: 'expense_transport',
      userId: 'user-1',
      name: '交通',
      kind: MoneyCategoryKind.expense,
      color: '#4F7DD9',
      icon: 'directions_bus',
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

final _existingTransaction = MoneyTransactionEntity(
  id: 'txn-1',
  userId: 'user-1',
  accountId: 'cash-1',
  toAccountId: null,
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  amountMinor: 3800,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  categoryId: 'expense_food',
  subCategoryId: null,
  paymentMethod: MoneyPaymentMethod.cash,
  customPaymentMethodName: null,
  actualPayerAccount: '',
  installmentPlanId: null,
  relatedTransactionId: null,
  sourceTemplateRunId: null,
  interestRateBasisPoints: null,
  totalInterestMinor: 0,
  calcMethod: null,
  merchant: null,
  location: null,
  description: '支出',
  notes: null,
  tags: const <String>[],
  transactionAt: DateTime(2026, 1, 1),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  isDeleted: false,
);
