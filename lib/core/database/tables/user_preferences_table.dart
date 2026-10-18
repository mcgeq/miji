import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

class UserPreferences extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  TextColumn get locale => text().nullable()();

  TextColumn get timezone => text().nullable()();

  TextColumn get currencyCode => text().nullable()();

  TextColumn get sensitiveAccessTtl =>
      text().withDefault(const Constant('10m'))();

  BoolColumn get showHomeTodayAction =>
      boolean().withDefault(const Constant(true))();

  /// 首页金额隐私：开启后所有金额以模糊 / 占位方式展示。
  BoolColumn get maskMoneyAmounts =>
      boolean().withDefault(const Constant(false))();

  /// 首页是否显示健康窄条（经期 / 孕期提示）。
  ///
  /// v2 起健康显示改由区块注册表控制（`HomeBlockId.healthCycle`），
  /// 这一列保留仅为向后兼容，不再写入。
  BoolColumn get showHomeHealthStrip =>
      boolean().withDefault(const Constant(false))();

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

  /// 时薪面板的界面偏好，JSON：`{"tab": "wishlist", "sort": "cost",
  /// "payrollYear": 2025}`。
  ///
  /// 为什么一个 JSON 而不是三列：这三项都是「上次停在哪」，读取时永远一起读、
  /// 写入时也不会单独改其中一项。每加一列就要一次迁移，而它们不值这个价
  /// （首页那几列是历史包袱，不必照抄）。
  TextColumn get lifeEnergyPrefs => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
