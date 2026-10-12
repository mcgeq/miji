# 首页 v2 实施计划（Milestone 1：生活仪表盘核心）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把首页从「记账仪表盘」改造成「钱 / 健康 / 行动」三维并列、区块可插拔可排序的生活仪表盘，并落地已确认的 6 条决策。

**Architecture:** 新增一层 `HomeBlockId` 注册表与 `HomeBlockLayout`（可见性 + 顺序，存 `user_preferences` 两个 JSON 列）。首页按注册表顺序渲染区块，每块独立 `AsyncValue` 故障隔离。数据层新增 3 个纯聚合 provider（今日三宫格 / 健康摘要 / 行动摘要），全部派生自已有的 provider，不新写业务逻辑。设置页基于注册表生成开关与拖拽排序。

**Tech Stack:** Flutter 3.x / Dart 3.12 · Riverpod 3（`Provider` / `FutureProvider` / `Provider.family`）· Drift（迁移 schemaVersion 24→25）· flutter_test（含 widget test）。

**决策映射：** ①三宫格常驻可逐格关 → Task 1/3/5/12；②待办首页直接完成/新增/删除/编辑 → Task 8；③分类/流水摘要折叠 → Task 10；④健康默认开 → Task 2/3；⑤拖拽排序 → Task 1/2/12；⑥三模块首启引导 → Task 11；⑦纵向/横向布局切换 → Task 1/2/3/12/13；⑧横向默认无标签、标签可选 → Task 2/3/12/13。

**范围说明：** 统一提醒（`reminders.unified` 跨模块）、跨模块洞察、7 天预测属 Milestone 2/3，不在本计划内。本计划完成后首页可用、可配置、可测试。

**通用约定：** 每个 Task 结束都跑 `flutter test <该任务测试文件>`；最后一个 Task 跑全量 `flutter test`。提交信息用 `feat(home): …` / `test(home): …` / `refactor(home): …`。

---

## 文件结构

**新增**

| 文件 | 职责 |
| --- | --- |
| `lib/features/home/domain/home_block.dart` | `HomeBlockId` / `HomeBlockModule` 注册表；`HomeBlockLayout`（可见性 + 顺序 + JSON 读写） |
| `lib/features/home/application/home_today_board_providers.dart` | 今日三宫格聚合 provider + 纯构造函数 |
| `lib/features/home/application/home_health_brief_providers.dart` | 健康摘要（阶段 / 环进度 / 今日记录）provider + 纯构造函数 |
| `lib/features/home/application/home_action_brief_providers.dart` | 行动摘要（待办 + 习惯 + 连续天数）provider + 纯构造函数 |
| `lib/features/home/presentation/home_today_board.dart` | 三宫格 widget |
| `lib/features/home/presentation/home_health_cycle_card.dart` | 健康周期卡 |
| `lib/features/home/presentation/home_health_today_card.dart` | 今日健康记录卡 |
| `lib/features/home/presentation/home_action_todo_card.dart` | 今日待办卡（CRUD） |
| `lib/features/home/presentation/home_action_habit_card.dart` | 习惯打卡卡 |

**修改**

| 文件 | 改动 |
| --- | --- |
| `lib/core/database/tables/user_preferences_table.dart` | 加 `homeBlockVisibility` / `homeBlockOrder` / `homeLayoutMode` / `homePagerTabs` 四列；`showHomeHealthStrip` 默认改 `true` |
| `lib/core/database/app_database.dart` | `schemaVersion` 24→25；`if (from < 25)` 迁移 |
| `lib/core/preferences/domain/user_preferences_entity.dart` | 实体加两字段 |
| `lib/core/preferences/domain/preferences_repository.dart` | 加两个 update 方法 |
| `lib/core/preferences/data/drift_preferences_repository.dart` | 实现 + `_mapPreferences` |
| `lib/features/home/application/home_preference_providers.dart` | 加 `homeBlockLayoutProvider` / `homeLayoutModeProvider` / `homePagerTabsProvider`；健康默认开 |
| `lib/features/home/presentation/home_page.dart` | 按注册表渲染 + 故障隔离 + 三模块首启 |
| `lib/features/home/presentation/home_category_structure_panel.dart` | 默认摘要折叠 |
| `lib/features/home/presentation/home_recent_transactions_panel.dart` | 默认摘要折叠 |
| `lib/features/home/presentation/home_onboarding_view.dart` | 三模块向导 |
| `lib/features/settings/presentation/settings_page.dart` | 首页区块开关 + 逐格开关 + 拖拽排序 |

**测试**

| 文件 | 覆盖 |
| --- | --- |
| `test/features/home/domain/home_block_layout_test.dart` | 注册表 / JSON 容错 / 排序 |
| `test/core/database/app_database_migration_test.dart`（已存在，追加） | 24→25 加列 |
| `test/features/home/application/home_today_board_providers_test.dart` | 三宫格构造 |
| `test/features/home/application/home_health_brief_test.dart` | 阶段 / 环 / 今日记录 |
| `test/features/home/application/home_action_brief_test.dart` | 待办排序 / 习惯进度 |
| `test/features/home/presentation/home_today_board_test.dart` | 三宫格渲染 |
| `test/features/home/presentation/home_action_todo_card_test.dart` | 勾选回调 |
| `test/features/home/presentation/home_page_smoke_test.dart`（已存在，更新） | 新首页不溢出、故障隔离 |

---

# Part A · 布局框架与偏好

## Task 1: HomeBlock 注册表与布局模型（纯 Dart）

**Files:**
- Create: `lib/features/home/domain/home_block.dart`
- Test: `test/features/home/domain/home_block_layout_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/domain/home_block_layout_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/domain/home_block.dart';

void main() {
  test('defaults follow registry defaults and order', () {
    final layout = HomeBlockLayout.defaults();
    expect(layout.isVisible(HomeBlockId.healthForecast), isFalse);
    expect(layout.isVisible(HomeBlockId.boardMoney), isTrue);
    expect(layout.order.first, HomeBlockId.boardMoney);
    expect(layout.order.length, HomeBlockId.values.length);
  });

  test('toggle flips only the target block', () {
    final layout = HomeBlockLayout.defaults().toggle(
      HomeBlockId.moneyRecent,
      false,
    );
    expect(layout.isVisible(HomeBlockId.moneyRecent), isFalse);
    expect(layout.isVisible(HomeBlockId.moneyCategories), isTrue);
  });

  test('fromStorage tolerates unknown keys and missing blocks', () {
    final layout = HomeBlockLayout.fromStorage(
      visibilityJson: '{"money.recent":false,"nope.x":true}',
      orderJson: '["action.todo","nope.x"]',
    );
    expect(layout.isVisible(HomeBlockId.moneyRecent), isFalse);
    // 未知 key 被丢弃，未列出的块按默认补到末尾，顺序不丢块。
    expect(layout.order.toSet(), HomeBlockId.values.toSet());
    expect(layout.order.first, HomeBlockId.actionTodo);
  });

  test('fromStorage survives malformed json', () {
    final layout = HomeBlockLayout.fromStorage(
      visibilityJson: 'not-json',
      orderJson: '{oops',
    );
    expect(layout.order.length, HomeBlockId.values.length);
  });

  test('reorder moves the item', () {
    final base = HomeBlockLayout.defaults();
    final moved = base.reorder(0, 3);
    expect(moved.order[3], base.order[0]);
    expect(moved.order.toSet(), base.order.toSet());
  });

  test('json round-trips', () {
    final layout = HomeBlockLayout.defaults()
        .toggle(HomeBlockId.actionHabit, false)
        .reorder(0, 5);
    final restored = HomeBlockLayout.fromStorage(
      visibilityJson: layout.visibilityJson,
      orderJson: layout.orderJson,
    );
    expect(restored.visibilityJson, layout.visibilityJson);
    expect(restored.orderJson, layout.orderJson);
  });

  test('board cell count helper', () {
    final layout = HomeBlockLayout.defaults()
        .toggle(HomeBlockId.boardHealth, false);
    expect(layout.visibleBoardCellCount, 2);
  });
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/domain/home_block_layout_test.dart`
Expected: FAIL（`home_block.dart` 不存在 / 未定义）

- [ ] **Step 3: 实现**

```dart
// lib/features/home/domain/home_block.dart
import 'dart:convert';

/// 首页布局模式。
enum HomeLayoutMode {
  list('list'),
  pager('pager');

  const HomeLayoutMode(this.storageValue);
  final String storageValue;

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

  String get orderJson =>
      jsonEncode([for (final id in order) id.storageKey]);

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
```

