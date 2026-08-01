part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Ledgers on _DriftMoneyRepositoryBase {
  @override
  Future<MoneySplitContextEntity> getDefaultSplitContextForUser(
    String userId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final ledger = await _getDefaultLedgerForUser(userId);
      final members = await _membersForLedger(userId, ledger.id);
      return MoneySplitContextEntity(
        ledger: _mapLedger(ledger),
        members: members.map(_mapMember).toList(),
      );
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
  Stream<List<MoneyMemberEntity>> watchMembersForUser(String userId) async* {
    await ensureReadyForUser(userId);

    final query = database.select(database.moneyMembers)
      ..where(
        (member) =>
            member.userId.equals(userId) &
            member.status.equals('active') &
            member.isDeleted.equals(false),
      )
      ..orderBy([
        (member) => OrderingTerm.asc(member.createdAt),
        (member) => OrderingTerm.asc(member.name),
      ]);

    yield* query.watch().map((rows) => rows.map(_mapMember).toList());
  }

  @override
  Stream<List<MoneyLedgerEntity>> watchLedgersForUser(String userId) async* {
    await ensureReadyForUser(userId);

    final query = database.select(database.moneyLedgers)
      ..where(
        (ledger) =>
            ledger.userId.equals(userId) &
            ledger.status.equals('active') &
            ledger.isDeleted.equals(false),
      )
      ..orderBy([
        (ledger) => OrderingTerm.asc(ledger.ledgerType),
        (ledger) => OrderingTerm.asc(ledger.createdAt),
        (ledger) => OrderingTerm.asc(ledger.name),
      ]);

    yield* query.watch().map((rows) {
      final ledgers = rows.map(_mapLedger).toList();
      ledgers.sort((a, b) {
        if (a.isPersonal != b.isPersonal) {
          return a.isPersonal ? -1 : 1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      return ledgers;
    });
  }

  @override
  Stream<List<MoneyLedgerEntity>> watchLedgersForTransaction(
    String userId,
    String transactionId,
  ) async* {
    await ensureReadyForUser(userId);
    await _getTransactionForUser(userId, transactionId);

    final linkQuery = database.select(database.moneyLedgerTransactions)
      ..where((link) => link.transactionId.equals(transactionId));

    yield* linkQuery.watch().asyncMap((links) async {
      final ledgerIds = links.map((link) => link.ledgerId).toList();
      if (ledgerIds.isEmpty) {
        return const <MoneyLedgerEntity>[];
      }

      final rows =
          await (database.select(database.moneyLedgers)..where(
                (ledger) =>
                    ledger.userId.equals(userId) &
                    ledger.id.isIn(ledgerIds) &
                    ledger.status.equals('active') &
                    ledger.isDeleted.equals(false),
              ))
              .get();
      final ledgers = rows.map(_mapLedger).toList();
      ledgers.sort((a, b) {
        if (a.isPersonal != b.isPersonal) {
          return a.isPersonal ? -1 : 1;
        }
        if (a.isFamily != b.isFamily) {
          return a.isFamily ? -1 : 1;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
      return ledgers;
    });
  }

  @override
  Stream<List<MoneyMemberEntity>> watchMembersForLedger(
    String userId,
    String ledgerId,
  ) async* {
    await ensureReadyForUser(userId);
    await _getLedgerForUser(userId, ledgerId);

    yield* _watchMembersForLedger(
      userId,
      ledgerId,
    ).map((rows) => rows.map(_mapMember).toList());
  }

  @override
  Future<MoneyLedgerEntity> getDefaultLedgerForUser(String userId) async {
    try {
      await ensureReadyForUser(userId);
      return _mapLedger(await _getDefaultLedgerForUser(userId));
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
  Future<void> linkTransactionToLedger(
    String userId,
    String transactionId,
    String ledgerId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final ledger = await _getLedgerForUser(userId, ledgerId);
      await _getTransactionForUser(userId, transactionId);
      await _linkTransactionToLedgerUnchecked(
        ledgerId: ledger.id,
        transactionId: transactionId,
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
  Future<void> unlinkTransactionFromLedger(
    String userId,
    String transactionId,
    String ledgerId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await database.transaction(() async {
        await _getTransactionForUser(userId, transactionId);
        final ledger = await _getLedgerForUser(userId, ledgerId);
        if (ledger.ledgerType == 'personal') {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.cannotUnlinkPersonalLedger,
          );
        }

        final activeSplit =
            await (database.select(database.moneySplitRecords)
                  ..where(
                    (record) =>
                        record.userId.equals(userId) &
                        record.ledgerId.equals(ledger.id) &
                        record.transactionId.equals(transactionId) &
                        record.status.equals(
                          MoneySplitRecordStatus.active.storageValue,
                        ) &
                        record.isDeleted.equals(false),
                  )
                  ..limit(1))
                .getSingleOrNull();
        if (activeSplit != null) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.cannotUnlinkLedgerWithActiveSplit,
          );
        }

        await (database.delete(database.moneyLedgerTransactions)..where(
              (row) =>
                  row.ledgerId.equals(ledger.id) &
                  row.transactionId.equals(transactionId),
            ))
            .go();
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
  Future<MoneyLedgerEntity> createLedger(
    String userId,
    MoneyLedgerDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.ledgerNotFound,
        );
      }

      return await database.transaction(() async {
        final now = DateTime.now().toUtc();
        final owner = await _getMemberForUser(userId, _defaultMemberId(userId));
        final ledgerId = _uuid.v4();
        await database
            .into(database.moneyLedgers)
            .insert(
              MoneyLedgersCompanion.insert(
                id: ledgerId,
                userId: userId,
                name: name,
                description: Value<String?>(_blankToNull(draft.description)),
                createdByMemberId: owner.id,
                ledgerType: draft.ledgerType,
                status: 'active',
                baseCurrencyCode: draft.baseCurrencyCode,
                settlementCycle: 'manual',
                settlementDay: 1,
                icon: Value<String?>(_blankToNull(draft.icon)),
                color: Value<String?>(_blankToNull(draft.color)),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.moneyLedgerMembers)
            .insert(
              MoneyLedgerMembersCompanion.insert(
                ledgerId: ledgerId,
                memberId: owner.id,
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _recordLedgerChange(
          userId: userId,
          recordId: ledgerId,
          operation: SyncChangeOperation.insert,
          changedFields: {
            ..._ledgerDraftSyncFields(draft),
            'created_by_member_id': owner.id,
          },
          afterVersion: 1,
        );
        return _mapLedger(await _getLedgerForUser(userId, ledgerId));
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
  Future<MoneyLedgerEntity> updateLedger(
    String userId,
    MoneyLedgerUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final name = update.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.ledgerNotFound,
        );
      }
      final existing = await _getLedgerForUser(userId, update.id);
      final changedFields = _ledgerUpdateSyncFields(existing, update);
      if (changedFields.isEmpty) {
        return _mapLedger(existing);
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyLedgers)..where(
            (ledger) =>
                ledger.id.equals(update.id) &
                ledger.userId.equals(userId) &
                ledger.isDeleted.equals(false),
          ))
          .write(
            MoneyLedgersCompanion(
              name: Value(name),
              description: Value<String?>(_blankToNull(update.description)),
              icon: Value<String?>(_blankToNull(update.icon)),
              color: Value<String?>(_blankToNull(update.color)),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordLedgerChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      return _mapLedger(await _getLedgerForUser(userId, update.id));
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
  Future<MoneyMemberEntity> createMember(
    String userId,
    MoneyMemberDraft draft, {
    required String ledgerId,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }

      return await database.transaction(() async {
        final now = DateTime.now().toUtc();
        final ledger = await _getLedgerForUser(userId, ledgerId);
        if (ledger.ledgerType == 'personal') {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidSplitTransaction,
          );
        }
        final memberId = _uuid.v4();
        await database
            .into(database.moneyMembers)
            .insert(
              MoneyMembersCompanion.insert(
                id: memberId,
                userId: userId,
                name: name,
                role: _memberRoleOrDefault(draft.role),
                status: 'active',
                color: Value<String?>(_blankToNull(draft.color)),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await database
            .into(database.moneyLedgerMembers)
            .insert(
              MoneyLedgerMembersCompanion.insert(
                ledgerId: ledger.id,
                memberId: memberId,
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _recordMemberChange(
          userId: userId,
          recordId: memberId,
          operation: SyncChangeOperation.insert,
          changedFields: {
            ..._memberDraftSyncFields(draft),
            'ledger_id': ledger.id,
          },
          afterVersion: 1,
        );
        return _mapMember(await _getMemberForUser(userId, memberId));
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
  Future<MoneyMemberEntity> updateMember(
    String userId,
    MoneyMemberUpdate update, {
    required String ledgerId,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final name = update.name.trim();
      if (name.isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }

      final ledger = await _getLedgerForUser(userId, ledgerId);
      if (ledger.ledgerType == 'personal') {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitTransaction,
        );
      }
      final member = await _getMemberForUser(userId, update.id);
      if (member.role == 'owner') {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitTransaction,
        );
      }
      final link =
          await (database.select(database.moneyLedgerMembers)
                ..where(
                  (row) =>
                      row.ledgerId.equals(ledger.id) &
                      row.memberId.equals(member.id),
                )
                ..limit(1))
              .getSingleOrNull();
      if (link == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }

      final changedFields = _memberUpdateSyncFields(member, update);
      if (changedFields.isEmpty) {
        return _mapMember(member);
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyMembers)..where(
            (row) =>
                row.id.equals(member.id) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyMembersCompanion(
              name: Value(name),
              role: Value(_memberRoleOrDefault(update.role)),
              color: Value<String?>(_blankToNull(update.color)),
              version: Value(member.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordMemberChange(
        userId: userId,
        recordId: member.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: member.version,
        afterVersion: member.version + 1,
      );
      return _mapMember(await _getMemberForUser(userId, member.id));
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
  Future<void> deleteMember(
    String userId,
    String memberId, {
    required String ledgerId,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final ledger = await _getLedgerForUser(userId, ledgerId);
      if (ledger.ledgerType == 'personal') {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitTransaction,
        );
      }
      final member = await _getMemberForUser(userId, memberId);
      if (member.role == 'owner') {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitTransaction,
        );
      }

      final link =
          await (database.select(database.moneyLedgerMembers)
                ..where(
                  (row) =>
                      row.ledgerId.equals(ledger.id) &
                      row.memberId.equals(member.id),
                )
                ..limit(1))
              .getSingleOrNull();
      if (link == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }

      final now = DateTime.now().toUtc();
      await database.transaction(() async {
        await (database.delete(database.moneyLedgerMembers)..where(
              (row) =>
                  row.ledgerId.equals(ledger.id) &
                  row.memberId.equals(member.id),
            ))
            .go();
        await (database.update(database.moneyMembers)..where(
              (row) =>
                  row.id.equals(member.id) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyMembersCompanion(
                status: const Value('inactive'),
                isDeleted: const Value(true),
                deletedAt: Value<DateTime?>(now),
                version: Value(member.version + 1),
                updatedAt: Value(now),
              ),
            );
        await _recordMemberChange(
          userId: userId,
          recordId: member.id,
          operation: SyncChangeOperation.delete,
          changedFields: {
            'ledger_id': ledger.id,
            'deleted_at': now.toIso8601String(),
          },
          beforeVersion: member.version,
          afterVersion: member.version + 1,
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

  Stream<List<MoneyMember>> _watchMembersForLedger(
    String userId,
    String ledgerId,
  ) {
    final linkQuery = database.select(database.moneyLedgerMembers)
      ..where((link) => link.ledgerId.equals(ledgerId));

    return linkQuery.watch().asyncMap((links) async {
      final memberIds = links.map((link) => link.memberId).toList();
      if (memberIds.isEmpty) {
        return const <MoneyMember>[];
      }

      return (database.select(database.moneyMembers)
            ..where(
              (member) =>
                  member.userId.equals(userId) &
                  member.id.isIn(memberIds) &
                  member.status.equals('active') &
                  member.isDeleted.equals(false),
            )
            ..orderBy([
              (member) => OrderingTerm.asc(member.createdAt),
              (member) => OrderingTerm.asc(member.name),
            ]))
          .get();
    });
  }

  Map<String, Object?> _ledgerDraftSyncFields(MoneyLedgerDraft draft) {
    return {
      'name': draft.name.trim(),
      'description': _blankToNull(draft.description),
      'ledger_type': draft.ledgerType,
      'status': 'active',
      'base_currency_code': draft.baseCurrencyCode,
      'settlement_cycle': 'manual',
      'settlement_day': 1,
      'icon': _blankToNull(draft.icon),
      'color': _blankToNull(draft.color),
    };
  }

  Map<String, Object?> _ledgerUpdateSyncFields(
    MoneyLedger existing,
    MoneyLedgerUpdate update,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
    _putIfChanged(
      fields,
      'description',
      existing.description,
      _blankToNull(update.description),
    );
    _putIfChanged(fields, 'icon', existing.icon, _blankToNull(update.icon));
    _putIfChanged(fields, 'color', existing.color, _blankToNull(update.color));
    return fields;
  }

  Map<String, Object?> _memberDraftSyncFields(MoneyMemberDraft draft) {
    return {
      'name': draft.name.trim(),
      'role': _memberRoleOrDefault(draft.role),
      'status': 'active',
      'color': _blankToNull(draft.color),
    };
  }

  Map<String, Object?> _memberUpdateSyncFields(
    MoneyMember existing,
    MoneyMemberUpdate update,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
    _putIfChanged(
      fields,
      'role',
      existing.role,
      _memberRoleOrDefault(update.role),
    );
    _putIfChanged(fields, 'color', existing.color, _blankToNull(update.color));
    return fields;
  }

  Future<void> _recordLedgerChange({
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

    await logger.recordLedgerChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordMemberChange({
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

    await logger.recordMemberChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }
}
