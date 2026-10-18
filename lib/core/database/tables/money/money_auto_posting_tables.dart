import 'package:drift/drift.dart';

import 'package:miji/core/database/tables/users_table.dart';

@TableIndex.sql(
  'CREATE INDEX money_auto_posting_templates_user_active '
  'ON money_auto_posting_templates(user_id, is_active, is_deleted)',
)
class MoneyAutoPostingTemplates extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get name => text()();

  TextColumn get type => text()();

  IntColumn get amountMinor => integer()();

  TextColumn get currencyCode => text()();

  TextColumn get description => text()();

  TextColumn get notes => text().nullable()();

  TextColumn get merchant => text().nullable()();

  TextColumn get accountId => text()();

  TextColumn get categoryId => text()();

  TextColumn get subCategoryId => text().nullable()();

  TextColumn get paymentMethod => text()();

  TextColumn get customPaymentMethodName => text().nullable()();

  TextColumn get actualPayerAccount =>
      text().withDefault(const Constant('default'))();

  TextColumn get ledgerId => text().nullable()();

  TextColumn get frequency => text()();

  IntColumn get dayOfMonth => integer().nullable()();

  IntColumn get weekday => integer().nullable()();

  IntColumn get timeOfDayMinutes => integer().withDefault(const Constant(0))();

  DateTimeColumn get startsOn => dateTime()();

  DateTimeColumn get endsOn => dateTime().nullable()();

  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  IntColumn get version => integer().withDefault(const Constant(1))();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  /// 被哪个分期计划接管。
  ///
  /// 非空表示「这笔周期支出与分期「X」的某一期是同一笔还款」，此时模板必须
  /// 停止独立入账，否则到期当天两个引擎各建一笔流水（见
  /// [_AutoPosting._executeAutoPostingOccurrence] 与 [_Installments.postInstallmentDetail]）。
  /// 置位时 [isActive] 同步置 false；解除接管时恢复。
  ///
  /// 之所以是「标记 + 停用」而不是直接删除模板：删除会丢掉用户的原始配置，
  /// 解除接管后没法恢复；而且 UI 上需要说清楚「这个模板为什么是停用的」。
  TextColumn get takenOverByPlanId => text().nullable()();

  @override
  String get tableName => 'money_auto_posting_templates';

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex.sql(
  'CREATE UNIQUE INDEX money_auto_posting_runs_occurrence '
  'ON money_auto_posting_runs(user_id, template_id, occurrence_key)',
)
@TableIndex.sql(
  'CREATE INDEX money_auto_posting_runs_user_status '
  'ON money_auto_posting_runs(user_id, status, scheduled_for)',
)
class MoneyAutoPostingRuns extends Table {
  TextColumn get id => text()();

  TextColumn get userId => text().references(Users, #id)();

  TextColumn get templateId => text()();

  TextColumn get occurrenceKey => text()();

  TextColumn get status => text()();

  TextColumn get transactionId => text().nullable()();

  DateTimeColumn get scheduledFor => dateTime()();

  DateTimeColumn get postedAt => dateTime().nullable()();

  IntColumn get templateVersion => integer()();

  TextColumn get errorCode => text().nullable()();

  TextColumn get errorMessage => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  String get tableName => 'money_auto_posting_runs';

  @override
  Set<Column<Object>> get primaryKey => {id};
}