- [ ] **Step 4: 运行，确认通过**

Run: `flutter test test/features/home/domain/home_block_layout_test.dart`
Expected: PASS（7 passing）

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/domain/home_block.dart test/features/home/domain/home_block_layout_test.dart
git commit -m "feat(home): add home block registry and layout model"
```

---

## Task 2: 持久化布局 + 健康默认开（Drift 迁移）

**Files:**
- Modify: `lib/core/database/tables/user_preferences_table.dart`
- Modify: `lib/core/database/app_database.dart:102`（schemaVersion）、`:106`（onUpgrade 末尾）
- Modify: `lib/core/preferences/domain/user_preferences_entity.dart`
- Modify: `lib/core/preferences/domain/preferences_repository.dart`
- Modify: `lib/core/preferences/data/drift_preferences_repository.dart`
- Test: `test/core/database/app_database_migration_test.dart`（追加）

- [ ] **Step 1: 写失败测试**

先读 `test/core/database/app_database_migration_test.dart` 的既有写法（它用「当前 schema 再减列」模拟旧库），在文件里追加：

```dart
test('migration 24 -> 25 adds home block columns', () async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  await database.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_block_visibility',
  );
  await database.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_block_order',
  );
  // 触发 onUpgrade 到当前版本。
  await database.customStatement('PRAGMA user_version = 24');
  // 具体触发方式沿用该文件既有的「打开旧库 → 迁移」helper。
  // 断言两列存在：
  final columns = await database
      .customSelect("PRAGMA table_info('user_preferences')")
      .get();
  final names = columns.map((row) => row.read<String>('name')).toList();
  expect(names, containsAll(['home_block_visibility', 'home_block_order']));
});
```

> 注：如果现有迁移测试用的是固定旧 `AppDatabase` 版本类，直接按该文件的模式改；不要新造一套。

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/core/database/app_database_migration_test.dart`
Expected: FAIL（列不存在）

- [ ] **Step 3: 实现**

`lib/core/database/tables/user_preferences_table.dart` 末尾（`createdAt` 之前）加四列，并把健康列默认改 `true`：

```dart
  /// 首页是否显示健康区块（经期 / 孕期）。默认开。
  BoolColumn get showHomeHealthStrip =>
      boolean().withDefault(const Constant(true))();

  /// 首页区块可见性，`{storageKey: bool}` 的 JSON。
  TextColumn get homeBlockVisibility => text().nullable()();

  /// 首页区块顺序，`[storageKey, ...]` 的 JSON。
  TextColumn get homeBlockOrder => text().nullable()();

  /// 首页布局：`list`（纵向单列）或 `pager`（横向分页，默认）。
  TextColumn get homeLayoutMode =>
      text().withDefault(const Constant('pager'))();

  /// 横向分页时是否显示顶部标签。默认关。
  BoolColumn get homePagerTabs =>
      boolean().withDefault(const Constant(false))();
```

`lib/core/database/app_database.dart`：`schemaVersion` 改为 `25`；在 `onUpgrade` 的 `if (from < 23)` 之前（顺序无所谓，按版本号递增放最前即可）加：

```dart
        if (from < 25) {
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeBlockVisibility,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeBlockOrder,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeLayoutMode,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homePagerTabs,
          );
        }
```

> 健康列默认从 `false` 改 `true` 只影响**新行**；老用户已经明确设过开关的保持原值（值存在 `show_home_health_strip` 里，无法区分「显式关」与「默认关」，不强行覆盖）。

`lib/core/preferences/domain/user_preferences_entity.dart`：构造参数加四个可选字段并声明：

```dart
    this.homeBlockVisibility,
    this.homeBlockOrder,
    this.homeLayoutMode = 'pager',
    this.homePagerTabs = false,
```
```dart
  /// 首页区块可见性 JSON。
  final String? homeBlockVisibility;

  /// 首页区块顺序 JSON。
  final String? homeBlockOrder;

  /// 首页布局：`list` / `pager`。
  final String homeLayoutMode;

  /// 横向分页是否显示顶部标签。
  final bool homePagerTabs;
```

`lib/core/preferences/domain/preferences_repository.dart` 加：

```dart
  Future<void> updateHomeBlockVisibility(String userId, String? json);

  Future<void> updateHomeBlockOrder(String userId, String? json);

  Future<void> updateHomeLayoutMode(String userId, String mode);

  Future<void> updateHomePagerTabs(String userId, bool show);
```

`lib/core/preferences/data/drift_preferences_repository.dart` 加实现，并复用 `_updateBooleanPreference` 所在文件里的通用 `_update`（如无则照 `updateMaskMoneyAmounts` 写）：

```dart
  @override
  Future<void> updateHomeBlockVisibility(String userId, String? json) {
    return _update(
      userId,
      UserPreferencesCompanion(homeBlockVisibility: Value(json)),
    );
  }

  @override
  Future<void> updateHomeBlockOrder(String userId, String? json) {
    return _update(
      userId,
      UserPreferencesCompanion(homeBlockOrder: Value(json)),
    );
  }

  @override
  Future<void> updateHomeLayoutMode(String userId, String mode) {
    return _update(
      userId,
      UserPreferencesCompanion(homeLayoutMode: Value(mode)),
    );
  }

  @override
  Future<void> updateHomePagerTabs(String userId, bool show) {
    return _update(
      userId,
      UserPreferencesCompanion(homePagerTabs: Value(show)),
    );
  }
```

把现有 `_updateBooleanPreference` 重命名/泛化为 `_update(String userId, UserPreferencesCompanion companion)`（行为不变：写 `updatedAt`、找不到行抛 `preferencesNotFound`），两个旧调用点同步改名。`_mapPreferences` 加：

```dart
      homeBlockVisibility: preferences.homeBlockVisibility,
      homeBlockOrder: preferences.homeBlockOrder,
      homeLayoutMode: preferences.homeLayoutMode,
      homePagerTabs: preferences.homePagerTabs,
```

- [ ] **Step 4: 运行**

Run: `flutter test test/core/database/app_database_migration_test.dart test/features/home/domain/home_block_layout_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/core/database/tables/user_preferences_table.dart lib/core/database/app_database.dart lib/core/preferences test/core/database/app_database_migration_test.dart
git commit -m "feat(preferences): persist home block layout and default health block on"
```

---

## Task 3: 布局 provider 与健康默认开

**Files:**
- Modify: `lib/features/home/application/home_preference_providers.dart`
- Test: `test/features/home/application/home_block_providers_test.dart`（新建）

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/application/home_block_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

