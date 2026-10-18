import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';

/// Reproduces the phone upgrade path: an existing database from a previous
/// release (schema v15/v16/v17/v18/v20) is opened by the current v21 code.
///
/// The old database is simulated by creating the current schema, dropping the
/// todo tables (which did not exist at v15) or the V1.1 columns (v16), then
/// rewinding `user_version`.

/// V1.5 给分类表加了业务顺序列。伪造 v21 及更早版本时同样要先删掉，
/// 否则 `addColumn` 会因重复列失败。
Future<void> _dropV15SortOrderColumns(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE money_categories DROP COLUMN sort_order',
  );
  await db.customStatement(
    'ALTER TABLE money_sub_categories DROP COLUMN sort_order',
  );
}

/// V1.6（v24）给自动记账模板加了「被分期接管」列。伪造 v23 及更早版本时同样
/// 要先删掉，否则迁移里的 `addColumn` 会因重复列失败。
Future<void> _dropTakenOverByPlanColumn(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE money_auto_posting_templates '
    'DROP COLUMN taken_over_by_plan_id',
  );
}

/// V1.7（v25）给 `user_preferences` 加了首页 v2 的四列。伪造 v24 及更早版本
/// 时必须把它们删掉，否则迁移里的 `addColumn` 会因重复列失败。
Future<void> _dropV25HomeBlockColumns(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_block_visibility',
  );
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_block_order',
  );
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_layout_mode',
  );
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN home_pager_tabs',
  );
}

/// V1.4 给 `user_preferences` 增加了两列。迁移测试通过「建当前 schema →
/// 删列 → 回退 user_version」来伪造旧库，所以伪造 v20 及更早版本时
/// 必须把这两列一并删掉，否则迁移会因重复列而失败。
/// v23 删掉了 theme_seed_color（死配置）。模拟 v23 之前的库时要先把这列加回来 ——
/// 迁移测试的做法是「从当前 schema 减列」，不减的话这一列本来就不在。
Future<void> _restoreThemeSeedColorColumn(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE user_preferences '
    'ADD COLUMN theme_seed_color INTEGER NOT NULL DEFAULT 0',
  );
}

Future<void> _dropV14PreferenceColumns(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN mask_money_amounts',
  );
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN show_home_health_strip',
  );
}

/// V1.10（v28）给 `life_energy_profiles` 加了税前推算的 19 列、给
/// `salary_segments` 加了 `gross_amount_minor`。伪造 v27 及更早版本时同样
/// 要先删掉，否则迁移里的 `addColumn` 会因重复列失败。
Future<void> _dropV28PayrollColumns(AppDatabase db) async {
  for (final column in const [
    'compensation_mode',
    'gross_monthly_minor',
    'social_base_mode',
    'social_base_minor',
    'social_base_floor_minor',
    'social_base_ceiling_minor',
    'rate_pension_bp',
    'rate_medical_bp',
    'rate_unemployment_bp',
    'rate_housing_fund_bp',
    'rate_pension_er_bp',
    'rate_medical_er_bp',
    'rate_unemployment_er_bp',
    'rate_injury_er_bp',
    'rate_housing_fund_er_bp',
    'medical_fixed_minor',
    'special_deduction_minor',
  ]) {
    await db.customStatement(
      'ALTER TABLE life_energy_profiles DROP COLUMN $column',
    );
  }
  await db.customStatement(
    'ALTER TABLE salary_segments DROP COLUMN gross_amount_minor',
  );
  // v29 的 `payroll_json` 那时也还不存在：伪造 v27 的库同样得减掉，否则
  // 迁移里的 addColumn 会撞「duplicate column」。
  await db.customStatement(
    'ALTER TABLE salary_segments DROP COLUMN payroll_json',
  );
}

/// V1.11（v29）给 `salary_segments` 加了 `payroll_json`，并删掉了
/// `life_energy_profiles.city_preset_id`。伪造 v28 的库要「减 payroll_json、
/// 把 city_preset_id 加回来」—— 迁移测试的做法是「建当前 schema 再往回改」，
/// 而这一列在当前 schema 里已经不存在了。
Future<void> _simulateV28Schema(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE salary_segments DROP COLUMN payroll_json',
  );
  await db.customStatement(
    'ALTER TABLE life_energy_profiles ADD COLUMN city_preset_id TEXT',
  );
}

