import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/categories/money_categories_section.dart';

void main() {
  testWidgets('keeps a create-category entry point when categories exist', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category]));
    await tester.pumpAndSettle();

    expect(find.text('餐饮'), findsOneWidget);

    // 回归：非空分支以前只有 ListView，没有任何新增入口，
    // 而种子数据总让 categories 非空 → 用户永远无法新增分类。
    expect(find.byTooltip('新增分类'), findsWidgets);

    await tester.tap(find.byTooltip('新增分类').first);
    await tester.pumpAndSettle();
    expect(find.text('新增分类'), findsWidgets);
  });

  testWidgets('renders the real category icon instead of the icon name', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap([_category]));
    await tester.pumpAndSettle();

    expect(find.text('restaurant'), findsNothing);
    expect(find.byIcon(Icons.restaurant), findsWidgets);
  });

  testWidgets('shows the create action in the empty state too', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_wrap(const []));
    await tester.pumpAndSettle();

    expect(find.text('暂无分类'), findsOneWidget);
    expect(find.byTooltip('新增分类'), findsWidgets);
  });

  testWidgets('shows this month usage and filters by search', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap([_category, _transport], usageMinor: {'expense_food': 30000}),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('本月 ¥300.00'), findsOneWidget);
    expect(find.textContaining('早餐'), findsWidgets);
    expect(find.text('交通'), findsOneWidget);

    // 搜索名命中子分类名时也要保留父分类。
    await tester.enterText(find.byType(TextField), '早餐');
    await tester.pumpAndSettle();
    expect(find.text('餐饮'), findsOneWidget);
    expect(find.text('交通'), findsNothing);
  });

  testWidgets('sorts by usage when the toggle is on', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _wrap(
        [_category, _transport],
        usageMinor: {'expense_food': 100, 'expense_transport': 900},
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('按本月用量排序'));
    await tester.pumpAndSettle();

    final traffic = tester.getTopLeft(find.text('交通')).dy;
    final food = tester.getTopLeft(find.text('餐饮')).dy;
    expect(traffic, lessThan(food));
  });
}

Widget _wrap(
  List<MoneyCategoryEntity> categories, {
  Map<String, int> usageMinor = const {},
}) {
  final catalog = MoneyCategoryCatalog(
    categories: categories,
    subCategories: const [_breakfast],
  );
  return ProviderScope(
    overrides: [
      currentUserCategoryManagementCatalogProvider.overrideWith(
        (ref, kind) => Stream.value(catalog),
      ),
      currentUserMonthCategoryUsageProvider.overrideWith(
        (ref, kind) async => MoneyCategoryUsage.fromStats(
          categoryStats: {
            for (final entry in usageMinor.entries)
              entry.key: MoneyUsageStat(amountMinor: entry.value),
          },
          subCategoryStats: const {},
        ),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: MoneyCategoriesSection()),
    ),
  );
}

const _breakfast = MoneySubCategoryEntity(
  id: 'expense_food_breakfast',
  categoryId: 'expense_food',
  userId: 'user-1',
  name: '早餐',
  kind: MoneyCategoryKind.expense,
  color: '#FDBA74',
  icon: 'breakfast_dining',
  isSystem: true,
);

const _transport = MoneyCategoryEntity(
  id: 'expense_transport',
  userId: 'user-1',
  name: '交通',
  kind: MoneyCategoryKind.expense,
  color: '#4F7DD9',
  icon: 'directions_bus',
  isSystem: true,
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