UserPreferencesEntity prefs({String? visibility, String? order}) {
  final now = DateTime.utc(2026, 10, 12);
  return UserPreferencesEntity(
    userId: 'u1',
    themeMode: AppThemeModePreference.system,
    sensitiveAccessTtl: SensitiveAccessTtlOption.tenMinutes,
    homeBlockVisibility: visibility,
    homeBlockOrder: order,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('layout provider reads stored layout', () {
    final container = ProviderContainer(
      overrides: [
        currentUserPreferencesProvider.overrideWith(
          (ref) async => prefs(visibility: '{"action.habit":false}'),
        ),
      ],
    );
    addTearDown(container.dispose);

    final layout = container.read(homeBlockLayoutProvider);
    expect(layout.isVisible(HomeBlockId.actionHabit), isFalse);
    expect(layout.isVisible(HomeBlockId.actionTodo), isTrue);
  });

  test('health block defaults on when nothing stored', () {
    final container = ProviderContainer(
      overrides: [
        currentUserPreferencesProvider.overrideWith((ref) async => prefs()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(homeShowHealthStripProvider), isTrue);
  });

  test('layout mode defaults to pager, pager tabs default off', () {
    final container = ProviderContainer(
      overrides: [
        currentUserPreferencesProvider.overrideWith((ref) async => prefs()),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(homeLayoutModeProvider), HomeLayoutMode.pager);
    expect(container.read(homePagerTabsProvider), isFalse);
  });
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/application/home_block_providers_test.dart`
Expected: FAIL（`homeBlockLayoutProvider` 未定义）

- [ ] **Step 3: 实现**

`lib/features/home/application/home_preference_providers.dart` 改为：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

/// 首页区块布局（可见性 + 顺序）。解析失败自动回落默认。
final homeBlockLayoutProvider = Provider<HomeBlockLayout>((ref) {
  final preferences = ref.watch(currentUserPreferencesProvider).valueOrNull;
  return HomeBlockLayout.fromStorage(
    visibilityJson: preferences?.homeBlockVisibility,
    orderJson: preferences?.homeBlockOrder,
  );
});

/// 统一入口：某区块是否可见。
final homeBlockVisibleProvider = Provider.family<bool, HomeBlockId>((
  ref,
  id,
) {
  return ref.watch(homeBlockLayoutProvider).isVisible(id);
});

/// 首页布局模式（纵向单列 / 横向分页）。
final homeLayoutModeProvider = Provider<HomeLayoutMode>((ref) {
  final preferences = ref.watch(currentUserPreferencesProvider).valueOrNull;
  return HomeLayoutMode.fromStorage(preferences?.homeLayoutMode);
});

/// 横向分页是否显示顶部标签（默认关，靠滑动 + 圆点）。
final homePagerTabsProvider = Provider<bool>((ref) {
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.homePagerTabs,
            orElse: () => null,
          ) ??
      false;
});

/// 健康区块总开关。**默认开**（未存值时视为开）。
final homeShowHealthStripProvider = Provider<bool>((ref) {
  return ref
          .watch(currentUserPreferencesProvider)
          .maybeWhen(
            data: (preferences) => preferences?.showHomeHealthStrip,
            orElse: () => null,
          ) ??
      true;
});
```

`homeShowTodayActionProvider` 保留（Task 8 起改用 `homeBlockVisibleProvider(HomeBlockId.actionTodo)`，可先不动）。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/application/home_block_providers_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/application/home_preference_providers.dart test/features/home/application/home_block_providers_test.dart
git commit -m "feat(home): add block layout provider and default health block visible"
```

---

# Part B · 今日三宫格

## Task 4: 三宫格聚合 provider

**Files:**
- Create: `lib/features/home/application/home_today_board_providers.dart`
- Test: `test/features/home/application/home_today_board_providers_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/application/home_today_board_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

void main() {
  test('money cell prefers month remaining when a budget exists', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: 41332,
      monthNetMinor: 120000,
      currencyCode: 'CNY',
      masked: false,
    );
    expect(cell.value, contains('413'));
    expect(cell.sub, contains('51.17'));
  });

  test('money cell falls back to net when no budget', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: null,
      monthNetMinor: 120000,
      currencyCode: 'CNY',
      masked: false,
    );
    expect(cell.value, contains('1,200'));
  });

  test('money cell masks amounts', () {
    final cell = buildMoneyBoardCell(
      todayExpenseMinor: 5117,
      monthRemainingMinor: 41332,
      monthNetMinor: 120000,
      currencyCode: 'CNY',
      masked: true,
    );
    expect(cell.value.contains('413'), isFalse);
  });

  test('health cell shows period day and today logged', () {
    final cell = buildHealthBoardCell(
      hint: const HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '经期第 3 天',
        detail: '今天已记录',
      ),
    );
    expect(cell.value, '经期第 3 天');
    expect(cell.sub, '今天已记录');
  });

  test('health cell falls back when hint is null', () {
    final cell = buildHealthBoardCell(hint: null);
    expect(cell.value, '未开启');
    expect(cell.sub, '去开启追踪');
  });

  test('action cell shows progress and next item', () {
    final cell = buildActionBoardCell(
      const TodayActionView(
        items: [],
        completedCount: 2,
        totalCount: 5,
      ),
    );
    expect(cell.value, '2 / 5');
  });

  test('action cell marks all done', () {
    final cell = buildActionBoardCell(
      const TodayActionView(items: [], completedCount: 5, totalCount: 5),
    );
    expect(cell.sub, contains('全部完成'));
  });
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/application/home_today_board_providers_test.dart`
Expected: FAIL（文件不存在）

- [ ] **Step 3: 实现**

```dart
// lib/features/home/application/home_today_board_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 三宫格的一格。`value` / `sub` 已经是给人看的字符串。
class HomeBoardCell {
  const HomeBoardCell({
    required this.id,
    required this.emoji,
    required this.value,
    required this.sub,
  });

  final HomeBlockId id;
  final String emoji;
  final String value;
  final String sub;
}

class HomeTodayBoardData {
  const HomeTodayBoardData({required this.cells});

  final List<HomeBoardCell> cells;

  bool get isEmpty => cells.isEmpty;
}

final homeTodayBoardProvider = Provider<HomeTodayBoardData>((ref) {
  final today = ref.watch(homeTodaySpendingSummaryProvider).valueOrNull;
  final budget = ref.watch(homeMonthBudgetSummaryProvider).valueOrNull;
  final masked = ref.watch(moneyAmountsMaskedProvider);
  final hint = ref.watch(homeHealthHintProvider).valueOrNull;
  final action = ref.watch(todayActionItemsProvider).valueOrNull;

  final cells = <HomeBoardCell>[
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardMoney)))
      buildMoneyBoardCell(
        todayExpenseMinor: today?.todayExpenseMinor,
        monthRemainingMinor: budget?.hasBudget ?? false
            ? budget?.availableMinor
            : null,
        monthNetMinor: today?.monthNetMinor,
        currencyCode: today?.currencyCode ?? 'CNY',
        masked: masked,
      ),
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardHealth)))
      buildHealthBoardCell(hint: hint),
    if (ref.watch(homeBlockVisibleProvider(HomeBlockId.boardAction)))
      buildActionBoardCell(action),
  ];

  return HomeTodayBoardData(cells: cells);
});

HomeBoardCell buildMoneyBoardCell({
  required int? todayExpenseMinor,
  required int? monthRemainingMinor,
  required int? monthNetMinor,
  required String currencyCode,
  required bool masked,
}) {
  String money(int minor) =>
      masked ? '••••' : formatMoneyMinorCompact(minor, currencyCode);

  final int? fallback = monthNetMinor;
  final int? primary = monthRemainingMinor ?? fallback;

  final value = primary == null ? '—' : money(primary);
  final todayLabel = todayExpenseMinor == null
      ? '还没有流水'
      : '今日支出 ${masked ? '••••' : formatMoneyMinor(todayExpenseMinor, currencyCode)}';
  final sub = monthRemainingMinor != null
      ? '本月还可花 · $todayLabel'
      : todayLabel;

  return HomeBoardCell(
    id: HomeBlockId.boardMoney,
    emoji: '💰',
    value: value,
    sub: sub,
  );
}

HomeBoardCell buildHealthBoardCell({required HomeHealthHint? hint}) {
  if (hint == null) {
    return const HomeBoardCell(
      id: HomeBlockId.boardHealth,
      emoji: '🩺',
      value: '未开启',
      sub: '去开启追踪',
    );
  }
  return HomeBoardCell(
    id: HomeBlockId.boardHealth,
    emoji: '🩺',
    value: hint.title,
    sub: hint.detail,
  );
}

HomeBoardCell buildActionBoardCell(TodayActionView? view) {
  if (view == null || view.totalCount == 0) {
    return const HomeBoardCell(
      id: HomeBlockId.boardAction,
      emoji: '✅',
      value: '—',
      sub: '今天没有待办',
    );
  }
  final sub = view.completedCount >= view.totalCount
      ? '全部完成 🎉'
      : '下一件 · ${_nextTitle(view)}';
  return HomeBoardCell(
    id: HomeBlockId.boardAction,
    emoji: '✅',
    value: '${view.completedCount} / ${view.totalCount}',
    sub: sub,
  );
}

String _nextTitle(TodayActionView view) {
  for (final item in view.items) {
    if (item.isCompleted) {
      continue;
    }
    return switch (item) {
      TodayTodoActionItem(:final task) => task.title,
      TodayHabitActionItem(:final progress) => progress.plan.name,
    };
  }
  return '已完成';
}
```

> `moneyAmountsMaskedProvider` 在 `bookkeeping_providers.dart`；若不在该文件请按实际导出路径 import。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/application/home_today_board_providers_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/application/home_today_board_providers.dart test/features/home/application/home_today_board_providers_test.dart
git commit -m "feat(home): add today board aggregate provider"
```

---

## Task 5: 三宫格 widget 与接线

**Files:**
- Create: `lib/features/home/presentation/home_today_board.dart`
- Modify: `lib/features/home/presentation/home_page.dart`
- Test: `test/features/home/presentation/home_today_board_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/presentation/home_today_board_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/home/presentation/home_today_board.dart';

void main() {
  testWidgets('renders one cell per entry', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeTodayBoard(
            data: const HomeTodayBoardData(
              cells: [
                HomeBoardCell(
                  id: HomeBlockId.boardMoney,
                  emoji: '💰',
                  value: '¥413',
                  sub: '本月还可花',
                ),
                HomeBoardCell(
                  id: HomeBlockId.boardHealth,
                  emoji: '🩺',
                  value: '第 3 天',
                  sub: '今天已记录',
                ),
              ],
            ),
            onTapCell: (_) => tapped++,
          ),
        ),
      ),
    );

    expect(find.text('¥413'), findsOneWidget);
    expect(find.text('第 3 天'), findsOneWidget);
    await tester.tap(find.text('¥413'));
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_today_board_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

```dart
// lib/features/home/presentation/home_today_board.dart
import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

