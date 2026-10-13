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

  group('compareUsageStats（B1 · 时间分层口径）', () {
    // 固定「今天」再断言，否则结果会随运行日期漂移（跨过 7/30/90 天边界就变）。
    final now = DateTime(2026, 10, 13);

    MoneyUsageStat used(DateTime at, {int count = 1, int amount = 0}) =>
        MoneyUsageStat(useCount: count, lastUsedAt: at, amountMinor: amount);

    test('档位顺序：近 7 天 > 近 30 天 > 近 90 天 > 更早 > 从未用过', () {
      final week = used(now.subtract(const Duration(days: 7)));
      final month = used(now.subtract(const Duration(days: 8)));
      final quarter = used(now.subtract(const Duration(days: 31)));
      final old = used(now.subtract(const Duration(days: 91)));

      final ordered = <MoneyUsageStat>[week, month, quarter, old];
      for (var i = 0; i < ordered.length - 1; i++) {
        expect(
          MoneyCategoryUsage.compareUsageStats(
            ordered[i],
            ordered[i + 1],
            now: now,
          ),
          lessThan(0),
          reason: '第 $i 档应排在下一档之前',
        );
      }
      expect(
        MoneyCategoryUsage.compareUsageStats(
          old,
          MoneyUsageStat.empty,
          now: now,
        ),
        lessThan(0),
      );
    });

    test('同一档内按次数：天天用的压过「昨天只用过一次」的新分类', () {
      // 早餐：近 7 天内记了 62 次；电影演出：昨天只记过 1 次。
      // 旧口径（纯最近优先）会把电影演出排到早餐前面，B1 不会。
      final breakfast = used(now.subtract(const Duration(days: 5)), count: 62);
      final movie = used(now.subtract(const Duration(days: 1)));

      expect(
        MoneyCategoryUsage.compareUsageStats(breakfast, movie, now: now),
        lessThan(0),
      );
      expect(
        MoneyCategoryUsage.compareUsageStats(movie, breakfast, now: now),
        greaterThan(0),
      );
    });

    test('跨档仍看时间：近 20 天的高频仍排在近 90 天之前', () {
      final lunch = used(now.subtract(const Duration(days: 20)), count: 88);
      final takeout = used(now.subtract(const Duration(days: 45)), count: 200);

      expect(
        MoneyCategoryUsage.compareUsageStats(lunch, takeout, now: now),
        lessThan(0),
      );
    });

    test('从未用过排最后，金额再大也不动', () {
      final old = used(now.subtract(const Duration(days: 365)));
      const never = MoneyUsageStat(amountMinor: 9999999);

      expect(
        MoneyCategoryUsage.compareUsageStats(old, never, now: now),
        lessThan(0),
      );
      expect(
        MoneyCategoryUsage.compareUsageStats(never, old, now: now),
        greaterThan(0),
      );
    });

    test('同档同次数比金额，再同则比谁更近（保证排序稳定）', () {
      final day = now.subtract(const Duration(days: 3));
      final big = used(day, count: 2, amount: 90000);
      final small = used(day, count: 2, amount: 100);
      expect(
        MoneyCategoryUsage.compareUsageStats(big, small, now: now),
        lessThan(0),
      );

      final nearer = used(now.subtract(const Duration(days: 1)), count: 2);
      final farther = used(now.subtract(const Duration(days: 6)), count: 2);
      expect(
        MoneyCategoryUsage.compareUsageStats(nearer, farther, now: now),
        lessThan(0),
      );
    });

    test('equal stats compare equal so callers can tie-break', () {
      final same = now.subtract(const Duration(days: 2));
      final left = used(same, count: 3);
      final right = used(same, count: 3);

      expect(MoneyCategoryUsage.compareUsageStats(left, right, now: now), 0);
    });

    test('recencyLevel 的边界含端点，未来时间归到最新档', () {
      int level(int daysAgo) => MoneyCategoryUsage.recencyLevel(
        now.subtract(Duration(days: daysAgo)),
        now: now,
      );

      expect(level(0), 0);
      expect(level(7), 0);
      expect(level(8), 1);
      expect(level(30), 1);
      expect(level(31), 2);
      expect(level(90), 2);
      expect(level(91), 3);
      expect(MoneyCategoryUsage.recencyLevel(null, now: now), 4);
      expect(level(-1), 0);
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
