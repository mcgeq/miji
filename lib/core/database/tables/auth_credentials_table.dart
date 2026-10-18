import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

class AuthCredentials extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get credentialType => text()();

  TextColumn get algorithm => text()();

  IntColumn get iterations => integer()();

  TextColumn get salt => text()();

  TextColumn get verifier => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
