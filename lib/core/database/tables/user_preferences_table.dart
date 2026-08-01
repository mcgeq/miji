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

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {userId};
}
