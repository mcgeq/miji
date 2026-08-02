import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:miji/core/database/app_database_path.dart';
import 'package:miji/core/database/tables/checkin/checkin_tables.dart';
import 'package:miji/core/database/tables/todo/todo_tables.dart';
import 'package:miji/core/database/tables/health/health_daily_record_tables.dart';
import 'package:miji/core/database/tables/health/health_period_tables.dart';
import 'package:miji/core/database/tables/health/health_reproductive_health_tables.dart';
import 'package:miji/core/database/tables/auth_credentials_table.dart';
import 'package:miji/core/database/tables/money/money_account_tables.dart';
import 'package:miji/core/database/tables/money/money_asset_snapshot_tables.dart';
import 'package:miji/core/database/tables/money/money_budget_tables.dart';
import 'package:miji/core/database/tables/money/money_currency_tables.dart';
import 'package:miji/core/database/tables/money/money_installment_tables.dart';
import 'package:miji/core/database/tables/money/money_auto_posting_tables.dart';
import 'package:miji/core/database/tables/money/money_ledger_tables.dart';
import 'package:miji/core/database/tables/money/money_report_tables.dart';
import 'package:miji/core/database/tables/money/money_split_tables.dart';
import 'package:miji/core/database/tables/money/money_transaction_tables.dart';
import 'package:miji/core/database/tables/money/money_usage_stats_tables.dart';
import 'package:miji/core/database/tables/sync/sync_change_log_table.dart';
import 'package:miji/core/database/tables/sync/sync_conflict_table.dart';
import 'package:miji/core/database/tables/user_preferences_table.dart';
import 'package:miji/core/database/tables/users_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    AuthCredentials,
    UserPreferences,
    MoneyCurrencies,
    MoneyCategories,
    MoneySubCategories,
    MoneyAccounts,
    MoneyTransactions,
    MoneyTransactionTags,
    MoneyBudgets,
    MoneyBudgetSnapshots,
    MoneyBudgetAllocationSnapshots,
    MoneyBudgetAllocations,
    MoneyInstallmentPlans,
    MoneyInstallmentDetails,
    MoneyAutoPostingTemplates,
    MoneyAutoPostingRuns,
    MoneyLedgers,
    MoneyMembers,
    MoneyLedgerAccounts,
    MoneyLedgerTransactions,
    MoneyLedgerMembers,
    MoneySplitRules,
    MoneySplitRecords,
    MoneySplitRecordDetails,
    MoneyBillReminders,
    MoneyReminderCenterProcessing,
    MoneyAnalysisReports,
    MoneyReportGenerationConfigs,
    MoneyCategoryUsageStats,
    MoneySubCategoryUsageStats,
    MoneyAccountUsageStats,
    MoneyPaymentMethodUsageStats,
    MoneyAccountPaymentMethodUsageStats,
    SyncMetadata,
    SyncChangeLogs,
    DeltaConflicts,
    HealthPeriodSettings,
    HealthPeriodRecords,
    HealthPeriodDailyRecords,
    HealthPeriodSymptoms,
    HealthPeriodPmsRecords,
    HealthPeriodPmsSymptoms,
    HealthOvulationTestRecords,
    HealthPregnancyRecords,
    HealthMedicationRecords,
    MoneyAssetSnapshots,
    CheckinPlans,
    CheckinRecords,
    CheckinPhotos,
    TodoTasks,
    TodoCategories,
    TodoTags,
    TodoTaskTags,
    TodoRecurrenceRules,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(
        executor ??
            driftDatabase(
              name: appDatabaseName,
              native: DriftNativeOptions(
                databasePath: () async => (await resolveAppDatabaseFile()).path,
              ),
            ),
      );

  @override
  int get schemaVersion => 18;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 2) {
          await migrator.addColumn(
            userPreferences,
            userPreferences.sensitiveAccessTtl,
          );
        }
        if (from < 3) {
          await migrator.addColumn(
            moneyInstallmentPlans,
            moneyInstallmentPlans.ledgerId,
          );
        }
        if (from < 4) {
          await migrator.addColumn(moneyAccounts, moneyAccounts.statementDay);
          await migrator.addColumn(moneyAccounts, moneyAccounts.repaymentDay);
        }
        if (from < 5) {
          await migrator.createTable(moneyBudgetSnapshots);
        }
        if (from < 6) {
          await customStatement(
            'DROP INDEX IF EXISTS money_budget_snapshots_period_unique',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'money_budget_snapshots_period_unique '
            'ON money_budget_snapshots('
            'budget_id, period_start_date, period_end_date, '
            'source_budget_version)',
          );
        }
        if (from < 7) {
          await migrator.createTable(moneyBudgetAllocationSnapshots);
        }
        if (from < 8) {
          await migrator.addColumn(
            moneyAccounts,
            moneyAccounts.autoRepaymentReminderEnabled,
          );
          await migrator.addColumn(
            moneyBillReminders,
            moneyBillReminders.sourceType,
          );
          await migrator.addColumn(
            moneyBillReminders,
            moneyBillReminders.sourceKey,
          );
          await migrator.addColumn(
            moneyBillReminders,
            moneyBillReminders.amountSource,
          );
          await migrator.addColumn(
            moneyBillReminders,
            moneyBillReminders.autoManaged,
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'money_bill_reminders_user_source_key '
            'ON money_bill_reminders(user_id, source_key) '
            'WHERE source_key IS NOT NULL',
          );
        }
        if (from < 9) {
          await migrator.addColumn(
            healthPeriodSettings,
            healthPeriodSettings.periodTrackingEnabled,
          );
        }
        if (from < 10) {
          await migrator.addColumn(
            moneyAccounts,
            moneyAccounts.budgetCycleStartDay,
          );
        }
        if (from < 11) {
          await migrator.createTable(moneyReminderCenterProcessing);
        }
        if (from < 13) {
          await migrator.createTable(moneyAssetSnapshots);
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS '
            'money_asset_snapshots_user_account_date '
            'ON money_asset_snapshots(user_id, account_id, captured_date)',
          );
        }
        if (from < 14) {
          await migrator.createTable(checkinPlans);
          await migrator.createTable(checkinRecords);
          await migrator.createTable(checkinPhotos);
        }
        if (from < 15) {
          // 支持「每次独立」记录：同一天同计划可有多条记录，
          // 合并去重改由 repository 的 upsert 查询保证。
          await customStatement(
            'DROP INDEX IF EXISTS checkin_records_user_plan_date_unique',
          );
        }
        if (from < 16) {
          // todo 表首次创建：当前表定义已包含 V1.1/V1.2 的全部新列，
          // 因此后续 addColumn 步骤必须跳过，否则会报重复列错误。
          await migrator.createTable(todoTasks);
          await migrator.createTable(todoCategories);
        } else if (from < 17) {
          // v16 库：todo_tasks 只有基础列，需要补齐 V1.1 字段。
          await migrator.addColumn(todoTasks, todoTasks.isRecurrenceTemplate);
          await migrator.addColumn(todoTasks, todoTasks.recurrenceRuleId);
          await migrator.addColumn(todoTasks, todoTasks.occurrenceDate);
          await migrator.addColumn(todoTasks, todoTasks.reminderAt);
        }
        if (from < 17) {
          // V1.1: 标签、重复规则表
          await migrator.createTable(todoTags);
          await migrator.createTable(todoTaskTags);
          await migrator.createTable(todoRecurrenceRules);
        }
        if (from >= 16 && from < 18) {
          // V1.2: Markdown 正文（from < 16 时表已带此列）
          await migrator.addColumn(todoTasks, todoTasks.markdownBody);
        }
      },
    );
  }
}
