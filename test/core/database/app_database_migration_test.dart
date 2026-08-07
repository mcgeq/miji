import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';

/// Reproduces the phone upgrade path: an existing database from a previous
/// release (schema v15/v16/v17/v18) is opened by the current v19 code.
///
/// The old database is simulated by creating the current schema, dropping the
/// todo tables (which did not exist at v15) or the V1.1 columns (v16), then
/// rewinding `user_version`.
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
    await v18db.customStatement('PRAGMA user_version = 15');
    await v18db.close();

    // Reopen with the current schema: this runs the 15 -> 19 migration.
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
    await v18db.customStatement('DROP TABLE IF EXISTS todo_task_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_tags');
    await v18db.customStatement('DROP TABLE IF EXISTS todo_recurrence_rules');
    await v18db.customStatement('PRAGMA user_version = 16');
    await v18db.close();

    // Reopen with the current schema: this runs the 16 -> 19 migration.
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
              themeSeedColor: 0xFF6750A4,
              createdAt: now,
              updatedAt: now,
            ),
          );

      // Simulate a v18 release: drop the V1.3 column that v18 lacked.
      await v19db.customStatement(
        'ALTER TABLE user_preferences DROP COLUMN show_home_today_action',
      );
      await v19db.customStatement('PRAGMA user_version = 18');
      await v19db.close();

      // Reopen with the current schema: this runs the 18 -> 19 migration.
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
}
