import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';

void main() {
  late AppDatabase database;
  late DriftMoneyRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    var nextChangeId = 0;
    repository = DriftMoneyRepository(
      database: database,
      seedRunner: DatabaseSeedRunner(database: database),
      syncChangeLogger: SyncChangeLogger(
        database: database,
        identityResolver: const FixedSyncIdentityResolver(
          SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
        ),
        createId: () => 'change-${nextChangeId += 1}',
        now: () => DateTime.utc(2026, 7, 13, 8),
      ),
    );

    final now = DateTime.utc(2026, 1, 2, 3, 4, 5);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '用户',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'creates and soft deletes custom category from active catalog',
    () async {
      final category = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(
          name: '宠物',
          kind: MoneyCategoryKind.expense,
          color: '#22C55E',
          icon: 'pets',
        ),
      );
      final subCategory = await repository.createSubCategory(
        'user_1',
        MoneySubCategoryDraft(
          categoryId: category.id,
          name: '猫粮',
          kind: MoneyCategoryKind.expense,
          color: '#22C55E',
          icon: 'shopping_bag',
        ),
      );

      final activeCatalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;

      expect(activeCatalog.categoryById(category.id)?.name, '宠物');
      expect(activeCatalog.subCategoryById(subCategory.id)?.name, '猫粮');
      expect(activeCatalog.categoryById(category.id)?.isSystem, isFalse);

      await repository.deleteCategory('user_1', category.id);

      final deletedCatalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;

      expect(deletedCatalog.categoryById(category.id), isNull);
      expect(deletedCatalog.subCategoryById(subCategory.id), isNull);

      final syncRows = await database.select(database.syncChangeLogs).get();
      expect(syncRows.map((row) => row.targetTable), [
        SyncChangeLogger.moneyCategoriesTableName,
        SyncChangeLogger.moneySubCategoriesTableName,
        SyncChangeLogger.moneyCategoriesTableName,
      ]);
      expect(syncRows.map((row) => row.operation), [
        'insert',
        'insert',
        'delete',
      ]);
    },
  );

  test('applies remote custom category and subcategory changes', () async {
    await repository.applyRemoteMoneyChange(
      const DeltaChangeRecord(
        table: SyncChangeLogger.moneyCategoriesTableName,
        recordId: 'remote-category-1',
        operation: 'insert',
        baseVersion: null,
        newVersion: 1,
        changedFields: {},
        recordSnapshot: {
          'id': 'remote-category-1',
          'user_id': 'user_1',
          'name': '宠物',
          'kind': 'expense',
          'color': '#22C55E',
          'icon': 'pets',
          'is_system': false,
          'version': 1,
          'is_deleted': false,
          'created_at': '2026-07-13T08:00:00.000Z',
          'updated_at': '2026-07-13T08:00:00.000Z',
        },
      ),
      null,
    );
    await repository.applyRemoteMoneyChange(
      const DeltaChangeRecord(
        table: SyncChangeLogger.moneySubCategoriesTableName,
        recordId: 'remote-sub-category-1',
        operation: 'insert',
        baseVersion: null,
        newVersion: 1,
        changedFields: {},
        recordSnapshot: {
          'id': 'remote-sub-category-1',
          'category_id': 'remote-category-1',
          'user_id': 'user_1',
          'name': '猫粮',
          'kind': 'expense',
          'color': '#22C55E',
          'icon': 'shopping_bag',
          'is_system': false,
          'version': 1,
          'is_deleted': false,
          'created_at': '2026-07-13T08:00:00.000Z',
          'updated_at': '2026-07-13T08:00:00.000Z',
        },
      ),
      null,
    );

    final catalog = await repository
        .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
        .first;

    expect(catalog.categoryById('remote-category-1')?.name, '宠物');
    expect(catalog.subCategoryById('remote-sub-category-1')?.name, '猫粮');
  });
}
