import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/presentation/reminders/bill_reminder_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/shared/widgets/money_keypad.dart';

/// 转账 / 账单提醒表单也接了底部停靠键盘（原来只有「记一笔」有）。
void main() {
  testWidgets('transfer form docks the keypad and pins it to the bottom', (
    tester,
  ) async {
    await _pump(tester, const TransferFormDialog(), (form) {
      return ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith(
            (ref) => Stream.value(const <MoneyLedgerEntity>[]),
          ),
          currentUserMoneyTransferAccountsProvider.overrideWith(
            (ref, ledgerId) => Stream.value([_cash]),
          ),
          currentUserCategoryCatalogProvider.overrideWith(
            (ref, kind) => Stream.value(const MoneyCategoryCatalog.empty()),
          ),
        ],
        child: form,
      );
    });

    expect(find.byType(MoneyKeypad), findsOneWidget);
    // 贴在屏幕下半部，和系统键盘一样。
    expect(
      tester.getTopLeft(find.byType(MoneyKeypad)).dy,
      greaterThan(900 * 0.5),
    );

    // 键盘输入会写进表单的金额（提交时用 controller.text）。
    for (final key in ['1', '2', '3']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(find.text('123'), findsOneWidget);
  });

  testWidgets('bill reminder form docks the keypad', (tester) async {
    await _pump(tester, const BillReminderFormDialog(), (form) {
      return ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith(
            (ref) => Stream.value(const <MoneyLedgerEntity>[]),
          ),
          currentUserCurrentLedgerValueProvider.overrideWithValue(null),
          currentUserCategoryCatalogProvider.overrideWith(
            (ref, kind) => Stream.value(const MoneyCategoryCatalog.empty()),
          ),
        ],
        child: form,
      );
    });

    expect(find.byType(MoneyKeypad), findsOneWidget);
    expect(find.byTooltip('创建'), findsOneWidget);
  });

  testWidgets('wide surface keeps the plain amount field', (tester) async {
    await _pump(
      tester,
      const TransferFormDialog(),
      (form) => ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith(
            (ref) => Stream.value(const <MoneyLedgerEntity>[]),
          ),
          currentUserMoneyTransferAccountsProvider.overrideWith(
            (ref, ledgerId) => Stream.value([_cash]),
          ),
          currentUserCategoryCatalogProvider.overrideWith(
            (ref, kind) => Stream.value(const MoneyCategoryCatalog.empty()),
          ),
        ],
        child: form,
      ),
      width: 900,
    );

    expect(find.byType(MoneyKeypad), findsNothing);
  });

  testWidgets('transfer form shows transfer leaves without a parent dropdown', (
    tester,
  ) async {
    await _pump(tester, const TransferFormDialog(), (form) {
      return ProviderScope(
        overrides: [
          currentUserMoneyLedgersProvider.overrideWith(
            (ref) => Stream.value(const <MoneyLedgerEntity>[]),
          ),
          currentUserMoneyTransferAccountsProvider.overrideWith(
            (ref, ledgerId) => Stream.value([_cash]),
          ),
          currentUserCategoryCatalogProvider.overrideWith(
            (ref, kind) => Stream.value(_catalogWithTransfer),
          ),
        ],
        child: form,
      );
    });

    // 父分类固定为「转账」，所以不再展示一格只读的「分类」下拉。
    expect(find.text('分类'), findsNothing);
    // 直接给出三个转账叶子。
    expect(find.text('账户间转账'), findsOneWidget);
    expect(find.text('亲友转账'), findsOneWidget);
    expect(find.text('信用卡还款'), findsOneWidget);

    await tester.tap(find.text('亲友转账'));
    await tester.pumpAndSettle();
    // 选中态用「已选」标识（父分类固定，不需要重复父分类名）。
    expect(find.text('已选'), findsOneWidget);
  });
}

/// [scopeBuilder] 负责包一层 ProviderScope。
///
/// Riverpod 的 `Override` 是 sealed 且未从公开接口导出，测试里无法命名这个类型，
/// 所以 overrides 列表在调用处以字面量写出、由 ProviderScope 自己推断。
Future<void> _pump(
  WidgetTester tester,
  Widget form,
  Widget Function(Widget form) scopeBuilder, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(resizeToAvoidBottomInset: false, body: scopeBuilder(form)),
    ),
  );
  await tester.pumpAndSettle();
}

final _cash = MoneyAccountEntity(
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

const _catalogWithTransfer = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'system_transfer',
      userId: 'user-1',
      name: '转账',
      kind: MoneyCategoryKind.expense,
      color: '#64748B',
      icon: 'swap_horiz',
      isSystem: true,
    ),
  ],
  subCategories: [
    MoneySubCategoryEntity(
      id: 'expense_transfer_account',
      categoryId: 'system_transfer',
      userId: 'user-1',
      name: '账户间转账',
      kind: MoneyCategoryKind.expense,
      color: '#CBD5E1',
      icon: 'swap_horiz',
      isSystem: true,
    ),
    MoneySubCategoryEntity(
      id: 'expense_transfer_family',
      categoryId: 'system_transfer',
      userId: 'user-1',
      name: '亲友转账',
      kind: MoneyCategoryKind.expense,
      color: '#94A3B8',
      icon: 'groups',
      isSystem: true,
    ),
    MoneySubCategoryEntity(
      id: 'expense_transfer_credit_card',
      categoryId: 'system_transfer',
      userId: 'user-1',
      name: '信用卡还款',
      kind: MoneyCategoryKind.expense,
      color: '#64748B',
      icon: 'credit_card',
      isSystem: true,
    ),
  ],
);