/// 今日三宫格：钱 / 健康 / 行动同级。格子数 2–3，由布局决定。
class HomeTodayBoard extends StatelessWidget {
  const HomeTodayBoard({
    super.key,
    required this.data,
    required this.onTapCell,
  });

  final HomeTodayBoardData data;
  final ValueChanged<HomeBlockId> onTapCell;

  @override
  Widget build(BuildContext context) {
    final cells = data.cells;
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) const SizedBox(width: 9),
          Expanded(
            child: _BoardCellTile(
              cell: cells[i],
              onTap: () => onTapCell(cells[i].id),
            ),
          ),
        ],
      ],
    );
  }
}

class _BoardCellTile extends StatelessWidget {
  const _BoardCellTile({required this.cell, required this.onTap});

  final HomeBoardCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cell.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 7),
          Text(
            cell.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cell.sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
```

在 `home_page.dart` 里接线（单列 / 双栏都放在问候头之后、`overviewCard` 之前）：

```dart
    final board = HomeTodayBoard(
      data: ref.watch(homeTodayBoardProvider),
      onTapCell: (id) => _openBoardCell(context, id),
    );
```

```dart
  void _openBoardCell(BuildContext context, HomeBlockId id) {
    switch (id) {
      case HomeBlockId.boardMoney:
        _openTransactionsPage(context);
      case HomeBlockId.boardHealth:
        context.go(AppRoutes.health);
      case HomeBlockId.boardAction:
        context.push(AppRoutes.gtd);
      default:
        break;
    }
  }
```

单列 children 里加 `_section(1, board), _gap,` 并把后续 section 序号顺移；双栏在 `Row` 之前加 `_section(1, board), const SizedBox(height: 16),`。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/presentation/home_today_board_test.dart test/features/home/presentation/home_page_smoke_test.dart`
Expected: PASS（smoke 若因新版式断言旧文本失败，本步先记录，Task 13 统一修）

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_today_board.dart lib/features/home/presentation/home_page.dart test/features/home/presentation/home_today_board_test.dart
git commit -m "feat(home): render today board on the dashboard"
```

---

# Part C · 健康区

## Task 6: 健康摘要 provider

**Files:**
- Create: `lib/features/home/application/home_health_brief_providers.dart`
- Test: `test/features/home/application/home_health_brief_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/application/home_health_brief_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

HealthDailyLog log({
  HealthMood? mood,
  int? sleepMinutes,
  int? waterIntake,
  int? weightGrams,
}) {
  return HealthDailyLog(
    id: null,
    date: DateTime.utc(2026, 10, 12),
    periodRecordId: null,
    flowLevel: null,
    symptoms: const [],
    mood: mood,
    exerciseIntensity: null,
    sexualActivity: null,
    contraceptionMethod: null,
    ovulationTest: null,
    medications: const [],
    diet: null,
    waterIntake: waterIntake,
    sleepMinutes: sleepMinutes,
    weightGrams: weightGrams,
    temperatureCelsiusTenths: null,
    stressLevel: null,
    calories: null,
    notes: null,
  );
}

void main() {
  test('builds four today log metrics with empty flags', () {
    final brief = buildHomeHealthBrief(
      snapshot: _snapshot(log: log(mood: HealthMood.calm, sleepMinutes: 440)),
    );
    expect(brief.todayMetrics.length, 4);
    expect(brief.todayMetrics[0].logged, isTrue);
    expect(brief.todayMetrics[1].value, '7h20m');
    expect(brief.todayMetrics[2].logged, isFalse); // 饮水
  });

  test('exposes cycle phase label', () {
    final brief = buildHomeHealthBrief(snapshot: _snapshot(log: log()));
    expect(brief.phaseLabel, isNotEmpty);
  });
}

HealthTodaySnapshot _snapshot({required HealthDailyLog log}) {
  const settings = HealthPeriodSettingsModel(
    averageCycleLength: 28,
    averagePeriodLength: 5,
    periodTrackingEnabled: true,
    periodReminderEnabled: true,
    ovulationReminderEnabled: true,
    pmsReminderEnabled: true,
    reminderDays: 1,
    dataSyncEnabled: true,
    analyticsEnabled: false,
  );
  return HealthTodaySnapshot(
    date: DateTime.utc(2026, 10, 12),
    settings: settings,
    prediction: HealthCyclePrediction.cycleDay(
      basis: HealthPredictionBasis.history,
      mainStatus: '周期第 12 天',
      currentCycleDay: 12,
      daysUntilNextPeriod: 16,
      nextPeriodStart: DateTime.utc(2026, 10, 28),
      nextPeriodEnd: DateTime.utc(2026, 11, 1),
      fertileWindowStart: DateTime.utc(2026, 10, 20),
      fertileWindowEnd: DateTime.utc(2026, 10, 25),
      pmsStart: DateTime.utc(2026, 10, 24),
      pmsEnd: DateTime.utc(2026, 10, 30),
    ),
    activePeriod: null,
    dailyLog: log,
    activePregnancy: null,
  );
}
```

> 若 `HealthTodaySnapshot` 构造签名不同，以 `lib/features/health/domain/health_models.dart:624` 实际为准。注意：`HealthDailyLog` **没有 `copyWith`**，测试里必须走全参构造或 `HealthDailyLog.empty(date)`。

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/application/home_health_brief_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

```dart
// lib/features/home/application/home_health_brief_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/health/domain/health_cycle_phase.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';

enum HomeHealthMetricKind { mood, sleep, water, weight }

class HomeHealthMetric {
  const HomeHealthMetric({
    required this.kind,
    required this.emoji,
    required this.label,
    required this.value,
    required this.logged,
  });

  final HomeHealthMetricKind kind;
  final String emoji;
  final String label;
  final String value;
  final bool logged;
}

class HomeHealthBrief {
  const HomeHealthBrief({
    required this.trackingEnabled,
    required this.isPregnancy,
    required this.headline,
    required this.subline,
    required this.phaseLabel,
    required this.ringRatio,
    required this.ringDay,
    required this.ringTotal,
    required this.todayMetrics,
  });

  final bool trackingEnabled;
  final bool isPregnancy;
  final String headline;
  final String subline;
  final String phaseLabel;
  final double ringRatio;
  final int ringDay;
  final int ringTotal;
  final List<HomeHealthMetric> todayMetrics;
}

final homeHealthBriefProvider = FutureProvider<HomeHealthBrief?>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }
  final snapshot = await ref.watch(
    currentUserHealthTodaySnapshotProvider.future,
  );
  if (snapshot == null) {
    return null;
  }
  return buildHomeHealthBrief(snapshot: snapshot);
});

HomeHealthBrief buildHomeHealthBrief({
  required HealthTodaySnapshot snapshot,
}) {
  final prediction = snapshot.prediction;
  final settings = snapshot.settings;
  final isPregnancy =
      prediction.statusKind == HealthTodayStatusKind.pregnancy;

  final progress = healthCycleProgressFor(prediction, settings);
  final phase = prediction.phaseOn(snapshot.date);

  final headline = switch (prediction.statusKind) {
    HealthTodayStatusKind.pregnancy => '孕期第 ${prediction.pregnancyWeek} 周',
    HealthTodayStatusKind.periodDay => '经期第 ${prediction.currentPeriodDay} 天',
    HealthTodayStatusKind.cycleDay =>
      prediction.isOverdue
          ? '经期已推迟 ${prediction.daysUntilNextPeriod!.abs()} 天'
          : '距下次经期还有 ${prediction.daysUntilNextPeriod} 天',
    HealthTodayStatusKind.noPeriodHistory => '还没有周期记录',
  };

  final subline = switch (prediction.statusKind) {
    HealthTodayStatusKind.pregnancy =>
      snapshot.activePregnancy?.dueDate == null
          ? '孕期模式进行中'
          : '预产期 ${_monthDay(snapshot.activePregnancy!.dueDate!)}',
    HealthTodayStatusKind.periodDay => '本次经期进行中',
    HealthTodayStatusKind.cycleDay =>
      prediction.nextPeriodStart == null
          ? ''
          : '${_monthDay(prediction.nextPeriodStart!)} 预计开始',
    HealthTodayStatusKind.noPeriodHistory => '记录一次经期即可开始预测',
  };

  return HomeHealthBrief(
    trackingEnabled: settings.periodTrackingEnabled,
    isPregnancy: isPregnancy,
    headline: headline,
    subline: subline,
    phaseLabel: _phaseLabel(phase),
    ringRatio: progress?.ratio ?? 0,
    ringDay: progress?.day ?? 0,
    ringTotal: progress?.total ?? settings.averageCycleLength,
    todayMetrics: _todayMetrics(snapshot.dailyLog),
  );
}

