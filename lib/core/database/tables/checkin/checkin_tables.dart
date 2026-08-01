import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

// ---------------------------------------------------------------------------
// checkin_plans — 打卡计划模板
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE UNIQUE INDEX checkin_plans_user_name_unique '
  'ON checkin_plans(user_id, name) '
  'WHERE is_deleted = 0',
)
class CheckinPlans extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get icon => text().withDefault(const Constant('📌'))();

  TextColumn get color => text().withDefault(const Constant('#6366F1'))();

  TextColumn get category => text().withDefault(const Constant('其他'))();

  /// cyclic | event
  TextColumn get planType => text().withDefault(const Constant('cyclic'))();

  /// daily | weekly | monthly | cron | once
  TextColumn get frequencyType => text().withDefault(const Constant('daily'))();

  /// JSON: cron 表达式 或 {"days":[1,3,5]} 等
  TextColumn get frequencyConfig => text().nullable()();

  RealColumn get targetValue => real().withDefault(const Constant(1))();

  TextColumn get targetUnit => text().withDefault(const Constant('次'))();

  /// button | photo | timer | location
  TextColumn get triggerMode => text().withDefault(const Constant('button'))();

  /// merged | detailed
  TextColumn get recordGranularity =>
      text().withDefault(const Constant('merged'))();

  /// private | public
  TextColumn get defaultVisibility =>
      text().withDefault(const Constant('private'))();

  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// "08:00" 或 JSON 数组
  TextColumn get reminderTime => text().nullable()();

  IntColumn get reminderDaysBefore => integer().nullable()();

  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'checkin_plans';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// checkin_records — 打卡记录（每日合并 or 每次独立）
// ---------------------------------------------------------------------------

@TableIndex.sql(
  'CREATE UNIQUE INDEX checkin_records_user_plan_date_unique '
  'ON checkin_records(user_id, plan_id, record_date) '
  'WHERE is_deleted = 0',
)
class CheckinRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get planId => text().references(CheckinPlans, #id)();

  /// UTC date-only timestamp (millisecondsSinceEpoch)
  IntColumn get recordDate => integer()();

  DateTimeColumn get completedAt => dateTime()();

  IntColumn get count => integer().withDefault(const Constant(1))();

  RealColumn get numericValue => real().nullable()();

  IntColumn get durationSeconds => integer().nullable()();

  /// 1-5
  IntColumn get mood => integer().nullable()();

  TextColumn get notes => text().nullable()();

  /// private | public
  TextColumn get visibility => text().withDefault(const Constant('private'))();

  /// JSON: {"lat":..., "lng":..., "poi_name":"..."}
  TextColumn get locationJson => text().nullable()();

  /// JSON: 类型专属扩展数据
  TextColumn get extraJson => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'checkin_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// checkin_photos — 打卡照片
// ---------------------------------------------------------------------------

class CheckinPhotos extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get recordId => text().references(CheckinRecords, #id)();

  TextColumn get localPath => text()();

  DateTimeColumn get takenAt => dateTime().nullable()();

  /// JSON: {"lat":..., "lng":..., "altitude":...}
  TextColumn get gpsJson => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'checkin_photos';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
