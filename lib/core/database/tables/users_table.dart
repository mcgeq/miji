import 'package:drift/drift.dart';

@TableIndex.sql(
  'CREATE UNIQUE INDEX users_username_active_unique '
  'ON users(username) WHERE is_deleted = 0',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX users_email_active_unique '
  'ON users(email) WHERE is_deleted = 0',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX users_phone_active_unique '
  'ON users(phone_number) WHERE is_deleted = 0 AND phone_number IS NOT NULL',
)
class Users extends Table {
  TextColumn get id => text()();

  TextColumn get username => text()();

  TextColumn get email => text()();

  DateTimeColumn get emailVerifiedAt => dateTime().nullable()();

  TextColumn get phoneNumber => text().nullable()();

  DateTimeColumn get phoneVerifiedAt => dateTime().nullable()();

  TextColumn get displayName => text()();

  TextColumn get avatarUri => text().nullable()();

  TextColumn get remoteUserId => text().nullable()();

  BoolColumn get syncEnabled => boolean().withDefault(const Constant(false))();

  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