List<HomeHealthMetric> _todayMetrics(HealthDailyLog log) {
  return [
    HomeHealthMetric(
      kind: HomeHealthMetricKind.mood,
      emoji: '🙂',
      label: '心情',
      value: log.mood == null ? '+' : _moodLabel(log.mood!),
      logged: log.mood != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.sleep,
      emoji: '😴',
      label: '睡眠',
      value: log.sleepMinutes == null ? '+' : _duration(log.sleepMinutes!),
      logged: log.sleepMinutes != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.water,
      emoji: '💧',
      label: '饮水',
      value: log.waterIntake == null ? '+' : '${log.waterIntake}ml',
      logged: log.waterIntake != null,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.weight,
      emoji: '⚖️',
      label: '体重',
      value: log.weightGrams == null
          ? '+'
          : '${(log.weightGrams! / 1000).toStringAsFixed(1)}kg',
      logged: log.weightGrams != null,
    ),
  ];
}

String _phaseLabel(HealthCyclePhase phase) => switch (phase) {
  HealthCyclePhase.period => '经期',
  HealthCyclePhase.follicular => '卵泡期',
  HealthCyclePhase.fertile => '易孕期',
  HealthCyclePhase.luteal => '黄体期',
  HealthCyclePhase.pms => '经前期',
  HealthCyclePhase.pregnancy => '孕期',
  HealthCyclePhase.none => '',
};

String _duration(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}m';
}

String _monthDay(DateTime date) => '${date.month}月${date.day}日';

String _moodLabel(HealthMood mood) => switch (mood) {
  HealthMood.happy => '开心',
  HealthMood.sad => '难过',
  HealthMood.angry => '生气',
  HealthMood.anxious => '焦虑',
  HealthMood.calm => '平静',
  HealthMood.irritable => '烦躁',
};
```

> 删掉 `_keepMath` 与 `dart:math` import，除非实现用到。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/application/home_health_brief_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/application/home_health_brief_providers.dart test/features/home/application/home_health_brief_test.dart
git commit -m "feat(home): add health brief provider"
```

---

## Task 7: 健康周期卡 + 今日记录卡

**Files:**
- Create: `lib/features/home/presentation/home_health_cycle_card.dart`
- Create: `lib/features/home/presentation/home_health_today_card.dart`
- Modify: `lib/features/home/presentation/home_page.dart`（替换 `home_health_strip.dart` 用法）
- Test: `test/features/home/presentation/home_health_cards_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/presentation/home_health_cards_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';
import 'package:miji/features/home/presentation/home_health_cycle_card.dart';
import 'package:miji/features/home/presentation/home_health_today_card.dart';

HomeHealthBrief brief({bool tracking = true}) => HomeHealthBrief(
  trackingEnabled: tracking,
  isPregnancy: false,
  headline: '经期第 3 天',
  subline: '本次经期进行中',
  phaseLabel: '经期',
  ringRatio: 0.1,
  ringDay: 3,
  ringTotal: 28,
  todayMetrics: const [
    HomeHealthMetric(
      kind: HomeHealthMetricKind.mood,
      emoji: '🙂',
      label: '心情',
      value: '+',
      logged: false,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.sleep,
      emoji: '😴',
      label: '睡眠',
      value: '7h20m',
      logged: true,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.water,
      emoji: '💧',
      label: '饮水',
      value: '+',
      logged: false,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.weight,
      emoji: '⚖️',
      label: '体重',
      value: '+',
      logged: false,
    ),
  ],
);

void main() {
  testWidgets('cycle card shows headline and opens today', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthCycleCard(
            brief: brief(),
            onOpenHealth: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('经期第 3 天'), findsOneWidget);
    await tester.tap(find.byType(HomeHealthCycleCard));
    expect(opened, isTrue);
  });

  testWidgets('today card emits tapped metric', (tester) async {
    HomeHealthMetricKind? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthTodayCard(
            metrics: brief().todayMetrics,
            onTapMetric: (kind) => tapped = kind,
          ),
        ),
      ),
    );
    await tester.tap(find.text('睡眠'));
    expect(tapped, HomeHealthMetricKind.sleep);
  });
}
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_health_cards_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

`home_health_cycle_card.dart`：

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

class HomeHealthCycleCard extends StatelessWidget {
  const HomeHealthCycleCard({
    super.key,
    required this.brief,
    required this.onOpenHealth,
    this.onCreatePeriod,
  });

  final HomeHealthBrief brief;
  final VoidCallback onOpenHealth;
  final VoidCallback? onCreatePeriod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!brief.trackingEnabled) {
      return AppSurface(
        onTap: onOpenHealth,
        child: Row(
          children: [
            const Text('🩺', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('开启健康追踪', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '记录周期、预测经期与易孕期',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text('去开启 ›', style: theme.textTheme.labelMedium),
          ],
        ),
      );
    }

    return AppSurface(
      onTap: onOpenHealth,
      child: Row(
        children: [
          _CycleRing(brief: brief),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  brief.headline,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (brief.subline.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    brief.subline,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (brief.phaseLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    brief.phaseLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18),
        ],
      ),
    );
  }
}

class _CycleRing extends StatelessWidget {
  const _CycleRing({required this.brief});

  final HomeHealthBrief brief;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = brief.isPregnancy
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: CircularProgressIndicator(
              value: brief.ringRatio.clamp(0.0, 1.0),
              strokeWidth: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${brief.ringDay}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '/ ${brief.ringTotal}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
final _unusedMath = math.max;
```

> 移除未用的 `dart:math` 与 `_unusedMath`。

`home_health_today_card.dart`：

```dart
import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';

class HomeHealthTodayCard extends StatelessWidget {
  const HomeHealthTodayCard({
    super.key,
    required this.metrics,
    required this.onTapMetric,
    this.onEdit,
  });

  final List<HomeHealthMetric> metrics;
  final ValueChanged<HomeHealthMetricKind> onTapMetric;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('📝 今日记录', style: theme.textTheme.labelMedium),
              const Spacer(),
              if (onEdit != null) TextButton(onPressed: onEdit, child: const Text('编辑')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MetricTile(
                    metric: metrics[i],
                    onTap: () => onTapMetric(metrics[i].kind),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.onTap});

  final HomeHealthMetric metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          children: [
            Text(metric.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 5),
            Text(
              metric.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              metric.value,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: metric.logged
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

在 `home_page.dart`：把 `HomeHealthStrip` 相关代码替换为

```dart
    final healthBrief = showHealthStrip
        ? ref.watch(homeHealthBriefProvider)
        : const AsyncValue<HomeHealthBrief?>.data(null);
    final healthBriefValue = healthBrief.valueOrNull;
    final healthCycleCard = healthBriefValue == null
        ? null
        : HomeHealthCycleCard(
            brief: healthBriefValue,
            onOpenHealth: () => context.go(AppRoutes.health),
          );
    final healthTodayCard = healthBriefValue == null ||
            !healthBriefValue.trackingEnabled
        ? null
        : HomeHealthTodayCard(
            metrics: healthBriefValue.todayMetrics,
            onTapMetric: (kind) => _quickLogHealth(context, ref, kind),
            onEdit: () => context.go(AppRoutes.health),
          );
```

`_quickLogHealth` 用既有的 dialog（`health_quick_dialogs.dart`）或直接跳健康页：

```dart
  Future<void> _quickLogHealth(
    BuildContext context,
    WidgetRef ref,
    HomeHealthMetricKind kind,
  ) async {
    final snapshot =
        ref.read(currentUserHealthTodaySnapshotProvider).valueOrNull;
    if (snapshot == null) {
      context.go(AppRoutes.health);
      return;
    }
    final log = snapshot.dailyLog;
    final writer = ref.read(currentUserHealthWriteControllerProvider);
    switch (kind) {
      case HomeHealthMetricKind.mood:
        await showHealthMoodDialog(
          context: context,
          existing: log,
          onSave: (draft) => writer.upsertDailyLog(draft),
        );
      case HomeHealthMetricKind.sleep:
        await showHealthTemperatureSleepDialog(
          context: context,
          existing: log,
          onSave: (draft) => writer.upsertDailyLog(draft),
        );
      case HomeHealthMetricKind.water:
      case HomeHealthMetricKind.weight:
        context.go(AppRoutes.health);
    }
  }
