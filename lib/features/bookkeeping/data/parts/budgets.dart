part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Budgets on _DriftMoneyRepositoryBase {
  @override
  Stream<List<MoneyBudgetEntity>> watchBudgetsForUser(
    String userId, {
    String? ledgerId,
  }) async* {
    await ensureReadyForUser(userId);
    final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);

    final query = database.select(database.moneyBudgets)
      ..where(
        (budget) =>
            budget.userId.equals(userId) &
            budget.isDeleted.equals(false) &
            _budgetLedgerPredicate(budget, resolvedLedgerId, userId),
      )
      ..orderBy([
        (budget) => OrderingTerm.asc(budget.priority),
        (budget) => OrderingTerm.desc(budget.updatedAt),
      ]);

    yield* query.watch().asyncMap((rows) async {
      final budgets = <MoneyBudgetEntity>[];
      for (final row in rows) {
        budgets.add(await _mapBudget(row));
      }
      return budgets;
    });
  }

  @override
  Stream<List<MoneyBudgetAllocationEntity>> watchBudgetAllocationsForUser(
    String userId,
    String budgetId,
  ) async* {
    await ensureReadyForUser(userId);
    await _getBudgetForUser(userId, budgetId);

    yield await _budgetAllocationsForUserWithUsage(userId, budgetId);
    final updates = database.tableUpdates(
      TableUpdateQuery.onAllTables([
        database.moneyBudgetAllocations,
        database.moneyBudgets,
        database.moneyTransactions,
        database.moneyLedgerTransactions,
        database.moneySplitRecords,
        database.moneySplitRecordDetails,
      ]),
    );

    await for (final _ in updates) {
      yield await _budgetAllocationsForUserWithUsage(userId, budgetId);
    }
  }

  @override
  Stream<List<MoneyBudgetHistorySnapshotEntity>> watchBudgetSnapshotsForUser(
    String userId, {
    String? budgetId,
  }) async* {
    await ensureReadyForUser(userId);
    if (budgetId != null) {
      await _getBudgetForUser(userId, budgetId);
    }

    final query = database.select(database.moneyBudgetSnapshots)
      ..where(
        (snapshot) =>
            snapshot.userId.equals(userId) &
            (budgetId == null
                ? const Constant(true)
                : snapshot.budgetId.equals(budgetId)),
      )
      ..orderBy([
        (snapshot) => OrderingTerm.desc(snapshot.periodStartDate),
        (snapshot) => OrderingTerm.desc(snapshot.capturedAt),
      ]);

    yield* query.watch().map((rows) => rows.map(_mapBudgetSnapshot).toList());
  }

  @override
  Stream<List<MoneyBudgetAllocationHistorySnapshotEntity>>
  watchBudgetAllocationSnapshotsForUser(String userId, String budgetId) async* {
    await ensureReadyForUser(userId);
    await _getBudgetForUser(userId, budgetId);

    final query = database.select(database.moneyBudgetAllocationSnapshots)
      ..where(
        (snapshot) =>
            snapshot.userId.equals(userId) & snapshot.budgetId.equals(budgetId),
      )
      ..orderBy([
        (snapshot) => OrderingTerm.desc(snapshot.capturedAt),
        (snapshot) => OrderingTerm.asc(snapshot.createdAt),
      ]);

    yield* query.watch().map(
      (rows) => rows.map(_mapBudgetAllocationSnapshot).toList(),
    );
  }

  @override
  Future<void> ensureBudgetSnapshotForBudget(
    String userId,
    String budgetId,
  ) async {
    await ensureReadyForUser(userId);
    final budget = await _getBudgetForUser(userId, budgetId);
    await _refreshBudgetSnapshotForBudget(budget);
  }

  @override
  Future<void> refreshBudgetSnapshotsForUser(String userId) async {
    await ensureReadyForUser(userId);
    final budgets =
        await (database.select(database.moneyBudgets)..where(
              (budget) =>
                  budget.userId.equals(userId) & budget.isDeleted.equals(false),
            ))
            .get();
    for (final budget in budgets) {
      await _refreshBudgetSnapshotForBudget(budget);
    }
  }

  @override
  Future<MoneyBudgetEntity> createBudget(
    String userId,
    MoneyBudgetDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await _validateBudgetDraft(userId, draft);
      final ledgerId = await _resolveLedgerId(userId, draft.ledgerId);

      final now = _utcNow();
      final period = await _budgetPeriodForAccount(
        userId: userId,
        periodType: draft.periodType,
        accountId: draft.accountId,
      );
      final budgetId = _uuid.v4();

      await database
          .into(database.moneyBudgets)
          .insert(
            MoneyBudgetsCompanion.insert(
              id: budgetId,
              userId: userId,
              name: draft.name.trim(),
              description: Value<String?>(_blankToNull(draft.description)),
              accountId: Value<String?>(draft.accountId),
              ledgerId: Value<String?>(ledgerId),
              amountMinor: draft.amountMinor,
              currencyCode: draft.currencyCode,
              repeatPeriodType: draft.periodType.storageValue,
              repeatInterval: draft.repeatInterval,
              startDate: _dateKey(period.start),
              endDate: _dateKey(period.end),
              alertEnabled: Value(draft.alertEnabled),
              alertThresholdPercent: Value<int?>(draft.alertThresholdPercent),
              autoRollover: Value(draft.autoRollover),
              color: Value<String?>(draft.color),
              currentPeriodStartDate: _dateKey(period.start),
              lastResetAt: now,
              budgetType: _DriftMoneyRepositoryBase._budgetTypeStandard,
              trackingType: Value(draft.trackingType.storageValue),
              scopeType: _budgetScopeType(
                scopeType: draft.scopeType,
                categoryId: draft.categoryId,
                accountId: draft.accountId,
              ),
              categoryScopeJson: Value<String?>(
                _budgetScopeJson(
                  categoryId: draft.categoryId,
                  subCategoryId: draft.subCategoryId,
                ),
              ),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _recordBudgetChange(
        userId: userId,
        recordId: budgetId,
        operation: SyncChangeOperation.insert,
        changedFields: _budgetDraftSyncFields(draft, ledgerId, period),
        afterVersion: 1,
      );
      final budget = await _getBudgetForUser(userId, budgetId);
      await _refreshBudgetSnapshotForBudget(budget);
      return _mapBudget(budget);
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
  Future<MoneyBudgetAllocationEntity> createBudgetAllocation(
    String userId,
    MoneyBudgetAllocationDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final budget = await _getBudgetForUser(userId, draft.budgetId);
      await _validateBudgetAllocationDraft(userId, budget, draft);

      final now = DateTime.now().toUtc();
      final allocationId = _uuid.v4();
      final remainingAmountMinor = draft.allocatedAmountMinor;

      await database
          .into(database.moneyBudgetAllocations)
          .insert(
            MoneyBudgetAllocationsCompanion.insert(
              id: allocationId,
              userId: userId,
              budgetId: budget.id,
              categoryId: Value<String?>(draft.categoryId),
              memberId: Value<String?>(draft.memberId),
              allocatedAmountMinor: draft.allocatedAmountMinor,
              remainingAmountMinor: remainingAmountMinor,
              percentageBasisPoints: Value<int?>(draft.percentageBasisPoints),
              allocationType: draft.allocationType,
              ruleConfigJson: Value<String?>(draft.ruleConfigJson),
              allowOverspend: Value(draft.allowOverspend),
              overspendLimitType: Value<String?>(draft.overspendLimitType),
              overspendLimitMinor: Value<int?>(draft.overspendLimitMinor),
              alertEnabled: Value(draft.alertEnabled),
              alertThresholdPercent: draft.alertThresholdPercent,
              alertConfigJson: Value<String?>(draft.alertConfigJson),
              priority: Value(draft.priority),
              isMandatory: Value(draft.isMandatory),
              status: MoneyBudgetAllocationStatus.active.storageValue,
              notes: Value<String?>(_blankToNull(draft.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _recordBudgetAllocationChange(
        userId: userId,
        recordId: allocationId,
        operation: SyncChangeOperation.insert,
        changedFields: _budgetAllocationDraftSyncFields(
          draft,
          budget.id,
          remainingAmountMinor,
        ),
        afterVersion: 1,
      );
      await _refreshBudgetSnapshotForBudget(budget);
      return _mapBudgetAllocationWithUsage(
        budget,
        await _getBudgetAllocationForUser(userId, allocationId),
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
  Future<MoneyBudgetEntity> updateBudget(
    String userId,
    MoneyBudgetUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await _validateBudgetUpdate(userId, update);
      final ledgerId = await _resolveLedgerId(userId, update.ledgerId);
      final existing = await _getBudgetForUser(userId, update.id);
      final period = await _budgetPeriodForAccount(
        userId: userId,
        periodType: update.periodType,
        accountId: update.accountId,
      );
      final changedFields = _budgetUpdateSyncFields(
        existing,
        update,
        ledgerId,
        period,
      );
      if (changedFields.isEmpty) {
        return _mapBudget(existing);
      }
      final now = _utcNow();

      await (database.update(database.moneyBudgets)..where(
            (budget) =>
                budget.id.equals(update.id) &
                budget.userId.equals(userId) &
                budget.isDeleted.equals(false),
          ))
          .write(
            MoneyBudgetsCompanion(
              name: Value(update.name.trim()),
              description: Value<String?>(_blankToNull(update.description)),
              accountId: Value<String?>(update.accountId),
              ledgerId: Value<String?>(ledgerId),
              amountMinor: Value(update.amountMinor),
              currencyCode: Value(update.currencyCode),
              repeatPeriodType: Value(update.periodType.storageValue),
              repeatInterval: Value(update.repeatInterval),
              startDate: Value(_dateKey(period.start)),
              endDate: Value(_dateKey(period.end)),
              currentPeriodStartDate: Value(_dateKey(period.start)),
              isActive: Value(update.isActive),
              alertEnabled: Value(update.alertEnabled),
              alertThresholdPercent: Value<int?>(update.alertThresholdPercent),
              autoRollover: Value(update.autoRollover),
              color: Value<String?>(update.color),
              trackingType: Value(update.trackingType.storageValue),
              scopeType: Value(
                _budgetScopeType(
                  scopeType: update.scopeType,
                  categoryId: update.categoryId,
                  accountId: update.accountId,
                ),
              ),
              categoryScopeJson: Value<String?>(
                _budgetScopeJson(
                  categoryId: update.categoryId,
                  subCategoryId: update.subCategoryId,
                ),
              ),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await _recordBudgetChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      final budget = await _getBudgetForUser(userId, update.id);
      await _refreshBudgetSnapshotForBudget(budget);
      return _mapBudget(budget);
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
  Future<MoneyBudgetAllocationEntity> updateBudgetAllocation(
    String userId,
    MoneyBudgetAllocationUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final existing = await _getBudgetAllocationForUser(userId, update.id);
      final budget = await _getBudgetForUser(userId, existing.budgetId);
      await _validateBudgetAllocationUpdate(userId, budget, update);
      final changedFields = _budgetAllocationUpdateSyncFields(existing, update);
      if (changedFields.isEmpty) {
        return _mapBudgetAllocationWithUsage(budget, existing);
      }

      final now = DateTime.now().toUtc();
      final remainingAmountMinor =
          update.allocatedAmountMinor - existing.usedAmountMinor;
      await (database.update(database.moneyBudgetAllocations)..where(
            (allocation) =>
                allocation.id.equals(update.id) &
                allocation.userId.equals(userId) &
                allocation.isDeleted.equals(false),
          ))
          .write(
            MoneyBudgetAllocationsCompanion(
              categoryId: Value<String?>(update.categoryId),
              memberId: Value<String?>(update.memberId),
              allocatedAmountMinor: Value(update.allocatedAmountMinor),
              remainingAmountMinor: Value(remainingAmountMinor),
              percentageBasisPoints: Value<int?>(update.percentageBasisPoints),
              allocationType: Value(update.allocationType),
              ruleConfigJson: Value<String?>(update.ruleConfigJson),
              allowOverspend: Value(update.allowOverspend),
              overspendLimitType: Value<String?>(update.overspendLimitType),
              overspendLimitMinor: Value<int?>(update.overspendLimitMinor),
              alertEnabled: Value(update.alertEnabled),
              alertThresholdPercent: Value(update.alertThresholdPercent),
              alertConfigJson: Value<String?>(update.alertConfigJson),
              priority: Value(update.priority),
              isMandatory: Value(update.isMandatory),
              status: Value(update.status.storageValue),
              notes: Value<String?>(_blankToNull(update.notes)),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await _recordBudgetAllocationChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      await _refreshBudgetSnapshotForBudget(budget);
      return _mapBudgetAllocationWithUsage(
        budget,
        await _getBudgetAllocationForUser(userId, update.id),
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
  Future<void> deleteBudget(String userId, String budgetId) async {
    try {
      final existing = await _getBudgetForUser(userId, budgetId);
      final now = _utcNow();
      await (database.update(database.moneyBudgets)..where(
            (budget) =>
                budget.id.equals(budgetId) &
                budget.userId.equals(userId) &
                budget.isDeleted.equals(false),
          ))
          .write(
            MoneyBudgetsCompanion(
              isActive: const Value(false),
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordBudgetChange(
        userId: userId,
        recordId: budgetId,
        operation: SyncChangeOperation.delete,
        changedFields: _deleteSyncFields(now),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      await _closeOpenBudgetSnapshotsForBudget(userId, budgetId);
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> deleteBudgetAllocation(
    String userId,
    String allocationId,
  ) async {
    try {
      final existing = await _getBudgetAllocationForUser(userId, allocationId);
      final budget = await _getBudgetForUser(userId, existing.budgetId);
      final allocationSnapshot = await _mapBudgetAllocationWithUsage(
        budget,
        existing,
      );
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyBudgetAllocations)..where(
            (allocation) =>
                allocation.id.equals(allocationId) &
                allocation.userId.equals(userId) &
                allocation.isDeleted.equals(false),
          ))
          .write(
            MoneyBudgetAllocationsCompanion(
              status: Value(MoneyBudgetAllocationStatus.inactive.storageValue),
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordBudgetAllocationChange(
        userId: userId,
        recordId: allocationId,
        operation: SyncChangeOperation.delete,
        changedFields: _deleteSyncFields(now),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      final budgetSnapshot = await _refreshBudgetSnapshotForBudget(budget);
      await _upsertBudgetAllocationSnapshot(
        budget: budget,
        budgetSnapshot: budgetSnapshot,
        allocation: allocationSnapshot,
        status: MoneyBudgetAllocationStatus.inactive,
        sourceAllocationVersion: existing.version + 1,
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

  Future<void> _validateBudgetDraft(
    String userId,
    MoneyBudgetDraft draft,
  ) async {
    if (draft.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetAmount,
      );
    }
    await _validateBudgetScope(
      userId: userId,
      trackingType: draft.trackingType,
      periodType: draft.periodType,
      repeatInterval: draft.repeatInterval,
      scopeType: draft.scopeType,
      categoryId: draft.categoryId,
      subCategoryId: draft.subCategoryId,
      accountId: draft.accountId,
    );
  }

  Future<void> _validateBudgetUpdate(
    String userId,
    MoneyBudgetUpdate update,
  ) async {
    if (update.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetAmount,
      );
    }
    await _validateBudgetScope(
      userId: userId,
      trackingType: update.trackingType,
      periodType: update.periodType,
      repeatInterval: update.repeatInterval,
      scopeType: update.scopeType,
      categoryId: update.categoryId,
      subCategoryId: update.subCategoryId,
      accountId: update.accountId,
    );
  }

  Future<void> _validateBudgetScope({
    required String userId,
    required MoneyBudgetTrackingType trackingType,
    required MoneyBudgetPeriodType periodType,
    required int repeatInterval,
    required MoneyBudgetScopeType? scopeType,
    required String? categoryId,
    required String? subCategoryId,
    required String? accountId,
  }) async {
    if (repeatInterval <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
      );
    }
    final effectiveScopeType =
        scopeType ??
        _inferBudgetScopeType(categoryId: categoryId, accountId: accountId);
    final hasCategory = categoryId != null;
    final hasAccount = accountId != null;
    final isValidShape = switch (effectiveScopeType) {
      MoneyBudgetScopeType.all =>
        !hasCategory && subCategoryId == null && !hasAccount,
      MoneyBudgetScopeType.category => hasCategory && !hasAccount,
      MoneyBudgetScopeType.account =>
        !hasCategory && subCategoryId == null && hasAccount,
      MoneyBudgetScopeType.categoryAccount => hasCategory && hasAccount,
    };
    if (!isValidShape) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetScope,
      );
    }

    final categoryKind = trackingType == MoneyBudgetTrackingType.incomeTarget
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
    if (categoryId != null) {
      await _assertCategoryForUser(userId, categoryId, categoryKind);
    }
    if (subCategoryId != null) {
      if (categoryId == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidBudgetScope,
        );
      }
      await _assertSubCategoryForUser(
        userId,
        categoryId,
        subCategoryId,
        categoryKind,
      );
    }
    MoneyAccount? account;
    if (accountId != null) {
      account = await _getAccountForUser(userId, accountId);
    }
    if (periodType == MoneyBudgetPeriodType.billingCycle) {
      final accountType = account == null
          ? null
          : MoneyAccountType.fromStorageValue(account.type);
      if (account == null ||
          accountType?.isCreditLike != true ||
          account.statementDay == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
        );
      }
    }
  }

  Future<void> _validateBudgetAllocationDraft(
    String userId,
    MoneyBudget budget,
    MoneyBudgetAllocationDraft draft,
  ) async {
    if (draft.allocatedAmountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetAmount,
      );
    }
    await _validateBudgetAllocationScope(
      userId: userId,
      budget: budget,
      categoryId: draft.categoryId,
      memberId: draft.memberId,
      allocatedAmountMinor: draft.allocatedAmountMinor,
    );
  }

  Future<void> _validateBudgetAllocationUpdate(
    String userId,
    MoneyBudget budget,
    MoneyBudgetAllocationUpdate update,
  ) async {
    if (update.allocatedAmountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetAmount,
      );
    }
    await _validateBudgetAllocationScope(
      userId: userId,
      budget: budget,
      categoryId: update.categoryId,
      memberId: update.memberId,
      allocatedAmountMinor: update.allocatedAmountMinor,
      excludedAllocationId: update.id,
    );
  }

  Future<void> _validateBudgetAllocationScope({
    required String userId,
    required MoneyBudget budget,
    required String? categoryId,
    required String? memberId,
    required int allocatedAmountMinor,
    String? excludedAllocationId,
  }) async {
    if (categoryId != null) {
      final categoryKind =
          MoneyBudgetTrackingType.fromStorageValue(budget.trackingType) ==
              MoneyBudgetTrackingType.incomeTarget
          ? MoneyCategoryKind.income
          : MoneyCategoryKind.expense;
      await _assertCategoryForUser(userId, categoryId, categoryKind);
    }
    if (memberId != null) {
      await _getMemberForUser(userId, memberId);
    }
    final existingAllocatedMinor = await _budgetAllocationAllocatedAmountMinor(
      userId: userId,
      budgetId: budget.id,
      excludedAllocationId: excludedAllocationId,
    );
    if (existingAllocatedMinor + allocatedAmountMinor > budget.amountMinor) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidBudgetAmount,
      );
    }
  }

  Expression<bool> _budgetLedgerPredicate(
    $MoneyBudgetsTable table,
    String ledgerId,
    String userId,
  ) {
    final currentLedgerPredicate = table.ledgerId.equals(ledgerId);
    if (ledgerId == _defaultLedgerId(userId)) {
      return currentLedgerPredicate | table.ledgerId.isNull();
    }
    return currentLedgerPredicate;
  }

  Future<int> _budgetAllocationAllocatedAmountMinor({
    required String userId,
    required String budgetId,
    String? excludedAllocationId,
  }) async {
    final amount = database.moneyBudgetAllocations.allocatedAmountMinor.sum();
    var predicate =
        database.moneyBudgetAllocations.userId.equals(userId) &
        database.moneyBudgetAllocations.budgetId.equals(budgetId) &
        database.moneyBudgetAllocations.isDeleted.equals(false);
    if (excludedAllocationId != null) {
      predicate =
          predicate &
          database.moneyBudgetAllocations.id.equals(excludedAllocationId).not();
    }

    final query = database.selectOnly(database.moneyBudgetAllocations)
      ..addColumns([amount])
      ..where(predicate);
    return (await query.getSingle()).read(amount) ?? 0;
  }

  Future<void> _recordBudgetChange({
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

    await logger.recordBudgetChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordBudgetAllocationChange({
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

    await logger.recordBudgetAllocationChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Map<String, Object?> _budgetDraftSyncFields(
    MoneyBudgetDraft draft,
    String ledgerId,
    ({DateTime start, DateTime end}) period,
  ) {
    return {
      'name': draft.name.trim(),
      'description': _blankToNull(draft.description),
      'account_id': draft.accountId,
      'ledger_id': ledgerId,
      'amount_minor': draft.amountMinor,
      'currency_code': draft.currencyCode,
      'repeat_period_type': draft.periodType.storageValue,
      'repeat_interval': draft.repeatInterval,
      'start_date': _dateKey(period.start),
      'end_date': _dateKey(period.end),
      'is_active': true,
      'alert_enabled': draft.alertEnabled,
      'alert_threshold_percent': draft.alertThresholdPercent,
      'auto_rollover': draft.autoRollover,
      'color': draft.color,
      'current_period_start_date': _dateKey(period.start),
      'budget_type': _DriftMoneyRepositoryBase._budgetTypeStandard,
      'tracking_type': draft.trackingType.storageValue,
      'scope_type': _budgetScopeType(
        scopeType: draft.scopeType,
        categoryId: draft.categoryId,
        accountId: draft.accountId,
      ),
      'category_scope_json': _budgetScopeJson(
        categoryId: draft.categoryId,
        subCategoryId: draft.subCategoryId,
      ),
    };
  }

  Map<String, Object?> _budgetUpdateSyncFields(
    MoneyBudget existing,
    MoneyBudgetUpdate update,
    String ledgerId,
    ({DateTime start, DateTime end}) period,
  ) {
    final scopeType = _budgetScopeType(
      scopeType: update.scopeType,
      categoryId: update.categoryId,
      accountId: update.accountId,
    );
    final categoryScopeJson = _budgetScopeJson(
      categoryId: update.categoryId,
      subCategoryId: update.subCategoryId,
    );
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
    _putIfChanged(
      fields,
      'description',
      existing.description,
      _blankToNull(update.description),
    );
    _putIfChanged(fields, 'account_id', existing.accountId, update.accountId);
    _putIfChanged(fields, 'ledger_id', existing.ledgerId, ledgerId);
    _putIfChanged(
      fields,
      'amount_minor',
      existing.amountMinor,
      update.amountMinor,
    );
    _putIfChanged(
      fields,
      'currency_code',
      existing.currencyCode,
      update.currencyCode,
    );
    _putIfChanged(
      fields,
      'repeat_period_type',
      existing.repeatPeriodType,
      update.periodType.storageValue,
    );
    _putIfChanged(
      fields,
      'repeat_interval',
      existing.repeatInterval,
      update.repeatInterval,
    );
    _putIfChanged(
      fields,
      'start_date',
      existing.startDate,
      _dateKey(period.start),
    );
    _putIfChanged(fields, 'end_date', existing.endDate, _dateKey(period.end));
    _putIfChanged(
      fields,
      'current_period_start_date',
      existing.currentPeriodStartDate,
      _dateKey(period.start),
    );
    _putIfChanged(fields, 'is_active', existing.isActive, update.isActive);
    _putIfChanged(
      fields,
      'alert_enabled',
      existing.alertEnabled,
      update.alertEnabled,
    );
    _putIfChanged(
      fields,
      'alert_threshold_percent',
      existing.alertThresholdPercent,
      update.alertThresholdPercent,
    );
    _putIfChanged(fields, 'color', existing.color, update.color);
    _putIfChanged(
      fields,
      'auto_rollover',
      existing.autoRollover,
      update.autoRollover,
    );
    _putIfChanged(
      fields,
      'tracking_type',
      existing.trackingType,
      update.trackingType.storageValue,
    );
    _putIfChanged(fields, 'scope_type', existing.scopeType, scopeType);
    _putIfChanged(
      fields,
      'category_scope_json',
      existing.categoryScopeJson,
      categoryScopeJson,
    );
    return fields;
  }

  Map<String, Object?> _budgetAllocationDraftSyncFields(
    MoneyBudgetAllocationDraft draft,
    String budgetId,
    int remainingAmountMinor,
  ) {
    return {
      'budget_id': budgetId,
      'category_id': draft.categoryId,
      'member_id': draft.memberId,
      'allocated_amount_minor': draft.allocatedAmountMinor,
      'used_amount_minor': 0,
      'remaining_amount_minor': remainingAmountMinor,
      'percentage_basis_points': draft.percentageBasisPoints,
      'allocation_type': draft.allocationType,
      'rule_config_json': draft.ruleConfigJson,
      'allow_overspend': draft.allowOverspend,
      'overspend_limit_type': draft.overspendLimitType,
      'overspend_limit_minor': draft.overspendLimitMinor,
      'alert_enabled': draft.alertEnabled,
      'alert_threshold_percent': draft.alertThresholdPercent,
      'alert_config_json': draft.alertConfigJson,
      'priority': draft.priority,
      'is_mandatory': draft.isMandatory,
      'status': MoneyBudgetAllocationStatus.active.storageValue,
      'notes': _blankToNull(draft.notes),
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _budgetAllocationUpdateSyncFields(
    MoneyBudgetAllocation existing,
    MoneyBudgetAllocationUpdate update,
  ) {
    final remainingAmountMinor =
        update.allocatedAmountMinor - existing.usedAmountMinor;
    final fields = <String, Object?>{};
    _putIfChanged(
      fields,
      'category_id',
      existing.categoryId,
      update.categoryId,
    );
    _putIfChanged(fields, 'member_id', existing.memberId, update.memberId);
    _putIfChanged(
      fields,
      'allocated_amount_minor',
      existing.allocatedAmountMinor,
      update.allocatedAmountMinor,
    );
    _putIfChanged(
      fields,
      'remaining_amount_minor',
      existing.remainingAmountMinor,
      remainingAmountMinor,
    );
    _putIfChanged(
      fields,
      'percentage_basis_points',
      existing.percentageBasisPoints,
      update.percentageBasisPoints,
    );
    _putIfChanged(
      fields,
      'allocation_type',
      existing.allocationType,
      update.allocationType,
    );
    _putIfChanged(
      fields,
      'rule_config_json',
      existing.ruleConfigJson,
      update.ruleConfigJson,
    );
    _putIfChanged(
      fields,
      'allow_overspend',
      existing.allowOverspend,
      update.allowOverspend,
    );
    _putIfChanged(
      fields,
      'overspend_limit_type',
      existing.overspendLimitType,
      update.overspendLimitType,
    );
    _putIfChanged(
      fields,
      'overspend_limit_minor',
      existing.overspendLimitMinor,
      update.overspendLimitMinor,
    );
    _putIfChanged(
      fields,
      'alert_enabled',
      existing.alertEnabled,
      update.alertEnabled,
    );
    _putIfChanged(
      fields,
      'alert_threshold_percent',
      existing.alertThresholdPercent,
      update.alertThresholdPercent,
    );
    _putIfChanged(
      fields,
      'alert_config_json',
      existing.alertConfigJson,
      update.alertConfigJson,
    );
    _putIfChanged(fields, 'priority', existing.priority, update.priority);
    _putIfChanged(
      fields,
      'is_mandatory',
      existing.isMandatory,
      update.isMandatory,
    );
    _putIfChanged(
      fields,
      'status',
      existing.status,
      update.status.storageValue,
    );
    _putIfChanged(fields, 'notes', existing.notes, _blankToNull(update.notes));
    return fields;
  }

  Future<MoneyBudgetAllocation> _getBudgetAllocationForUser(
    String userId,
    String allocationId,
  ) async {
    final allocation =
        await (database.select(database.moneyBudgetAllocations)
              ..where(
                (allocation) =>
                    allocation.id.equals(allocationId) &
                    allocation.userId.equals(userId) &
                    allocation.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (allocation == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.budgetNotFound,
      );
    }

    return allocation;
  }

  @override
  Future<List<MoneyBudgetHistoryTrendPoint>> getBudgetHistoryTrendForUser(
    String userId,
    String ledgerId, {
    int months = 6,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);

      final rows =
          await (database.select(database.moneyBudgetSnapshots)..where(
                (snapshot) =>
                    snapshot.userId.equals(userId) &
                    (snapshot.ledgerId.equals(resolvedLedgerId) |
                        snapshot.ledgerId.isNull()),
              ))
              .get();

      if (rows.isEmpty) {
        return const <MoneyBudgetHistoryTrendPoint>[];
      }

      // Group by periodStartDate, keep latest capturedAt per period
      final periodMap = <int, List<MoneyBudgetSnapshot>>{};
      for (final row in rows) {
        periodMap
            .putIfAbsent(row.periodStartDate, () => <MoneyBudgetSnapshot>[])
            .add(row);
      }

      final trendPoints = <MoneyBudgetHistoryTrendPoint>[];
      for (final entry in periodMap.entries) {
        final periodRows = entry.value;
        // Sort by capturedAt descending, take first per budgetId
        periodRows.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
        final seenBudgets = <String>{};
        final latestRows = <MoneyBudgetSnapshot>[];
        for (final row in periodRows) {
          if (seenBudgets.add(row.budgetId)) {
            latestRows.add(row);
          }
        }

        int budgetAmountMinor = 0;
        int usedAmountMinor = 0;
        int overspentCount = 0;

        for (final row in latestRows) {
          budgetAmountMinor += row.budgetAmountMinor;
          usedAmountMinor += row.usedAmountMinor;
          if (row.usedAmountMinor > row.budgetAmountMinor) {
            overspentCount++;
          }
        }

        trendPoints.add(
          MoneyBudgetHistoryTrendPoint(
            periodStart: _dateFromKey(entry.key),
            periodEnd: _dateFromKey(latestRows.first.periodEndDate),
            budgetAmountMinor: budgetAmountMinor,
            usedAmountMinor: usedAmountMinor,
            budgetCount: latestRows.length,
            overspentBudgetCount: overspentCount,
          ),
        );
      }

      // Sort by periodStart descending, take last N months
      trendPoints.sort((a, b) => b.periodStart.compareTo(a.periodStart));
      final cutoff = DateTime.now().subtract(Duration(days: months * 31));
      final filtered = trendPoints
          .where((p) => p.periodStart.isAfter(cutoff))
          .toList();
      filtered.sort((a, b) => a.periodStart.compareTo(b.periodStart));

      return filtered;
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }
}
