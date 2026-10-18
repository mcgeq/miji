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
/// 「常用」排序统一走 [compareUsageStats]，口径是 **B1 · 时间分层**：
/// 先按「最近使用」距今天远近分档（近 7 天 > 近 30 天 > 近 90 天 > 更早 > 从未用过），
/// **同一档内按使用次数 → 累计金额 → 谁更近 → 原顺序**。
///
/// 为什么不是「纯最近优先」（旧口径）：纯时间排序下，昨天只记过一次的
/// 「电影演出」会插到天天用的「早餐」前面。分层后「刚用过」仍然优先（跨档看时间），
/// 但同一档内改看次数，高频分类不会因为「这两天刚好没记」就被一次性分类挤下去。
/// 也不再按「本月金额」排序：月初或某分类本月刚好没用过时会全部归零、把常用项挤掉。
///
/// 表里没有事件序列（只有累计次数 + 最后一次时间），所以真「频率」（近 30 天 X 次）
/// 算不出来 —— 用「档位」代替连续分数，是现有字段能做到、且结果可解释的上限。
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
  ///
  /// [now] 只用于测试注入「今天」，生产走 [DateTime.now]。
  static int compareUsageStats(
    MoneyUsageStat left,
    MoneyUsageStat right, {
    DateTime? now,
  }) {
    // 1) 时间分档：新近的一档整体靠前；从未用过单独垫底。
    final leftLevel = recencyLevel(left.lastUsedAt, now: now);
    final rightLevel = recencyLevel(right.lastUsedAt, now: now);
    if (leftLevel != rightLevel) {
      return leftLevel.compareTo(rightLevel);
    }
    // 2) 同一档内用得多的优先 —— 这是 B1 相对「纯最近优先」的关键差异：
    //    昨天只记过一次的电影演出，不再压过近 7 天记了 62 次的早餐。
    final countCompare = right.useCount.compareTo(left.useCount);
    if (countCompare != 0) {
      return countCompare;
    }
    // 3) 金额大的优先。
    final amountCompare = right.amountMinor.compareTo(left.amountMinor);
    if (amountCompare != 0) {
      return amountCompare;
    }
    // 4) 档位、次数、金额都相同时再按谁更近，顺带让结果不依赖 List.sort 是否稳定。
    final leftUsed = left.lastUsedAt;
    final rightUsed = right.lastUsedAt;
    if (leftUsed != null && rightUsed != null) {
      return rightUsed.compareTo(leftUsed);
    }
    return 0;
  }

  /// 「最近使用」的时间档位：0 = 近 7 天、1 = 近 30 天、2 = 近 90 天、
  /// 3 = 更早、4 = 从未用过。**小 = 更新**。按自然日算，忽略时分秒
  /// （同一天记的账不该因为差几个小时就分到两档）。
  static int recencyLevel(DateTime? lastUsedAt, {DateTime? now}) {
    if (lastUsedAt == null) {
      return 4;
    }
    final days = _daysBetween(lastUsedAt, now ?? DateTime.now());
    if (days <= 7) {
      return 0;
    }
    if (days <= 30) {
      return 1;
    }
    if (days <= 90) {
      return 2;
    }
    return 3;
  }

  /// 距「今天」的自然日天数；未来时间返回负数（归到最新的档）。
  static int _daysBetween(DateTime usedAt, DateTime today) {
    final used = usedAt.toLocal();
    final base = today.toLocal();
    final usedDay = DateTime(used.year, used.month, used.day);
    final baseDay = DateTime(base.year, base.month, base.day);
    return baseDay.difference(usedDay).inDays;
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
