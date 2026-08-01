import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:miji/core/database/app_database_path.dart';
import 'package:miji/core/database/tables/checkin/checkin_tables.dart';
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
  int get schemaVersion => 14;

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
      },
    );
  }
}
