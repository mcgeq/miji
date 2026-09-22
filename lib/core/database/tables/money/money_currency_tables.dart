import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

class MoneyCurrencies extends Table {
  TextColumn get code => text()();

  TextColumn get locale => text()();

  TextColumn get symbol => text()();

  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_currencies';

  @override
  Set<Column<Object>> get primaryKey => {code};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_categories_system_name_active_unique '
  'ON money_categories(kind, name) '
  'WHERE is_deleted = 0 AND user_id IS NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX money_categories_user_name_active_unique '
  'ON money_categories(user_id, kind, name) '
  'WHERE is_deleted = 0 AND user_id IS NOT NULL',
)
class MoneyCategories extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().nullable().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get kind => text()();

  TextColumn get color => text().nullable()();

  TextColumn get icon => text().nullable()();

  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// 业务顺序（餐饮 / 交通 / 购物 …）。
  ///
  /// 内置分类按种子声明顺序写入；用户自建分类追加到末尾（max + 1）。
  /// 0 表示「未设置」（旧数据、同步下来缺字段的记录），排序时视为最后，
  /// 避免它插到内置分类前面。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_categories';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_sub_categories_system_name_active_unique '
  'ON money_sub_categories(category_id, name) '
  'WHERE is_deleted = 0 AND user_id IS NULL',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX money_sub_categories_user_name_active_unique '
  'ON money_sub_categories(user_id, category_id, name) '
  'WHERE is_deleted = 0 AND user_id IS NOT NULL',
)
class MoneySubCategories extends Table {
  TextColumn get id => text()();

  TextColumn get categoryId => text().references(MoneyCategories, #id)();

  TextColumn get userId => text().nullable().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get kind => text()();

  TextColumn get color => text().nullable()();

  TextColumn get icon => text().nullable()();

  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// 业务顺序，同 [MoneyCategories.sortOrder]；0 视为未设置（排最后）。
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_sub_categories';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
