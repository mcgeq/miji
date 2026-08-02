import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';

void main() {
  late AppDatabase database;
  late DatabaseSeedRunner seedRunner;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    seedRunner = DatabaseSeedRunner(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  test('seeds currencies and system categories on first run', () async {
    await seedRunner.seedGlobalDefaults();

    final currencies = await database.select(database.moneyCurrencies).get();
    expect(currencies.length, greaterThanOrEqualTo(10));

    final categories = await (database.select(
      database.moneyCategories,
    )..where((category) => category.userId.isNull())).get();
    expect(categories, isNotEmpty);
    expect(categories.every((category) => !category.isDeleted), isTrue);
  });

  test('re-running seedGlobalDefaults does not resurrect a soft-deleted '
      'system category', () async {
    await seedRunner.seedGlobalDefaults();

    final category =
        await (database.select(database.moneyCategories)
              ..where((row) => row.userId.isNull())
              ..limit(1))
            .getSingle();
    await (database.update(
      database.moneyCategories,
    )..where((row) => row.id.equals(category.id))).write(
      MoneyCategoriesCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.utc(2026, 7, 1)),
      ),
    );

    await seedRunner.seedGlobalDefaults();

    final after = await (database.select(
      database.moneyCategories,
    )..where((row) => row.id.equals(category.id))).getSingle();
    expect(after.isDeleted, isTrue);
    expect(after.deletedAt, isNot(isNull));
  });

  test('re-running seedGlobalDefaults does not overwrite a renamed '
      'system category', () async {
    await seedRunner.seedGlobalDefaults();

    final category =
        await (database.select(database.moneyCategories)
              ..where((row) => row.userId.isNull())
              ..limit(1))
            .getSingle();
    await (database.update(database.moneyCategories)
          ..where((row) => row.id.equals(category.id)))
        .write(const MoneyCategoriesCompanion(name: Value('自定义名称')));

    await seedRunner.seedGlobalDefaults();

    final after = await (database.select(
      database.moneyCategories,
    )..where((row) => row.id.equals(category.id))).getSingle();
    expect(after.name, '自定义名称');
  });

  test('re-running seedUserDefaults does not resurrect soft-deleted '
      'default checkin plans', () async {
    const userId = 'user-1';
    await seedRunner.seedUserDefaults(userId);

    final plans = await (database.select(
      database.checkinPlans,
    )..where((row) => row.userId.equals(userId))).get();
    expect(plans.length, 3);

    await (database.update(
      database.checkinPlans,
    )..where((row) => row.userId.equals(userId))).write(
      CheckinPlansCompanion(
        isDeleted: const Value(true),
        deletedAt: Value(DateTime.utc(2026, 7, 1)),
      ),
    );

    await seedRunner.seedUserDefaults(userId);

    final after = await (database.select(
      database.checkinPlans,
    )..where((row) => row.userId.equals(userId))).get();
    expect(after.length, 3);
    expect(after.every((plan) => plan.isDeleted), isTrue);
  });

  test(
    'seedUserDefaults seeds default checkin plans only once per user',
    () async {
      const userId = 'user-2';
      await seedRunner.seedUserDefaults(userId);
      await seedRunner.seedUserDefaults(userId);

      final plans = await (database.select(
        database.checkinPlans,
      )..where((row) => row.userId.equals(userId))).get();
      expect(plans.length, 3);
    },
  );
}
