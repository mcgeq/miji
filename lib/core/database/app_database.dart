import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:miji/core/database/app_database_path.dart';
import 'package:miji/core/database/tables/checkin/checkin_tables.dart';
import 'package:miji/core/database/tables/todo/todo_tables.dart';
import 'package:miji/core/database/tables/health/health_daily_record_tables.dart';
import 'package:miji/core/database/tables/health/health_period_tables.dart';
import 'package:miji/core/database/tables/health/health_reproductive_health_tables.dart';
import 'package:miji/core/database/tables/auth_credentials_table.dart';
import 'package:miji/core/database/tables/life_energy/life_energy_tables.dart';
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
import 'package:miji/core/database/seed/money_seed_data.dart';

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
    LifeEnergyProfiles,
    WishlistItems,
    OvertimeEntries,
    SalarySegments,
    BonusPayments,
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
  int get schemaVersion => 33;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) => migrator.createAll(),
      onUpgrade: (migrator, from, to) async {
        if (from < 23) {
          // 删掉 theme_seed_color：这个偏好有列、注册时写默认值，但主题从未读取它
          // （app_theme.dart 一直用写死的 AppThemeTokens），留着会误导下一个人。
          // 这里先查一下列是否存在：迁移测试是用「当前 schema 再减列」来模拟旧版本，
          // 那种库上并没有这一列，直接 ALTER 会报错。
          final columns = await customSelect(
            "PRAGMA table_info('user_preferences')",
          ).get();
          final hasSeedColor = columns.any(
            (row) => row.read<String>('name') == 'theme_seed_color',
          );
          if (hasSeedColor) {
            await customStatement(
              'ALTER TABLE user_preferences DROP COLUMN theme_seed_color',
            );
          }
        }
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
        if (from < 19) {
          // V1.3: 首页今日行动卡片显示开关
          await migrator.addColumn(
            userPreferences,
            userPreferences.showHomeTodayAction,
          );
        }
        if (from < 20) {
          // 同步日志按 (datasetId, syncedAt) 索引：避免每次同步
          // 拉取未同步日志时全表扫描（日志表会持续增长）。
          await customStatement(
            'CREATE INDEX IF NOT EXISTS sync_change_logs_dataset_synced '
            "ON sync_change_logs(dataset_id, synced_at)",
          );
        }
        if (from < 21) {
          // V1.4: 首页金额隐私 / 健康窄条显示开关。
          await migrator.addColumn(
            userPreferences,
            userPreferences.maskMoneyAmounts,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.showHomeHealthStrip,
          );
        }
        if (from < 22) {
          // V1.5: 分类业务顺序。内置分类按种子声明顺序回填，
          // 用户自建分类保持 0（排序时视为最后），避免插到内置分类前面。
          await migrator.addColumn(moneyCategories, moneyCategories.sortOrder);
          await migrator.addColumn(
            moneySubCategories,
            moneySubCategories.sortOrder,
          );
          for (
            var index = 0;
            index < defaultMoneyCategorySeeds.length;
            index++
          ) {
            final category = defaultMoneyCategorySeeds[index];
            await customStatement(
              'UPDATE money_categories SET sort_order = ? WHERE id = ?',
              [index + 1, category.id],
            );
            for (
              var subIndex = 0;
              subIndex < category.subCategories.length;
              subIndex++
            ) {
              await customStatement(
                'UPDATE money_sub_categories SET sort_order = ? WHERE id = ?',
                [subIndex + 1, category.subCategories[subIndex].id],
              );
            }
          }
        }
        if (from < 24) {
          // V1.6: 自动记账模板被分期接管。同一笔周期还款若同时登记为分期期次
          // 和自动记账模板，到期当天两个引擎会各建一笔流水；接管后模板停止
          // 独立入账（isActive 同步置 false），由分期引擎独占。
          await migrator.addColumn(
            moneyAutoPostingTemplates,
            moneyAutoPostingTemplates.takenOverByPlanId,
          );
        }
        if (from < 25) {
          // 首页 v2：区块可见性 / 顺序 + 布局模式。默认横向分页、无顶部标签。
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeBlockVisibility,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeBlockOrder,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homeLayoutMode,
          );
          await migrator.addColumn(
            userPreferences,
            userPreferences.homePagerTabs,
          );
        }
        if (from < 26) {
          // V1.8: 时薪（真实时薪 / 想买清单 / 加班记录）。
          // 三张都是新表，老库只需补建；数据从零开始，没有回填。
          await migrator.createTable(lifeEnergyProfiles);
          await migrator.createTable(wishlistItems);
          await migrator.createTable(overtimeEntries);
        }
        if (from < 27) {
          // V1.9: 职业段（薪资历史 / 涨薪与跳槽）。
          // 只建表，**不把现有档案补成第一段**：空表就是「没有历史」，读时
          // 直接回退到 profile。补一条等于伪造一个「从建档那天起」的段，
          // 而那个起点没人知道。
          await migrator.createTable(salarySegments);
        }
        if (from < 28 && from >= 26) {
          // V1.10: 税前推算（填税前月薪 → 算逐月到手）。
          //
          // 加 `from >= 26` 这个下限：v26 之前的库里根本没有这张表，上面
          // `from < 26` 那一段刚 `createTable` 出来 —— 建出来的表已经带上这些
          // 列了，再 addColumn 会撞「duplicate column」。
          //
          // 新列全部带默认值，且默认口径仍是 `net` —— 老用户升级后看到的
          // 界面和之前一模一样，不会凭空多出「你的到手应该是 14,650」。
          // 不回填 grossMonthlyMinor：反推税前是多解的，宁可留空让用户填合同。
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.compensationMode,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.grossMonthlyMinor,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.socialBaseMode,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.socialBaseMinor,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.socialBaseFloorMinor,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.socialBaseCeilingMinor,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.ratePensionBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateMedicalBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateUnemploymentBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateHousingFundBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.ratePensionErBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateMedicalErBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateUnemploymentErBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateInjuryErBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.rateHousingFundErBp,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.medicalFixedMinor,
          );
          await migrator.addColumn(
            lifeEnergyProfiles,
            lifeEnergyProfiles.specialDeductionMinor,
          );
        }
        if (from < 28 && from >= 27) {
          // 同上：v27 之前 `salary_segments` 是这一段刚建出来的，列已经有了。
          await migrator.addColumn(
            salarySegments,
            salarySegments.grossAmountMinor,
          );
        }
        if (from < 30) {
          // V1.12: 年终奖从「档案上的一个数」改成「按纳税年度记的一行」。
          //
          // 为什么要换表：单独计税的全年一次性奖金按**发放年度**算税，且一个
          // 纳税年度只能用一次。挂在档案上没法表达「2025 年这笔是星野发的、
          // 2026 年这笔是云图发的」，换一次公司就把旧奖金覆盖了。
          //
          // 旧值不丢也不猜年份：搬进来时 `tax_year = 0`（未指定），任何一年的
          // 账都不会把它算进去，界面上单独列出来等人补年份 —— 猜一个年度的
          // 代价是某一年的账凭空多出一笔钱，那比空着更糟。
          await migrator.createTable(bonusPayments);
          final profileColumns = await customSelect(
            "PRAGMA table_info('life_energy_profiles')",
          ).get();
          final hasBonusColumn = profileColumns.any(
            (row) => row.read<String>('name') == 'bonus_minor',
          );
          if (hasBonusColumn) {
            await customStatement(
              'INSERT INTO bonus_payments '
              '(id, user_id, tax_year, amount_minor, source_label, note, '
              'version, is_deleted, created_at, updated_at) '
              "SELECT 'legacy-bonus-' || user_id, user_id, 0, bonus_minor, "
              // 时间列按 drift 的口径存 unix 秒，不是 `CURRENT_TIMESTAMP`
              // 那个字符串 —— 混着存会让读出来的 DateTime 解析崩掉。
              'NULL, NULL, 1, 0, '
              "CAST(strftime('%s','now') AS INTEGER), "
              "CAST(strftime('%s','now') AS INTEGER) "
              'FROM life_energy_profiles WHERE bonus_minor > 0',
            );
            await customStatement(
              'ALTER TABLE life_energy_profiles DROP COLUMN bonus_minor',
            );
          }
        }
        if (from < 33) {
          // V1.15: 档案表补上同步四件套。它是账号级单例，接同步后需要 version
          // 才能判定冲突（另外四张表 v26 起就有）。
          //
          // 按列名逐个查再补：模拟旧库的迁移测试是「当前 schema 再减列」，
          // v26 建表时表里已经带着这四列，直接 addColumn 会撞 duplicate。
          final profileColumns =
              await customSelect(
                "PRAGMA table_info('life_energy_profiles')",
              ).get().then(
                (rows) => {for (final row in rows) row.read<String>('name')},
              );
          Future<void> addIfMissing(
            String name,
            GeneratedColumn<Object> column,
          ) async {
            if (!profileColumns.contains(name)) {
              await migrator.addColumn(lifeEnergyProfiles, column);
            }
          }

          await addIfMissing('device_id', lifeEnergyProfiles.deviceId);
          await addIfMissing('version', lifeEnergyProfiles.version);
          await addIfMissing('is_deleted', lifeEnergyProfiles.isDeleted);
          await addIfMissing('deleted_at', lifeEnergyProfiles.deletedAt);
        }
        if (from < 32) {
          // V1.14: 时薪面板记住「上次停在哪」：面板分段、清单排序、年度账年份。
          // 一列 JSON 足够 —— 它们永远一起读，也不会单独改其中一项。
          await migrator.addColumn(
            userPreferences,
            userPreferences.lifeEnergyPrefs,
          );
        }
        if (from < 31) {
          // V1.13: `bonus_payments` 补上「一人一年一条」的唯一索引。
          //
          // 表注释一直说这个索引在管着「一年只能有一条」，实际没建 —— 约束只
          // 落在仓库层的「先查同年再 upsert」上，并发或快速两次保存能留下两条。
          //
          // 建索引前先清重复：保留同一 (user, year) 里最后更新的那条，其余软删。
          // 不直接 DELETE：软删保留可追溯性，也不会让同步侧看到行凭空消失。
          await customStatement(
            'UPDATE bonus_payments SET is_deleted = 1, deleted_at = '
            "CAST(strftime('%s','now') AS INTEGER) "
            'WHERE is_deleted = 0 AND EXISTS ('
            '  SELECT 1 FROM bonus_payments AS other '
            '  WHERE other.user_id = bonus_payments.user_id '
            '  AND other.tax_year = bonus_payments.tax_year '
            '  AND other.is_deleted = 0 '
            '  AND (other.updated_at > bonus_payments.updated_at '
            '  OR (other.updated_at = bonus_payments.updated_at '
            '  AND other.id > bonus_payments.id))'
            ')',
          );
          await customStatement(
            'CREATE UNIQUE INDEX IF NOT EXISTS bonus_payments_user_year '
            'ON bonus_payments(user_id, tax_year) WHERE is_deleted = 0',
          );
        }
        if (from < 29) {
          // V1.11: 职业段自己存一份五险一金参数快照。
          //
          // 参数不是常数：换城市、换公司（公积金比例由单位定）、每年 7 月
          // 基数调整都会在年中变，而历史段的到手与时薪是拿参数算出来的。
          // 老段一律留 null = 继续跟随档案（升级后数字一点不变，不会凭空改写
          // 历史），从下一次新建段开始才冻结。
          if (from >= 27) {
            await migrator.addColumn(
              salarySegments,
              salarySegments.payrollJson,
            );
          }

          // 顺手清掉上一版留下的孤儿列：城市预设已撑掉，这一列再没有任何
          // 读写方。先查一下列是否存在：模拟旧库的迁移测试是用「现 schema
          // 再减列」造的，那种库上本来就没有它。
          final profileColumns = await customSelect(
            "PRAGMA table_info('life_energy_profiles')",
          ).get();
          final hasPresetColumn = profileColumns.any(
            (row) => row.read<String>('name') == 'city_preset_id',
          );
          if (hasPresetColumn) {
            await customStatement(
              'ALTER TABLE life_energy_profiles DROP COLUMN city_preset_id',
            );
          }
        }
      },
    );
  }
}
