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
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_net_worth_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_detail_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_accounts_section.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/providers/account_flow_providers.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  group('账户卡', () {
    testWidgets('点卡片打开账户弹窗，不再切走面板', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var switchedToPanel = false;
      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          onViewTransactions: (_) => switchedToPanel = true,
        ),
      );
      await tester.pumpAndSettle();

      // 旧行为：点卡片会把整页换成流水列表。现在必须是就地打开弹窗。
      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountDetailSheet), findsOneWidget);
      expect(switchedToPanel, isFalse);
    });

    testWidgets('「查看流水」按钮打开同一个弹窗', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var switchedToPanel = false;
      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          onViewTransactions: (_) => switchedToPanel = true,
        ),
      );
      await tester.pumpAndSettle();

      // 按钮只留图标，靠 tooltip / 语义标签识别。
      await tester.tap(find.byTooltip('查看流水'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountDetailSheet), findsOneWidget);
      // 按钮同样不该把用户踢到流水面板。
      expect(switchedToPanel, isFalse);
    });

    testWidgets('菜单里不再重复放「查看流水」', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(accounts: [_bankAccount]));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();

      // 菜单里不该出现第二个「查看流水」——只剩卡底那个图标按钮。
      expect(find.byTooltip('查看流水'), findsOneWidget);
      expect(find.byTooltip('编辑账户'), findsOneWidget);
    });

    testWidgets('资产卡右侧显示本月净变化，底部给出收支明细', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          summaries: {
            _bankAccount.id: const MoneyAccountMonthlySummary(
              accountId: 'bank-1',
              currentIncomeMinor: 200000,
              currentExpenseMinor: 124000,
              previousIncomeMinor: 0,
              previousExpenseMinor: 0,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('本月净'), findsOneWidget);
      expect(find.text('+¥760.00'), findsOneWidget);
      expect(find.text('本月 收 ¥2,000.00 · 支 ¥1,240.00'), findsOneWidget);
    });

    testWidgets('窄屏 320dp 下不溢出（卡底动作行与右侧辅助值最挤）', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          summaries: {
            _bankAccount.id: const MoneyAccountMonthlySummary(
              accountId: 'bank-1',
              currentIncomeMinor: 200000,
              currentExpenseMinor: 124000,
              previousIncomeMinor: 0,
              previousExpenseMinor: 0,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 溢出会让测试直接失败（RenderFlex overflow 是 FlutterError）。
      expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    });

    testWidgets('贷款账户按负债渲染：剩余欠款、已还比例、不再显示负余额', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_harness(accounts: [_loanAccount]));
      await tester.pumpAndSettle();

      expect(find.text('剩余欠款'), findsOneWidget);
      expect(find.text('¥486,200.00'), findsOneWidget);
      expect(find.text('已还进度'), findsOneWidget);
      expect(find.text('19%'), findsOneWidget);
      expect(find.text('本金 ¥600,000.00（建账时录入）'), findsOneWidget);
      // 贷款余额存的是负数，直接渲染会得到「−¥486,200.00」。
      expect(find.textContaining('−¥486,200.00'), findsNothing);
      // 也不该再落进资产分支。
      expect(find.text('当前余额'), findsNothing);
    });

    testWidgets('授信卡展示可用额度、本期应还与额度使用率', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(accounts: [_creditAccount], bill: _bill),
      );
      await tester.pumpAndSettle();

      expect(find.text('可用额度'), findsOneWidget);
      expect(find.text('本期应还'), findsOneWidget);
      expect(find.text('¥1,200.00'), findsOneWidget);
      expect(find.text('已用 ¥3,580.00 / 额度 ¥12,000.00'), findsOneWidget);
      expect(find.text('账单详情 ›'), findsOneWidget);
    });
  });

  group('账户弹窗', () {
    testWidgets('概览用卡片同款口径并标注「不含转账」', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          summaries: {
            _bankAccount.id: const MoneyAccountMonthlySummary(
              accountId: 'bank-1',
              currentIncomeMinor: 200000,
              currentExpenseMinor: 124000,
              previousIncomeMinor: 0,
              previousExpenseMinor: 0,
            ),
          },
          transactions: [_expense, _income],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      expect(find.text('本月 收 ¥2,000.00 · 支 ¥1,240.00 · 不含转账'), findsOneWidget);
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('瑞幸咖啡'), findsOneWidget);
      expect(find.text('工资'), findsOneWidget);
    });

    testWidgets('按类型筛选只保留对应流水', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(accounts: [_bankAccount], transactions: [_expense, _income]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();
      expect(find.text('瑞幸咖啡'), findsOneWidget);
      expect(find.text('工资'), findsOneWidget);

      await tester.tap(find.text('支出'));
      await tester.pumpAndSettle();

      expect(find.text('瑞幸咖啡'), findsOneWidget);
      expect(find.text('工资'), findsNothing);
    });

    testWidgets('卡面遮罩时，弹窗里的金额一律展示（弹窗内不做遮罩）', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          masked: true,
          transactions: [_expense],
        ),
      );
      await tester.pumpAndSettle();

      // 卡面该遮还是遮。
      expect(find.text('••••'), findsWidgets);

      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      expect(find.byType(AccountDetailSheet), findsOneWidget);
      // 弹窗是用户主动点开的详情页，且没有眼睛开关 —— 这里必须直接给数。
      // 断言都要收敛到弹窗自己的子树上：底下的卡片仍然挂在 Navigator 里，
      // 全局 find.text 会把它卡面上的 •••• 也数进来。
      expect(_inSheet(find.text('¥12,345.67')), findsOneWidget);
      expect(_inSheet(find.text('−¥28.00')), findsOneWidget);
      expect(_inSheet(find.text('••••')), findsNothing);
      expect(find.text('瑞幸咖啡'), findsOneWidget);

      // 再点一层：流水详情同样展示，否则最里层又变回 ••••。
      await tester.tap(find.text('瑞幸咖啡'));
      await tester.pumpAndSettle();

      expect(find.text('流水详情'), findsOneWidget);
      expect(_inDetail(find.text('-¥28.00')), findsOneWidget);
      expect(_inDetail(find.text('••••')), findsNothing);
    });

    testWidgets('弹窗底部两个动作只留图标，「在流水中查看全部」仍能回到老面板', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      MoneyAccountEntity? opened;
      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          onViewTransactions: (account) => opened = account,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      // 底部不再有文字按钮：名称只由 tooltip / 语义标签承担。
      expect(_inSheet(find.text('在流水中查看全部')), findsNothing);
      expect(_inSheet(find.text('记一笔')), findsNothing);
      expect(_inSheet(find.byTooltip('在流水中查看全部')), findsOneWidget);
      expect(_inSheet(find.byTooltip('记一笔')), findsOneWidget);

      await tester.tap(_inSheet(find.byTooltip('在流水中查看全部')));
      await tester.pumpAndSettle();

      expect(opened?.id, _bankAccount.id);
      expect(find.byType(AccountDetailSheet), findsNothing);
    });

    testWidgets('窄屏 320dp 下弹窗底部的图标行不溢出', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_bankAccount],
          transactions: [_expense],
          // 不传的话底部第一个入口根本不渲染（真实应用里它一直在）。
          onViewTransactions: (_) {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      // 溢出会让测试直接失败（RenderFlex overflow 是 FlutterError）。
      expect(find.byType(AccountDetailSheet), findsOneWidget);
      expect(_inSheet(find.byTooltip('在流水中查看全部')), findsOneWidget);
      expect(_inSheet(find.byTooltip('记一笔')), findsOneWidget);
    });

    testWidgets('点「近 90 天」不会一直转圈', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          accounts: [_creditAccount],
          bill: _bill,
          transactions: [_expense],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('信用卡'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('近 90 天'));
      // 只推进两帧、不 settle：key 不稳定时 provider 会被反复重建，
      // 永远到不了 data 态，这两帧就足以暴露。
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('瑞幸咖啡'), findsOneWidget);
    });
  });

  group('时间范围', () {
    /// 区间会进 provider 的 family key，带毫秒就会每帧变一次 key、
    /// 列表永远停在 loading ——「近 90 天」曾因此一直转圈。
    test('同一时刻的不同毫秒取到同一个区间', () {
      final morning = DateTime(2026, 10, 20, 8, 0, 0, 1);
      final evening = DateTime(2026, 10, 20, 23, 59, 59, 999);

      final a = accountFlowRangeBounds(
        range: AccountFlowRange.recent90,
        now: morning,
      );
      final b = accountFlowRangeBounds(
        range: AccountFlowRange.recent90,
        now: evening,
      );

      expect(a.$1, b.$1);
      expect(a.$1, DateTime(2026, 7, 22));
      expect(a.$2, isNull);
    });

    test('「本期」用账单区间时也归一到天', () {
      final bounds = accountFlowRangeBounds(
        range: AccountFlowRange.current,
        now: DateTime(2026, 10, 20, 12, 34, 56, 789),
        statement: _bill.toStatement(),
      );

      expect(bounds.$1, _bill.periodStart);
      expect(bounds.$2, DateTime(2026, 10, 19));
      expect(bounds.$1?.hour, 0);
      expect(bounds.$2?.minute, 0);
    });

    test('「全部」不带区间', () {
      final bounds = accountFlowRangeBounds(
        range: AccountFlowRange.all,
        now: DateTime(2026, 10, 20, 12),
      );

      expect(bounds.$1, isNull);
      expect(bounds.$2, isNull);
    });
  });
}

