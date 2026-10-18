import 'package:drift/drift.dart';

class DeltaConflicts extends Table {
  TextColumn get id => text()();

  TextColumn get datasetId => text()();

  TextColumn get userId => text()();

  TextColumn get targetTable => text().named('table_name')();

  TextColumn get recordId => text()();

  TextColumn get fieldGroupsJson => text()();

  TextColumn get localSnapshotJson => text()();

  TextColumn get remoteChangeJson => text()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  DateTimeColumn get resolvedAt => dateTime().nullable()();

  TextColumn get resolution => text().nullable()();

  TextColumn get resolvedByDeviceId => text().nullable()();

  @override
  String get tableName => 'delta_conflicts';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
