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

      for (var index = 0; index < defaultMoneyCategorySeeds.length; index++) {
        final category = defaultMoneyCategorySeeds[index];
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
                // 业务顺序 = 种子声明顺序（餐饮/交通/购物…）。
                sortOrder: Value(index + 1),
                isDeleted: const Value(false),
                deletedAt: const Value<DateTime?>(null),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );

        for (
          var subIndex = 0;
          subIndex < category.subCategories.length;
          subIndex++
        ) {
          final subCategory = category.subCategories[subIndex];
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
                  sortOrder: Value(subIndex + 1),
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

    await _seedHealthDefaults(userId, now);
    await _seedCheckinDefaults(userId, now);
  }

  /// 每个用户一份生理周期设置。
  ///
  /// 健康模块的其它查询（`_activeSettingsForUser`）都依赖这一行；
  /// 缺失时会直接抛错，因此这里是必要的用户级种子。
  Future<void> _seedHealthDefaults(String userId, DateTime now) async {
    await database.transaction(() async {
      final existing =
          await (database.select(database.healthPeriodSettings)
                ..where(
                  (row) =>
                      row.userId.equals(userId) & row.isDeleted.equals(false),
                )
                ..limit(1))
              .getSingleOrNull();
      if (existing != null) {
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
              reminderDays: 1,
              periodTrackingEnabled: const Value(true),
              periodReminderEnabled: const Value(false),
              ovulationReminderEnabled: const Value(false),
              pmsReminderEnabled: const Value(false),
              dataSyncEnabled: const Value(true),
              analyticsEnabled: const Value(false),
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    });
  }

  Future<void> _seedCheckinDefaults(String userId, DateTime now) async {
    // 只要该用户曾经有过任何计划（包括已软删除的），就不再预置默认计划，
    // 避免用户删光默认计划后，下次启动/升级应用时又被重新创建。
    final existingPlan =
        await (database.select(database.checkinPlans)
              ..where((row) => row.userId.equals(userId))
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
