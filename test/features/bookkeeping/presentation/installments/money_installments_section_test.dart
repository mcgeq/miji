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
    // 空态 CTA 在批次三换成了带文字的 FilledButton，所以断文字而不是 tooltip。
    expect(find.text('还没有可用信用账户'), findsOneWidget);
    expect(find.text('新建信用账户'), findsOneWidget);
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

  testWidgets('renders 下一期 as a dedicated banner with a short date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // 回归：原来「下一期」挤在指标格里（宽屏写死 132px、紧凑屏半行），值是
    // `2026-10-03 · 已逾期` 这类复合长串，被单行省略号截成 `2026-10-03 · 已..`。
    // 现在改成独立的到期条：日期与相对时间分两段，完整可见。
    final due = DateTime.now().add(const Duration(days: 3));
    final plan = _plan();
    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [plan],
        details: [_detail(planId: plan.id, dueDate: due, periodNumber: 5)],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('下一期 · 第 5 期'), findsOneWidget);
    expect(find.text('${due.month}月${due.day}日'), findsOneWidget);
    expect(find.text('还剩 3 天'), findsOneWidget);
    // 卡片上直接入账（原来只能进明细弹窗）。
    expect(find.text('去入账'), findsOneWidget);
  });

  testWidgets('lays out without overflow on a narrow phone', (tester) async {
    // 到期条右侧要放状态 chip + 「去入账」，窄屏最容易挤爆。
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final due = DateTime.now().add(const Duration(days: 3));
    final plan = _plan(name: '一个名字很长很长的信用卡分期计划');
    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [plan],
        details: [_detail(planId: plan.id, dueDate: due, periodNumber: 5)],
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('去入账'), findsOneWidget);
  });

  testWidgets('summarises overdue periods at the top of the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final overdueDue = DateTime.now().subtract(const Duration(days: 5));
    final plan = _plan();
    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [plan],
        details: [
          _detail(planId: plan.id, dueDate: overdueDue, periodNumber: 6),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('1 期已逾期'), findsOneWidget);
    expect(find.textContaining('请尽快入账'), findsOneWidget);
    expect(find.text('已逾期 5 天'), findsOneWidget);
  });

  testWidgets('shows a neutral banner when no period is pending', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final today = DateTime.now();
    final plan = _plan();
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
          _detail(
            planId: plan.id,
            dueDate: today,
            periodNumber: 2,
            status: MoneyInstallmentDetailStatus.skipped,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 已入账 1/2、跳过 1/2 → 没有待入账期次，到期条给中性结论而不是空白。
    expect(find.text('暂无待入账期次'), findsOneWidget);
    expect(find.text('去入账'), findsNothing);
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

  testWidgets('搜索默认折叠成图标，与新增同排居中，点开才展开', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [_plan(name: 'iPhone 15 Pro')],
      ),
    );
    await tester.pumpAndSettle();

    // 默认只有一枚搜索图标：输入框不再独占一行。
    expect(find.byType(TextField), findsNothing);
    final searchButton = find.byTooltip('搜索分期');
    expect(searchButton, findsOneWidget);

    // 两枚按钮同排（同一水平中轴），顺序是 搜索 / 新增。
    final searchRect = tester.getRect(searchButton);
    final addRect = tester.getRect(find.byTooltip('新增分期'));
    expect(searchRect.center.dy, closeTo(addRect.center.dy, 0.5));
    expect(searchRect.right, lessThan(addRect.left));

    await tester.tap(searchButton);
    await tester.pumpAndSettle();

    // 点开：输入框在同一行展开，新增被推到右侧。
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.getRect(find.byTooltip('新增分期')).left,
      greaterThan(addRect.left),
      reason: '展开后新增按钮要让位到右边',
    );
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

    // 搜索默认是折叠的图标，得先点开才有输入框。
    await tester.tap(find.byTooltip('搜索分期'));
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
    // 用精确匹配：卡片上的「下一期 · 第 N 期」只是包含「第 N 期」。
    expect(find.text('第 1 期'), findsOneWidget);
    expect(find.text('第 2 期'), findsOneWidget);
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