/// V1.12（v30）把年终奖从 `life_energy_profiles.bonus_minor` 搬进
/// `bonus_payments` 表。伪造 v29 的库要「drop 新表 + 把旧列加回来」。
Future<void> _simulateV29Schema(AppDatabase db) async {
  await db.customStatement('DROP TABLE IF EXISTS bonus_payments');
  await db.customStatement(
    'ALTER TABLE life_energy_profiles '
    'ADD COLUMN bonus_minor INTEGER NOT NULL DEFAULT 0',
  );
}

/// V1.15（v33）给 `life_energy_profiles` 补了同步四件套。
/// 伪造 v32 的库先把它们删掉（迁移里按列名查，删掉才走得到 addColumn）。
Future<void> _simulateV32ProfileColumns(AppDatabase db) async {
  for (final column in const [
    'device_id',
    'version',
    'is_deleted',
    'deleted_at',
  ]) {
    await db.customStatement(
      'ALTER TABLE life_energy_profiles DROP COLUMN $column',
    );
  }
}

/// V1.14（v32）给 `user_preferences` 加了时薪面板的偏好列。
/// 伪造 v31 及更早版本的库时同样要先删掉，否则迁移里的 addColumn 会因重复列失败。
Future<void> _dropV32LifeEnergyPrefsColumn(AppDatabase db) async {
  await db.customStatement(
    'ALTER TABLE user_preferences DROP COLUMN life_energy_prefs',
  );
}

/// V1.13（v31）给 `bonus_payments` 加了部分唯一索引。
/// 伪造 v30 的库先把它删掉，否则迁移里的 CREATE INDEX IF NOT EXISTS 什么都不做，
/// 也就测不出「重复清理」这一步。
Future<void> _simulateV30Schema(AppDatabase db) async {
  await db.customStatement('DROP INDEX IF EXISTS bonus_payments_user_year');
}

