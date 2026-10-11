import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_ledger_tables.dart';
import 'package:miji/core/database/tables/money/money_transaction_tables.dart';

@TableIndex.sql(
  'CREATE INDEX money_bill_reminders_user_due_date '
  'ON money_bill_reminders(user_id, due_date)',
)
@TableIndex.sql(
  'CREATE INDEX money_bill_reminders_user_account '
  'ON money_bill_reminders(user_id, account_id)',
)
@TableIndex.sql(
  'CREATE INDEX money_bill_reminders_user_ledger '
  'ON money_bill_reminders(user_id, ledger_id)',
)
@TableIndex.sql(
  'CREATE INDEX money_bill_reminders_user_status '
  'ON money_bill_reminders(user_id, status)',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX money_bill_reminders_user_source_key '
  'ON money_bill_reminders(user_id, source_key) '
  'WHERE source_key IS NOT NULL',
)
class MoneyBillReminders extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  IntColumn get dueDate => integer()();

  IntColumn get remindBeforeDays => integer()();

  TextColumn get repeatPeriodType => text().nullable()();

  IntColumn get repeatInterval => integer().nullable()();

  TextColumn get accountId =>
      text().nullable().references(MoneyAccounts, #id)();

  TextColumn get ledgerId => text().nullable().references(MoneyLedgers, #id)();

  TextColumn get categoryId =>
      text().nullable().references(MoneyCategories, #id)();

  TextColumn get relatedTransactionId =>
      text().nullable().references(MoneyTransactions, #id)();

  TextColumn get status => text()();

  TextColumn get sourceType => text().withDefault(const Constant('manual'))();

  TextColumn get sourceKey => text().nullable()();

  TextColumn get amountSource => text().withDefault(const Constant('static'))();

  BoolColumn get autoManaged => boolean().withDefault(const Constant(false))();

  TextColumn get notes => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_bill_reminders';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE INDEX money_reminder_center_processing_user_state '
  'ON money_reminder_center_processing(user_id, state)',
)
@TableIndex.sql(
  'CREATE UNIQUE INDEX money_reminder_center_processing_user_item '
  'ON money_reminder_center_processing(user_id, item_key)',
)
class MoneyReminderCenterProcessing extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get itemKey => text()();

  TextColumn get sourceType => text()();

  TextColumn get sourceId => text()();

  TextColumn get title => text()();

  IntColumn get dueDate => integer()();

  IntColumn get amountMinor => integer()();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  TextColumn get actionType => text()();

  TextColumn get ledgerId => text().nullable().references(MoneyLedgers, #id)();

  TextColumn get accountId =>
      text().nullable().references(MoneyAccounts, #id)();

  BoolColumn get isBudgetExceeded =>
      boolean().withDefault(const Constant(false))();

  TextColumn get state => text()();

  IntColumn get snoozedUntil => integer().nullable()();

  DateTimeColumn get processedAt => dateTime().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_reminder_center_processing';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyAnalysisReports extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get scopeType => text()();

  TextColumn get ledgerId => text().nullable().references(MoneyLedgers, #id)();

  TextColumn get reportPeriod => text()();

  IntColumn get periodStartDate => integer()();

  IntColumn get periodEndDate => integer()();

  TextColumn get status => text()();

  TextColumn get reportDataJson => text()();

  DateTimeColumn get generationStartedAt => dateTime().nullable()();

  DateTimeColumn get generationCompletedAt => dateTime().nullable()();

  TextColumn get errorMessage => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_analysis_reports';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MoneyReportGenerationConfigs extends Table {
  TextColumn get userId => text().references(Users, #id)();

  TextColumn get ledgerId => text().references(MoneyLedgers, #id)();

  BoolColumn get autoGenerateWeekly =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get autoGenerateMonthly =>
      boolean().withDefault(const Constant(true))();

  BoolColumn get autoGenerateQuarterly =>
      boolean().withDefault(const Constant(false))();

  BoolColumn get autoGenerateYearly =>
      boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_report_generation_configs';

  @override
  Set<Column<Object>> get primaryKey => {ledgerId};
}
