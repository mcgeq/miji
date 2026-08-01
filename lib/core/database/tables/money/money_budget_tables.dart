import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_ledger_tables.dart';

class MoneyBudgets extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get accountId =>
      text().nullable().references(MoneyAccounts, #id)();

  TextColumn get ledgerId => text().nullable()();

  TextColumn get createdByMemberId => text().nullable()();

  TextColumn get name => text()();

  TextColumn get description => text().nullable()();

  IntColumn get amountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  TextColumn get repeatPeriodType => text()();

  IntColumn get repeatInterval => integer()();

  TextColumn get repeatDays => text().nullable()();

  IntColumn get startDate => integer()();

  IntColumn get endDate => integer()();

  IntColumn get usedAmountMinor => integer().withDefault(const Constant(0))();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  BoolColumn get alertEnabled => boolean().withDefault(const Constant(false))();

  IntColumn get alertThresholdPercent => integer().nullable()();

  TextColumn get color => text().nullable()();

  IntColumn get currentPeriodUsedMinor =>
      integer().withDefault(const Constant(0))();

  IntColumn get currentPeriodStartDate => integer()();

  DateTimeColumn get lastResetAt => dateTime()();

  TextColumn get budgetType => text()();

  TextColumn get trackingType =>
      text().withDefault(const Constant('expense_limit'))();

  IntColumn get progressMinor => integer().withDefault(const Constant(0))();

  TextColumn get linkedGoal => text().nullable()();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  BoolColumn get autoRollover => boolean().withDefault(const Constant(false))();

  TextColumn get scopeType => text()();

  TextColumn get accountScopeJson => text().nullable()();

  TextColumn get categoryScopeJson => text().nullable()();

  TextColumn get advancedRulesJson => text().nullable()();

  TextColumn get tagsJson => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_budgets';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyBudgetAllocations extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get budgetId => text().references(MoneyBudgets, #id)();

  TextColumn get categoryId =>
      text().nullable().references(MoneyCategories, #id)();

  TextColumn get memberId => text().nullable()();

  IntColumn get allocatedAmountMinor => integer()();

  IntColumn get usedAmountMinor => integer().withDefault(const Constant(0))();

  IntColumn get remainingAmountMinor => integer()();

  IntColumn get percentageBasisPoints => integer().nullable()();

  TextColumn get allocationType => text()();

  TextColumn get ruleConfigJson => text().nullable()();

  BoolColumn get allowOverspend =>
      boolean().withDefault(const Constant(false))();

  TextColumn get overspendLimitType => text().nullable()();

  IntColumn get overspendLimitMinor => integer().nullable()();

  BoolColumn get alertEnabled => boolean().withDefault(const Constant(false))();

  IntColumn get alertThresholdPercent => integer()();

  TextColumn get alertConfigJson => text().nullable()();

  IntColumn get priority => integer().withDefault(const Constant(0))();

  BoolColumn get isMandatory => boolean().withDefault(const Constant(false))();

  TextColumn get status => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_budget_allocations';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_budget_snapshots_period_unique '
  'ON money_budget_snapshots('
  'budget_id, period_start_date, period_end_date, source_budget_version)',
)
class MoneyBudgetSnapshots extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get budgetId => text().references(MoneyBudgets, #id)();

  TextColumn get ledgerId => text().nullable().references(MoneyLedgers, #id)();

  TextColumn get trackingType => text()();

  TextColumn get periodType => text()();

  IntColumn get repeatInterval => integer()();

  IntColumn get periodStartDate => integer()();

  IntColumn get periodEndDate => integer()();

  IntColumn get budgetAmountMinor => integer()();

  IntColumn get usedAmountMinor => integer()();

  IntColumn get remainingAmountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  TextColumn get status => text()();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get sourceBudgetVersion => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_budget_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_budget_allocation_snapshots_unique '
  'ON money_budget_allocation_snapshots('
  'budget_snapshot_id, allocation_id, source_allocation_version)',
)
class MoneyBudgetAllocationSnapshots extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get budgetSnapshotId =>
      text().references(MoneyBudgetSnapshots, #id)();

  TextColumn get budgetId => text().references(MoneyBudgets, #id)();

  TextColumn get allocationId =>
      text().references(MoneyBudgetAllocations, #id)();

  TextColumn get categoryId =>
      text().nullable().references(MoneyCategories, #id)();

  TextColumn get memberId => text().nullable()();

  IntColumn get allocatedAmountMinor => integer()();

  IntColumn get usedAmountMinor => integer()();

  IntColumn get remainingAmountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  TextColumn get status => text()();

  DateTimeColumn get capturedAt => dateTime()();

  IntColumn get sourceAllocationVersion => integer()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_budget_allocation_snapshots';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