/// V1.8（v26）新增了时薪三张表。伪造 v25 及更早版本的库时必须先把它们
/// 删掉：迁移测试的做法是「建当前 schema 再往回减」，不减的话迁移里的
/// `createTable` 会撞上已存在的表。
Future<void> _dropV26LifeEnergyTables(AppDatabase db) async {
  await db.customStatement('DROP TABLE IF EXISTS life_energy_profiles');
  await db.customStatement('DROP TABLE IF EXISTS wishlist_items');
  await db.customStatement('DROP TABLE IF EXISTS overtime_entries');
  // V1.9（v27）的 salary_segments 也在这里删：伪造任何旧版本时它都「还不存在」，
  // 而 v27 的迁移里有 createTable —— 不删就会撞上已存在的表。
  await db.customStatement('DROP TABLE IF EXISTS salary_segments');
}

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('miji_migration_test');
    dbFile = File('${tempDir.path}/miji.sqlite');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  test('v15 -> v18 upgrade succeeds and keeps existing data', () async {
    final now = DateTime.now().toUtc();

    final v18db = AppDatabase(NativeDatabase(dbFile));
    await v18db
        .into(v18db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate the v15 release: no todo tables, user_version = 15.
    await v18db.customStatement('DROP TABLE IF EXISTS todo_task_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_recurrence_rules');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_tasks');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_categories');
    await v18db.customStatement(
      'ALTER TABLE user_preferences DROP COLUMN show_home_today_action',
    );
    await _dropV14PreferenceColumns(v18db);
    await _dropV15SortOrderColumns(v18db);
    await _restoreThemeSeedColorColumn(v18db);
    await _dropTakenOverByPlanColumn(v18db);
    await _dropV25HomeBlockColumns(v18db);
    await _dropV26LifeEnergyTables(v18db);
    await _dropV32LifeEnergyPrefsColumn(v18db);
    await v18db.customStatement('PRAGMA user_version = 15');
    await v18db.close();

    // Reopen with the current schema: this runs the 15 -> 21 migration.
    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

    final user = await (db.select(
      db.users,
    )..where((row) => row.id.equals('user-1'))).getSingleOrNull();
    expect(user, isNotNull);
    expect(user!.displayName, 'Demo');

    // todo tables must exist with the full current schema.
    expect(await (db.select(db.todoTasks)).get(), isEmpty);
    expect(await (db.select(db.todoCategories)).get(), isEmpty);
    expect(await (db.select(db.todoTags)).get(), isEmpty);
    expect(await (db.select(db.todoTaskTags)).get(), isEmpty);
    expect(await (db.select(db.todoRecurrenceRules)).get(), isEmpty);
    expect(await (db.select(db.todoTasks)).get(), isA<List<dynamic>>());
    await db.close();
  });

  test('v16 -> v18 upgrade adds the V1.1 columns', () async {
    final now = DateTime.now().toUtc();

    final v18db = AppDatabase(NativeDatabase(dbFile));
    await v18db
        .into(v18db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v16 release: drop the V1.1/V1.2 columns that v16 lacked
    // (indexes referencing them must be dropped first, as in a real v16 DB).
    await v18db.customStatement(
      'DROP INDEX IF EXISTS todo_tasks_user_recurrence',
    );
    await v18db.customStatement(
      'DROP INDEX IF EXISTS todo_tasks_user_occurrence',
    );
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN is_recurrence_template',
    );
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN recurrence_rule_id',
    );
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN occurrence_date',
    );
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN reminder_at',
    );
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN markdown_body',
    );
    await v18db.customStatement(
      'ALTER TABLE user_preferences DROP COLUMN show_home_today_action',
    );
    await _dropV14PreferenceColumns(v18db);
    await _dropV15SortOrderColumns(v18db);
    await v18db.customStatement('DROP TABLE IF EXISTS todo_task_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_recurrence_rules');
    await _restoreThemeSeedColorColumn(v18db);
    await _dropTakenOverByPlanColumn(v18db);
    await _dropV25HomeBlockColumns(v18db);
    await _dropV26LifeEnergyTables(v18db);
    await _dropV32LifeEnergyPrefsColumn(v18db);
    await v18db.customStatement('PRAGMA user_version = 16');
    await v18db.close();

    // Reopen with the current schema: this runs the 16 -> 21 migration.
    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

    // V1.1 columns must exist after the migration.
    final columns = await db
        .customSelect('PRAGMA table_info(todo_tasks)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toList());
    expect(
      columns,
      containsAll([
        'is_recurrence_template',
        'occurrence_date',
        'markdown_body',
      ]),
    );
    await db.close();
  });

  test('v17 -> v18 upgrade adds markdown_body only', () async {
    final now = DateTime.now().toUtc();

    final v18db = AppDatabase(NativeDatabase(dbFile));
    await v18db
        .into(v18db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v17 release: drop the V1.2 column that v17 lacked.
    await v18db.customStatement(
      'ALTER TABLE todo_tasks DROP COLUMN markdown_body',
    );
    await v18db.customStatement(
      'ALTER TABLE user_preferences DROP COLUMN show_home_today_action',
    );
    await _dropV14PreferenceColumns(v18db);
    await _dropV15SortOrderColumns(v18db);
    await _restoreThemeSeedColorColumn(v18db);
    await _dropTakenOverByPlanColumn(v18db);
    await _dropV25HomeBlockColumns(v18db);
    await _dropV26LifeEnergyTables(v18db);
    await _dropV32LifeEnergyPrefsColumn(v18db);
    await v18db.customStatement('PRAGMA user_version = 17');
    await v18db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

    final columns = await db
        .customSelect('PRAGMA table_info(todo_tasks)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toList());
    expect(columns, contains('markdown_body'));
    await db.close();
  });

  test('fresh install still creates every table', () async {
    final db = AppDatabase(NativeDatabase(dbFile));
    expect(await (db.select(db.todoTasks)).get(), isEmpty);
    expect(await (db.select(db.todoCategories)).get(), isEmpty);
    expect(await (db.select(db.todoTags)).get(), isEmpty);
    await db.close();
  });

  test(
    'v18 -> v19 upgrade adds show_home_today_action with default true',
    () async {
      final now = DateTime.now().toUtc();

      final v19db = AppDatabase(NativeDatabase(dbFile));
      await v19db
          .into(v19db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v19db
          .into(v19db.userPreferences)
          .insert(
            UserPreferencesCompanion.insert(
              userId: 'user-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simulate a v18 release: drop the V1.3 column that v18 lacked.
      await v19db.customStatement(
        'ALTER TABLE user_preferences DROP COLUMN show_home_today_action',
      );
      await _dropV14PreferenceColumns(v19db);
      await _dropV15SortOrderColumns(v19db);
      await _restoreThemeSeedColorColumn(v19db);
      await _dropTakenOverByPlanColumn(v19db);
      await _dropV25HomeBlockColumns(v19db);
      await _dropV26LifeEnergyTables(v19db);
      await _dropV32LifeEnergyPrefsColumn(v19db);
      await v19db.customStatement('PRAGMA user_version = 18');
      await v19db.close();

      // Reopen with the current schema: this runs the 18 -> 21 migration.
      final db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

      final columns = await db
          .customSelect('PRAGMA table_info(user_preferences)')
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toList());
      expect(columns, contains('show_home_today_action'));

      // Existing rows keep data and the new column defaults to true.
      final preferences = await (db.select(db.userPreferences)).getSingle();
      expect(preferences.userId, 'user-1');
      expect(preferences.showHomeTodayAction, isTrue);
      await db.close();
    },
  );

  test(
    'v21 -> v22 upgrade adds category sort_order and backfills the seed order',
    () async {
      final now = DateTime.now().toUtc();

      final v21db = AppDatabase(NativeDatabase(dbFile));
      await v21db
          .into(v21db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
      // 一个内置分类 + 一个用户自建分类。
      await v21db
          .into(v21db.moneyCategories)
          .insert(
            MoneyCategoriesCompanion.insert(
              id: 'expense_food',
              name: '餐饮',
              kind: 'expense',
              isSystem: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v21db
          .into(v21db.moneyCategories)
          .insert(
            MoneyCategoriesCompanion.insert(
              id: 'custom-1',
              userId: const Value<String?>('user-1'),
              name: '我的分类',
              kind: 'expense',
              isSystem: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simulate a v21 release: no sort_order columns.
      await _dropV15SortOrderColumns(v21db);
      await _restoreThemeSeedColorColumn(v21db);
      await _dropTakenOverByPlanColumn(v21db);
      await _dropV25HomeBlockColumns(v21db);
      await _dropV26LifeEnergyTables(v21db);
      await _dropV32LifeEnergyPrefsColumn(v21db);
      await v21db.customStatement('PRAGMA user_version = 21');
      await v21db.close();

      // Reopen with the current schema: this runs the 21 -> 22 migration.
      final db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

      final categoryColumns = await db
          .customSelect('PRAGMA table_info(money_categories)')
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toList());
      expect(categoryColumns, contains('sort_order'));

      final subCategoryColumns = await db
          .customSelect('PRAGMA table_info(money_sub_categories)')
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toList());
      expect(subCategoryColumns, contains('sort_order'));

      final rows = await (db.select(db.moneyCategories)).get();
      final byId = {for (final row in rows) row.id: row};
      // 内置分类按种子声明顺序回填（餐饮是第 1 个）。
      expect(byId['expense_food']!.sortOrder, 1);
      expect(byId['expense_food']!.name, '餐饮');
      // 用户自建分类保持 0：排序时视为最后，不会插到内置分类前面。
      expect(byId['custom-1']!.sortOrder, 0);

      await db.close();
    },
  );

  test(
    'v20 -> v21 upgrade adds the home preference columns with safe defaults',
    () async {
      final now = DateTime.now().toUtc();

      final v20db = AppDatabase(NativeDatabase(dbFile));
      await v20db
          .into(v20db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v20db
          .into(v20db.userPreferences)
          .insert(
            UserPreferencesCompanion.insert(
              userId: 'user-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simulate a v20 release: drop the V1.4 columns that v20 lacked.
      await _dropV14PreferenceColumns(v20db);
      await _dropV15SortOrderColumns(v20db);
      await _restoreThemeSeedColorColumn(v20db);
      await _dropTakenOverByPlanColumn(v20db);
      await _dropV25HomeBlockColumns(v20db);
      await _dropV26LifeEnergyTables(v20db);
      await _dropV32LifeEnergyPrefsColumn(v20db);
      await v20db.customStatement('PRAGMA user_version = 20');
      await v20db.close();

      // Reopen with the current schema: this runs the 20 -> 21 migration.
      final db = AppDatabase(NativeDatabase(dbFile));
      await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

      final columns = await db
          .customSelect('PRAGMA table_info(user_preferences)')
          .get()
          .then((rows) => rows.map((r) => r.read<String>('name')).toList());
      expect(
        columns,
        containsAll(['mask_money_amounts', 'show_home_health_strip']),
      );

      // 老用户默认不隐藏金额、不显示健康条。
      final preferences = await (db.select(db.userPreferences)).getSingle();
      expect(preferences.userId, 'user-1');
      expect(preferences.maskMoneyAmounts, isFalse);
      expect(preferences.showHomeHealthStrip, isFalse);
      await db.close();
    },
  );

  test('v24 -> v25 upgrade adds home block layout columns', () async {
    final now = DateTime.now().toUtc();

    final v24db = AppDatabase(NativeDatabase(dbFile));
    await v24db
        .into(v24db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v24db
        .into(v24db.userPreferences)
        .insert(
          UserPreferencesCompanion.insert(
            userId: 'user-1',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v24 release: no home block columns.
    await _dropV25HomeBlockColumns(v24db);
    await _dropV26LifeEnergyTables(v24db);
    await _dropV32LifeEnergyPrefsColumn(v24db);
    await v24db.customStatement('PRAGMA user_version = 24');
    await v24db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

    final columns = await db
        .customSelect('PRAGMA table_info(user_preferences)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toList());
    expect(
      columns,
      containsAll([
        'home_block_visibility',
        'home_block_order',
        'home_layout_mode',
        'home_pager_tabs',
      ]),
    );

    final preferences = await (db.select(db.userPreferences)).getSingle();
    expect(preferences.homeBlockVisibility, isNull);
    expect(preferences.homeBlockOrder, isNull);
    expect(preferences.homeLayoutMode, 'pager');
    expect(preferences.homePagerTabs, isFalse);
    await db.close();
  });
  test('v25 -> v26 upgrade creates the life energy tables', () async {
    final now = DateTime.now().toUtc();

    final v25db = AppDatabase(NativeDatabase(dbFile));
    await v25db
        .into(v25db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v25 release: the three tables did not exist yet.
    await _dropV26LifeEnergyTables(v25db);
    await _dropV32LifeEnergyPrefsColumn(v25db);
    await v25db.customStatement('PRAGMA user_version = 25');
    await v25db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    await db.customSelect('SELECT COUNT(*) FROM users').getSingle();

    expect(await (db.select(db.lifeEnergyProfiles)).get(), isEmpty);
    expect(await (db.select(db.wishlistItems)).get(), isEmpty);
    expect(await (db.select(db.overtimeEntries)).get(), isEmpty);

    // 档案的主键是 userId —— 一个账号一份，不能是 id。
    final columns = await db
        .customSelect('PRAGMA table_info(life_energy_profiles)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toList());
    expect(columns, containsAll(['user_id', 'pay_amount_minor', 'pay_cycle']));

    await db.close();
  });

  test('v26 -> v27 upgrade creates the salary segments table', () async {
    final now = DateTime.now().toUtc();

    final v26db = AppDatabase(NativeDatabase(dbFile));
    await v26db
        .into(v26db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v26 release: only the life energy tables existed, and the
    // gross-mode columns did not exist yet either.
    await _dropV28PayrollColumns(v26db);
    await v26db.customStatement('DROP TABLE IF EXISTS salary_segments');
    await _dropV32LifeEnergyPrefsColumn(v26db);
    await v26db.customStatement('PRAGMA user_version = 26');
    await v26db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    expect(await (db.select(db.salarySegments)).get(), isEmpty);

    final columns = await db
        .customSelect('PRAGMA table_info(salary_segments)')
        .get()
        .then((rows) => rows.map((r) => r.read<String>('name')).toList());
    expect(
      columns,
      containsAll([
        'employer',
        'effective_year',
        'effective_month',
        'amount_minor',
        'pay_cycle',
        'commute_minutes_per_day',
        'work_cost_monthly_minor',
      ]),
    );

    // 覆盖列必须可空：null 表示「继承档案」，这是冻结逻辑的前提。
    final notNull = await db
        .customSelect('PRAGMA table_info(salary_segments)')
        .get()
        .then(
          (rows) => {
            for (final r in rows)
              r.read<String>('name'): r.read<int>('notnull'),
          },
        );
    expect(notNull['commute_minutes_per_day'], 0);
    expect(notNull['work_cost_monthly_minor'], 0);
    expect(notNull['employer'], 0);

    await db.close();
  });

  test('v27 -> v28 upgrade adds the payroll columns', () async {
    final now = DateTime.now().toUtc();

    final v27db = AppDatabase(NativeDatabase(dbFile));
    await v27db
        .into(v27db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v27db
        .into(v27db.lifeEnergyProfiles)
        .insert(
          LifeEnergyProfilesCompanion.insert(
            userId: 'user-1',
            payAmountMinor: 1200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Simulate a v27 release: no gross-mode columns yet.
    await _dropV28PayrollColumns(v27db);
    await _dropV32LifeEnergyPrefsColumn(v27db);
    await v27db.customStatement('PRAGMA user_version = 27');
    await v27db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final profile = await (db.select(db.lifeEnergyProfiles)).getSingle();

    // 老档案不被重新解释成税前：口径默认 net、税前留空。
    expect(profile.compensationMode, 'net');
    expect(profile.grossMonthlyMinor, 0);
    expect(profile.payAmountMinor, 1200000);
    // 比例有默认值（北京口径），切过去就能算，不用先填十几个字段。
    expect(profile.rateHousingFundBp, 1200);
    expect(profile.ratePensionBp, 800);
    expect(profile.socialBaseFloorMinor, 682100);

    final segmentColumns = await db
        .customSelect('PRAGMA table_info(salary_segments)')
        .get()
        .then(
          (rows) => {
            for (final r in rows)
              r.read<String>('name'): r.read<int>('notnull'),
          },
        );
    // 段的税前列必须可空：null = 这一段是在「直接填到手」时记的。
    expect(segmentColumns['gross_amount_minor'], 0);

    await db.close();
  });

  test('v28 -> v29 adds the payroll snapshot and drops the orphan '
      'city_preset_id column', () async {
    final now = DateTime.now().toUtc();

    final v28db = AppDatabase(NativeDatabase(dbFile));
    await v28db
        .into(v28db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v28db
        .into(v28db.lifeEnergyProfiles)
        .insert(
          LifeEnergyProfilesCompanion.insert(
            userId: 'user-1',
            payAmountMinor: 1200000,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v28db
        .into(v28db.salarySegments)
        .insert(
          SalarySegmentsCompanion.insert(
            id: 'seg-1',
            userId: 'user-1',
            effectiveYear: 2025,
            effectiveMonth: 1,
            amountMinor: 1600000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _simulateV28Schema(v28db);
    await _dropV32LifeEnergyPrefsColumn(v28db);
    await v28db.customStatement('PRAGMA user_version = 28');
    await v28db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final segment = await (db.select(db.salarySegments)).getSingle();
    // 老段留空 = 继续跟随档案，升级后历史数字一点不变。
    expect(segment.payrollJson, isNull);
    expect(segment.amountMinor, 1600000);

    final profileColumns = await db
        .customSelect("PRAGMA table_info('life_energy_profiles')")
        .get()
        .then((rows) => {for (final r in rows) r.read<String>('name')});
    expect(profileColumns.contains('city_preset_id'), isFalse);

    await db.close();
  });

  test('v29 -> v30 moves the bonus into bonus_payments without inventing '
      'a year', () async {
    final now = DateTime.now().toUtc();

    final v29db = AppDatabase(NativeDatabase(dbFile));
    await v29db
        .into(v29db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v29db
        .into(v29db.lifeEnergyProfiles)
        .insert(
          LifeEnergyProfilesCompanion.insert(
            userId: 'user-1',
            payAmountMinor: 1200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _simulateV29Schema(v29db);
    // 老版本的奖金：先写进来，再看迁移有没有把它搬走。
    await v29db.customStatement(
      "UPDATE life_energy_profiles SET bonus_minor = 3600000 "
      "WHERE user_id = 'user-1'",
    );
    await _dropV32LifeEnergyPrefsColumn(v29db);
    await v29db.customStatement('PRAGMA user_version = 29');
    await v29db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final bonuses = await db.select(db.bonusPayments).get();
    expect(bonuses, hasLength(1));
    expect(bonuses.single.amountMinor, 3600000);
    // **不猜年份**：搬过来时标成「未指定」，不进任何一年的账。
    expect(bonuses.single.taxYear, 0);

    final profileColumns = await db
        .customSelect("PRAGMA table_info('life_energy_profiles')")
        .get()
        .then((rows) => {for (final r in rows) r.read<String>('name')});
    expect(profileColumns.contains('bonus_minor'), isFalse);

    await db.close();
  });

  test(
    'v30 -> v31 dedupes bonus rows and adds the per-year unique index',
    () async {
      final now = DateTime.now().toUtc();

      final v30db = AppDatabase(NativeDatabase(dbFile));
      await v30db
          .into(v30db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v30db
          .into(v30db.lifeEnergyProfiles)
          .insert(
            LifeEnergyProfilesCompanion.insert(
              userId: 'user-1',
              payAmountMinor: 1200000,
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _simulateV30Schema(v30db);
      // 同一年两条（迁移前的脏数据）：保留 updated_at 更新的那条。
      await v30db.customStatement(
        'INSERT INTO bonus_payments (id, user_id, tax_year, amount_minor, '
        'source_label, note, version, is_deleted, created_at, updated_at) VALUES '
        "('old', 'user-1', 2026, 100000, NULL, NULL, 1, 0, 100, 100), "
        "('new', 'user-1', 2026, 200000, NULL, NULL, 1, 0, 100, 200)",
      );
      await _dropV32LifeEnergyPrefsColumn(v30db);
      await v30db.customStatement('PRAGMA user_version = 30');
      await v30db.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      final active = await (db.select(
        db.bonusPayments,
      )..where((row) => row.isDeleted.equals(false))).get();
      expect(active, hasLength(1));
      expect(active.single.id, 'new');
      expect(active.single.amountMinor, 200000);

      // 软删掉的那条还在（可追溯），只是不再占唯一位。
      expect(await db.select(db.bonusPayments).get(), hasLength(2));

      // 索引真的挡住了第二条同年记录。
      var threw = false;
      try {
        await db.customStatement(
          'INSERT INTO bonus_payments (id, user_id, tax_year, amount_minor, '
          'source_label, note, version, is_deleted, created_at, updated_at) VALUES '
          "('dup', 'user-1', 2026, 300000, NULL, NULL, 1, 0, 300, 300)",
        );
      } on Exception {
        threw = true;
      }
      expect(threw, isTrue, reason: '一年只能有一条未被删除的记录');

      await db.close();
    },
  );

  test(
    'v31 -> v32 adds the life energy prefs column and keeps it nullable',
    () async {
      final now = DateTime.now().toUtc();
      final v31db = AppDatabase(NativeDatabase(dbFile));
      await v31db
          .into(v31db.users)
          .insert(
            UsersCompanion.insert(
              id: 'user-1',
              username: 'demo',
              email: 'demo@example.com',
              displayName: 'Demo',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await v31db
          .into(v31db.userPreferences)
          .insert(
            UserPreferencesCompanion.insert(
              userId: 'user-1',
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _dropV32LifeEnergyPrefsColumn(v31db);
      await v31db.customStatement('PRAGMA user_version = 31');
      await v31db.close();

      final db = AppDatabase(NativeDatabase(dbFile));
      final prefs = await db.select(db.userPreferences).getSingle();
      // 老用户升级后这一列是空的：界面回到默认（换算 / 最近加入 / 今年）。
      expect(prefs.lifeEnergyPrefs, isNull);
      expect(prefs.userId, 'user-1');

      await db.close();
    },
  );

  test('v32 -> v33 restores the sync columns on the profile row', () async {
    final now = DateTime.now().toUtc();
    final v32db = AppDatabase(NativeDatabase(dbFile));
    await v32db
        .into(v32db.users)
        .insert(
          UsersCompanion.insert(
            id: 'user-1',
            username: 'demo',
            email: 'demo@example.com',
            displayName: 'Demo',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await v32db
        .into(v32db.lifeEnergyProfiles)
        .insert(
          LifeEnergyProfilesCompanion.insert(
            userId: 'user-1',
            payAmountMinor: 1200000,
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _simulateV32ProfileColumns(v32db);
    await v32db.customStatement('PRAGMA user_version = 32');
    await v32db.close();

    final db = AppDatabase(NativeDatabase(dbFile));
    final profile = await db.select(db.lifeEnergyProfiles).getSingle();
    // 没有 version 就没法判定冲突，所以默认值必须是 1 而不是 0。
    expect(profile.version, 1);
    expect(profile.isDeleted, isFalse);
    expect(profile.deviceId, isNull);
    // 老数据本身不能丢。
    expect(profile.payAmountMinor, 1200000);

    await db.close();
  });
}