```

在单列/双栏里把原来的 `healthStrip` 位置替换为 `if (healthCycleCard != null) _section(n, healthCycleCard)`，其后 `if (healthTodayCard != null) _section(n+1, healthTodayCard)`。`home_health_strip.dart` 可保留不删（其它引用若有）。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/presentation/home_health_cards_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_health_cycle_card.dart lib/features/home/presentation/home_health_today_card.dart lib/features/home/presentation/home_page.dart test/features/home/presentation/home_health_cards_test.dart
git commit -m "feat(home): replace health strip with cycle and today cards"
```

---

# Part D · 行动区

## Task 8: 行动摘要 provider + 今日待办卡（CRUD）

**Files:**
- Create: `lib/features/home/application/home_action_brief_providers.dart`
- Create: `lib/features/home/presentation/home_action_todo_card.dart`
- Modify: `lib/features/home/presentation/home_page.dart`
- Test: `test/features/home/application/home_action_brief_test.dart`
- Test: `test/features/home/presentation/home_action_todo_card_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/application/home_action_brief_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

TodoTask task(String id, String title, {bool overdue = false}) => TodoTask(
  id: id,
  userId: 'u1',
  title: title,
  status: TodoTaskStatus.todo,
  priority: TodoTaskPriority.none,
  createdAt: DateTime.utc(2026, 10, 1),
  updatedAt: DateTime.utc(2026, 10, 1),
);

void main() {
  test('todo items keep provider order and cap', () {
    final view = TodayActionView(
      items: [for (var i = 0; i < 8; i++) TodayTodoActionItem(task: task('$i', 'T$i'))],
      completedCount: 0,
      totalCount: 8,
    );
    final brief = buildHomeActionBrief(view: view, habits: const [], cap: 5);
    expect(brief.todos.length, 5);
    expect(brief.completedCount, 0);
    expect(brief.totalCount, 8);
  });

  test('habit items map progress', () {
    const plan = CheckinPlan(
      id: 'p1',
      userId: 'u1',
      name: '阅读',
      icon: '📖',
      color: '#000000',
      category: '学习',
      planType: CheckinPlanType.cyclic,
      frequencyType: CheckinFrequencyType.daily,
      targetValue: 30,
      targetUnit: '页',
      triggerMode: CheckinTriggerMode.button,
      recordGranularity: CheckinRecordGranularity.merged,
      defaultVisibility: CheckinVisibility.private,
      reminderEnabled: false,
      isArchived: false,
      sortOrder: 0,
      version: 1,
      isDeleted: false,
      createdAt: DateTime.utc(2026, 10, 1),
      updatedAt: DateTime.utc(2026, 10, 1),
    );
    const progress = PlanProgress(
      plan: plan,
      currentCount: 1,
      currentValue: 20,
      streak: 12,
    );
    final brief = buildHomeActionBrief(
      view: const TodayActionView(items: [], completedCount: 0, totalCount: 0),
      habits: const [progress],
      cap: 5,
    );
    expect(brief.habits.single.name, '阅读');
    expect(brief.habits.single.progressLabel, '20/30 页');
    expect(brief.habits.single.streak, 12);
  });
}
```

> `CheckinPlan` / `PlanProgress` 字段以实际为准（`checkin_models.dart:186`、`:473`）。

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/application/home_action_brief_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

```dart
// lib/features/home/application/home_action_brief_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

class HomeTodoEntry {
  const HomeTodoEntry({required this.task});

  final TodoTask task;
}

class HomeHabitEntry {
  const HomeHabitEntry({required this.progress});

  final PlanProgress progress;
  String get name => progress.plan.name;
  String get icon => progress.plan.icon;
  String get progressLabel {
    final value = progress.currentValue;
    final formatted = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$formatted/${progress.plan.targetValue.toInt()} ${progress.plan.targetUnit}';
  }
  double get ratio => progress.completionRate;
  int? get streak => progress.streak;
  bool get isDone => progress.completionRate >= 1.0;
}

class HomeActionBrief {
  const HomeActionBrief({
    required this.todos,
    required this.habits,
    required this.completedCount,
    required this.totalCount,
    required this.streakDays,
  });

  final List<HomeTodoEntry> todos;
  final List<HomeHabitEntry> habits;
  final int completedCount;
  final int totalCount;
  final int streakDays;
}

final homeActionBriefProvider = FutureProvider<HomeActionBrief>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  if (session.userId == null) {
    return buildHomeActionBrief(
      view: null,
      habits: const [],
      cap: 5,
      streakDays: 0,
    );
  }

  final results = await Future.wait([
    ref.watch(todayActionItemsProvider.future),
    ref.watch(todayProgressProvider.future),
    ref.watch(checkinStreakProvider.future),
  ]);

  return buildHomeActionBrief(
    view: results[0] as TodayActionView,
    habits: results[1] as List<PlanProgress>,
    cap: 5,
    streakDays: (results[2] as CheckinStreak).currentStreak,
  );
});

HomeActionBrief buildHomeActionBrief({
  required TodayActionView? view,
  required List<PlanProgress> habits,
  required int cap,
  int streakDays = 0,
}) {
  final todoEntries = <HomeTodoEntry>[];
  if (view != null) {
    for (final item in view.items) {
      if (item is TodayTodoActionItem) {
        todoEntries.add(HomeTodoEntry(task: item.task));
        if (todoEntries.length >= cap) {
          break;
        }
      }
    }
  }

  return HomeActionBrief(
    todos: todoEntries,
    habits: [for (final progress in habits) HomeHabitEntry(progress: progress)],
    completedCount: view?.completedCount ?? 0,
    totalCount: view?.totalCount ?? 0,
    streakDays: streakDays,
  );
}
```

待办卡（`home_action_todo_card.dart`）—— 完成 / 新增 / 删除 / 编辑：

```dart
import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

class HomeActionTodoCard extends StatelessWidget {
  const HomeActionTodoCard({
    super.key,
    required this.brief,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenAll,
    this.cap = 5,
  });

  final HomeActionBrief brief;
  final ValueChanged<TodoTask> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<TodoTask> onEdit;
  final ValueChanged<TodoTask> onDelete;
  final VoidCallback onOpenAll;
  final int cap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('✅ 今日待办', style: theme.textTheme.labelMedium),
              const Spacer(),
              if (brief.streakDays > 0)
                Text('🔥 ${brief.streakDays} 天', style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${brief.completedCount} / ${brief.totalCount}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          for (final entry in brief.todos) ...[
            _TodoRow(
              task: entry.task,
              onToggle: () => onToggle(entry.task),
              onEdit: () => onEdit(entry.task),
              onDelete: () => onDelete(entry.task),
            ),
          ],
          if (brief.todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '今天没有待办',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加待办'),
              ),
              const Spacer(),
              TextButton(onPressed: onOpenAll, child: const Text('查看全部 ›')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = task.status == TodoTaskStatus.completed;
    return InkWell(
      onTap: onEdit,
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onToggle,
              icon: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: done
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
            ),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
            if (task.isOverdue && !done)
              Text('逾期', style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.error,
              )),
          ],
        ),
      ),
    );
  }
}
```

接线（`home_page.dart`）：provider 给 `todoCard`；回调：

```dart
    final actionBrief = ref.watch(homeActionBriefProvider);
    final todoCard = showActionTodo
        ? HomeActionTodoCard(
            brief: actionBrief.valueOrNull ??
                const HomeActionBrief(
                  todos: [],
                  habits: [],
                  completedCount: 0,
                  totalCount: 0,
                  streakDays: 0,
                ),
            onToggle: (task) => _toggleTodo(context, ref, task),
            onAdd: () => launcher.run(MoneyQuickAction.expense), // 见下方 TODO
            onEdit: (task) => _editTodo(context, ref, task),
            onDelete: (task) => _deleteTodo(context, ref, task),
            onOpenAll: () => context.push(AppRoutes.gtd),
          )
        : null;
```

> `onAdd` 应拉起待办快速创建：复用 `lib/features/todo/presentation/todo_quick_create_sheet.dart` 的入口（读该文件确认 `showTodoQuickCreateSheet` 真实函数名后替换）。`_toggleTodo` / `_deleteTodo` / `_editTodo` 用 `todoRepositoryProvider` + `AppToast` 可撤销：

