part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _BillReminders on _DriftMoneyRepositoryBase {
  @override
  Stream<List<MoneyBillReminderEntity>> watchBillRemindersForUser(
    String userId, {
    String? ledgerId,
  }) async* {
    await ensureReadyForUser(userId);
    final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);

    final query = database.select(database.moneyBillReminders)
      ..where(
        (reminder) =>
            reminder.userId.equals(userId) &
            reminder.isDeleted.equals(false) &
            (reminder.ledgerId.equals(resolvedLedgerId) |
                reminder.ledgerId.isNull()),
      )
      ..orderBy([
        (reminder) => OrderingTerm.asc(reminder.dueDate),
        (reminder) => OrderingTerm.desc(reminder.updatedAt),
      ]);

    yield* query.watch().map(
      (rows) => rows.map(_mapBillReminder).toList(growable: false),
    );
  }

  @override
  Future<List<MoneyReminderCenterItem>> getPendingReminderCenterItems(
    String userId, {
    String? ledgerId,
    DateTime? today,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = ledgerId == null
          ? null
          : await _resolveLedgerId(userId, ledgerId);
      final currentDate = today ?? _utcNow();

      final reminderQuery = database.select(database.moneyBillReminders)
        ..where(
          (reminder) =>
              reminder.userId.equals(userId) &
              reminder.isDeleted.equals(false) &
              reminder.status.equals(
                MoneyBillReminderStatus.pending.storageValue,
              ) &
              (resolvedLedgerId == null
                  ? const Constant(true)
                  : (reminder.ledgerId.equals(resolvedLedgerId) |
                        reminder.ledgerId.isNull())),
        );
      final reminderItems = (await reminderQuery.get())
          .map((reminder) => _billReminderCenterItem(reminder))
          .toList(growable: false);
      final sourceItems = <MoneyReminderCenterItem>[
        ...reminderItems,
        ...await _budgetReminderCenterItems(userId, resolvedLedgerId),
        ...await _installmentReminderCenterItems(userId, resolvedLedgerId),
      ];
      final processingRecords = await _reminderProcessingByItemKey(
        userId,
        sourceItems.map((item) => item.itemKey),
      );

      final pending = <MoneyReminderCenterItem>[];
      for (final item in sourceItems) {
        final processing = processingRecords[item.itemKey];
        final effectiveItem = processing == null
            ? item
            : _applyReminderProcessing(item, processing);
        if (effectiveItem.isPending(today: currentDate)) {
          pending.add(effectiveItem);
        }
      }
      pending.sort(
        (left, right) => left.comparePriorityTo(right, today: currentDate),
      );
      return pending;
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<List<MoneyReminderCenterItem>> getReminderCenterHistory(
    String userId, {
    String? ledgerId,
    int limit = 50,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = ledgerId == null
          ? null
          : await _resolveLedgerId(userId, ledgerId);
      final query = database.select(database.moneyReminderCenterProcessing)
        ..where(
          (record) =>
              record.userId.equals(userId) &
              record.isDeleted.equals(false) &
              record.state.isIn([
                MoneyReminderCenterState.completed.storageValue,
                MoneyReminderCenterState.ignored.storageValue,
              ]) &
              (resolvedLedgerId == null
                  ? const Constant(true)
                  : record.ledgerId.equals(resolvedLedgerId)),
        )
        ..orderBy([
          (record) => OrderingTerm.desc(record.processedAt),
          (record) => OrderingTerm.desc(record.updatedAt),
        ])
        ..limit(limit);
      return (await query.get())
          .map(_mapReminderProcessingItem)
          .toList(growable: false);
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<void> setReminderCenterState(
    String userId,
    MoneyReminderCenterItem item,
    MoneyReminderCenterState state, {
    DateTime? snoozedUntil,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final now = _utcNow();
      final processedAt = switch (state) {
        MoneyReminderCenterState.completed ||
        MoneyReminderCenterState.ignored => now,
        MoneyReminderCenterState.pending ||
        MoneyReminderCenterState.snoozed => null,
      };
      final existing =
          await (database.select(database.moneyReminderCenterProcessing)..where(
                (record) =>
                    record.userId.equals(userId) &
                    record.itemKey.equals(item.itemKey),
              ))
              .getSingleOrNull();

      if (existing == null) {
        final recordId = _uuid.v4();
        await database
            .into(database.moneyReminderCenterProcessing)
            .insert(
              MoneyReminderCenterProcessingCompanion.insert(
                id: recordId,
                userId: userId,
                itemKey: item.itemKey,
                sourceType: item.sourceType.storageValue,
                sourceId: item.sourceId,
                title: item.title,
                dueDate: _dateKey(item.dueDate),
                amountMinor: item.amountMinor,
                currencyCode: item.currencyCode,
                actionType: item.actionType.storageValue,
                ledgerId: Value(item.ledgerId),
                accountId: Value(item.accountId),
                isBudgetExceeded: Value(item.isBudgetExceeded),
                state: state.storageValue,
                snoozedUntil: Value(
                  snoozedUntil == null ? null : _dateKey(snoozedUntil),
                ),
                processedAt: Value(processedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _recordReminderCenterProcessingChange(
          userId: userId,
          recordId: recordId,
          operation: SyncChangeOperation.insert,
          changedFields: _reminderCenterSyncFields(
            item: item,
            state: state,
            snoozedUntil: snoozedUntil,
            processedAt: processedAt,
          ),
          afterVersion: 1,
        );
        return;
      }

      await (database.update(database.moneyReminderCenterProcessing)..where(
            (record) =>
                record.id.equals(existing.id) & record.userId.equals(userId),
          ))
          .write(
            MoneyReminderCenterProcessingCompanion(
              title: Value(item.title),
              dueDate: Value(_dateKey(item.dueDate)),
              amountMinor: Value(item.amountMinor),
              currencyCode: Value(item.currencyCode),
              actionType: Value(item.actionType.storageValue),
              ledgerId: Value(item.ledgerId),
              accountId: Value(item.accountId),
              isBudgetExceeded: Value(item.isBudgetExceeded),
              state: Value(state.storageValue),
              snoozedUntil: Value(
                snoozedUntil == null ? null : _dateKey(snoozedUntil),
              ),
              processedAt: Value(processedAt),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordReminderCenterProcessingChange(
        userId: userId,
        recordId: existing.id,
        operation: SyncChangeOperation.update,
        changedFields: _reminderCenterSyncFields(
          item: item,
          state: state,
          snoozedUntil: snoozedUntil,
          processedAt: processedAt,
        ),
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
  Future<MoneyBillReminderEntity> createBillReminder(
    String userId,
    MoneyBillReminderDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateBillReminderDraft(draft);
      final ledgerId = await _resolveLedgerId(userId, draft.ledgerId);
      final now = DateTime.now().toUtc();
      final reminderId = _uuid.v4();

      await database
          .into(database.moneyBillReminders)
          .insert(
            MoneyBillRemindersCompanion.insert(
              id: reminderId,
              userId: userId,
              name: draft.name.trim(),
              amountMinor: draft.amountMinor,
              currencyCode: draft.currencyCode,
              dueDate: _dateKey(draft.dueDate),
              remindBeforeDays: draft.remindBeforeDays,
              repeatPeriodType: Value<String?>(
                draft.repeatPeriodType?.storageValue,
              ),
              repeatInterval: Value<int?>(draft.repeatInterval),
              accountId: Value<String?>(draft.accountId),
              ledgerId: Value<String?>(ledgerId),
              categoryId: Value<String?>(draft.categoryId),
              relatedTransactionId: Value<String?>(draft.relatedTransactionId),
              status: MoneyBillReminderStatus.pending.storageValue,
              sourceType: Value(draft.sourceType.storageValue),
              sourceKey: Value<String?>(draft.sourceKey),
              amountSource: Value(draft.amountSource.storageValue),
              autoManaged: Value(draft.autoManaged),
              notes: Value<String?>(_blankToNull(draft.notes)),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await _recordBillReminderChange(
        userId: userId,
        recordId: reminderId,
        operation: SyncChangeOperation.insert,
        changedFields: _billReminderDraftSyncFields(draft, ledgerId),
        afterVersion: 1,
      );
      return _mapBillReminder(
        await _getBillReminderForUser(userId, reminderId),
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
  Future<MoneyBillReminderEntity> updateBillReminder(
    String userId,
    MoneyBillReminderUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateBillReminderUpdate(update);
      final existing = await _getBillReminderForUser(userId, update.id);
      final ledgerId = await _resolveLedgerId(userId, update.ledgerId);
      final changedFields = _billReminderUpdateSyncFields(
        existing,
        update,
        ledgerId,
      );
      if (changedFields.isEmpty) {
        return _mapBillReminder(existing);
      }
      final now = DateTime.now().toUtc();

      await (database.update(database.moneyBillReminders)..where(
            (reminder) =>
                reminder.id.equals(update.id) &
                reminder.userId.equals(userId) &
                reminder.isDeleted.equals(false),
          ))
          .write(
            MoneyBillRemindersCompanion(
              name: Value(update.name.trim()),
              amountMinor: Value(update.amountMinor),
              currencyCode: Value(update.currencyCode),
              dueDate: Value(_dateKey(update.dueDate)),
              remindBeforeDays: Value(update.remindBeforeDays),
              repeatPeriodType: Value<String?>(
                update.repeatPeriodType?.storageValue,
              ),
              repeatInterval: Value<int?>(update.repeatInterval),
              accountId: Value<String?>(update.accountId),
              ledgerId: Value<String?>(ledgerId),
              categoryId: Value<String?>(update.categoryId),
              relatedTransactionId: Value<String?>(update.relatedTransactionId),
              status: Value(update.status.storageValue),
              sourceType: Value(update.sourceType.storageValue),
              sourceKey: Value<String?>(update.sourceKey),
              amountSource: Value(update.amountSource.storageValue),
              autoManaged: Value(update.autoManaged),
              notes: Value<String?>(_blankToNull(update.notes)),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await _recordBillReminderChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      return _mapBillReminder(await _getBillReminderForUser(userId, update.id));
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
  Future<void> setBillReminderStatus(
    String userId,
    String reminderId,
    MoneyBillReminderStatus status,
  ) async {
    try {
      final existing = await _getBillReminderForUser(userId, reminderId);
      if (existing.status == status.storageValue) {
        return;
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyBillReminders)..where(
            (reminder) =>
                reminder.id.equals(reminderId) &
                reminder.userId.equals(userId) &
                reminder.isDeleted.equals(false),
          ))
          .write(
            MoneyBillRemindersCompanion(
              status: Value(status.storageValue),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordBillReminderChange(
        userId: userId,
        recordId: reminderId,
        operation: SyncChangeOperation.update,
        changedFields: {'status': status.storageValue},
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
  Future<void> deleteBillReminder(String userId, String reminderId) async {
    try {
      final existing = await _getBillReminderForUser(userId, reminderId);
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyBillReminders)..where(
            (reminder) =>
                reminder.id.equals(reminderId) &
                reminder.userId.equals(userId) &
                reminder.isDeleted.equals(false),
          ))
          .write(
            MoneyBillRemindersCompanion(
              status: Value(MoneyBillReminderStatus.cancelled.storageValue),
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordBillReminderChange(
        userId: userId,
        recordId: reminderId,
        operation: SyncChangeOperation.delete,
        changedFields: {
          'status': MoneyBillReminderStatus.cancelled.storageValue,
          ..._deleteSyncFields(now),
        },
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      if (existing.sourceType ==
              MoneyBillReminderSourceType.creditRepayment.storageValue &&
          existing.accountId != null) {
        await _setAccountAutoRepaymentReminderEnabled(
          userId: userId,
          accountId: existing.accountId!,
          enabled: false,
        );
      }
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

  Future<void> _setAccountAutoRepaymentReminderEnabled({
    required String userId,
    required String accountId,
    required bool enabled,
  }) async {
    final account = await _getAccountForUser(userId, accountId);
    if (account.autoRepaymentReminderEnabled == enabled) {
      return;
    }
    final now = _utcNow();
    await (database.update(
          database.moneyAccounts,
        )..where((row) => row.id.equals(accountId) & row.userId.equals(userId)))
        .write(
          MoneyAccountsCompanion(
            autoRepaymentReminderEnabled: Value(enabled),
            version: Value(account.version + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordAccountChange(
      userId: userId,
      recordId: accountId,
      operation: SyncChangeOperation.update,
      changedFields: {'auto_repayment_reminder_enabled': enabled},
      beforeVersion: account.version,
      afterVersion: account.version + 1,
    );
  }

  Map<String, Object?> _billReminderDraftSyncFields(
    MoneyBillReminderDraft draft,
    String ledgerId,
  ) {
    return {
      'name': draft.name.trim(),
      'amount_minor': draft.amountMinor,
      'currency_code': draft.currencyCode,
      'due_date': _dateKey(draft.dueDate),
      'remind_before_days': draft.remindBeforeDays,
      'repeat_period_type': draft.repeatPeriodType?.storageValue,
      'repeat_interval': draft.repeatInterval,
      'account_id': draft.accountId,
      'ledger_id': ledgerId,
      'category_id': draft.categoryId,
      'related_transaction_id': draft.relatedTransactionId,
      'status': MoneyBillReminderStatus.pending.storageValue,
      'source_type': draft.sourceType.storageValue,
      'source_key': draft.sourceKey,
      'amount_source': draft.amountSource.storageValue,
      'auto_managed': draft.autoManaged,
      'notes': _blankToNull(draft.notes),
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _billReminderUpdateSyncFields(
    MoneyBillReminder existing,
    MoneyBillReminderUpdate update,
    String ledgerId,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
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
      'due_date',
      existing.dueDate,
      _dateKey(update.dueDate),
    );
    _putIfChanged(
      fields,
      'remind_before_days',
      existing.remindBeforeDays,
      update.remindBeforeDays,
    );
    _putIfChanged(
      fields,
      'repeat_period_type',
      existing.repeatPeriodType,
      update.repeatPeriodType?.storageValue,
    );
    _putIfChanged(
      fields,
      'repeat_interval',
      existing.repeatInterval,
      update.repeatInterval,
    );
    _putIfChanged(fields, 'account_id', existing.accountId, update.accountId);
    _putIfChanged(fields, 'ledger_id', existing.ledgerId, ledgerId);
    _putIfChanged(
      fields,
      'category_id',
      existing.categoryId,
      update.categoryId,
    );
    _putIfChanged(
      fields,
      'related_transaction_id',
      existing.relatedTransactionId,
      update.relatedTransactionId,
    );
    _putIfChanged(
      fields,
      'status',
      existing.status,
      update.status.storageValue,
    );
    _putIfChanged(
      fields,
      'source_type',
      existing.sourceType,
      update.sourceType.storageValue,
    );
    _putIfChanged(fields, 'source_key', existing.sourceKey, update.sourceKey);
    _putIfChanged(
      fields,
      'amount_source',
      existing.amountSource,
      update.amountSource.storageValue,
    );
    _putIfChanged(
      fields,
      'auto_managed',
      existing.autoManaged,
      update.autoManaged,
    );
    _putIfChanged(fields, 'notes', existing.notes, _blankToNull(update.notes));
    return fields;
  }

  Future<MoneyBillReminder> _getBillReminderForUser(
    String userId,
    String reminderId,
  ) async {
    final reminder =
        await (database.select(database.moneyBillReminders)
              ..where(
                (reminder) =>
                    reminder.id.equals(reminderId) &
                    reminder.userId.equals(userId) &
                    reminder.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (reminder == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.reminderNotFound,
      );
    }

    return reminder;
  }

  Future<List<MoneyReminderCenterItem>> _budgetReminderCenterItems(
    String userId,
    String? resolvedLedgerId,
  ) async {
    final query = database.select(database.moneyBudgets)
      ..where(
        (budget) =>
            budget.userId.equals(userId) &
            budget.isDeleted.equals(false) &
            budget.isActive.equals(true) &
            (resolvedLedgerId == null
                ? const Constant(true)
                : (budget.ledgerId.equals(resolvedLedgerId) |
                      budget.ledgerId.isNull())),
      );
    final items = <MoneyReminderCenterItem>[];
    for (final row in await query.get()) {
      final budget = await _mapBudget(row);
      if (!budget.alertEnabled || !budget.shouldAlert) {
        continue;
      }
      items.add(
        MoneyReminderCenterItem(
          sourceType: MoneyReminderCenterSourceType.budget,
          sourceId: budget.id,
          title: budget.name,
          dueDate: budget.periodEnd,
          amountMinor: budget.usedAmountMinor,
          currencyCode: budget.currencyCode,
          ledgerId: budget.ledgerId,
          accountId: budget.accountId,
          isBudgetExceeded: true,
          actionType: MoneyReminderCenterActionType.viewBudget,
        ),
      );
    }
    return items;
  }

  Future<List<MoneyReminderCenterItem>> _installmentReminderCenterItems(
    String userId,
    String? resolvedLedgerId,
  ) async {
    final planQuery = database.select(database.moneyInstallmentPlans)
      ..where(
        (plan) =>
            plan.userId.equals(userId) &
            plan.isDeleted.equals(false) &
            plan.status.equals(MoneyInstallmentPlanStatus.active.storageValue) &
            (resolvedLedgerId == null
                ? const Constant(true)
                : _installmentLedgerPredicate(plan, resolvedLedgerId, userId)),
      );
    final items = <MoneyReminderCenterItem>[];
    for (final plan in await planQuery.get()) {
      final detailQuery = database.select(database.moneyInstallmentDetails)
        ..where(
          (detail) =>
              detail.userId.equals(userId) &
              detail.planId.equals(plan.id) &
              detail.isDeleted.equals(false) &
              detail.status.equals(
                MoneyInstallmentDetailStatus.pending.storageValue,
              ),
        );
      for (final detail in await detailQuery.get()) {
        items.add(
          MoneyReminderCenterItem(
            sourceType: MoneyReminderCenterSourceType.installment,
            sourceId: '${plan.id}:${detail.id}',
            title: '${plan.name} 第 ${detail.periodNumber} 期',
            dueDate: _dateFromKey(detail.dueDate),
            amountMinor: detail.amountMinor,
            currencyCode: plan.currencyCode,
            ledgerId: plan.ledgerId ?? _defaultLedgerId(userId),
            accountId: detail.accountId,
            actionType: MoneyReminderCenterActionType.recordTransaction,
          ),
        );
      }
    }
    return items;
  }
}
