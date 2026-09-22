import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/money_budgets_section.dart';

void main() {
  testWidgets('shows summary bar and a create entry point when budgets exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_expenseBudget]));
    await tester.pumpAndSettle();

    expect(find.text('餐饮预算'), findsOneWidget);

    // 回归：非空分支以前只有筛选触发器，有预算之后就没有新增入口了。
    expect(find.byTooltip('新增预算'), findsWidgets);

    // 新增的汇总条（「已用 / 剩余」在卡片上也会出现，所以按 findsWidgets 断言）。
    expect(find.text('合计'), findsOneWidget);
    expect(find.text('已用'), findsWidgets);
    expect(find.text('剩余'), findsWidgets);
    expect(find.text('¥500.00'), findsWidgets);
  });

  testWidgets('budget card shows the daily allowance hint', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_expenseBudget]));
    await tester.pumpAndSettle();

    expect(find.textContaining('日均可用'), findsOneWidget);
    expect(find.textContaining('还剩'), findsWidgets);
  });

  testWidgets('keeps the create action in the empty state too', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('还没有预算'), findsOneWidget);
    expect(find.byTooltip('新增预算'), findsWidgets);
  });
}

Widget _wrap(List<MoneyBudgetEntity> budgets) {
  return ProviderScope(
    overrides: [
      currentUserBudgetsProvider.overrideWith((ref) => Stream.value(budgets)),
      currentUserCategoryCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(
          MoneyCategoryCatalog(
            categories: const [_category],
            subCategories: const [],
          ),
        ),
      ),
      currentUserBudgetAllocationsProvider.overrideWith(
        (ref, budgetId) => Stream.value(const <MoneyBudgetAllocationEntity>[]),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: MoneyBudgetsSection()),
    ),
  );
}

/// 当期预算 ¥1,000，已用 ¥500 → 日均可用取决于剩余天数，所以只断言前缀。
final _expenseBudget = MoneyBudgetEntity(
  id: 'budget-1',
  userId: 'user-1',
  ledgerId: 'ledger-1',
  scopeType: MoneyBudgetScopeType.category,
  name: '餐饮预算',
  trackingType: MoneyBudgetTrackingType.expenseLimit,
  periodType: MoneyBudgetPeriodType.monthly,
  repeatInterval: 1,
  amountMinor: 100000,
  currencyCode: 'CNY',
  periodStart: DateTime(2026, 9, 1),
  periodEnd: DateTime(2099, 12, 31),
  categoryId: 'expense_food',
  subCategoryId: null,
  accountId: null,
  tag: null,
  usedAmountMinor: 50000,
  isActive: true,
  alertEnabled: false,
  alertThresholdPercent: 80,
  autoRollover: false,
  color: '#F97316',
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

const _category = MoneyCategoryEntity(
  id: 'expense_food',
  userId: 'user-1',
  name: '餐饮',
  kind: MoneyCategoryKind.expense,
  color: '#F97316',
  icon: 'restaurant',
  isSystem: true,
);