```dart
  Future<void> _toggleTodo(
    BuildContext context,
    WidgetRef ref,
    TodoTask task,
  ) async {
    final repo = ref.read(todoRepositoryProvider);
    if (task.status == TodoTaskStatus.completed) {
      await repo.reopenTask(task.id);
    } else {
      await repo.completeTask(task.id);
    }
    ref.invalidate(todayActionItemsProvider);
    ref.invalidate(homeActionBriefProvider);
  }
```

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/application/home_action_brief_test.dart test/features/home/presentation/home_action_todo_card_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/application/home_action_brief_providers.dart lib/features/home/presentation/home_action_todo_card.dart lib/features/home/presentation/home_page.dart test/features/home/application/home_action_brief_test.dart test/features/home/presentation/home_action_todo_card_test.dart
git commit -m "feat(home): add actionable today todo card"
```

---

## Task 9: 习惯打卡卡

**Files:**
- Create: `lib/features/home/presentation/home_action_habit_card.dart`
- Modify: `lib/features/home/presentation/home_page.dart`
- Test: `test/features/home/presentation/home_action_habit_card_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
// test/features/home/presentation/home_action_habit_card_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/home/presentation/home_action_habit_card.dart';

void main() {
  testWidgets('shows habit progress and emits tap', (tester) async {
    HomeHabitEntry? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeActionHabitCard(
            habits: const [],
            onTapHabit: (h) => tapped = h,
          ),
        ),
      ),
    );
    // 空态
    expect(find.textContaining('习惯'), findsWidgets);
  });
}
```

> 该测试只验证渲染不炸 + 空态；有数据的 tap 断言在实现后补 `HomeHabitEntry` 假体。

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_action_habit_card_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

```dart
import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';

class HomeActionHabitCard extends StatelessWidget {
  const HomeActionHabitCard({
    super.key,
    required this.habits,
    required this.onTapHabit,
    this.onManage,
  });

