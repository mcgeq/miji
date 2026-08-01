import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/money_seed_data.dart';

class DatabaseSeedRunner {
  const DatabaseSeedRunner({required this.database, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid _uuid;

  Future<void> seedGlobalDefaults() async {
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      for (final currency in defaultCurrencySeeds) {
        await database
            .into(database.moneyCurrencies)
            .insert(
              MoneyCurrenciesCompanion.insert(
                code: currency.code,
                locale: currency.locale,
                symbol: currency.symbol,
                isDefault: Value(currency.isDefault),
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      for (final category in defaultMoneyCategorySeeds) {
        await database
            .into(database.moneyCategories)
            .insert(
              MoneyCategoriesCompanion.insert(
                id: category.id,
                userId: const Value<String?>(null),
                name: category.name,
                kind: category.kind,
                color: Value(category.color),
                icon: Value(category.icon),
                isSystem: const Value(true),
                isDeleted: const Value(false),
                deletedAt: const Value<DateTime?>(null),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );

        for (final subCategory in category.subCategories) {
          await database
              .into(database.moneySubCategories)
              .insert(
                MoneySubCategoriesCompanion.insert(
                  id: subCategory.id,
                  categoryId: category.id,
                  userId: const Value<String?>(null),
                  name: subCategory.name,
                  kind: subCategory.kind,
                  color: Value(subCategory.color),
                  icon: Value(subCategory.icon),
                  isSystem: const Value(true),
                  isDeleted: const Value(false),
                  deletedAt: const Value<DateTime?>(null),
                  createdAt: now,
                  updatedAt: now,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      }
    });
  }

  Future<void> seedUserDefaults(String userId) async {
    final now = DateTime.now().toUtc();

    await database.transaction(() async {
      final existingSetting =
          await (database.select(database.healthPeriodSettings)
                ..where(
                  (setting) =>
                      setting.userId.equals(userId) &
                      setting.isDeleted.equals(false),
                )
                ..limit(1))
              .getSingleOrNull();

      if (existingSetting != null) {
        return;
      }

      await database
          .into(database.healthPeriodSettings)
          .insert(
            HealthPeriodSettingsCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              averageCycleLength: 28,
              averagePeriodLength: 5,
              periodTrackingEnabled: const Value(true),
              periodReminderEnabled: const Value(false),
              ovulationReminderEnabled: const Value(false),
              pmsReminderEnabled: const Value(false),
              reminderDays: 1,
              dataSyncEnabled: const Value(true),
              analyticsEnabled: const Value(false),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }
}
