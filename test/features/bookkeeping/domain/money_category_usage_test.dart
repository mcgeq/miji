import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

void main() {
  group('MoneyCategoryUsage.fromSlices', () {
    test('maps slices to per-category amounts and shares', () {
      final usage = MoneyCategoryUsage.fromSlices(
        currencyCode: 'CNY',
        slices: const [
          MoneyStatisticsCategorySlice(
            categoryId: 'expense_food',
            categoryName: '餐饮',
            amountMinor: 30000,
            percentage: 0.3,
          ),
          MoneyStatisticsCategorySlice(
            categoryId: 'expense_shopping',
            categoryName: '购物',
            amountMinor: 70000,
            percentage: 0.7,
          ),
        ],
      );

      expect(usage.totalMinor, 100000);
      expect(usage.amountFor('expense_food'), 30000);
      expect(usage.shareFor('expense_food'), closeTo(0.3, 0.0001));
      expect(usage.shareFor('expense_shopping'), closeTo(0.7, 0.0001));
    });

    test('keeps sub category amounts and counts', () {
      final usage = MoneyCategoryUsage.fromSlices(
        currencyCode: 'CNY',
        slices: const [],
        subSlices: const [
          MoneyStatisticsRankSlice(
            id: 'expense_food_lunch',
            name: '午餐',
            amountMinor: 12000,
            transactionCount: 6,
            percentage: 1,
          ),
        ],
      );

      expect(usage.amountForSub('expense_food_lunch'), 12000);
      expect(usage.statForSub('expense_food_lunch').useCount, 6);
      // 窗口口径拿不到「最近使用」，排序会退到次数/金额。
      expect(usage.statForSub('expense_food_lunch').lastUsedAt, isNull);
    });

    test('returns zero for unknown or missing categories', () {
      final usage = MoneyCategoryUsage.fromSlices(
        currencyCode: 'CNY',
        slices: const [
          MoneyStatisticsCategorySlice(
            categoryId: 'expense_food',
            categoryName: '餐饮',
            amountMinor: 100,
            percentage: 1,
          ),
        ],
      );

      expect(usage.amountFor('unknown'), 0);
      expect(usage.amountFor(null), 0);
      expect(usage.shareFor('unknown'), 0);
      expect(usage.amountForLeaf('expense_food', 'expense_food_lunch'), 0);
    });

    test('does not divide by zero when there is no usage', () {
      const usage = MoneyCategoryUsage.empty();

      expect(usage.isEmpty, isTrue);
      expect(usage.totalMinor, 0);
      expect(usage.shareFor('expense_food'), 0);
    });

    test('sums duplicate slices for the same category', () {
      final usage = MoneyCategoryUsage.fromSlices(
        currencyCode: 'CNY',
        slices: const [
          MoneyStatisticsCategorySlice(
            categoryId: 'expense_food',
            categoryName: '餐饮',
            amountMinor: 100,
            percentage: 0.5,
          ),
          MoneyStatisticsCategorySlice(
            categoryId: 'expense_food',
            categoryName: '餐饮',
            amountMinor: 300,
            percentage: 0.5,
          ),
        ],
      );

      expect(usage.amountFor('expense_food'), 400);
    });
  });

  group('compareUsageStats（统一的「常用」口径）', () {
    test('more recent wins', () {
      final recent = MoneyUsageStat(
        useCount: 1,
        lastUsedAt: DateTime(2026, 9, 20),
      );
      final older = MoneyUsageStat(
        useCount: 50,
        lastUsedAt: DateTime(2026, 1, 1),
      );

      expect(MoneyCategoryUsage.compareUsageStats(recent, older), lessThan(0));
    });

    test('never used sorts last even with a big amount', () {
      final used = MoneyUsageStat(
        useCount: 1,
        lastUsedAt: DateTime(2020, 1, 1),
      );
      const never = MoneyUsageStat(amountMinor: 9999999);

      expect(MoneyCategoryUsage.compareUsageStats(used, never), lessThan(0));
      expect(MoneyCategoryUsage.compareUsageStats(never, used), greaterThan(0));
    });

    test('falls back to use count, then amount', () {
      final sameDay = DateTime(2026, 9, 20);
      final busy = MoneyUsageStat(useCount: 10, lastUsedAt: sameDay);
      final rare = MoneyUsageStat(useCount: 2, lastUsedAt: sameDay);
      expect(MoneyCategoryUsage.compareUsageStats(busy, rare), lessThan(0));

      final big = MoneyUsageStat(
        amountMinor: 90000,
        useCount: 2,
        lastUsedAt: sameDay,
      );
      final small = MoneyUsageStat(
        amountMinor: 100,
        useCount: 2,
        lastUsedAt: sameDay,
      );
      expect(MoneyCategoryUsage.compareUsageStats(big, small), lessThan(0));
    });

    test('equal stats compare equal so callers can tie-break', () {
      final same = DateTime(2026, 9, 20);
      final left = MoneyUsageStat(useCount: 3, lastUsedAt: same);
      final right = MoneyUsageStat(useCount: 3, lastUsedAt: same);

      expect(MoneyCategoryUsage.compareUsageStats(left, right), 0);
    });
  });

  test('statForLeaf prefers the sub category, falls back to the parent', () {
    final usage = MoneyCategoryUsage.fromStats(
      categoryStats: {
        'expense_transport': MoneyUsageStat(
          amountMinor: 500,
          useCount: 5,
          lastUsedAt: DateTime(2026, 9, 1),
        ),
      },
      subCategoryStats: {
        'expense_food_lunch': MoneyUsageStat(
          amountMinor: 1200,
          useCount: 9,
          lastUsedAt: DateTime(2026, 9, 20),
        ),
      },
    );

    // 有子分类 → 看子分类。
    expect(usage.statForLeaf('expense_food', 'expense_food_lunch').useCount, 9);
    // 父分类自己作叶子 → 回退父分类。
    expect(usage.statForLeaf('expense_transport', null).useCount, 5);
    expect(usage.statForLeaf('unknown', null).isUsed, isFalse);
  });
}