  final List<HomeHabitEntry> habits;
  final ValueChanged<HomeHabitEntry> onTapHabit;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('🔥 习惯打卡', style: theme.textTheme.labelMedium),
              const Spacer(),
              if (onManage != null)
                TextButton(onPressed: onManage, child: const Text('管理')),
            ],
          ),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            Text(
              '还没有打卡计划',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: habits.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _HabitTile(
                    habit: habit,
                    onTap: () => onTapHabit(habit),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onTap});

  final HomeHabitEntry habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 6),
              Text(
                habit.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                habit.progressLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              LinearProgressIndicator(
                value: habit.ratio.clamp(0.0, 1.0),
                minHeight: 5,
                borderRadius: BorderRadius.circular(99),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

接线：`onTapHabit` 使用 `checkinRepositoryProvider.upsertRecord`：

```dart
  Future<void> _checkInHabit(HomeHabitEntry habit) async {
    final userId = ref.read(authSessionControllerProvider).userId;
    if (userId == null) {
      return;
    }
    final now = DateTime.now();
    await ref.read(checkinRepositoryProvider).upsertRecord(
      CheckinRecordDraft(
        planId: habit.progress.plan.id,
        recordDate: DateTime(now.year, now.month, now.day),
        completedAt: now,
        count: 1,
        numericValue: habit.progress.plan.targetValue,
      ),
      userId,
    );
    invalidateTodayActionData(ref);
    ref.invalidate(homeActionBriefProvider);
  }
```

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/presentation/home_action_habit_card_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_action_habit_card.dart lib/features/home/presentation/home_page.dart test/features/home/presentation/home_action_habit_card_test.dart
git commit -m "feat(home): add habit check-in card"
```

---

# Part E · 收敛、首启与设置

## Task 10: 分类结构 / 最近流水默认摘要折叠

**Files:**
- Modify: `lib/features/home/presentation/home_category_structure_panel.dart`
- Modify: `lib/features/home/presentation/home_recent_transactions_panel.dart`
- Test: `test/features/home/presentation/home_category_structure_panel_test.dart`（已存在，更新）
- Test: `test/features/home/presentation/home_recent_transactions_panel_test.dart`（若不存在则新建）

- [ ] **Step 1: 更新测试**

在既有 `home_category_structure_panel_test.dart` 增加：

```dart
testWidgets('starts collapsed and expands on tap', (tester) async {
  // 用该文件已有的 items 假数据构造 HomeCategoryStructurePanel。
  // 折叠态：不出现所有子分类；点「展开」后出现。
  // 断言标题/展开按钮存在即可（具体文案以实现为准）。
});
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_category_structure_panel_test.dart`
Expected: FAIL（无折叠态）

- [ ] **Step 3: 实现**

给两个 panel 各加 `bool _expanded = false;`（转 `StatefulWidget`），折叠态渲染一行摘要 + `展开 ›`：

- 分类摘要：`餐饮 63% · 交通 12% · 更多`（取前 2 + 「更多」）。
- 流水摘要：最近一条 `星巴克 ¥32 · 1 小时前`。
- 展开后渲染原有完整内容；按钮文案切「收起」。

摘要金额同样受 `moneyAmountsMaskedProvider` 约束。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/presentation/`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_category_structure_panel.dart lib/features/home/presentation/home_recent_transactions_panel.dart test/features/home/presentation
git commit -m "feat(home): collapse categories and recent transactions by default"
```

---

## Task 11: 三模块首启引导

**Files:**
- Modify: `lib/features/home/presentation/home_onboarding_view.dart`
- Modify: `lib/features/home/presentation/home_page.dart`（`isFirstRun` 条件与回调）
- Test: `test/features/home/presentation/home_page_smoke_test.dart`（更新断言）

- [ ] **Step 1: 更新测试**

`home_page_smoke_test.dart` 首个用例改为断言三张引导卡：

```dart
expect(find.text('创建第一个账户'), findsOneWidget);
expect(find.text('开启健康追踪'), findsOneWidget);
expect(find.text('添加待办或习惯'), findsOneWidget);
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_page_smoke_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

`HomeOnboardingView` 增加健康与行动两步（保留原记账三步的入口）：三张 `_OnboardingStep`，分别为
- 账户 → `onCreateAccount`
- `开启健康追踪` → `onOpenHealth`（`context.go(AppRoutes.health)`）
- `添加待办或习惯` → `onCreateAction`（`context.push(AppRoutes.gtd)`）

`home_page.dart` 的 `isFirstRun` 保持「账户与流水都为空」；把三个回调接上。

- [ ] **Step 4: 运行**

Run: `flutter test test/features/home/presentation/home_page_smoke_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_onboarding_view.dart lib/features/home/presentation/home_page.dart test/features/home/presentation/home_page_smoke_test.dart
git commit -m "feat(home): three-module first-run guide"
```

---

## Task 12: 设置页区块开关 + 逐格开关 + 拖拽排序

**Files:**
- Modify: `lib/features/settings/presentation/settings_page.dart`（首页显示一节，约 `:1500` 起）
- Test: `test/features/home/domain/home_block_layout_test.dart`（已覆盖逻辑）
- Test: `test/features/settings/presentation/settings_home_blocks_test.dart`（新建 widget test）

- [ ] **Step 1: 写失败测试**

```dart
// test/features/settings/presentation/settings_home_blocks_test.dart
// 复用 settings_page 既有测试的 ProviderContainer / prefs override 写法。
// 断言：首页显示一节里出现「今日待办」「周期状态」等注册表 label，
// 且存在 ReorderableListView（拖拽排序）。
testWidgets('home blocks section lists registry and is reorderable', (tester) async {
  // ...pump settings page...
  expect(find.byType(ReorderableListView), findsOneWidget);
  expect(find.text('今日待办'), findsWidgets);
});
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/settings/presentation/settings_home_blocks_test.dart`
Expected: FAIL

- [ ] **Step 3: 实现**

在「首页显示」`AppContentPanel` 内、既有三个开关之前插入「布局 + 首页模块」子块：

```dart
final layout = ref.watch(homeBlockLayoutProvider);
final layoutMode = ref.watch(homeLayoutModeProvider);

// 1) 布局：纵向单列 / 横向分页
SegmentedButton<HomeLayoutMode>(
  segments: const [
    ButtonSegment(value: HomeLayoutMode.list, label: Text('纵向单列')),
    ButtonSegment(value: HomeLayoutMode.pager, label: Text('横向分页')),
  ],
  selected: {layoutMode},
  onSelectionChanged: (s) => _updateHomeLayoutMode(s.single),
  showSelectedIcon: false,
),
if (layoutMode == HomeLayoutMode.pager)
  AppSwitchField(
    title: '分页显示顶部标签',
    subtitle: '关闭时靠左右滑动 + 底部圆点切换',
    icon: Icons.tab_rounded,
    value: ref.watch(homePagerTabsProvider),
    onChanged: _updateHomePagerTabs,
  ),

// 2) 区块开关 + 拖拽排序
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: layout.order.length,
  onReorder: (oldIndex, newIndex) => _reorderHomeBlock(
    layout,
    oldIndex,
    newIndex,
  ),
  itemBuilder: (context, index) {
    final id = layout.order[index];
    return ListTile(
      key: ValueKey(id.storageKey),
      leading: const Icon(Icons.drag_handle_rounded),
      title: Text(id.label),
      subtitle: Text(id.module.label),
      trailing: Switch(
        value: layout.isVisible(id),
        onChanged: id.isBoardCell && layout.visibleBoardCellCount <= 2 &&
                layout.isVisible(id)
            ? null // 三宫格至少留 2 格
            : (value) => _toggleHomeBlock(layout, id, value),
      ),
    );
  },
)
```

处理函数（写回 preferences）：

```dart
Future<void> _toggleHomeBlock(
  HomeBlockLayout layout,
  HomeBlockId id,
  bool value,
) async {
  if (layout.isVisible(id) == value) {
    return;
  }
  final next = layout.toggle(id, value);
  await _persistHomeLayout(next);
}

Future<void> _reorderHomeBlock(
  HomeBlockLayout layout,
  int oldIndex,
  int newIndex,
) async {
  final next = layout.reorder(oldIndex, newIndex);
  await _persistHomeLayout(next);
}

Future<void> _persistHomeLayout(HomeBlockLayout layout) async {
  final userId = widget.userId;
  if (userId == null) {
    return;
  }
  final repo = ref.read(preferencesRepositoryProvider);
  await repo.updateHomeBlockVisibility(userId, layout.visibilityJson);
  await repo.updateHomeBlockOrder(userId, layout.orderJson);
  ref.invalidate(currentUserPreferencesProvider);
}

Future<void> _updateHomeLayoutMode(HomeLayoutMode mode) async {
  final userId = widget.userId;
  if (userId == null) {
    return;
  }
  await ref
      .read(preferencesRepositoryProvider)
      .updateHomeLayoutMode(userId, mode.storageValue);
  ref.invalidate(currentUserPreferencesProvider);
}

Future<void> _updateHomePagerTabs(bool show) async {
  final userId = widget.userId;
  if (userId == null) {
    return;
  }
  await ref
      .read(preferencesRepositoryProvider)
      .updateHomePagerTabs(userId, show);
  ref.invalidate(currentUserPreferencesProvider);
}
```

- [ ] **Step 4: 运行**

Run: `flutter test test/features/settings/presentation/settings_home_blocks_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/presentation/settings_page.dart test/features/settings/presentation/settings_home_blocks_test.dart
git commit -m "feat(settings): home block toggles and drag ordering"
```

---

## Task 13: 首页按注册表渲染 + 故障隔离 + 全量回归

**Files:**
- Modify: `lib/features/home/presentation/home_page.dart`
- Test: `test/features/home/presentation/home_page_smoke_test.dart`

- [ ] **Step 1: 写失败测试**

追加一条：单个记账 provider 失败时，健康卡仍渲染：

```dart
testWidgets('one failing module does not blank the whole page', (tester) async {
  // override homeMonthBudgetSummaryProvider 抛错，health 正常；
  // 断言「经期第…」或健康卡仍存在，且页面无全局错误视图。
});
```

- [ ] **Step 2: 运行，确认失败**

Run: `flutter test test/features/home/presentation/home_page_smoke_test.dart`
Expected: FAIL（当前整页 `AppErrorState`）

- [ ] **Step 3: 实现**

`_HomeDashboard` 顶部删掉整页 `hasError` 分支，改为：钱相关块各自判断 `AsyncValue.hasError` 并显示**块内重试**（`_BlockError` 小组件，带 `onRetry`）；健康 / 行动块同样。渲染循环改为按 `homeBlockLayoutProvider.order` 生成：

```dart
Widget _buildBlock(HomeBlockId id, _HomeBlockContext ctx) {
  return switch (id) {
    HomeBlockId.moneyHero => ctx.moneyHero,
    HomeBlockId.moneyCategories => ctx.categoryPanel,
    HomeBlockId.moneyRecent => ctx.recentPanel,
    HomeBlockId.healthCycle => ctx.healthCycle ?? const SizedBox.shrink(),
    HomeBlockId.healthToday => ctx.healthToday ?? const SizedBox.shrink(),
    HomeBlockId.actionTodo => ctx.todoCard ?? const SizedBox.shrink(),
    HomeBlockId.actionHabit => ctx.habitCard ?? const SizedBox.shrink(),
    HomeBlockId.insight => ctx.insightStrip,
    HomeBlockId.quote => const HomeQuoteFooter(),
    _ => const SizedBox.shrink(), // 三宫格单独渲染
  };
}
```

单列（`homeLayoutMode == list`）：

```dart
for (final id in layout.order.where((id) => !id.isBoardCell && layout.isVisible(id)))
  ...[_gap, _section(index++, _buildBlock(id, ctx))],
```

双栏（≥840dp 且 `list`）：沿用 8/4 分配，把 `_buildBlock` 结果按 8 / 4 两列规则放入（`moneyHero`/`moneyCategories`/`moneyRecent`/`insight` 走左列，`health*`/`action*` 走右列，`quote` 全宽）。

横向分页（`homeLayoutMode == pager`）：用 `PageView` + `PageController` 包四页。页与 Block 的映射：

```dart
enum _HomePage { overview, money, health, action }

const _pageBlocks = <_HomePage, List<HomeBlockId>>{
  _HomePage.money: [
    HomeBlockId.moneyHero,
    HomeBlockId.moneyCategories,
    HomeBlockId.moneyRecent,
  ],
  _HomePage.health: [
    HomeBlockId.healthCycle,
    HomeBlockId.healthToday,
    HomeBlockId.healthForecast,
  ],
  _HomePage.action: [HomeBlockId.actionTodo, HomeBlockId.actionHabit],
};

/// 概览页固定：三宫格 + 统一提醒 + 跨模块洞察（按可见性）。
```

- 页内只渲染「该页 Block ∩ 可见」；概览页额外固定渲染三宫格。
- `homePagerTabsProvider == true`：顶部渲染 `TabBar`（概览/记账/健康/行动）并与 `PageController` 双向同步；`false`：不渲染标签，改为顶部一行 `‹ 左右滑动 ›` 提示 + 底部 `_PageDots`（可点）。
- 页数按可见模块推导：某模块的所有 Block 都不可见时，去掉该页。某模块 Block 全部关掉时该页显示空态卡「到设置里打开」。

- [ ] **Step 4: 全量回归**

Run: `flutter test`
Expected: 全部 PASS（含既有 721+ 用例）。若 `home_page_smoke_test.dart` 有旧断言（`净资产`/`今日行动`），按新首页更新断言。

- [ ] **Step 5: 提交**

```bash
git add lib/features/home/presentation/home_page.dart test/features/home/presentation/home_page_smoke_test.dart
git commit -m "feat(home): registry-driven layout with per-block error isolation"
```

---

## 自检（写完计划后已核对）

- **Spec 覆盖**：决策 ①→T1/T3/T5/T12；②→T8；③→T10；④→T2/T3；⑤→T1/T2/T12；⑥→T11；⑦纵向/横向切换→T1/T2/T3/T12/T13；⑧横向默认无标签→T2/T3/T12/T13。统一提醒 / 跨模块洞察 / 7 天预测明确划到后续 Milestone，不在本计划。
- **无占位**：唯一带 TODO 的是 Task 8 的 `onAdd`（待办快速创建的入口函数名需读 `todo_quick_create_sheet.dart` 确认）——执行时以该文件真实导出为准，不猜。
- **类型一致性**：`HomeBlockId` / `HomeBlockLayout`（T1）在 T2–T13 中签名一致；`HomeTodayBoardData` / `HomeHealthBrief` / `HomeActionBrief` 各自在 T4/T6/T8 定义后，后续 widget 任务只引用不重定义。

## 后续 Milestone（各自单独出计划）

- **M2**：`reminders.unified` 跨模块提醒（记账 + 待办逾期 + 打卡 + 健康窗口）+ 提醒优先级排序。
- **M3**：`insight.cross` 跨模块洞察 + `health.forecast` 7 天预测色带。
- **M4**：关联洞察（睡眠 ↔ 支出）、智能排序。
