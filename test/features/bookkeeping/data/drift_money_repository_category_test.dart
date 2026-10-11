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

  /// 读取某行的 version，用于断言「只写变化行」。
  Future<int> versionOfCategory(String id) async {
    final row = await (database.select(
      database.moneyCategories,
    )..where((category) => category.id.equals(id))).getSingle();
    return row.version;
  }

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

  test('applies the sort order coming from a remote change', () async {
    await repository.applyRemoteMoneyChange(
      const DeltaChangeRecord(
        table: SyncChangeLogger.moneyCategoriesTableName,
        recordId: 'remote-category-1',
        operation: 'insert',
        baseVersion: null,
        newVersion: 1,
        changedFields: {'sort_order': 9},
        recordSnapshot: {
          'id': 'remote-category-1',
          'user_id': 'user_1',
          'name': '远端分类',
          'kind': 'expense',
          'color': '#22C55E',
          'icon': 'pets',
          'is_system': false,
          'sort_order': 9,
        },
      ),
      null,
    );

    final row =
        await (database.select(database.moneyCategories)
              ..where((category) => category.id.equals('remote-category-1')))
            .getSingle();
    // 接收端必须落 sort_order，否则拖拽顺序不会跨设备生效。
    expect(row.sortOrder, 9);
  });

  group('reorderCategories（拖拽排序）', () {
    test(
      'reorders built-in categories even though they are system rows',
      () async {
        await repository.ensureReadyForUser('user_1');

        final before = await repository
            .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
            .first;
        final ids = before.categories.map((c) => c.id).toList();
        final reordered = [ids[2], ids[0], ids[1], ...ids.skip(3)];

        await repository.reorderCategories(
          'user_1',
          MoneyCategoryKind.expense,
          reordered,
        );

        final after = await repository
            .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
            .first;
        expect(
          after.categories.map((c) => c.id).take(3).toList(),
          reordered.take(3).toList(),
        );
        expect(after.categories.first.sortOrder, 1);
        expect(after.categories[1].sortOrder, 2);
        // 内置分类不产生同步记录。
        final logs = await database.select(database.syncChangeLogs).get();
        expect(logs, isEmpty);
      },
    );

    test('only writes rows whose order actually changed', () async {
      await repository.ensureReadyForUser('user_1');
      final before = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      final ids = before.categories.map((c) => c.id).toList();
      final versions = <String, int>{};
      for (final id in ids) {
        versions[id] = await versionOfCategory(id);
      }

      // 顺序完全没变 → 不写任何行。
      await repository.reorderCategories(
        'user_1',
        MoneyCategoryKind.expense,
        ids,
      );
      for (final id in ids) {
        expect(await versionOfCategory(id), versions[id], reason: id);
      }

      // 只交换前两个 → 只有前两个 version 增加。
      await repository.reorderCategories('user_1', MoneyCategoryKind.expense, [
        ids[1],
        ids[0],
        ...ids.skip(2),
      ]);
      expect(await versionOfCategory(ids[0]), versions[ids[0]]! + 1);
      expect(await versionOfCategory(ids[1]), versions[ids[1]]! + 1);
      expect(await versionOfCategory(ids[2]), versions[ids[2]]);
    });

    test('keeps rows missing from the list in their previous order', () async {
      await repository.ensureReadyForUser('user_1');
      final before = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      final ids = before.categories.map((c) => c.id).toList();

      await repository.reorderCategories('user_1', MoneyCategoryKind.expense, [
        ids[1],
        ids[0],
      ]);

      final after = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      expect(after.categories.length, ids.length);
      expect(after.categories.map((c) => c.id).take(2).toList(), [
        ids[1],
        ids[0],
      ]);
      expect(
        after.categories.map((c) => c.id).skip(2).toList(),
        ids.skip(2).toList(),
      );
    });

    test('records the order of user categories for sync', () async {
      await repository.ensureReadyForUser('user_1');
      final first = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '自建A', kind: MoneyCategoryKind.expense),
      );
      final second = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '自建B', kind: MoneyCategoryKind.expense),
      );
      final ids =
          (await repository
                  .watchCategoryCatalogForUser(
                    'user_1',
                    MoneyCategoryKind.expense,
                  )
                  .first)
              .categories
              .map((c) => c.id)
              .toList();

      await repository.reorderCategories('user_1', MoneyCategoryKind.expense, [
        second.id,
        first.id,
        ...ids.where((id) => id != first.id && id != second.id),
      ]);

      final logs = await database.select(database.syncChangeLogs).get();
      final reorderLogs = logs.where(
        (row) => row.changedFieldsJson.contains('sort_order'),
      );
      expect(reorderLogs.map((row) => row.recordId).toSet(), {
        first.id,
        second.id,
      });
    });

    test('reorders sub categories inside one parent only', () async {
      await repository.ensureReadyForUser('user_1');
      final catalog = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      final foodSubs = catalog.subCategoriesFor('expense_food');
      final transportSubs = catalog.subCategoriesFor('expense_transport');
      expect(foodSubs.length, greaterThan(2));

      await repository.reorderSubCategories('user_1', 'expense_food', [
        foodSubs[2].id,
        foodSubs[0].id,
        foodSubs[1].id,
        ...foodSubs.skip(3).map((s) => s.id),
      ]);

      final after = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      expect(
        after
            .subCategoriesFor('expense_food')
            .map((s) => s.id)
            .take(3)
            .toList(),
        [foodSubs[2].id, foodSubs[0].id, foodSubs[1].id],
      );
      expect(
        after.subCategoriesFor('expense_transport').map((s) => s.id).toList(),
        transportSubs.map((s) => s.id).toList(),
      );
    });
  });

  test(
    'resetCategoryOrder restores the seed order and pushes custom to the end',
    () async {
      await repository.ensureReadyForUser('user_1');
      final custom = await repository.createCategory(
        'user_1',
        const MoneyCategoryDraft(name: '自建X', kind: MoneyCategoryKind.expense),
      );
      final ids =
          (await repository
                  .watchCategoryCatalogForUser(
                    'user_1',
                    MoneyCategoryKind.expense,
                  )
                  .first)
              .categories
              .map((c) => c.id)
              .toList();

      // 先打乱：把最后一个提到最前。
      await repository.reorderCategories('user_1', MoneyCategoryKind.expense, [
        ids.last,
        ...ids.take(ids.length - 1),
      ]);
      var after = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      expect(after.categories.first.id, ids.last);

      await repository.resetCategoryOrder('user_1', MoneyCategoryKind.expense);

      after = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      // 内置回到种子顺序（餐饮第一），自建排最后。
      expect(after.categories.first.name, '餐饮');
      expect(after.categories.last.id, custom.id);
    },
  );

  test(
    'resetSubCategoryOrder restores the seed order within a parent',
    () async {
      await repository.ensureReadyForUser('user_1');
      final foodSubs =
          (await repository
                  .watchCategoryCatalogForUser(
                    'user_1',
                    MoneyCategoryKind.expense,
                  )
                  .first)
              .subCategoriesFor('expense_food');

      await repository.reorderSubCategories('user_1', 'expense_food', [
        foodSubs.last.id,
        ...foodSubs.take(foodSubs.length - 1).map((s) => s.id),
      ]);
      await repository.resetSubCategoryOrder('user_1', 'expense_food');

      final after = await repository
          .watchCategoryCatalogForUser('user_1', MoneyCategoryKind.expense)
          .first;
      expect(after.subCategoriesFor('expense_food').first.name, '早餐');
    },
  );

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
