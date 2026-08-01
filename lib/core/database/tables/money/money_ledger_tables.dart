import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_transaction_tables.dart';

class MoneyLedgers extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get createdByMemberId => text()();

  TextColumn get ledgerType => text()();

  TextColumn get status => text()();

  TextColumn get baseCurrencyCode =>
      text().references(MoneyCurrencies, #code)();

  TextColumn get settlementCycle => text()();

  IntColumn get settlementDay => integer()();

  TextColumn get icon => text().nullable()();

  TextColumn get color => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_ledgers';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyMembers extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get role => text()();

  TextColumn get status => text()();

  TextColumn get avatarUri => text().nullable()();

  TextColumn get color => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_members';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyLedgerAccounts extends Table {
  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'money_ledger_accounts';

  @override
  Set<Column<Object>> get primaryKey => {ledgerId, accountId};
}

class MoneyLedgerTransactions extends Table {
  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  TextColumn get transactionId => text().references(MoneyTransactions, #id)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'money_ledger_transactions';

  @override
  Set<Column<Object>> get primaryKey => {ledgerId, transactionId};
}

class MoneyLedgerMembers extends Table {
  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  TextColumn get memberId => text().references(MoneyMembers, #id)();

  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'money_ledger_members';

  @override
  Set<Column<Object>> get primaryKey => {ledgerId, memberId};
}
