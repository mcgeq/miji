import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';

@TableIndex.sql(
  'CREATE INDEX money_transactions_user_date '
  'ON money_transactions(user_id, transaction_at)',
)
@TableIndex.sql(
  'CREATE INDEX money_transactions_user_account_date '
  'ON money_transactions(user_id, account_id, transaction_at)',
)
@TableIndex.sql(
  'CREATE INDEX money_transactions_user_category_date '
  'ON money_transactions(user_id, category_id, transaction_at)',
)
@TableIndex.sql(
  'CREATE INDEX money_transactions_user_status '
  'ON money_transactions(user_id, type, status, is_deleted)',
)
@TableIndex.sql(
  'CREATE INDEX money_transactions_user_payment_method '
  'ON money_transactions(user_id, payment_method, type, status, is_deleted)',
)
@TableIndex.sql(
  'CREATE INDEX money_transactions_user_currency_date '
  'ON money_transactions(user_id, currency_code, transaction_at)',
)
class MoneyTransactions extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get type => text()();

  TextColumn get status => text()();

  DateTimeColumn get transactionAt => dateTime()();

  IntColumn get amountMinor => integer()();

  IntColumn get refundAmountMinor => integer().withDefault(const Constant(0))();

  TextColumn get currencyCode => text().references(MoneyCurrencies, #code)();

  TextColumn get description => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get merchant => text().nullable()();

  TextColumn get location => text().nullable()();

  @ReferenceName('accountTransactions')
  TextColumn get accountId => text().references(MoneyAccounts, #id)();

  @ReferenceName('transferTargetTransactions')
  TextColumn get toAccountId =>
      text().nullable().references(MoneyAccounts, #id)();

  TextColumn get categoryId => text().references(MoneyCategories, #id)();

  TextColumn get subCategoryId =>
      text().nullable().references(MoneySubCategories, #id)();

  TextColumn get paymentMethod => text()();

  TextColumn get customPaymentMethodName => text().nullable()();

  TextColumn get actualPayerAccount => text()();

  TextColumn get relatedTransactionId => text().nullable()();

  TextColumn get installmentPlanId => text().nullable()();

  TextColumn get sourceTemplateRunId => text().nullable()();

  IntColumn get interestRateBasisPoints => integer().nullable()();

  IntColumn get totalInterestMinor =>
      integer().withDefault(const Constant(0))();

  TextColumn get calcMethod => text().nullable()();

  TextColumn get deviceId => text().nullable()();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_transactions';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE INDEX money_transaction_tags_tag ON money_transaction_tags(tag)',
)
class MoneyTransactionTags extends Table {
  TextColumn get transactionId => text().references(MoneyTransactions, #id)();

  TextColumn get tag => text()();

  @override
  String get tableName => 'money_transaction_tags';

  @override
  Set<Column<Object>> get primaryKey => {transactionId, tag};
}