/// 只在本弹窗子树里找 —— 弹窗打开时下层页面还在 widget 树里。
Finder _inSheet(Finder matching) =>
    find.descendant(of: find.byType(AccountDetailSheet), matching: matching);

Finder _inDetail(Finder matching) => find.descendant(
  of: find.byType(TransactionDetailFrame),
  matching: matching,
);

Widget _harness({
  required List<MoneyAccountEntity> accounts,
  Map<String, MoneyAccountMonthlySummary> summaries = const {},
  List<MoneyTransactionEntity> transactions = const [],
  MoneyCreditCardBillView? bill,
  ValueChanged<MoneyAccountEntity>? onViewTransactions,
  bool masked = false,
}) {
  return ProviderScope(
    overrides: [
      currentUserVisibleAccountsProvider.overrideWith(
        (ref) => Stream.value(accounts),
      ),
      currentUserAccountMonthlySummariesProvider.overrideWith(
        (ref) async => summaries,
      ),
      currentUserNetWorthSummaryProvider.overrideWith(
        (ref) async => const MoneyNetWorthSummary(
          currencyCode: 'CNY',
          assetMinor: 200000,
          liabilityMinor: 100000,
        ),
      ),
      currentUserCreditCardBillViewProvider(
        _creditAccount.id,
      ).overrideWith((ref) async => bill),
      currentUserCategoryCatalogProvider(
        MoneyCategoryKind.expense,
      ).overrideWith((ref) => Stream.value(_expenseCatalog)),
      currentUserCategoryCatalogProvider(
        MoneyCategoryKind.income,
      ).overrideWith((ref) => Stream.value(_incomeCatalog)),
      accountFlowPageProvider.overrideWith((ref, request) async {
        final filtered = request.type == null
            ? transactions
            : transactions
                  .where((item) => item.type == request.type)
                  .toList(growable: false);
        final items = filtered.take(request.limit).toList(growable: false);
        return MoneyTransactionPage(
          items: items,
          page: 1,
          pageSize: request.limit,
          hasMore: items.length < filtered.length,
          total: filtered.length,
        );
      }),
      currentUserPreferencesProvider.overrideWith(
        (ref) async => _preferences(maskMoneyAmounts: masked),
      ),
      // 详情弹窗会读这三个，缺了会去打真实数据库。
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
    // 作用域包在 MaterialApp 外面，与 main.dart 的真实结构一致：
    // 包在 home 里的话，对话框（根导航器）读不到，遮罩会漏。
    child: MoneyPrivacyScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MoneyAccountsSection(onViewTransactions: onViewTransactions),
        ),
      ),
    ),
  );
}

