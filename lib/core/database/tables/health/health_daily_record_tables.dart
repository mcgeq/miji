import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/health/health_period_tables.dart';

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_daily_records_user_date_unique '
  'ON health_period_daily_records(user_id, record_date) '
  'WHERE is_deleted = 0',
)
class HealthPeriodDailyRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get periodRecordId =>
      text().nullable().references(HealthPeriodRecords, #id)();

  IntColumn get recordDate => integer()();

  TextColumn get flowLevel => text().nullable()();

  TextColumn get exerciseIntensity => text().nullable()();

  BoolColumn get sexualActivity => boolean().nullable()();

  TextColumn get contraceptionMethod => text().nullable()();

  TextColumn get diet => text().nullable()();

  TextColumn get mood => text().nullable()();

  IntColumn get waterIntake => integer().nullable()();

  IntColumn get sleepMinutes => integer().nullable()();

  IntColumn get weightGrams => integer().nullable()();

  IntColumn get temperatureCelsiusTenths => integer().nullable()();

  IntColumn get stressLevel => integer().nullable()();

  IntColumn get calories => integer().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_period_daily_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_symptoms_daily_symptom_unique '
  'ON health_period_symptoms(daily_record_id, symptom_type) '
  'WHERE is_deleted = 0',
)
class HealthPeriodSymptoms extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get dailyRecordId =>
      text().references(HealthPeriodDailyRecords, #id)();

  TextColumn get symptomType => text()();

  TextColumn get intensity => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_period_symptoms';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
