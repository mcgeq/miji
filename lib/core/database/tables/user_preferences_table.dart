import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

class UserPreferences extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get themeMode => text().withDefault(const Constant('system'))();

  IntColumn get themeSeedColor => integer()();

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
  BoolColumn get showHomeHealthStrip =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
