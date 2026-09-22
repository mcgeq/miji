import 'package:drift/drift.dart' show Value;
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

  test(
    'keeps the seed business order when nothing has been used yet',
    () async {
      // 种子按声明顺序写入 sort_order（餐饮=1、交通=2 …），
      // 排序在「无用量」时就应该落到这个业务顺序，而不是中文码点序。
      // ensureReadyForUser 内部会跑一次种子（含内置分类的业务顺序）。
      await repository.ensureReadyForUser('user_1');

      final catalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;

      final names = catalog.categories.map((c) => c.name).toList();
      // 种子前几个：餐饮 / 交通 / 购物 / 居住缴费。
      expect(names.take(4).toList(), ['餐饮', '交通', '购物', '居住缴费']);
      // 码点序（交通/人情礼金/其他支出…）不再是兜底顺序。
      expect(names.first, isNot('交通'));

      final first = catalog.categoryById('expense_food')!;
      final second = catalog.categoryById('expense_transport')!;
      expect(first.sortOrder, lessThan(second.sortOrder));

      // 子分类同理：餐饮下第一个应该是种子里的第一个。
      final foodSubs = catalog.subCategoriesFor('expense_food');
      expect(foodSubs.first.name, '早餐');
      expect(foodSubs.first.sortOrder, lessThan(foodSubs[1].sortOrder));
    },
  );

  test(
    'user-created categories append to the end of the business order',
    () async {
      // ensureReadyForUser 内部会跑一次种子（含内置分类的业务顺序）。
      await repository.ensureReadyForUser('user_1');

      final created = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(
          name: '自定义尾部分类',
          kind: MoneyCategoryKind.expense,
        ),
      );

      final catalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;

      // sort_order 取 max + 1 → 排在所有内置分类之后。
      final maxSystemOrder = catalog.categories
          .where((c) => c.isSystem)
          .map((c) => c.sortOrder)
          .reduce((a, b) => a > b ? a : b);
      expect(created.sortOrder, maxSystemOrder + 1);
      expect(catalog.categories.last.id, created.id);
    },
  );

  test(
    'sortOrder of 0 (e.g. missing in a sync payload) sinks to the end',
    () async {
      // ensureReadyForUser 内部会跑一次种子（含内置分类的业务顺序）。
      await repository.ensureReadyForUser('user_1');

      // 模拟同步下来缺失 sort_order 的记录。
      await database
          .into(database.moneyCategories)
          .insert(
            MoneyCategoriesCompanion.insert(
              id: 'legacy-category',
              userId: const Value<String?>('user_1'),
              name: '阿历史分类',
              kind: 'expense',
              createdAt: DateTime.utc(2026, 1, 2),
              updatedAt: DateTime.utc(2026, 1, 2),
            ),
          );

      final catalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;

      // 0 视为未设置 → 排最后，即使它的名字在码点序里很靠前（阿…）。
      expect(catalog.categories.last.id, 'legacy-category');
    },
  );
}
