import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/components/bookkeeping_floating_actions.dart';
import 'package:miji/features/bookkeeping/presentation/installments/money_installments_section.dart';

/// 悬浮条默认收成贴边的一枚手柄，先点手柄才能点到里面的按钮。
Future<void> _expandActions(WidgetTester tester) async {
  await tester.tap(find.byTooltip('展开操作条'));
  await tester.pumpAndSettle();
}

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
    // 前置条件不满足时，悬浮条里的新增入口禁用并说明原因。
    await _expandActions(tester);
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
    await _expandActions(tester);
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

  testWidgets('悬浮条默认靠边收起：只有一枚贴边的手柄，按钮不在树上', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [_plan(name: 'iPhone 15 Pro')],
      ),
    );
    await tester.pumpAndSettle();

    // 顶部不再常驻操作行，搜索框默认根本不在树上。
    expect(find.byType(TextField), findsNothing);
    // 收起态只剩手柄：两枚按钮都在里面，没展开就点不到。
    expect(find.byTooltip('展开操作条'), findsOneWidget);
    expect(find.byTooltip('搜索分期'), findsNothing);
    expect(find.byTooltip('新增分期'), findsNothing);

    final collapsed = tester.getRect(
      find.byKey(BookkeepingFloatingActions.pillKey),
    );
    // 「靠边收起来」：贴着右边缘、不留缝，宽度只够放一枚手柄。
    expect(collapsed.right, closeTo(390, 1));
    expect(collapsed.width, lessThan(28));
    expect(collapsed.center.dy, greaterThan(900 / 2));

    await _expandActions(tester);

    final expanded = tester.getRect(
      find.byKey(BookkeepingFloatingActions.pillKey),
    );
    expect(find.byTooltip('搜索分期'), findsOneWidget);
    expect(find.byTooltip('新增分期'), findsOneWidget);
    // 展开后变宽，并退到 12 的边距里。
    expect(expanded.width, greaterThan(collapsed.width));
    expect(expanded.right, closeTo(390 - 12, 1));

    // 再点手柄推回边缘。
    await tester.tap(find.byTooltip('收起操作条'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(BookkeepingFloatingActions.pillKey)).right,
      closeTo(390, 1),
    );
    expect(find.byTooltip('新增分期'), findsNothing);
  });

  testWidgets('再点一次搜索图标：收起顶部搜索框并清空关键词', (tester) async {
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

    await _expandActions(tester);
    await tester.tap(find.byTooltip('搜索分期'));
    await tester.pumpAndSettle();

    // 点开：输入框出现在页面顶部，而不是悬浮条那一行里。
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getRect(find.byType(TextField)).top, lessThan(60));

    await tester.enterText(find.byType(TextField), 'macbook');
    await tester.pumpAndSettle();
    expect(find.text('MacBook Air'), findsOneWidget);
    expect(find.text('iPhone 15 Pro'), findsNothing);

    // 展开状态下这枚图标的说明变成「收起搜索框」——再点一次就收回去。
    await tester.tap(find.byTooltip('收起搜索框'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    // 收起即清空：输入框没了却还过滤着列表，等于凭空少了几条。
    expect(find.text('iPhone 15 Pro'), findsOneWidget);
    expect(find.text('MacBook Air'), findsOneWidget);
    expect(find.byTooltip('搜索分期'), findsOneWidget);
  });

  testWidgets('悬浮操作条可拖动，松手吸附到最近的边缘', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [_plan(name: 'iPhone 15 Pro')],
      ),
    );
    await tester.pumpAndSettle();

    final pill = find.byKey(BookkeepingFloatingActions.pillKey);
    final before = tester.getRect(pill);

    // 从手柄上起手拖：收起态也能拖，悬浮条整体跟着走，不是只有按钮动。
    await tester.drag(find.byTooltip('展开操作条'), const Offset(-220, -320));
    await tester.pumpAndSettle();

    final after = tester.getRect(pill);
    // 跟手：拖到哪就在哪（左上方向）。
    expect(after.center.dx, lessThan(before.center.dx));
    expect(after.center.dy, lessThan(before.center.dy));
    // 收起态吸附时贴到边缘，不留边距；纵向保持用户拖到的高度。
    expect(after.left, closeTo(0, 1));
    expect(after.center.dy, isNot(closeTo(before.center.dy, 1)));

    // 展开态同样吸附，但留出 12 的边距。
    await tester.tap(find.byTooltip('展开操作条'));
    await tester.pumpAndSettle();
    await tester.drag(find.byTooltip('新增分期'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(tester.getRect(pill).left, closeTo(12, 1));
  });

  testWidgets('金额汇总默认收起，点开关才展开（进行中）', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final plan = _plan(name: 'iPhone 15 Pro');
    await tester.pumpWidget(_wrap(accounts: [_creditAccount], plans: [plan]));
    await tester.pumpAndSettle();

    // 5 格汇总默认不在卡面上：这些数字建计划那天就定死了，「剩余」又与进度条
    // 重复；常驻要占窄屏三行格子，一张卡就吃掉一屏。
    expect(find.text('总应还'), findsNothing);
    expect(find.text('每期'), findsNothing);
    expect(find.text('剩余'), findsNothing);
    expect(find.text('本金'), findsNothing);
    expect(find.text('利息'), findsNothing);

    // 但「下一期」必须留着：它是这张卡上唯一能动手的地方。
    expect(find.textContaining('下一期'), findsWidgets);
    expect(find.text('已入账 0/${plan.totalPeriods} 期'), findsOneWidget);

    // 卡头只留「查看明细」：金额开关搬到进度行上，不再并排两枚图标。
    expect(find.byTooltip('查看明细'), findsOneWidget);
    expect(find.byTooltip('展开金额'), findsOneWidget);

    // 点进度行（不是卡头上那枚图标）就展开。
    await tester.tap(find.text('已入账 0/${plan.totalPeriods} 期'));
    await tester.pumpAndSettle();

    expect(find.text('总应还'), findsOneWidget);
    expect(find.text('每期'), findsOneWidget);
    expect(find.text('剩余'), findsOneWidget);
    expect(find.text('本金'), findsOneWidget);
    expect(find.text('利息'), findsOneWidget);
    // 开关本身还在，而且换成了「收起」。
    expect(find.byTooltip('收起金额'), findsOneWidget);

    await tester.tap(find.byTooltip('收起金额'));
    await tester.pumpAndSettle();
    expect(find.text('总应还'), findsNothing);
  });

  testWidgets('金额汇总默认收起（已结束）：没有「下一期」，靠开关展开', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        accounts: [_creditAccount],
        plans: [
          _plan(
            name: 'MacBook Air',
            status: MoneyInstallmentPlanStatus.completed,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // 已完成的分期折在「已结束」里，先展开这一组。
    await tester.tap(find.text('已结束 1 个'));
    await tester.pumpAndSettle();

    expect(find.text('MacBook Air'), findsOneWidget);
    expect(find.text('总应还'), findsNothing);
    // 已结束的卡没有「下一期」——它不欠任何东西了。
    expect(find.textContaining('下一期'), findsNothing);

    await tester.tap(find.byTooltip('展开金额'));
    await tester.pumpAndSettle();
    expect(find.text('总应还'), findsOneWidget);
    expect(find.text('本金'), findsOneWidget);
    expect(find.text('利息'), findsOneWidget);
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

    // 悬浮条默认收起，先拉出来，再点搜索才有输入框。
    await _expandActions(tester);
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
