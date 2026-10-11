import 'package:flutter/foundation.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

/// 单个分类 / 子分类的用量。
@immutable
class MoneyUsageStat {
  const MoneyUsageStat({
    this.amountMinor = 0,
    this.useCount = 0,
    this.lastUsedAt,
  });

  static const empty = MoneyUsageStat();

  final int amountMinor;

  /// 历史累计使用次数（来自用量缓存表，与统计窗口无关）。
  final int useCount;

  /// 最近一次使用时间；从未用过为 null。
  final DateTime? lastUsedAt;

  bool get isUsed => useCount > 0 || lastUsedAt != null;

  @override
  bool operator ==(Object other) =>
      other is MoneyUsageStat &&
      other.amountMinor == amountMinor &&
      other.useCount == useCount &&
      other.lastUsedAt == lastUsedAt;

  @override
  int get hashCode => Object.hash(amountMinor, useCount, lastUsedAt);
}

/// 分类用量：既服务于「本月花了多少」的展示，也服务于「常用」排序。
///
/// 两个来源：
/// * [MoneyCategoryUsage.fromSlices] —— 统计模块的窗口聚合（有金额与笔数，没有最近使用时间）；
/// * [MoneyCategoryUsage.fromStats] —— 用量缓存表（有次数与最近使用，覆盖全时段）。
///
/// 「常用」排序统一走 [compareUsageStats]，口径是
/// **最近使用 → 使用次数 → 累计金额 → 原顺序**。
/// 不再用「本月金额」排序：月初或某分类本月刚好没用过时会全部归零、把常用项挤掉。
class MoneyCategoryUsage {
  const MoneyCategoryUsage({
    required this.categoryStats,
    required this.subCategoryStats,
    required this.currencyCode,
  });

  const MoneyCategoryUsage.empty()
    : categoryStats = const <String, MoneyUsageStat>{},
      subCategoryStats = const <String, MoneyUsageStat>{},
      currencyCode = 'CNY';

  final Map<String, MoneyUsageStat> categoryStats;
  final Map<String, MoneyUsageStat> subCategoryStats;
  final String currencyCode;

  bool get isEmpty => categoryStats.isEmpty && subCategoryStats.isEmpty;

  int get totalMinor =>
      categoryStats.values.fold(0, (sum, stat) => sum + stat.amountMinor);

  MoneyUsageStat statFor(String? categoryId) {
    if (categoryId == null) {
      return MoneyUsageStat.empty;
    }
    return categoryStats[categoryId] ?? MoneyUsageStat.empty;
  }

  MoneyUsageStat statForSub(String? subCategoryId) {
    if (subCategoryId == null) {
      return MoneyUsageStat.empty;
    }
    return subCategoryStats[subCategoryId] ?? MoneyUsageStat.empty;
  }

  /// 叶子用量：有子分类看子分类，否则回退到父分类。
  MoneyUsageStat statForLeaf(String? categoryId, String? subCategoryId) {
    if (subCategoryId != null) {
      return statForSub(subCategoryId);
    }
    return statFor(categoryId);
  }

  int amountFor(String? categoryId) => statFor(categoryId).amountMinor;

  int amountForSub(String? subCategoryId) =>
      statForSub(subCategoryId).amountMinor;

  int amountForLeaf(String? categoryId, String? subCategoryId) =>
      statForLeaf(categoryId, subCategoryId).amountMinor;

  /// 占比 0..1；总额为 0 时返回 0。
  double shareFor(String? categoryId) {
    final total = totalMinor;
    if (total <= 0) {
      return 0;
    }
    return amountFor(categoryId) / total;
  }

  /// 「常用」比较：负数表示 [left] 更靠前。
  static int compareUsageStats(MoneyUsageStat left, MoneyUsageStat right) {
    // 1) 最近使用过的优先；越近越前，从未用过排最后。
    final leftUsed = left.lastUsedAt;
    final rightUsed = right.lastUsedAt;
    if (leftUsed != null || rightUsed != null) {
      if (leftUsed == null) {
        return 1;
      }
      if (rightUsed == null) {
        return -1;
      }
      final recency = rightUsed.compareTo(leftUsed);
      if (recency != 0) {
        return recency;
      }
    }
    // 2) 用得多的优先。
    final countCompare = right.useCount.compareTo(left.useCount);
    if (countCompare != 0) {
      return countCompare;
    }
    // 3) 金额大的优先。
    return right.amountMinor.compareTo(left.amountMinor);
  }

  factory MoneyCategoryUsage.fromStats({
    required Map<String, MoneyUsageStat> categoryStats,
    required Map<String, MoneyUsageStat> subCategoryStats,
    String currencyCode = 'CNY',
  }) {
    if (categoryStats.isEmpty && subCategoryStats.isEmpty) {
      return MoneyCategoryUsage.empty();
    }
    return MoneyCategoryUsage(
      categoryStats: categoryStats,
      subCategoryStats: subCategoryStats,
      currencyCode: currencyCode,
    );
  }

  /// 由统计模块的分类 / 子分类聚合构建（只有金额与笔数）。
  factory MoneyCategoryUsage.fromSlices({
    required List<MoneyStatisticsCategorySlice> slices,
    required String currencyCode,
    List<MoneyStatisticsRankSlice> subSlices =
        const <MoneyStatisticsRankSlice>[],
  }) {
    final categoryStats = <String, MoneyUsageStat>{};
    for (final slice in slices) {
      final previous = categoryStats[slice.categoryId];
      categoryStats[slice.categoryId] = MoneyUsageStat(
        amountMinor: (previous?.amountMinor ?? 0) + slice.amountMinor,
        useCount: previous?.useCount ?? 0,
      );
    }
    final subCategoryStats = <String, MoneyUsageStat>{};
    for (final slice in subSlices) {
      final previous = subCategoryStats[slice.id];
      subCategoryStats[slice.id] = MoneyUsageStat(
        amountMinor: (previous?.amountMinor ?? 0) + slice.amountMinor,
        useCount: (previous?.useCount ?? 0) + slice.transactionCount,
      );
    }
    if (categoryStats.isEmpty && subCategoryStats.isEmpty) {
      return MoneyCategoryUsage.empty();
    }
    return MoneyCategoryUsage(
      categoryStats: categoryStats,
      subCategoryStats: subCategoryStats,
      currencyCode: currencyCode,
    );
  }
}
