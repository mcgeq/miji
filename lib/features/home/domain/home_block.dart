import 'dart:convert';

/// 首页布局模式。默认横向分页，可在设置里切成纵向单列。
enum HomeLayoutMode {
  list('list'),
  pager('pager');

  const HomeLayoutMode(this.storageValue);
  final String storageValue;

  /// 只有显式存了 `list` 才是纵向；其它（含 null / 脏值）都回落到横向。
  static HomeLayoutMode fromStorage(String? value) =>
      value == 'list' ? HomeLayoutMode.list : HomeLayoutMode.pager;
}

/// 首页区块归属模块，设置页按此分组。
enum HomeBlockModule {
  money('记账'),
  health('健康'),
  action('行动'),
  global('通用');

  const HomeBlockModule(this.label);
  final String label;
}

/// 首页可插拔区块注册表。storageKey 是持久化 key，一旦发布**不可改**。
enum HomeBlockId {
  boardMoney('board.money', '今日 · 钱', HomeBlockModule.money, true),
  boardHealth('board.health', '今日 · 健康', HomeBlockModule.health, true),
  boardAction('board.action', '今日 · 行动', HomeBlockModule.action, true),
  moneyHero('money.hero', '预算 Hero', HomeBlockModule.money, true),
  moneyCategories('money.categories', '分类结构', HomeBlockModule.money, true),
  moneyRecent('money.recent', '最近流水', HomeBlockModule.money, true),
  healthCycle('health.cycle', '周期状态', HomeBlockModule.health, true),
  healthToday('health.today', '今日健康记录', HomeBlockModule.health, true),
  healthForecast('health.forecast', '未来 7 天预测', HomeBlockModule.health, false),
  actionTodo('action.todo', '今日待办', HomeBlockModule.action, true),
  actionHabit('action.habit', '习惯打卡', HomeBlockModule.action, true),
  timeline('timeline.week', '本周时间线', HomeBlockModule.global, true),
  insight('insight.cross', '跨模块洞察', HomeBlockModule.global, true),
  quote('footer.quote', '语录', HomeBlockModule.global, true);

  const HomeBlockId(
    this.storageKey,
    this.label,
    this.module,
    this.defaultVisible,
  );

  final String storageKey;
  final String label;
  final HomeBlockModule module;
  final bool defaultVisible;

  /// 三宫格的格子（用于「至少保留 2 格」约束）。
  bool get isBoardCell =>
      this == boardMoney || this == boardHealth || this == boardAction;

  static HomeBlockId? fromStorageKey(String key) {
    for (final id in HomeBlockId.values) {
      if (id.storageKey == key) {
        return id;
      }
    }
    return null;
  }
}

/// 首页区块的可见性与顺序。不可变值对象；解析失败时回落到默认。
class HomeBlockLayout {
  const HomeBlockLayout({required this.visible, required this.order});

  final Map<HomeBlockId, bool> visible;
  final List<HomeBlockId> order;

  factory HomeBlockLayout.defaults() => HomeBlockLayout(
    visible: {for (final id in HomeBlockId.values) id: id.defaultVisible},
    order: List<HomeBlockId>.unmodifiable(HomeBlockId.values),
  );

  bool isVisible(HomeBlockId id) => visible[id] ?? id.defaultVisible;

  int get visibleBoardCellCount =>
      HomeBlockId.values.where((id) => id.isBoardCell && isVisible(id)).length;

  HomeBlockLayout toggle(HomeBlockId id, bool value) =>
      copyWith(visible: {...visible, id: value});

  HomeBlockLayout reorder(int oldIndex, int newIndex) {
    final next = [...order];
    if (oldIndex < 0 || oldIndex >= next.length) {
      return this;
    }
    var target = newIndex;
    if (target < 0) {
      target = 0;
    }
    if (target >= next.length) {
      target = next.length - 1;
    }
    final item = next.removeAt(oldIndex);
    next.insert(target, item);
    return copyWith(order: List<HomeBlockId>.unmodifiable(next));
  }

  HomeBlockLayout copyWith({
    Map<HomeBlockId, bool>? visible,
    List<HomeBlockId>? order,
  }) => HomeBlockLayout(
    visible: visible ?? this.visible,
    order: order ?? this.order,
  );

  static HomeBlockLayout fromStorage({
    String? visibilityJson,
    String? orderJson,
  }) {
    final defaults = HomeBlockLayout.defaults();

    final visible = <HomeBlockId, bool>{...defaults.visible};
    final decodedVisibility = _tryDecodeMap(visibilityJson);
    if (decodedVisibility != null) {
      decodedVisibility.forEach((key, value) {
        final id = HomeBlockId.fromStorageKey(key);
        if (id != null && value is bool) {
          visible[id] = value;
        }
      });
    }

    final order = <HomeBlockId>[];
    final decodedOrder = _tryDecodeList(orderJson);
    if (decodedOrder != null) {
      for (final entry in decodedOrder) {
        if (entry is! String) {
          continue;
        }
        final id = HomeBlockId.fromStorageKey(entry);
        if (id != null && !order.contains(id)) {
          order.add(id);
        }
      }
    }
    for (final id in HomeBlockId.values) {
      if (!order.contains(id)) {
        order.add(id);
      }
    }

    return HomeBlockLayout(
      visible: visible,
      order: List<HomeBlockId>.unmodifiable(order),
    );
  }

  String get visibilityJson => jsonEncode({
    for (final entry in visible.entries) entry.key.storageKey: entry.value,
  });

  String get orderJson => jsonEncode([for (final id in order) id.storageKey]);

  static Map<String, dynamic>? _tryDecodeMap(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map ? decoded.cast<String, dynamic>() : null;
    } catch (_) {
      return null;
    }
  }

  static List<dynamic>? _tryDecodeList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
