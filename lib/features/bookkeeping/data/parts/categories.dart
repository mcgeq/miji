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
      ..orderBy([
        (category) => OrderingTerm.desc(category.isSystem),
        (category) => OrderingTerm.asc(category.name),
      ]);

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
        changedFields: _categoryDraftSyncFields(draft),
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
        changedFields: _subCategoryDraftSyncFields(draft),
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

  Map<String, Object?> _categoryDraftSyncFields(MoneyCategoryDraft draft) {
    return {
      'user_id': null,
      'name': draft.name.trim(),
      'kind': draft.kind.storageValue,
      'color': _blankToNull(draft.color),
      'icon': _blankToNull(draft.icon),
      'is_system': false,
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
    MoneySubCategoryDraft draft,
  ) {
    return {
      'category_id': draft.categoryId,
      'user_id': null,
      'name': draft.name.trim(),
      'kind': draft.kind.storageValue,
      'color': _blankToNull(draft.color),
      'icon': _blankToNull(draft.icon),
      'is_system': false,
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
