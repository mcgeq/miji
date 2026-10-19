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

  /// 卡片背景样式：`default` / `color` / `image`。NULL 视同 `default`。
  ///
  /// 与 [color]（标识色：图标底色、图表分布色）语义分离，改背景不能
  /// 连带动到全 App 的标识色。
  TextColumn get backgroundStyle => text().nullable()();

  /// 卡片背景色（hex 字符串），[backgroundStyle] 为 `color` 时生效。
  TextColumn get backgroundColor => text().nullable()();

  /// 卡片背景图相对路径（AttachmentStore 存储）。附件文件不参与同步，
  /// 其他设备读不到文件时按「背景图 → 背景色 → 默认」降级。
  TextColumn get backgroundImage => text().nullable()();

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
