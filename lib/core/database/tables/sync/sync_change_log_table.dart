import 'package:drift/drift.dart';

class SyncMetadata extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'sync_metadata';

  @override
  Set<Column<Object>> get primaryKey => {key};
}

class SyncChangeLogs extends Table {
  TextColumn get id => text()();

  TextColumn get datasetId => text()();

  TextColumn get userId => text()();

  TextColumn get targetTable => text().named('table_name')();

  TextColumn get recordId => text()();

  TextColumn get operation => text()();

  TextColumn get changedFieldsJson => text()();

  IntColumn get beforeVersion => integer().nullable()();

  IntColumn get afterVersion => integer().nullable()();

  TextColumn get deviceId => text().nullable()();

  DateTimeColumn get changedAt => dateTime()();

  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  String get tableName => 'sync_change_logs';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
