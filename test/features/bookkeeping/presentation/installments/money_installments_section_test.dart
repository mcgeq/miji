import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/installments/money_installments_section.dart';

void main() {
  testWidgets('offers to create a credit account when none exists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(accounts: const []));
    await tester.pumpAndSettle();

    // 回归：三个空态原来都没有 action，用户不知道该去哪。
    expect(find.text('还没有可用信用账户'), findsOneWidget);
    expect(find.byTooltip('新建信用账户'), findsOneWidget);
    // 前置条件不满足时，头部的新增入口禁用并说明原因。
    expect(find.byTooltip('需要先有信用账户和支出分类'), findsOneWidget);
  });

  testWidgets('keeps a create entry point when a credit account exists', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(accounts: [_creditAccount]));
    await tester.pumpAndSettle();

    expect(find.text('还没有分期计划'), findsOneWidget);
    // 回归：_MoneyInstallmentsContent 声明了 onCreate 却从未使用，
    // 页面实际上没有任何新增入口。
    expect(find.byTooltip('新增分期'), findsWidgets);
  });

  testWidgets('shows the plan card with a countdown for the next period', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final plan = _plan(firstDueDate: today);
    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [plan],
        details: [_detail(planId: plan.id, dueDate: today, periodNumber: 4)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    // 「下一期」不再只给裸日期。
    expect(find.textContaining('今天'), findsWidgets);
  });

  testWidgets('groups plans by status and folds finished ones', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [
          _plan(name: '进行中的分期'),
          _plan(name: '已完成的分期', status: MoneyInstallmentPlanStatus.completed),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 进行中在上（分组标题与卡片状态胶囊同名，用 findsWidgets），已结束折叠。
    expect(find.text('进行中'), findsWidgets);
    expect(find.text('已结束 1 个'), findsOneWidget);
    expect(find.text('已完成的分期'), findsNothing);

    await tester.tap(find.text('已结束 1 个'));
    await tester.pumpAndSettle();
    expect(find.text('已完成的分期'), findsOneWidget);
  });

  testWidgets('filters plans by keyword', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [
          _plan(name: 'iPhone 15 Pro'),
          _plan(name: 'MacBook Air'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'macbook');
    await tester.pumpAndSettle();

    expect(find.text('MacBook Air'), findsOneWidget);
    expect(find.text('iPhone 15 Pro'), findsNothing);
  });

  testWidgets('shows the period timeline in the details dialog', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final plan = _plan(name: 'iPhone 15 Pro', firstDueDate: today);
    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [plan],
        details: [
          _detail(
            planId: plan.id,
            dueDate: today.subtract(const Duration(days: 30)),
            periodNumber: 1,
            status: MoneyInstallmentDetailStatus.posted,
          ),
          _detail(planId: plan.id, dueDate: today, periodNumber: 2),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('查看明细'));
    await tester.pumpAndSettle();

    // 时间轴：已入账 / 当前 两种状态都能看到。
    expect(find.textContaining('第 1 期'), findsOneWidget);
    expect(find.textContaining('第 2 期'), findsOneWidget);
  });
}

Widget _wrap({
  required List<MoneyAccountEntity> accounts,
  List<MoneyInstallmentPlanEntity> plans = const [],
  List<MoneyInstallmentDetailEntity> details = const [],
}) {
  final ledger = MoneyLedgerEntity(
    id: 'ledger-1',
    userId: 'user-1',
    name: '日常账本',
    ledgerType: 'personal',
    status: 'active',
    baseCurrencyCode: 'CNY',
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
  return ProviderScope(
    overrides: [
      currentUserCurrentLedgerValueProvider.overrideWithValue(ledger),
      currentUserMoneyLedgerAccountsProvider.overrideWith(
        (ref, ledgerId) => Stream.value(accounts),
      ),
      currentUserInstallmentPlansProvider.overrideWith(
        (ref) => Stream.value(plans),
      ),
      currentUserCategoryCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(
          const MoneyCategoryCatalog(
            categories: [_category],
            subCategories: [],
          ),
        ),
      ),
      currentUserInstallmentDetailsProvider.overrideWith(
        (ref, planId) => Stream.value(
          details.where((detail) => detail.planId == planId).toList(),
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: MoneyInstallmentsSection()),
    ),
  );
}

final _createdAt = DateTime(2026, 1, 1);

MoneyInstallmentPlanEntity _plan({
  DateTime? firstDueDate,
  String name = 'iPhone 15 Pro',
  MoneyInstallmentPlanStatus status = MoneyInstallmentPlanStatus.active,
}) {
  return MoneyInstallmentPlanEntity(
    id: 'plan-1',
    userId: 'user-1',
    ledgerId: 'ledger-1',
    accountId: 'credit-1',
    name: name,
    totalPrincipalMinor: 499200,
    totalInterestMinor: 0,
    totalPeriods: 12,
    remainingPeriods: 9,
    periodAmountMinor: 41600,
    currencyCode: 'CNY',
    categoryId: 'expense_digital',
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2027, 6, 1),
    firstDueDate: firstDueDate ?? DateTime.now(),
    status: status,
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
}

MoneyInstallmentDetailEntity _detail({
  required String planId,
  required DateTime dueDate,
  required int periodNumber,
  MoneyInstallmentDetailStatus status = MoneyInstallmentDetailStatus.pending,
}) {
  return MoneyInstallmentDetailEntity(
    id: 'detail-$periodNumber',
    userId: 'user-1',
    planId: planId,
    accountId: 'credit-1',
    periodNumber: periodNumber,
    amountMinor: 41600,
    principalMinor: 41600,
    interestMinor: 0,
    dueDate: dueDate,
    status: status,
    createdAt: _createdAt,
    updatedAt: _createdAt,
  );
}

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '招行信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 2000000,
  postedDebtMinor: 0,
  frozenCreditMinor: 0,
  statementDay: 5,
  budgetCycleStartDay: 1,
  repaymentDay: 23,
  autoRepaymentReminderEnabled: false,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _createdAt,
  updatedAt: _createdAt,
);

const _category = MoneyCategoryEntity(
  id: 'expense_digital',
  userId: 'user-1',
  name: '数码',
  kind: MoneyCategoryKind.expense,
  color: '#4F7DD9',
  icon: 'devices',
  isSystem: true,
);
