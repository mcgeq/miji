part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Splits on _DriftMoneyRepositoryBase {
  @override
  Future<MoneySplitRecordEntity> replaceSplitForTransaction(
    String userId,
    MoneySplitDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      return await database.transaction(() async {
        final activeSplit =
            await (database.select(database.moneySplitRecords)
                  ..where(
                    (record) =>
                        record.userId.equals(userId) &
                        record.ledgerId.equals(draft.ledgerId) &
                        record.transactionId.equals(draft.transactionId) &
                        record.status.equals(
                          MoneySplitRecordStatus.active.storageValue,
                        ) &
                        record.isDeleted.equals(false),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (activeSplit == null) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.splitRecordNotFound,
          );
        }

        await (database.update(
          database.moneySplitRecords,
        )..where((record) => record.id.equals(activeSplit.id))).write(
          MoneySplitRecordsCompanion(
            status: Value(MoneySplitRecordStatus.cancelled.storageValue),
            version: Value(activeSplit.version + 1),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
        await _recordSplitRecordChange(
          userId: userId,
          recordId: activeSplit.id,
          operation: SyncChangeOperation.update,
          changedFields: {
            'status': MoneySplitRecordStatus.cancelled.storageValue,
          },
          beforeVersion: activeSplit.version,
          afterVersion: activeSplit.version + 1,
        );

        return _createSplitForExistingTransaction(userId, draft);
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
  Future<void> cancelSplitRecord(String userId, String splitRecordId) async {
    try {
      await ensureReadyForUser(userId);
      await database.transaction(() async {
        final split = await _getSplitRecordForUser(userId, splitRecordId);
        if (MoneySplitRecordStatus.fromStorageValue(split.status) !=
            MoneySplitRecordStatus.active) {
          return;
        }

        final updatedRows =
            await (database.update(database.moneySplitRecords)..where(
                  (record) =>
                      record.userId.equals(userId) &
                      record.id.equals(splitRecordId) &
                      record.isDeleted.equals(false),
                ))
                .write(
                  MoneySplitRecordsCompanion(
                    status: Value(
                      MoneySplitRecordStatus.cancelled.storageValue,
                    ),
                    version: Value(split.version + 1),
                    updatedAt: Value(DateTime.now().toUtc()),
                  ),
                );
        if (updatedRows == 0) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.splitRecordNotFound,
          );
        }
        await _recordSplitRecordChange(
          userId: userId,
          recordId: splitRecordId,
          operation: SyncChangeOperation.update,
          changedFields: {
            'status': MoneySplitRecordStatus.cancelled.storageValue,
          },
          beforeVersion: split.version,
          afterVersion: split.version + 1,
        );
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
  Stream<List<MoneySplitRecordEntity>> watchSplitRecordsForTransaction(
    String userId,
    String transactionId,
  ) async* {
    await ensureReadyForUser(userId);

    final query = database.select(database.moneySplitRecords)
      ..where(
        (record) =>
            record.userId.equals(userId) &
            record.transactionId.equals(transactionId) &
            record.status.equals(MoneySplitRecordStatus.active.storageValue) &
            record.isDeleted.equals(false),
      )
      ..orderBy([(record) => OrderingTerm.desc(record.createdAt)]);

    yield* query.watch().asyncMap((rows) async {
      final records = <MoneySplitRecordEntity>[];
      for (final row in rows) {
        records.add(await _mapSplitRecord(row));
      }
      return records;
    });
  }

  @override
  Stream<List<MoneySplitRuleEntity>> watchSplitRulesForLedger(
    String userId,
    String ledgerId, {
    bool includeDeleted = false,
  }) async* {
    await ensureReadyForUser(userId);

    final query = database.select(database.moneySplitRules)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.ledgerId.equals(ledgerId) &
            (includeDeleted
                ? const Constant(true)
                : row.isDeleted.equals(false)),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.priority),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);

    yield* query.watch().asyncMap((rows) async {
      return rows.map(_mapSplitRule).toList(growable: false);
    });
  }

  @override
  Future<MoneySplitRecordEntity> createSplitForTransaction(
    String userId,
    MoneySplitDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);

      return await database.transaction(() async {
        return _createSplitForExistingTransaction(userId, draft);
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
  Future<MoneySplitRuleEntity> createSplitRule(
    String userId,
    MoneySplitRuleDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final ledger = await _getLedgerForUser(userId, draft.ledgerId);
      if (ledger.ledgerType.toLowerCase() != 'family') {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitTransaction,
        );
      }
      final name = draft.name.trim();
      final ruleConfigJson = draft.ruleConfigJson.trim();
      if (name.isEmpty || ruleConfigJson.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }
      jsonDecode(ruleConfigJson);

      final now = DateTime.now().toUtc();
      final ruleId = _uuid.v4();
      await database
          .into(database.moneySplitRules)
          .insert(
            MoneySplitRulesCompanion.insert(
              id: ruleId,
              userId: userId,
              ledgerId: ledger.id,
              name: name,
              ruleType: draft.ruleType.storageValue,
              ruleConfigJson: ruleConfigJson,
              isActive: Value(draft.isActive),
              priority: Value(draft.priority),
              deviceId: const Value<String?>(null),
              version: const Value(1),
              isDeleted: const Value(false),
              deletedAt: const Value<DateTime?>(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _recordSplitRuleChange(
        userId: userId,
        recordId: ruleId,
        operation: SyncChangeOperation.insert,
        changedFields: _splitRuleDraftSyncFields(draft, ledger.id),
        afterVersion: 1,
      );
      return _mapSplitRule(await _getSplitRuleForUser(userId, ruleId));
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
  Future<MoneySplitRuleEntity> updateSplitRule(
    String userId,
    MoneySplitRuleUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final existing = await _getSplitRuleForUser(userId, update.id);
      final name = update.name.trim();
      final ruleConfigJson = update.ruleConfigJson.trim();
      if (name.isEmpty || ruleConfigJson.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }
      jsonDecode(ruleConfigJson);

      final changedFields = _splitRuleUpdateSyncFields(existing, update);
      if (changedFields.isEmpty) {
        return _mapSplitRule(existing);
      }

      final now = DateTime.now().toUtc();
      await (database.update(database.moneySplitRules)..where(
            (row) =>
                row.id.equals(update.id) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneySplitRulesCompanion(
              name: Value(name),
              ruleType: Value(update.ruleType.storageValue),
              ruleConfigJson: Value(ruleConfigJson),
              isActive: Value(update.isActive),
              priority: Value(update.priority),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordSplitRuleChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      return _mapSplitRule(await _getSplitRuleForUser(userId, update.id));
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
  Future<void> deleteSplitRule(String userId, String ruleId) async {
    try {
      await ensureReadyForUser(userId);
      final existing = await _getSplitRuleForUser(userId, ruleId);
      final now = DateTime.now().toUtc();
      await (database.update(database.moneySplitRules)..where(
            (row) =>
                row.id.equals(ruleId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneySplitRulesCompanion(
              isActive: const Value(false),
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordSplitRuleChange(
        userId: userId,
        recordId: ruleId,
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

  Map<String, Object?> _splitRuleDraftSyncFields(
    MoneySplitRuleDraft draft,
    String ledgerId,
  ) {
    return {
      'ledger_id': ledgerId,
      'name': draft.name.trim(),
      'rule_type': draft.ruleType.storageValue,
      'rule_config_json': draft.ruleConfigJson.trim(),
      'is_active': draft.isActive,
      'priority': draft.priority,
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _splitRuleUpdateSyncFields(
    MoneySplitRule existing,
    MoneySplitRuleUpdate update,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
    _putIfChanged(
      fields,
      'rule_type',
      existing.ruleType,
      update.ruleType.storageValue,
    );
    _putIfChanged(
      fields,
      'rule_config_json',
      existing.ruleConfigJson,
      update.ruleConfigJson.trim(),
    );
    _putIfChanged(fields, 'is_active', existing.isActive, update.isActive);
    _putIfChanged(fields, 'priority', existing.priority, update.priority);
    return fields;
  }

  Future<MoneySplitRule> _getSplitRuleForUser(
    String userId,
    String splitRuleId,
  ) async {
    final rule =
        await (database.select(database.moneySplitRules)
              ..where(
                (row) =>
                    row.id.equals(splitRuleId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (rule == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.splitRecordNotFound,
      );
    }
    return rule;
  }

  Future<void> _recordSplitRuleChange({
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

    await logger.recordSplitRuleChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }
}
