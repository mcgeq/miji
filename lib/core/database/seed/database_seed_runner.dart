import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/money_seed_data.dart';
import 'package:miji/core/database/seed/checkin_seed_data.dart';

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
      // ... existing health seed ...
    });

    await _seedCheckinDefaults(userId, now);
  }

  Future<void> _seedCheckinDefaults(String userId, DateTime now) async {
    final existingPlan =
        await (database.select(database.checkinPlans)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existingPlan != null) return;

    // 默认插入 3 个最常用的计划
    const defaultPlanNames = ['喝水', '每日学习', '每日一拍'];
    final templates = allCheckinPlanTemplates
        .where((t) => defaultPlanNames.contains(t.name))
        .toList();

    await database.transaction(() async {
      for (var i = 0; i < templates.length; i++) {
        final t = templates[i];
        await database
            .into(database.checkinPlans)
            .insert(
              CheckinPlansCompanion.insert(
                id: _uuid.v4(),
                userId: userId,
                name: t.name,
                icon: Value(t.icon),
                color: Value(t.color),
                category: Value(t.category),
                planType: Value(t.planType),
                frequencyType: Value(t.frequencyType),
                frequencyConfig: Value(t.frequencyConfig),
                targetValue: Value(t.targetValue),
                targetUnit: Value(t.targetUnit),
                triggerMode: Value(t.triggerMode),
                recordGranularity: Value(t.recordGranularity),
                defaultVisibility: Value(t.defaultVisibility),
                sortOrder: Value(i),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }
}
