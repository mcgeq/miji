import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';

class MoneyCategoryUsageStats extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get categoryId => text().references(MoneyCategories, #id)();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_category_usage_stats';

  @override
  Set<Column<Object>> get primaryKey => {userId, categoryId};
}

class MoneySubCategoryUsageStats extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get subCategoryId => text().references(MoneySubCategories, #id)();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_sub_category_usage_stats';

  @override
  Set<Column<Object>> get primaryKey => {userId, subCategoryId};
}

class MoneyAccountUsageStats extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_account_usage_stats';

  @override
  Set<Column<Object>> get primaryKey => {userId, accountId};
}

class MoneyPaymentMethodUsageStats extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get paymentMethod => text()();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_payment_method_usage_stats';

  @override
  Set<Column<Object>> get primaryKey => {userId, paymentMethod};
}

class MoneyAccountPaymentMethodUsageStats extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  TextColumn get paymentMethod => text()();

  IntColumn get useCount => integer().withDefault(const Constant(0))();

  IntColumn get totalAmountMinor => integer().withDefault(const Constant(0))();

  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_account_payment_method_usage_stats';

  @override
  Set<Column<Object>> get primaryKey => {userId, accountId, paymentMethod};
}