final _now = DateTime(2026, 10, 20);

final _bankAccount = MoneyAccountEntity(
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

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 1200000,
  postedDebtMinor: 358000,
  frozenCreditMinor: 0,
  statementDay: 19,
  budgetCycleStartDay: 18,
  repaymentDay: 28,
  autoRepaymentReminderEnabled: true,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _loanAccount = MoneyAccountEntity(
  id: 'loan-1',
  userId: 'user-1',
  name: '房贷',
  type: MoneyAccountType.loan,
  balanceMinor: -48620000,
  initialBalanceMinor: -60000000,
  creditLimitMinor: null,
  postedDebtMinor: null,
  frozenCreditMinor: null,
  statementDay: null,
  budgetCycleStartDay: null,
  repaymentDay: 5,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _bill = MoneyCreditCardBillView(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  source: MoneyCreditCardBillViewSource.issuedStatement,
  periodStart: DateTime(2026, 9, 20),
  periodEndExclusive: DateTime(2026, 10, 20),
  repaymentDate: DateTime(2026, 10, 28),
  purchaseAmountMinor: 358000,
  repaymentAmountMinor: 0,
  amountDueMinor: 120000,
  availableCreditMinor: 842000,
  postedDebtMinor: 358000,
  state: MoneyCreditCardStatementState.dueSoon,
);

final _expense = MoneyTransactionEntity(
  id: 'transaction-1',
  userId: 'user-1',
  type: MoneyTransactionType.expense,
  status: MoneyTransactionStatus.completed,
  transactionAt: DateTime.now().copyWith(hour: 9, minute: 12),
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

final _income = MoneyTransactionEntity(
  id: 'transaction-2',
  userId: 'user-1',
  type: MoneyTransactionType.income,
  status: MoneyTransactionStatus.completed,
  transactionAt: DateTime.now().copyWith(hour: 10, minute: 0),
  amountMinor: 800000,
  refundAmountMinor: 0,
  currencyCode: 'CNY',
  description: '工资',
  notes: null,
  merchant: null,
  location: null,
  accountId: 'bank-1',
  toAccountId: null,
  categoryId: 'category-salary',
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

final _expenseCatalog = MoneyCategoryCatalog(
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
  subCategories: const <MoneySubCategoryEntity>[],
);

final _incomeCatalog = MoneyCategoryCatalog(
  categories: [
    MoneyCategoryEntity(
      id: 'category-salary',
      userId: null,
      name: '工资',
      kind: MoneyCategoryKind.income,
      color: '#22C55E',
      icon: 'payments',
      isSystem: true,
    ),
  ],
  subCategories: const <MoneySubCategoryEntity>[],
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
