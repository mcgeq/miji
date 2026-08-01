import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_ledger_tables.dart';
import 'package:miji/core/database/tables/money/money_transaction_tables.dart';

class MoneyInstallmentPlans extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  TextColumn get transactionId =>
      text().nullable().references(MoneyTransactions, #id)();

  TextColumn get ledgerId => text().nullable().references(MoneyLedgers, #id)();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  TextColumn get categoryId => text().references(MoneyCategories, #id)();

  TextColumn get subCategoryId =>
      text().nullable().references(MoneySubCategories, #id)();

  IntColumn get totalAmountMinor => integer()();

  IntColumn get totalPeriods => integer()();

  IntColumn get remainingPeriods => integer()();

  IntColumn get periodAmountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  IntColumn get startDate => integer()();

  IntColumn get endDate => integer()();

  IntColumn get firstDueDate => integer()();

  TextColumn get status => text()();

  IntColumn get interestRateBasisPoints => integer().nullable()();

  IntColumn get totalInterestMinor => integer().nullable()();

  TextColumn get calcMethod => text().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_installment_plans';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_installment_details_plan_period_unique '
  'ON money_installment_details(plan_id, period_number)',
)
class MoneyInstallmentDetails extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get planId => text().references(MoneyInstallmentPlans, #id)();

  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  IntColumn get periodNumber => integer()();

  IntColumn get amountMinor => integer()();

  IntColumn get principalMinor => integer()();

  IntColumn get interestMinor => integer()();

  IntColumn get dueDate => integer()();

  IntColumn get paidDate => integer().nullable()();

  TextColumn get status => text()();

  TextColumn get transactionId =>
      text().nullable().references(MoneyTransactions, #id)();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_installment_details';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
