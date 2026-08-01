import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/health/health_period_tables.dart';

class HealthPeriodPmsRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get periodRecordId =>
      text().references(HealthPeriodRecords, #id)();

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
  String get tableName => 'health_period_pms_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_period_pms_symptoms_record_symptom_unique '
  'ON health_period_pms_symptoms(pms_record_id, symptom_type) '
  'WHERE is_deleted = 0',
)
class HealthPeriodPmsSymptoms extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get pmsRecordId =>
      text().references(HealthPeriodPmsRecords, #id)();

  TextColumn get symptomType => text()();

  TextColumn get intensity => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_period_pms_symptoms';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_ovulation_test_records_user_date_unique '
  'ON health_ovulation_test_records(user_id, test_date) '
  'WHERE is_deleted = 0',
)
class HealthOvulationTestRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  IntColumn get testDate => integer()();

  TextColumn get result => text()();

  TextColumn get testLineIntensity => text().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_ovulation_test_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX health_pregnancy_records_user_active_unique '
  'ON health_pregnancy_records(user_id) '
  "WHERE status = 'active' AND is_deleted = 0",
)
class HealthPregnancyRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  IntColumn get startDate => integer()();

  IntColumn get dueDate => integer().nullable()();

  IntColumn get endDate => integer().nullable()();

  TextColumn get status => text()();

  TextColumn get deliveryType => text().nullable()();

  TextColumn get babyGender => text().nullable()();

  IntColumn get babyWeightGrams => integer().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'health_pregnancy_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class HealthMedicationRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get periodRecordId =>
      text().nullable().references(HealthPeriodRecords, #id)();

  TextColumn get name => text()();

  TextColumn get dosage => text().nullable()();

  TextColumn get frequency => text()();

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
  String get tableName => 'health_medication_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
