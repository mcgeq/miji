// 「从提醒发起的记账表单必须带着提醒的数据出现」。
//
// 之前点击提醒只会打开一个全空的支出表单：金额、账户、标题、日期一个都没带上，
// 用户必须自己再填一遍——这就是提醒与流水对不上的起点。这里锁定预填接线。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/application/transaction_entry_defaults_store.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
// `MoneyLedgerEntity` 目前和分账实体放在同一个文件里，没有独立的 ledger 文件。
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';

void main() {
  final dueDate = DateTime(2026, 9, 1, 12);

  Future<void> pumpDialog(
    WidgetTester tester, {
    required TransactionFormDialog dialog,
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(
            _UnlockedAuthController.new,
          ),
          currentUserMoneyLedgersProvider.overrideWith((ref) async* {
            yield const <MoneyLedgerEntity>[];
          }),
          currentUserVisibleAccountsProvider.overrideWith((ref) async* {
            yield <MoneyAccountEntity>[_account];
          }),
          currentUserMoneyInternalAccountsProvider.overrideWith((ref) async* {
            yield const <MoneyAccountEntity>[];
          }),
          currentUserCategoryCatalogProvider(
            MoneyCategoryKind.expense,
          ).overrideWith((ref) async* {
            yield const MoneyCategoryCatalog.empty();
          }),
          currentUserTagCandidatesProvider.overrideWith((ref) async* {
            yield const <String>[];
          }),
          transactionEntryDefaultsStoreProvider.overrideWithValue(
            _FakeTransactionEntryDefaultsStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(body: dialog),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TransactionFormDialog dialogWithReminder() {
    return TransactionFormDialog(
      type: MoneyTransactionType.expense,
      initialAmountMinor: 128800,
      initialAccountId: _account.id,
      initialDescription: '房租',
      initialNotes: '来自账单提醒',
      initialTransactionAt: dueDate,
    );
  }

  testWidgets('prefills amount, notes and date from the reminder', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDialog(tester, dialog: dialogWithReminder());

    // 128800 minor → 1288.00
    expect(find.text('1288.00'), findsOneWidget);
    // 备注带值时会把「高级选项」一并展开，否则用户根本看不到它被塞进来了。
    expect(find.text('来自账单提醒'), findsOneWidget);
    // 有时候是带时刻的完整格式（2026-09-01 12:00），所以按前缀匹配。
    expect(find.textContaining('2026-09-01'), findsWidgets);
  });

  testWidgets('leaves an empty form when no reminder context is given', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpDialog(
      tester,
      dialog: const TransactionFormDialog(type: MoneyTransactionType.expense),
    );

    expect(find.text('1288.00'), findsNothing);
    expect(find.text('来自账单提醒'), findsNothing);
    // 空白表单用的是「今天」，而不是提醒的到期日。
    expect(find.textContaining('2026-09-01'), findsNothing);
  });
}

final _account = MoneyAccountEntity(
  id: 'account-1',
  userId: 'user-1',
  name: '储蓄卡',
  type: MoneyAccountType.bank,
  balanceMinor: 500000,
  initialBalanceMinor: 500000,
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
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _UnlockedAuthController extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}

/// 表单会去读「上次录入偏好」，那是 SharedPreferences 上的东西，
/// 测试环境没有插件。这里给一个恒空的替身——预填断言不依赖它。
class _FakeTransactionEntryDefaultsStore extends TransactionEntryDefaultsStore {
  @override
  Future<TransactionEntryDefaults?> readDefaults({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
  }) async {
    return null;
  }

  @override
  Future<String?> readSubCategoryForCategory({
    required String userId,
    required String? ledgerId,
    required MoneyTransactionType type,
    required String categoryId,
  }) async {
    return null;
  }
}
