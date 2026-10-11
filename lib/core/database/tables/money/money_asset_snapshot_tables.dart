import 'package:drift/drift.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/users_table.dart';

class MoneyAssetSnapshots extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().references(Users, #id)();
  TextColumn get accountId => text().references(MoneyAccounts, #id)();
  IntColumn get balanceMinor => integer()();
  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();
  IntColumn get capturedDate => integer()();
  TextColumn get deviceId => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_asset_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
