import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';

/// 统计页的一张卡。
///
/// 统计页原来把 20 多张卡硬编码在 5 个固定分页里，想看「信用使用率」必须
/// 一路滑到最后一页。这里给每张卡一个稳定 id，让「显示 / 隐藏 / 排序」
/// 变成可持久化的用户配置。
enum MoneyDashboardCard {
  totals,
  trend,
  comparison,
  anomaly,
  category,
  subCategory,
  merchant,
  tag,
  paymentMethod,
  accountPaymentMethod,
  weekdayPattern,
  sourceBreakdown,
  budgetExecution,
  budgetHistory,
  accountDistribution,
  accountType,
  creditUtilization,
  netWorth,
  upcomingBills,
  upcomingCashflow,
  memberParticipation,
  report,
}

extension MoneyDashboardCardMeta on MoneyDashboardCard {
  String get id => name;

  String get label => switch (this) {
    MoneyDashboardCard.totals => '收支总览',
    MoneyDashboardCard.trend => '收支趋势',
    MoneyDashboardCard.comparison => '环比对比',
    MoneyDashboardCard.anomaly => '支出异常',
    MoneyDashboardCard.category => '分类占比',
    MoneyDashboardCard.subCategory => '二级分类排行',
    MoneyDashboardCard.merchant => '商家排行',
    MoneyDashboardCard.tag => '标签排行',
    MoneyDashboardCard.paymentMethod => '支付渠道',
    MoneyDashboardCard.accountPaymentMethod => '账户渠道',
    MoneyDashboardCard.weekdayPattern => '时段与星期',
    MoneyDashboardCard.sourceBreakdown => '来源拆解',
    MoneyDashboardCard.budgetExecution => '预算执行',
    MoneyDashboardCard.budgetHistory => '预算历史',
    MoneyDashboardCard.accountDistribution => '账户分布',
    MoneyDashboardCard.accountType => '账户类型',
    MoneyDashboardCard.creditUtilization => '信用使用率',
    MoneyDashboardCard.netWorth => '净值趋势',
    MoneyDashboardCard.upcomingBills => '未来账单',
    MoneyDashboardCard.upcomingCashflow => '未来现金流',
    MoneyDashboardCard.memberParticipation => '成员参与',
    MoneyDashboardCard.report => 'AI 报表',
  };

  /// 所属分组。分组只影响默认分页，跨分组拖动会顺带改变分页顺序。
  String get group => switch (this) {
    MoneyDashboardCard.totals ||
    MoneyDashboardCard.trend ||
    MoneyDashboardCard.comparison ||
    MoneyDashboardCard.anomaly => '概览',
    MoneyDashboardCard.category ||
    MoneyDashboardCard.subCategory ||
    MoneyDashboardCard.merchant ||
    MoneyDashboardCard.tag => '消费',
    MoneyDashboardCard.paymentMethod ||
    MoneyDashboardCard.accountPaymentMethod ||
    MoneyDashboardCard.weekdayPattern ||
    MoneyDashboardCard.sourceBreakdown => '渠道',
    MoneyDashboardCard.budgetExecution ||
    MoneyDashboardCard.budgetHistory => '预算',
    _ => '账户',
  };
}

/// 一页看板：一个分组 + 该分组下的卡（已按用户排序）。
class MoneyDashboardPage {
  const MoneyDashboardPage({required this.group, required this.cards});

  final String group;
  final List<MoneyDashboardCard> cards;
}

/// 用户的统计看板布局。
///
/// `order` 始终包含**全部**卡片（含隐藏的），这样隐藏后再显示能回到原位；
/// 新增卡片时也能从 JSON 里补齐，不会把老用户的布局打乱。
class MoneyDashboardLayout {
  const MoneyDashboardLayout({required this.order, required this.hidden});

  static MoneyDashboardLayout defaults = MoneyDashboardLayout(
    order: List<MoneyDashboardCard>.unmodifiable(MoneyDashboardCard.values),
    hidden: const <MoneyDashboardCard>{},
  );

  final List<MoneyDashboardCard> order;
  final Set<MoneyDashboardCard> hidden;

  bool isVisible(MoneyDashboardCard card) => !hidden.contains(card);

  List<MoneyDashboardCard> get visibleCards =>
      order.where(isVisible).toList(growable: false);

  /// 按分组切成页：分组顺序取该组第一张可见卡在 `order` 中的位置。
  ///
  /// 整个分组都被隐藏时该页不会出现——否则会留下一个空标签页。
  List<MoneyDashboardPage> get pages {
    final buckets = <String, List<MoneyDashboardCard>>{};
    for (final card in visibleCards) {
      buckets.putIfAbsent(card.group, () => <MoneyDashboardCard>[]).add(card);
    }
    return buckets.entries
        .map(
          (entry) => MoneyDashboardPage(group: entry.key, cards: entry.value),
        )
        .toList(growable: false);
  }

