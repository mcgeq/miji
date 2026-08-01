import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';

class MoneyAccounts extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get type => text()();

  IntColumn get balanceMinor => integer()();

  IntColumn get initialBalanceMinor => integer()();

  IntColumn get creditLimitMinor => integer().nullable()();

  IntColumn get postedDebtMinor => integer().nullable()();

  IntColumn get frozenCreditMinor => integer().nullable()();

  IntColumn get statementDay => integer().nullable()();

  IntColumn get budgetCycleStartDay => integer().nullable()();

  IntColumn get repaymentDay => integer().nullable()();

  BoolColumn get autoRepaymentReminderEnabled =>
      boolean().withDefault(const Constant(true))();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  BoolColumn get isVirtual => boolean().withDefault(const Constant(false))();

  TextColumn get ownerMemberId => text().nullable()();

  TextColumn get color => text().nullable()();

  TextColumn get icon => text().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_accounts';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
