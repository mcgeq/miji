part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Categories on _DriftMoneyRepositoryBase {
  @override
  Stream<MoneyCategoryCatalog> watchCategoryCatalogForUser(
    String userId,
    MoneyCategoryKind kind, {
    bool includeDeleted = false,
  }) async* {
    await ensureReadyForUser(userId);

    final categoryQuery = database.select(database.moneyCategories)
      ..where((category) {
        final basePredicate =
            category.kind.equals(kind.storageValue) &
            (category.userId.isNull() | category.userId.equals(userId));
        return includeDeleted
            ? basePredicate
            : basePredicate & category.isDeleted.equals(false);
      })
      // 不再用 isSystem 排序：种子数据里所有内置分类都是 system=true，
      // 这一层对它们没有区分度，只会把用户自建分类（往往最在意）永远压到后面。
      ..orderBy([(category) => OrderingTerm.asc(category.name)]);

    await for (final categoryRows in categoryQuery.watch()) {
      final categoryIds = categoryRows.map((category) => category.id).toList();
      final subCategoryRows = categoryIds.isEmpty
          ? const <MoneySubCategory>[]
          : await (database.select(database.moneySubCategories)
                  ..where((subCategory) {
                    final basePredicate =
                        subCategory.kind.equals(kind.storageValue) &
                        subCategory.categoryId.isIn(categoryIds) &
                        (subCategory.userId.isNull() |
                            subCategory.userId.equals(userId));
                    return includeDeleted
                        ? basePredicate
                        : basePredicate & subCategory.isDeleted.equals(false);
                  })
                  ..orderBy([
                    (subCategory) => OrderingTerm.desc(subCategory.isSystem),
                    (subCategory) => OrderingTerm.asc(subCategory.name),
                  ]))
                .get();

      final categoryUsageRanks = await _categoryUsageRanks(userId);
      final subCategoryUsageRanks = await _subCategoryUsageRanks(userId);
      final categories = categoryRows.map(_mapCategory).toList();
      final subCategories = subCategoryRows.map(_mapSubCategory).toList();
      _sortCategoriesByUsage(categories, categoryUsageRanks);
      _sortSubCategoriesByUsage(subCategories, subCategoryUsageRanks);

      yield MoneyCategoryCatalog(
        categories: categories,
        subCategories: subCategories,
      );
    }
  }

  @override
  Future<MoneyCategoryEntity> createCategory(
    String userId,
    MoneyCategoryDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidCategoryName,
        );
      }

      final now = DateTime.now().toUtc();
      final categoryId = _uuid.v4();
      final nextSortOrder = await _nextCategorySortOrder(userId, draft.kind);
      await database
          .into(database.moneyCategories)
          .insert(
            MoneyCategoriesCompanion.insert(
              id: categoryId,
              userId: Value<String?>(userId),
              name: name,
              kind: draft.kind.storageValue,
              color: Value<String?>(draft.color),
              icon: Value<String?>(draft.icon),
              isSystem: const Value(false),
              // 自建分类追加到业务顺序末尾。
              sortOrder: Value(nextSortOrder),
              deviceId: const Value<String?>(null),
              version: const Value(1),
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _recordCategoryChange(
        userId: userId,
        recordId: categoryId,
        operation: SyncChangeOperation.insert,
        changedFields: _categoryDraftSyncFields(
          draft,
          sortOrder: nextSortOrder,
        ),
        afterVersion: 1,
      );

      return _mapCategory(
        await _getCustomCategoryForUser(
          userId,
          categoryId,
          includeDeleted: true,
        ),
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyCategoryEntity> updateCategory(
    String userId,
    MoneyCategoryUpdate update,
  ) async {
    try {
      final existing = await _getCustomCategoryForUser(userId, update.id);
      final name = update.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyCategories)..where(
            (category) =>
                category.id.equals(update.id) &
                category.userId.equals(userId) &
                category.isSystem.equals(false) &
                category.isDeleted.equals(false),
          ))
          .write(
            MoneyCategoriesCompanion(
              name: Value(name),
              color: Value<String?>(update.color),
              icon: Value<String?>(update.icon),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await _recordCategoryChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: _categoryUpdateSyncFields(update),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );

      return _mapCategory(await _getCustomCategoryForUser(userId, update.id));
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> deleteCategory(String userId, String categoryId) async {
    try {
      final existing = await _getCustomCategoryForUser(userId, categoryId);
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyCategories)..where(
            (category) =>
                category.id.equals(categoryId) &
                category.userId.equals(userId) &
                category.isSystem.equals(false) &
                category.isDeleted.equals(false),
          ))
          .write(
            MoneyCategoriesCompanion(
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordCategoryChange(
        userId: userId,
        recordId: categoryId,
        operation: SyncChangeOperation.delete,
        changedFields: _deleteSyncFields(now),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> restoreCategory(String userId, String categoryId) async {
    try {
      final existing = await _getCustomCategoryForUser(
        userId,
        categoryId,
        includeDeleted: true,
      );
      if (!existing.isDeleted) {
        return;
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyCategories)..where(
            (category) =>
                category.id.equals(categoryId) &
                category.userId.equals(userId) &
                category.isSystem.equals(false),
          ))
          .write(
            MoneyCategoriesCompanion(
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordCategoryChange(
        userId: userId,
        recordId: categoryId,
        operation: SyncChangeOperation.update,
        changedFields: _restoreSyncFields(),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<MoneySubCategoryEntity> createSubCategory(
    String userId,
    MoneySubCategoryDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await _assertCategoryForUser(userId, draft.categoryId, draft.kind);
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }

      final now = DateTime.now().toUtc();
      final subCategoryId = _uuid.v4();
      final nextSortOrder = await _nextSubCategorySortOrder(
        userId,
        draft.categoryId,
      );
      await database
          .into(database.moneySubCategories)
          .insert(
            MoneySubCategoriesCompanion.insert(
              id: subCategoryId,
              categoryId: draft.categoryId,
              userId: Value<String?>(userId),
              name: name,
              kind: draft.kind.storageValue,
              color: Value<String?>(draft.color),
              icon: Value<String?>(draft.icon),
              isSystem: const Value(false),
              // 自建子分类追加到该分类内的末尾。
              sortOrder: Value(nextSortOrder),
              deviceId: const Value<String?>(null),
              version: const Value(1),
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _recordSubCategoryChange(
        userId: userId,
        recordId: subCategoryId,
        operation: SyncChangeOperation.insert,
        changedFields: _subCategoryDraftSyncFields(
          draft,
          sortOrder: nextSortOrder,
        ),
        afterVersion: 1,
      );

      return _mapSubCategory(
        await _getCustomSubCategoryForUser(
          userId,
          subCategoryId,
          includeDeleted: true,
        ),
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<MoneySubCategoryEntity> updateSubCategory(
    String userId,
    MoneySubCategoryUpdate update,
  ) async {
    try {
      final existing = await _getCustomSubCategoryForUser(userId, update.id);
      final name = update.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneySubCategories)..where(
            (subCategory) =>
                subCategory.id.equals(update.id) &
                subCategory.userId.equals(userId) &
                subCategory.isSystem.equals(false) &
                subCategory.isDeleted.equals(false),
          ))
          .write(
            MoneySubCategoriesCompanion(
              name: Value(name),
              color: Value<String?>(update.color),
              icon: Value<String?>(update.icon),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await _recordSubCategoryChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: _subCategoryUpdateSyncFields(update),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );

      return _mapSubCategory(
        await _getCustomSubCategoryForUser(userId, update.id),
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> deleteSubCategory(String userId, String subCategoryId) async {
    try {
      final existing = await _getCustomSubCategoryForUser(
        userId,
        subCategoryId,
      );
      final now = DateTime.now().toUtc();
      await (database.update(database.moneySubCategories)..where(
            (subCategory) =>
                subCategory.id.equals(subCategoryId) &
                subCategory.userId.equals(userId) &
                subCategory.isSystem.equals(false) &
                subCategory.isDeleted.equals(false),
          ))
          .write(
            MoneySubCategoriesCompanion(
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordSubCategoryChange(
        userId: userId,
        recordId: subCategoryId,
        operation: SyncChangeOperation.delete,
        changedFields: _deleteSyncFields(now),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> restoreSubCategory(String userId, String subCategoryId) async {
    try {
      final existing = await _getCustomSubCategoryForUser(
        userId,
        subCategoryId,
        includeDeleted: true,
      );
      if (!existing.isDeleted) {
        return;
      }
      await _assertCategoryForUser(
        userId,
        existing.categoryId,
        MoneyCategoryKind.fromStorageValue(existing.kind),
      );
      final now = DateTime.now().toUtc();
      await (database.update(database.moneySubCategories)..where(
            (subCategory) =>
                subCategory.id.equals(subCategoryId) &
                subCategory.userId.equals(userId) &
                subCategory.isSystem.equals(false),
          ))
          .write(
            MoneySubCategoriesCompanion(
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordSubCategoryChange(
        userId: userId,
        recordId: subCategoryId,
        operation: SyncChangeOperation.update,
        changedFields: _restoreSyncFields(),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<void> _recordCategoryChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordCategoryChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordSubCategoryChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordSubCategoryChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Map<String, Object?> _categoryDraftSyncFields(
    MoneyCategoryDraft draft, {
    int? sortOrder,
  }) {
    return {
      'user_id': null,
      'name': draft.name.trim(),
      'kind': draft.kind.storageValue,
      'color': _blankToNull(draft.color),
      'icon': _blankToNull(draft.icon),
      'is_system': false,
      'sort_order': ?sortOrder,
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _categoryUpdateSyncFields(MoneyCategoryUpdate update) {
    return {
      'name': update.name.trim(),
      'color': _blankToNull(update.color),
      'icon': _blankToNull(update.icon),
    };
  }

  Map<String, Object?> _subCategoryDraftSyncFields(
    MoneySubCategoryDraft draft, {
    int? sortOrder,
  }) {
    return {
      'category_id': draft.categoryId,
      'user_id': null,
      'name': draft.name.trim(),
      'kind': draft.kind.storageValue,
      'color': _blankToNull(draft.color),
      'icon': _blankToNull(draft.icon),
      'is_system': false,
      'sort_order': ?sortOrder,
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _subCategoryUpdateSyncFields(
    MoneySubCategoryUpdate update,
  ) {
    return {
      'name': update.name.trim(),
      'color': _blankToNull(update.color),
      'icon': _blankToNull(update.icon),
    };
  }

  Future<MoneyCategory> _getCustomCategoryForUser(
    String userId,
    String categoryId, {
    bool includeDeleted = false,
  }) async {
    final category =
        await (database.select(database.moneyCategories)
              ..where((category) {
                final predicate =
                    category.id.equals(categoryId) &
                    category.userId.equals(userId) &
                    category.isSystem.equals(false);
                return includeDeleted
                    ? predicate
                    : predicate & category.isDeleted.equals(false);
              })
              ..limit(1))
            .getSingleOrNull();

    if (category == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.categoryNotFound,
      );
    }

    return category;
  }

  Future<MoneySubCategory> _getCustomSubCategoryForUser(
    String userId,
    String subCategoryId, {
    bool includeDeleted = false,
  }) async {
    final subCategory =
        await (database.select(database.moneySubCategories)
              ..where((subCategory) {
                final predicate =
                    subCategory.id.equals(subCategoryId) &
                    subCategory.userId.equals(userId) &
                    subCategory.isSystem.equals(false);
                return includeDeleted
                    ? predicate
                    : predicate & subCategory.isDeleted.equals(false);
              })
              ..limit(1))
            .getSingleOrNull();

    if (subCategory == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.categoryNotFound,
      );
    }

    return subCategory;
  }

  // ---------------------------------------------------------------------------
  // 业务顺序重排
  //
  // 关于同步：内置分类（user_id IS NULL, is_system = 1）**不产生同步记录**。
  // 原因是远端应用侧 `_remoteUserId` 要求 payload 里必须有一个非空 user_id，
  // 而内置分类的 user_id 恒为 NULL；硬要同步就得改远端应用对「共享行」的语义
  // （user_id / is_system 回写），风险远大于收益。所以：
  //   * 内置分类的顺序 = 本机设置（拖拽后立即生效，且会持久化）；
  //   * 自建分类的顺序 = 会随分类一起同步到其它设备。
  // 如果以后需要「内置分类顺序也跨设备」，正确做法是单独建一张
  // 「用户 × 分类」顺序偏好表，而不是改这张共享表。
  // ---------------------------------------------------------------------------

  @override
  Future<void> reorderCategories(
    String userId,
    MoneyCategoryKind kind,
    List<String> orderedIds,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final rows =
          await (database.select(database.moneyCategories)..where(
                (category) =>
                    category.kind.equals(kind.storageValue) &
                    category.isDeleted.equals(false) &
                    (category.userId.isNull() | category.userId.equals(userId)),
              ))
              .get();
      if (rows.isEmpty) {
        return;
      }

      final byId = {for (final row in rows) row.id: row};
      final ordered = <MoneyCategory>[];
      for (final id in orderedIds) {
        final row = byId.remove(id);
        if (row != null) {
          ordered.add(row);
        }
      }
      // 没出现在 orderedIds 里的（被筛选/刚好新增）按现有顺序补在后面，
      // 避免漏掉的行被挤到随机位置。
      final remaining = byId.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      ordered.addAll(remaining);

      await database.transaction(() async {
        final now = DateTime.now().toUtc();
        for (var index = 0; index < ordered.length; index++) {
          final row = ordered[index];
          final nextOrder = index + 1;
          if (row.sortOrder == nextOrder) {
            continue;
          }
          await (database.update(
            database.moneyCategories,
          )..where((category) => category.id.equals(row.id))).write(
            MoneyCategoriesCompanion(
              sortOrder: Value(nextOrder),
              version: Value(row.version + 1),
              updatedAt: Value(now),
            ),
          );
          if (row.isSystem) {
            continue;
          }
          await _recordCategoryChange(
            userId: userId,
            recordId: row.id,
            operation: SyncChangeOperation.update,
            changedFields: {'sort_order': nextOrder},
            beforeVersion: row.version,
            afterVersion: row.version + 1,
          );
        }
      });
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> reorderSubCategories(
    String userId,
    String categoryId,
    List<String> orderedIds,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final rows =
          await (database.select(database.moneySubCategories)..where(
                (subCategory) =>
                    subCategory.categoryId.equals(categoryId) &
                    subCategory.isDeleted.equals(false) &
                    (subCategory.userId.isNull() |
                        subCategory.userId.equals(userId)),
              ))
              .get();
      if (rows.isEmpty) {
        return;
      }

      final byId = {for (final row in rows) row.id: row};
      final ordered = <MoneySubCategory>[];
      for (final id in orderedIds) {
        final row = byId.remove(id);
        if (row != null) {
          ordered.add(row);
        }
      }
      final remaining = byId.values.toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      ordered.addAll(remaining);

      await database.transaction(() async {
        final now = DateTime.now().toUtc();
        for (var index = 0; index < ordered.length; index++) {
          final row = ordered[index];
          final nextOrder = index + 1;
          if (row.sortOrder == nextOrder) {
            continue;
          }
          await (database.update(
            database.moneySubCategories,
          )..where((subCategory) => subCategory.id.equals(row.id))).write(
            MoneySubCategoriesCompanion(
              sortOrder: Value(nextOrder),
              version: Value(row.version + 1),
              updatedAt: Value(now),
            ),
          );
          if (row.isSystem) {
            continue;
          }
          await _recordSubCategoryChange(
            userId: userId,
            recordId: row.id,
            operation: SyncChangeOperation.update,
            changedFields: {'sort_order': nextOrder},
            beforeVersion: row.version,
            afterVersion: row.version + 1,
          );
        }
      });
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> resetCategoryOrder(String userId, MoneyCategoryKind kind) async {
    final rows =
        await (database.select(database.moneyCategories)..where(
              (category) =>
                  category.kind.equals(kind.storageValue) &
                  category.isDeleted.equals(false) &
                  (category.userId.isNull() | category.userId.equals(userId)),
            ))
            .get();
    if (rows.isEmpty) {
      return;
    }

    // 内置分类按种子声明顺序；自建分类（以及种子里没有的）按创建时间排在后面。
    final seedIndex = <String, int>{
      for (var i = 0; i < defaultMoneyCategorySeeds.length; i++)
        defaultMoneyCategorySeeds[i].id: i,
    };
    final ordered = _defaultOrder<MoneyCategory>(
      rows,
      isBuiltIn: (row) => row.isSystem,
      seedIndex: (row) => seedIndex[row.id],
      createdAt: (row) => row.createdAt,
      name: (row) => row.name,
    );

    await reorderCategories(
      userId,
      kind,
      ordered.map((row) => row.id).toList(),
    );
  }

  @override
  Future<void> resetSubCategoryOrder(String userId, String categoryId) async {
    final rows =
        await (database.select(database.moneySubCategories)..where(
              (subCategory) =>
                  subCategory.categoryId.equals(categoryId) &
                  subCategory.isDeleted.equals(false) &
                  (subCategory.userId.isNull() |
                      subCategory.userId.equals(userId)),
            ))
            .get();
    if (rows.isEmpty) {
      return;
    }

    final seedIndex = <String, int>{};
    for (final category in defaultMoneyCategorySeeds) {
      for (var i = 0; i < category.subCategories.length; i++) {
        seedIndex[category.subCategories[i].id] = i;
      }
    }
    final ordered = _defaultOrder<MoneySubCategory>(
      rows,
      isBuiltIn: (row) => row.isSystem,
      seedIndex: (row) => seedIndex[row.id],
      createdAt: (row) => row.createdAt,
      name: (row) => row.name,
    );

    await reorderSubCategories(
      userId,
      categoryId,
      ordered.map((row) => row.id).toList(),
    );
  }

  /// 默认顺序：种子里的排前面（按种子下标），其余按创建时间、再按名称。
  List<T> _defaultOrder<T>(
    List<T> rows, {
    required bool Function(T row) isBuiltIn,
    required int? Function(T row) seedIndex,
    required DateTime Function(T row) createdAt,
    required String Function(T row) name,
  }) {
    final ordered = List<T>.of(rows);
    ordered.sort((a, b) {
      final aIndex = seedIndex(a);
      final bIndex = seedIndex(b);
      if (aIndex != null || bIndex != null) {
        if (aIndex == null) return 1;
        if (bIndex == null) return -1;
        return aIndex.compareTo(bIndex);
      }
      // 种子里没有的：内置（理论上不存在）在前，然后按创建时间。
      if (isBuiltIn(a) != isBuiltIn(b)) {
        return isBuiltIn(a) ? -1 : 1;
      }
      final byCreated = createdAt(a).compareTo(createdAt(b));
      return byCreated != 0 ? byCreated : name(a).compareTo(name(b));
    });
    return ordered;
  }

  /// 下一个可用的业务顺序（父分类维度，按 kind 隔离）。
  Future<int> _nextCategorySortOrder(
    String userId,
    MoneyCategoryKind kind,
  ) async {
    final maxOrder = database.moneyCategories.sortOrder.max();
    final query = database.selectOnly(database.moneyCategories)
      ..addColumns([maxOrder])
      ..where(
        database.moneyCategories.kind.equals(kind.storageValue) &
            (database.moneyCategories.userId.isNull() |
                database.moneyCategories.userId.equals(userId)),
      );
    final row = await query.getSingleOrNull();
    return (row?.read(maxOrder) ?? 0) + 1;
  }

  /// 下一个可用的业务顺序（同一父分类内的子分类）。
  Future<int> _nextSubCategorySortOrder(
    String userId,
    String categoryId,
  ) async {
    final maxOrder = database.moneySubCategories.sortOrder.max();
    final query = database.selectOnly(database.moneySubCategories)
      ..addColumns([maxOrder])
      ..where(
        database.moneySubCategories.categoryId.equals(categoryId) &
            (database.moneySubCategories.userId.isNull() |
                database.moneySubCategories.userId.equals(userId)),
      );
    final row = await query.getSingleOrNull();
    return (row?.read(maxOrder) ?? 0) + 1;
  }

  @override
  Future<MoneyCategoryUsage> getCategoryUsageStatsForUser(String userId) async {
    final categoryRanks = await _categoryUsageRanks(userId);
    final subCategoryRanks = await _subCategoryUsageRanks(userId);
    return MoneyCategoryUsage.fromStats(
      categoryStats: {
        for (final entry in categoryRanks.entries)
          entry.key: MoneyUsageStat(
            amountMinor: entry.value.totalAmountMinor,
            useCount: entry.value.useCount,
            lastUsedAt: entry.value.lastUsedAt?.toLocal(),
          ),
      },
      subCategoryStats: {
        for (final entry in subCategoryRanks.entries)
          entry.key: MoneyUsageStat(
            amountMinor: entry.value.totalAmountMinor,
            useCount: entry.value.useCount,
            lastUsedAt: entry.value.lastUsedAt?.toLocal(),
          ),
      },
    );
  }

  Future<Map<String, _UsageStat>> _categoryUsageRanks(String userId) async {
    final rows = await (database.select(
      database.moneyCategoryUsageStats,
    )..where((row) => row.userId.equals(userId))).get();
    return {
      for (final row in rows)
        row.categoryId: _UsageStat(
          useCount: row.useCount,
          totalAmountMinor: row.totalAmountMinor,
          lastUsedAt: row.lastUsedAt,
        ),
    };
  }

  Future<Map<String, _UsageStat>> _subCategoryUsageRanks(String userId) async {
    final rows = await (database.select(
      database.moneySubCategoryUsageStats,
    )..where((row) => row.userId.equals(userId))).get();
    return {
      for (final row in rows)
        row.subCategoryId: _UsageStat(
          useCount: row.useCount,
          totalAmountMinor: row.totalAmountMinor,
          lastUsedAt: row.lastUsedAt,
        ),
    };
  }
}
