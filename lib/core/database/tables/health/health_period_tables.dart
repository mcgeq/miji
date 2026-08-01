import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_settings_user_unique '
  'ON health_period_settings(user_id) '
  'WHERE is_deleted = 0',
)
class HealthPeriodSettings extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  IntColumn get averageCycleLength => integer()();

  IntColumn get averagePeriodLength => integer()();

  BoolColumn get periodTrackingEnabled =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get periodReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get ovulationReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get pmsReminderEnabled =>
      boolean().withDefault(const Constant(false))();

  IntColumn get reminderDays => integer()();

  BoolColumn get dataSyncEnabled =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get analyticsEnabled =>
      boolean().withDefault(const Constant(false))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_period_settings';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_records_user_start_unique '
  'ON health_period_records(user_id, start_date) '
  'WHERE is_deleted = 0',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_records_user_open_unique '
  'ON health_period_records(user_id) '
  'WHERE end_date IS NULL AND is_deleted = 0',
)
class HealthPeriodRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  IntColumn get startDate => integer()();

  IntColumn get endDate => integer().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_period_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