  MoneyDashboardLayout copyWith({
    List<MoneyDashboardCard>? order,
    Set<MoneyDashboardCard>? hidden,
  }) {
    return MoneyDashboardLayout(
      order: order ?? this.order,
      hidden: hidden ?? this.hidden,
    );
  }

  MoneyDashboardLayout toggle(MoneyDashboardCard card, bool visible) {
    final next = Set<MoneyDashboardCard>.from(hidden);
    if (visible) {
      next.remove(card);
    } else {
      next.add(card);
    }
    return copyWith(hidden: next);
  }

  /// 把 `card` 从 `oldIndex` 移到 `newIndex`（ReorderableListView 的语义：
  /// newIndex 是移除旧项后的目标下标）。
  MoneyDashboardLayout reorder(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= order.length) {
      return this;
    }
    final next = List<MoneyDashboardCard>.from(order);
    final moved = next.removeAt(oldIndex);
    var target = newIndex;
    if (target > next.length) {
      target = next.length;
    }
    if (target < 0) {
      target = 0;
    }
    next.insert(target, moved);
    return copyWith(order: next);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'version': 1,
      'order': order.map((card) => card.id).toList(),
      'hidden': hidden.map((card) => card.id).toList(),
    };
  }

  static MoneyDashboardLayout fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      return defaults;
    }
    final all = MoneyDashboardCard.values;
    final byId = <String, MoneyDashboardCard>{
      for (final card in all) card.id: card,
    };

    final order = <MoneyDashboardCard>[];
    final consumed = <MoneyDashboardCard>{};
    final rawOrder = raw['order'];
    if (rawOrder is List) {
      for (final item in rawOrder) {
        if (item is! String) {
          continue;
        }
        final card = byId[item];
        // 未知 id（老版本留下的 / 已删除的卡）直接丢掉，不写回。
        if (card == null || consumed.contains(card)) {
          continue;
        }
        order.add(card);
        consumed.add(card);
      }
    }
    // 新增的卡补在末尾，老用户升级后不会莫名其妙少一块内容。
    for (final card in all) {
      if (!consumed.contains(card)) {
        order.add(card);
      }
    }

    final hidden = <MoneyDashboardCard>{};
    final rawHidden = raw['hidden'];
    if (rawHidden is List) {
      for (final item in rawHidden) {
        if (item is! String) {
          continue;
        }
        final card = byId[item];
        if (card != null) {
          hidden.add(card);
        }
      }
    }

    return MoneyDashboardLayout(order: order, hidden: hidden);
  }
}

/// 按用户隔离的看板存储。
abstract final class MoneyDashboardLayoutStore {
  static String _keyFor(String userId) => 'money_dashboard_layout_$userId';

  static Future<MoneyDashboardLayout> load(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(userId));
    if (raw == null || raw.isEmpty) {
      return MoneyDashboardLayout.defaults;
    }
    try {
      return MoneyDashboardLayout.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return MoneyDashboardLayout.defaults;
    }
  }

  static Future<void> save(String userId, MoneyDashboardLayout layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFor(userId), jsonEncode(layout.toJson()));
  }
}

final moneyDashboardLayoutProvider =
    AsyncNotifierProvider<MoneyDashboardLayoutController, MoneyDashboardLayout>(
      MoneyDashboardLayoutController.new,
    );

class MoneyDashboardLayoutController
    extends AsyncNotifier<MoneyDashboardLayout> {
  @override
  Future<MoneyDashboardLayout> build() async {
    final userId = ref.watch(authSessionControllerProvider).userId;
    if (userId == null || userId.isEmpty) {
      return MoneyDashboardLayout.defaults;
    }
    return MoneyDashboardLayoutStore.load(userId);
  }

  /// 方法名不能叫 `update`：`AsyncNotifier` 自带签名不同的 `update`，
  /// 同名会被判定为非法覆写。
  Future<bool> save(MoneyDashboardLayout layout) async {
    final userId = ref.read(authSessionControllerProvider).userId;
    state = AsyncData(layout);
    if (userId == null || userId.isEmpty) {
      return false;
    }
    try {
      await MoneyDashboardLayoutStore.save(userId, layout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> saveWith(
    MoneyDashboardLayout Function(MoneyDashboardLayout current) transform,
  ) async {
    final current = state.value ?? MoneyDashboardLayout.defaults;
    return save(transform(current));
  }

  Future<bool> toggle(MoneyDashboardCard card, bool visible) {
    return saveWith((current) => current.toggle(card, visible));
  }

  Future<bool> reorder(int oldIndex, int newIndex) {
    return saveWith((current) => current.reorder(oldIndex, newIndex));
  }

  Future<bool> reset() => save(MoneyDashboardLayout.defaults);
}
