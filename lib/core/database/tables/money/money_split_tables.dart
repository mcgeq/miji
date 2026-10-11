import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_ledger_tables.dart';
import 'package:miji/core/database/tables/money/money_transaction_tables.dart';

class MoneySplitRules extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  TextColumn get name => text()();

  TextColumn get ruleType => text()();

  TextColumn get ruleConfigJson => text()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_split_rules';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneySplitRecords extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  TextColumn get transactionId =>
      text().nullable().references(MoneyTransactions, #id)();

  TextColumn get splitRuleId =>
      text().nullable().references(MoneySplitRules, #id)();

  TextColumn get status => text()();

  TextColumn get splitType => text()();

  IntColumn get totalAmountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  @ReferenceName('payerSplitRecords')
  TextColumn get payerMemberId => text().references(MoneyMembers, #id)();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_split_records';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneySplitRecordDetails extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get splitRecordId => text().references(MoneySplitRecords, #id)();

  TextColumn get memberId => text().references(MoneyMembers, #id)();

  IntColumn get amountMinor => integer()();

  IntColumn get percentageBasisPoints => integer().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_split_record_details';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
