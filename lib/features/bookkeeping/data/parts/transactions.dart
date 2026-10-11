part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Transactions on _DriftMoneyRepositoryBase {
  @override
  Future<MoneyTransactionEntity> createTransaction(
    String userId,
    MoneyTransactionDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateTransactionDraft(draft);
      final ledgerIds = await _resolveTransactionLedgerIds(
        userId,
        draft.ledgerId,
      );
      final transaction = await database.transaction(() async {
        final transaction = await _createTransactionRow(
          userId,
          draft,
          ledgerIds,
        );
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: transaction.id,
        );
        return transaction;
      });
      await _tryRefreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: ledgerIds,
          tags: transaction.tags,
        ),
      ]);
      await _trySyncCreditAccountRepaymentRemindersForAccounts(userId, [
        transaction.accountId,
      ]);
      await _tryRebuildUsageStatsForUser(userId);
      return transaction;
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
  Future<MoneyTransactionEntity> createTransactionWithSplit(
    String userId,
    MoneyTransactionDraft draft,
    MoneySplitConfigDraft splitConfig,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateTransactionDraft(draft);
      final ledgerId = await _resolveLedgerId(userId, splitConfig.ledgerId);
      final ledgerIds = await _resolveTransactionLedgerIds(userId, ledgerId);
      final transaction = await database.transaction(() async {
        final transaction = await _createTransactionRow(
          userId,
          draft,
          ledgerIds,
        );
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: transaction.id,
        );
        await _createSplitForExistingTransaction(
          userId,
          splitConfig.forTransaction(transaction.id),
        );
        return transaction;
      });
      await _tryRefreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: ledgerIds,
          tags: transaction.tags,
        ),
      ]);
      await _trySyncCreditAccountRepaymentRemindersForAccounts(userId, [
        transaction.accountId,
      ]);
      await _tryRebuildUsageStatsForUser(userId);
      return transaction;
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
  Future<MoneyTransferResult> createTransfer(
    String userId,
    MoneyTransferDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateTransferDraft(draft);

      final result = await database.transaction(() async {
        final ledgerIds = await _resolveTransactionLedgerIds(
          userId,
          draft.ledgerId,
        );
        final fromAccount = await _getWritableAccountForUser(
          userId,
          draft.fromAccountId,
        );
        final toAccount = await _getWritableAccountForUser(
          userId,
          draft.toAccountId,
        );
        final transferCategoryId = await _getTransferCategoryId();
        if (draft.subCategoryId != null) {
          await _assertSubCategoryForUser(
            userId,
            transferCategoryId,
            draft.subCategoryId!,
            MoneyCategoryKind.expense,
          );
        }

        final fromLedger = _MutableAccountLedger.fromAccount(fromAccount)
          ..applyTransferOutgoing(draft.amountMinor)
          ..validate();
        final toLedger = _MutableAccountLedger.fromAccount(toAccount)
          ..applyTransferIncoming(draft.amountMinor)
          ..validate();

        final now = DateTime.now().toUtc();
        final outgoingId = _uuid.v4();
        final incomingId = _uuid.v4();
        final description = draft.description.trim().isEmpty
            ? '转账'
            : draft.description.trim();

        await database
            .into(database.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                id: outgoingId,
                userId: userId,
                type: MoneyTransactionType.transfer.storageValue,
                status: MoneyTransactionStatus.completed.storageValue,
                transactionAt: draft.transactionAt.toUtc(),
                amountMinor: draft.amountMinor,
                currencyCode: draft.currencyCode,
                description: description,
                notes: Value<String?>(_blankToNull(draft.notes)),
                accountId: fromAccount.id,
                toAccountId: Value<String?>(toAccount.id),
                categoryId: transferCategoryId,
                subCategoryId: Value<String?>(draft.subCategoryId),
                paymentMethod: draft.paymentMethod.storageValue,
                customPaymentMethodName: Value<String?>(
                  _blankToNull(draft.customPaymentMethodName),
                ),
                actualPayerAccount:
                    _DriftMoneyRepositoryBase._transferOutMarker,
                relatedTransactionId: Value<String?>(incomingId),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _recordTransactionChange(
          userId: userId,
          recordId: outgoingId,
          operation: SyncChangeOperation.insert,
          changedFields: _transferTransactionSyncFields(
            type: MoneyTransactionType.transfer,
            status: MoneyTransactionStatus.completed,
            transactionAt: draft.transactionAt,
            amountMinor: draft.amountMinor,
            currencyCode: draft.currencyCode,
            description: description,
            notes: draft.notes,
            accountId: fromAccount.id,
            toAccountId: toAccount.id,
            categoryId: transferCategoryId,
            subCategoryId: draft.subCategoryId,
            paymentMethod: draft.paymentMethod,
            customPaymentMethodName: draft.customPaymentMethodName,
            actualPayerAccount: _DriftMoneyRepositoryBase._transferOutMarker,
            relatedTransactionId: incomingId,
            ledgerIds: ledgerIds,
          ),
          afterVersion: 1,
        );

        await database
            .into(database.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                id: incomingId,
                userId: userId,
                type: MoneyTransactionType.transfer.storageValue,
                status: MoneyTransactionStatus.completed.storageValue,
                transactionAt: draft.transactionAt.toUtc(),
                amountMinor: draft.amountMinor,
                currencyCode: draft.currencyCode,
                description: description,
                notes: Value<String?>(_blankToNull(draft.notes)),
                accountId: toAccount.id,
                toAccountId: Value<String?>(fromAccount.id),
                categoryId: transferCategoryId,
                subCategoryId: Value<String?>(draft.subCategoryId),
                paymentMethod: draft.paymentMethod.storageValue,
                customPaymentMethodName: Value<String?>(
                  _blankToNull(draft.customPaymentMethodName),
                ),
                actualPayerAccount: _DriftMoneyRepositoryBase._transferInMarker,
                relatedTransactionId: Value<String?>(outgoingId),
                createdAt: now,
                updatedAt: now,
              ),
            );
        await _recordTransactionChange(
          userId: userId,
          recordId: incomingId,
          operation: SyncChangeOperation.insert,
          changedFields: _transferTransactionSyncFields(
            type: MoneyTransactionType.transfer,
            status: MoneyTransactionStatus.completed,
            transactionAt: draft.transactionAt,
            amountMinor: draft.amountMinor,
            currencyCode: draft.currencyCode,
            description: description,
            notes: draft.notes,
            accountId: toAccount.id,
            toAccountId: fromAccount.id,
            categoryId: transferCategoryId,
            subCategoryId: draft.subCategoryId,
            paymentMethod: draft.paymentMethod,
            customPaymentMethodName: draft.customPaymentMethodName,
            actualPayerAccount: _DriftMoneyRepositoryBase._transferInMarker,
            relatedTransactionId: outgoingId,
            ledgerIds: ledgerIds,
          ),
          afterVersion: 1,
        );

        await _updateAccountLedger(userId, fromAccount.id, fromLedger, now);
        await _updateAccountLedger(userId, toAccount.id, toLedger, now);
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: outgoingId,
        );
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: incomingId,
        );

        return MoneyTransferResult(
          outgoing: _mapTransaction(
            await _getTransactionForUser(userId, outgoingId),
            tags: const <String>[],
          ),
          incoming: _mapTransaction(
            await _getTransactionForUser(userId, incomingId),
            tags: const <String>[],
          ),
        );
      });
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        result.outgoing.accountId,
        result.incoming.accountId,
      ]);
      return result;
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
  Future<MoneyTransactionEntity> updateTransaction(
    String userId,
    MoneyTransactionUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateTransactionUpdate(update);
      final existing = await _getTransactionForUser(userId, update.id);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentStatus,
        );
      }
      final existingType = MoneyTransactionType.fromStorageValue(existing.type);
      if (existingType == MoneyTransactionType.transfer ||
          existingType != update.type) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransferAccounts,
        );
      }
      final existingStatus = MoneyTransactionStatus.fromStorageValue(
        existing.status,
      );
      if (existingStatus == MoneyTransactionStatus.voided) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransactionStatus,
        );
      }

      final expectedCategoryKind = update.type == MoneyTransactionType.income
          ? MoneyCategoryKind.income
          : MoneyCategoryKind.expense;
      await _assertCategoryForUser(
        userId,
        update.categoryId,
        expectedCategoryKind,
      );
      if (update.subCategoryId != null) {
        await _assertSubCategoryForUser(
          userId,
          update.categoryId,
          update.subCategoryId!,
          expectedCategoryKind,
        );
      }

      final oldAccount = await _getAccountForUser(userId, existing.accountId);
      final newAccount = await _getWritableAccountForUser(
        userId,
        update.accountId,
      );
      _assertTransactionAccountRules(update.type, newAccount);
      final refundAmountMinor = existing.refundAmountMinor > update.amountMinor
          ? update.amountMinor
          : existing.refundAmountMinor;
      final appliesToBalance =
          existingStatus == MoneyTransactionStatus.completed;
      final oldLedger = _MutableAccountLedger.fromAccount(oldAccount);
      if (appliesToBalance) {
        oldLedger.applyTransactionRollback(
          existingType,
          _effectiveTransactionAmountMinor(existing),
        );
      }
      final newLedger = oldAccount.id == newAccount.id
          ? oldLedger
          : _MutableAccountLedger.fromAccount(newAccount);
      if (appliesToBalance) {
        newLedger.applyTransactionCreate(
          update.type,
          _effectiveAmountMinor(
            amountMinor: update.amountMinor,
            refundAmountMinor: refundAmountMinor,
          ),
        );
      }
      newLedger.validate();
      if (oldAccount.id != newAccount.id) {
        oldLedger.validate();
      }

      final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);
      final existingTags = await _getTagsForTransaction(existing.id);

      final now = _utcNow();
      await database.transaction(() async {
        if (oldAccount.id != newAccount.id) {
          await _updateAccountLedger(userId, oldAccount.id, oldLedger, now);
        }
        await _updateAccountLedger(userId, newAccount.id, newLedger, now);

        await (database.update(database.moneyTransactions)..where(
              (row) =>
                  row.id.equals(update.id) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyTransactionsCompanion(
                transactionAt: Value(update.transactionAt.toUtc()),
                amountMinor: Value(update.amountMinor),
                currencyCode: Value(update.currencyCode),
                description: Value(_transactionUpdateDescription(update)),
                notes: Value<String?>(_blankToNull(update.notes)),
                merchant: Value<String?>(_blankToNull(update.merchant)),
                location: Value<String?>(_blankToNull(update.location)),
                accountId: Value(update.accountId),
                refundAmountMinor: Value(refundAmountMinor),
                categoryId: Value(update.categoryId),
                subCategoryId: Value<String?>(update.subCategoryId),
                paymentMethod: Value(update.paymentMethod.storageValue),
                customPaymentMethodName: Value<String?>(
                  _blankToNull(update.customPaymentMethodName),
                ),
                version: Value(existing.version + 1),
                updatedAt: Value(now),
              ),
            );
        await _replaceTransactionTags(update.id, update.tags);
        await _recordTransactionChange(
          userId: userId,
          recordId: update.id,
          operation: SyncChangeOperation.update,
          changedFields: _transactionUpdateSyncFields(
            update,
            refundAmountMinor: refundAmountMinor,
          ),
          beforeVersion: existing.version,
          afterVersion: existing.version + 1,
        );
      });

      final updated = _mapTransaction(
        await _getTransactionForUser(userId, update.id),
        tags: await _getTagsForTransaction(update.id),
      );
      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: existingType,
          accountId: existing.accountId,
          categoryId: existing.categoryId,
          subCategoryId: existing.subCategoryId,
          ledgerIds: ledgerIds,
          tags: existingTags,
        ),
        _BudgetTransactionImpact(
          type: updated.type,
          accountId: updated.accountId,
          categoryId: updated.categoryId,
          subCategoryId: updated.subCategoryId,
          ledgerIds: ledgerIds,
          tags: updated.tags,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        existing.accountId,
        updated.accountId,
      ]);
      await _tryRebuildUsageStatsForUser(userId);
      return updated;
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
  Future<MoneyTransactionEntity> recordTransactionRefund(
    String userId,
    String transactionId,
    int refundAmountMinor,
  ) async {
    if (refundAmountMinor < 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransactionAmount,
      );
    }

    try {
      await ensureReadyForUser(userId);
      final existing = await _getTransactionForUser(userId, transactionId);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentStatus,
        );
      }
      final type = MoneyTransactionType.fromStorageValue(existing.type);
      if (type == MoneyTransactionType.transfer) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransferAccounts,
        );
      }
      if (existing.status != MoneyTransactionStatus.completed.storageValue) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransactionStatus,
        );
      }
      if (refundAmountMinor > existing.amountMinor) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransactionAmount,
        );
      }
      if (refundAmountMinor == existing.refundAmountMinor) {
        return _mapTransaction(
          existing,
          tags: await _getTagsForTransaction(existing.id),
        );
      }

      final account = await _getAccountForUser(userId, existing.accountId);
      final ledger = _MutableAccountLedger.fromAccount(account);
      final delta = refundAmountMinor - existing.refundAmountMinor;
      if (delta > 0) {
        ledger.applyTransactionRollback(type, delta);
      } else {
        ledger.applyTransactionCreate(type, -delta);
      }
      ledger.validate();

      final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);
      final tags = await _getTagsForTransaction(existing.id);
      final now = _utcNow();
      await database.transaction(() async {
        await _updateAccountLedger(userId, account.id, ledger, now);
        await (database.update(database.moneyTransactions)..where(
              (row) =>
                  row.id.equals(transactionId) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyTransactionsCompanion(
                refundAmountMinor: Value(refundAmountMinor),
                version: Value(existing.version + 1),
                updatedAt: Value(now),
              ),
            );
        await _recordTransactionChange(
          userId: userId,
          recordId: transactionId,
          operation: SyncChangeOperation.update,
          changedFields: _transactionSnapshotSyncFields(
            existing,
            refundAmountMinor: refundAmountMinor,
            ledgerIds: ledgerIds,
            tags: tags,
          ),
          beforeVersion: existing.version,
          afterVersion: existing.version + 1,
        );
      });

      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: type,
          accountId: existing.accountId,
          categoryId: existing.categoryId,
          subCategoryId: existing.subCategoryId,
          ledgerIds: ledgerIds,
          tags: tags,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        existing.accountId,
      ]);
      await _tryRebuildUsageStatsForUser(userId);

      return _mapTransaction(
        await _getTransactionForUser(userId, transactionId),
        tags: tags,
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
  Future<MoneyTransferResult> updateTransfer(
    String userId,
    MoneyTransferUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateTransferUpdate(update);

      final result = await database.transaction(() async {
        final selected = await _getTransactionForUser(userId, update.id);
        final pair = await _getTransferPair(userId, selected);
        final outgoing = pair.outgoing;
        final incoming = pair.incoming;

        final accounts = <String, MoneyAccount>{};
        void addAccount(MoneyAccount account) {
          accounts[account.id] = account;
        }

        addAccount(await _getAccountForUser(userId, outgoing.accountId));
        addAccount(await _getAccountForUser(userId, incoming.accountId));
        addAccount(
          await _getWritableAccountForUser(userId, update.fromAccountId),
        );
        addAccount(
          await _getWritableAccountForUser(userId, update.toAccountId),
        );

        final ledgers = <String, _MutableAccountLedger>{
          for (final account in accounts.values)
            account.id: _MutableAccountLedger.fromAccount(account),
        };
        ledgers[outgoing.accountId]!.applyTransferOutgoingRollback(
          outgoing.amountMinor,
        );
        ledgers[incoming.accountId]!.applyTransferIncomingRollback(
          incoming.amountMinor,
        );
        ledgers[update.fromAccountId]!.applyTransferOutgoing(
          update.amountMinor,
        );
        ledgers[update.toAccountId]!.applyTransferIncoming(update.amountMinor);

        for (final ledger in ledgers.values) {
          ledger.validate();
        }

        final now = DateTime.now().toUtc();
        for (final entry in ledgers.entries) {
          await _updateAccountLedger(userId, entry.key, entry.value, now);
        }

        final description = MoneyTransactionType.transfer.label;
        final transferCategoryId = await _getTransferCategoryId();
        if (update.subCategoryId != null) {
          await _assertSubCategoryForUser(
            userId,
            transferCategoryId,
            update.subCategoryId!,
            MoneyCategoryKind.expense,
          );
        }
        await _writeTransferRowUpdate(
          userId: userId,
          transactionId: outgoing.id,
          transactionAt: update.transactionAt,
          amountMinor: update.amountMinor,
          currencyCode: update.currencyCode,
          description: description,
          notes: update.notes,
          accountId: update.fromAccountId,
          toAccountId: update.toAccountId,
          categoryId: transferCategoryId,
          subCategoryId: update.subCategoryId,
          paymentMethod: update.paymentMethod,
          customPaymentMethodName: update.customPaymentMethodName,
          beforeVersion: outgoing.version,
          now: now,
        );
        await _writeTransferRowUpdate(
          userId: userId,
          transactionId: incoming.id,
          transactionAt: update.transactionAt,
          amountMinor: update.amountMinor,
          currencyCode: update.currencyCode,
          description: description,
          notes: update.notes,
          accountId: update.toAccountId,
          toAccountId: update.fromAccountId,
          categoryId: transferCategoryId,
          subCategoryId: update.subCategoryId,
          paymentMethod: update.paymentMethod,
          customPaymentMethodName: update.customPaymentMethodName,
          beforeVersion: incoming.version,
          now: now,
        );

        return MoneyTransferResult(
          outgoing: _mapTransaction(
            await _getTransactionForUser(userId, outgoing.id),
            tags: const <String>[],
          ),
          incoming: _mapTransaction(
            await _getTransactionForUser(userId, incoming.id),
            tags: const <String>[],
          ),
        );
      });
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        result.outgoing.accountId,
        result.incoming.accountId,
      ]);
      return result;
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
  Future<MoneyTransactionEntity> getTransactionForUser(
    String userId,
    String transactionId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      return _mapTransaction(
        await _getTransactionForUser(userId, transactionId),
        tags: const <String>[],
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
  Future<MoneyTransactionEntity> setTransactionStatus(
    String userId,
    String transactionId,
    MoneyTransactionStatus status,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final existing = await _getTransactionForUser(userId, transactionId);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentStatus,
        );
      }
      final type = MoneyTransactionType.fromStorageValue(existing.type);
      if (type == MoneyTransactionType.transfer) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransferAccounts,
        );
      }

      final currentStatus = MoneyTransactionStatus.fromStorageValue(
        existing.status,
      );
      if (currentStatus == status) {
        return _mapTransaction(
          existing,
          tags: await _getTagsForTransaction(existing.id),
        );
      }
      final allowed = switch (currentStatus) {
        MoneyTransactionStatus.pending =>
          status == MoneyTransactionStatus.completed ||
              status == MoneyTransactionStatus.voided,
        MoneyTransactionStatus.completed =>
          status == MoneyTransactionStatus.voided,
        MoneyTransactionStatus.voided => false,
      };
      if (!allowed) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransactionStatus,
        );
      }

      final account = await _getAccountForUser(userId, existing.accountId);
      final ledger = _MutableAccountLedger.fromAccount(account);
      final effectiveAmountMinor = _effectiveTransactionAmountMinor(existing);
      if (status == MoneyTransactionStatus.completed) {
        ledger.applyTransactionCreate(type, effectiveAmountMinor);
      } else if (currentStatus == MoneyTransactionStatus.completed) {
        ledger.applyTransactionRollback(type, effectiveAmountMinor);
      }
      ledger.validate();

      final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);
      final tags = await _getTagsForTransaction(existing.id);
      final now = _utcNow();
      await database.transaction(() async {
        await _updateAccountLedger(userId, account.id, ledger, now);
        await (database.update(database.moneyTransactions)..where(
              (row) =>
                  row.id.equals(transactionId) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyTransactionsCompanion(
                status: Value(status.storageValue),
                version: Value(existing.version + 1),
                updatedAt: Value(now),
              ),
            );
        await _recordTransactionChange(
          userId: userId,
          recordId: transactionId,
          operation: SyncChangeOperation.update,
          changedFields: {'status': status.storageValue},
          beforeVersion: existing.version,
          afterVersion: existing.version + 1,
        );
      });

      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: type,
          accountId: existing.accountId,
          categoryId: existing.categoryId,
          subCategoryId: existing.subCategoryId,
          ledgerIds: ledgerIds,
          tags: tags,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        existing.accountId,
      ]);
      await _tryRebuildUsageStatsForUser(userId);

      return _mapTransaction(
        await _getTransactionForUser(userId, transactionId),
        tags: tags,
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
  Future<int> setTransactionsStatus(
    String userId,
    List<String> transactionIds,
    MoneyTransactionStatus status,
  ) async {
    final uniqueIds = _uniqueTransactionIds(transactionIds);
    if (uniqueIds.isEmpty) {
      return 0;
    }

    try {
      await ensureReadyForUser(userId);
      final impacts = <_BudgetTransactionImpact>[];
      final accountIds = <String>{};
      var applied = 0;
      for (final transactionId in uniqueIds) {
        final changed = await _applyTransactionStatus(
          userId: userId,
          transactionId: transactionId,
          status: status,
          impacts: impacts,
          accountIds: accountIds,
        );
        if (changed) {
          applied += 1;
        }
      }
      if (applied == 0) {
        return 0;
      }
      // 批量场景下把这些副作用攒到最后各跑一次：每条都刷一遍预算快照
      // 会把「确认 20 笔待处理」拖成 20 次全量重算。
      if (impacts.isNotEmpty) {
        await _refreshBudgetSnapshotsForTransactionImpacts(userId, impacts);
      }
      if (accountIds.isNotEmpty) {
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds.toList(),
        );
      }
      await _tryRebuildUsageStatsForUser(userId);
      return applied;
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

  /// 单条状态变更的核心逻辑，返回是否真的写入。
  ///
  /// 不合法的流转直接返回 false：批量操作里一条不合适不该让整批失败，
  /// 单条场景的错误提示由 `setTransactionStatus` 负责抛出。
  Future<bool> _applyTransactionStatus({
    required String userId,
    required String transactionId,
    required MoneyTransactionStatus status,
    required List<_BudgetTransactionImpact> impacts,
    required Set<String> accountIds,
  }) async {
    final existing =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      return false;
    }
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
      return false;
    }
    final type = MoneyTransactionType.fromStorageValue(existing.type);
    if (type == MoneyTransactionType.transfer) {
      return false;
    }

    final currentStatus = MoneyTransactionStatus.fromStorageValue(
      existing.status,
    );
    if (currentStatus == status) {
      return false;
    }
    final allowed = switch (currentStatus) {
      MoneyTransactionStatus.pending =>
        status == MoneyTransactionStatus.completed ||
            status == MoneyTransactionStatus.voided,
      MoneyTransactionStatus.completed =>
        status == MoneyTransactionStatus.voided,
      MoneyTransactionStatus.voided => false,
    };
    if (!allowed) {
      return false;
    }

    final account = await _getAccountForUser(userId, existing.accountId);
    final ledger = _MutableAccountLedger.fromAccount(account);
    final effectiveAmountMinor = _effectiveTransactionAmountMinor(existing);
    if (status == MoneyTransactionStatus.completed) {
      ledger.applyTransactionCreate(type, effectiveAmountMinor);
    } else if (currentStatus == MoneyTransactionStatus.completed) {
      ledger.applyTransactionRollback(type, effectiveAmountMinor);
    }
    ledger.validate();

    final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);
    final tags = await _getTagsForTransaction(existing.id);
    final now = _utcNow();
    await database.transaction(() async {
      await _updateAccountLedger(userId, account.id, ledger, now);
      await (database.update(database.moneyTransactions)..where(
            (row) =>
                row.id.equals(transactionId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyTransactionsCompanion(
              status: Value(status.storageValue),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordTransactionChange(
        userId: userId,
        recordId: transactionId,
        operation: SyncChangeOperation.update,
        changedFields: {'status': status.storageValue},
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    });

    impacts.add(
      _BudgetTransactionImpact(
        type: type,
        accountId: existing.accountId,
        categoryId: existing.categoryId,
        subCategoryId: existing.subCategoryId,
        ledgerIds: ledgerIds,
        tags: tags,
      ),
    );
    accountIds.add(existing.accountId);
    return true;
  }

  @override
  Future<int> updateTransactions(
    String userId,
    List<String> transactionIds,
    MoneyTransactionBatchUpdate patch,
  ) async {
    final uniqueIds = _uniqueTransactionIds(transactionIds);
    if (uniqueIds.isEmpty || patch.isEmpty) {
      return 0;
    }

    try {
      await ensureReadyForUser(userId);
      final impacts = <_BudgetTransactionImpact>[];
      final accountIds = <String>{};
      var applied = 0;
      for (final transactionId in uniqueIds) {
        final changed = await _applyTransactionBatchUpdate(
          userId: userId,
          transactionId: transactionId,
          patch: patch,
          impacts: impacts,
          accountIds: accountIds,
        );
        if (changed) {
          applied += 1;
        }
      }
      if (applied == 0) {
        return 0;
      }
      if (impacts.isNotEmpty) {
        await _refreshBudgetSnapshotsForTransactionImpacts(userId, impacts);
      }
      if (accountIds.isNotEmpty) {
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds.toList(),
        );
      }
      await _tryRebuildUsageStatsForUser(userId);
      return applied;
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

  /// 单条批量补丁的核心逻辑，返回是否真的写入。
  ///
  /// 不合适的流水（分期入账 / 转账 / 已作废 / 找不到）返回 false：
  /// 一条不合适不该让整批失败，条数差由调用方提示。
  Future<bool> _applyTransactionBatchUpdate({
    required String userId,
    required String transactionId,
    required MoneyTransactionBatchUpdate patch,
    required List<_BudgetTransactionImpact> impacts,
    required Set<String> accountIds,
  }) async {
    final existing =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      return false;
    }
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
      return false;
    }
    final type = MoneyTransactionType.fromStorageValue(existing.type);
    // 转账是一对两行（转出 / 转入），只改其中一行的账户或分类会让两行对不上。
    if (type == MoneyTransactionType.transfer) {
      return false;
    }
    final status = MoneyTransactionStatus.fromStorageValue(existing.status);
    if (status == MoneyTransactionStatus.voided) {
      return false;
    }
    final expectedCategoryKind = type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;

    String? nextCategoryId;
    String? nextSubCategoryId;
    final touchesCategory = patch.categoryId != null;
    if (patch.categoryId != null) {
      await _assertCategoryForUser(
        userId,
        patch.categoryId!,
        expectedCategoryKind,
      );
      final nextSub = patch.subCategoryId;
      if (nextSub != null) {
        await _assertSubCategoryForUser(
          userId,
          patch.categoryId!,
          nextSub,
          expectedCategoryKind,
        );
      }
      nextCategoryId = patch.categoryId;
      nextSubCategoryId = nextSub;
    }

    final targetAccountId = patch.accountId;
    var touchesAccount = false;
    MoneyAccount? oldAccount;
    MoneyAccount? newAccount;
    if (targetAccountId != null && targetAccountId != existing.accountId) {
      oldAccount = await _getAccountForUser(userId, existing.accountId);
      newAccount = await _getWritableAccountForUser(userId, targetAccountId);
      _assertTransactionAccountRules(type, newAccount);
      touchesAccount = true;
    }

    final existingTags = await _getTagsForTransaction(existing.id);
    final nextTags = _mergeTransactionTags(existingTags, patch);
    final tagsChanged = !_sameTagSets(existingTags, nextTags);

    if (!touchesCategory && !touchesAccount && !tagsChanged) {
      return false;
    }

    final effectiveAmountMinor = _effectiveTransactionAmountMinor(existing);
    final appliesToBalance = status == MoneyTransactionStatus.completed;
    _MutableAccountLedger? oldLedger;
    _MutableAccountLedger? newLedger;
    if (touchesAccount && appliesToBalance) {
      oldLedger = _MutableAccountLedger.fromAccount(oldAccount!)
        ..applyTransactionRollback(type, effectiveAmountMinor);
      newLedger = _MutableAccountLedger.fromAccount(newAccount!)
        ..applyTransactionCreate(type, effectiveAmountMinor);
      newLedger.validate();
      oldLedger.validate();
    }

    final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);
    final now = _utcNow();
    final changedFields = <String, Object?>{
      if (touchesAccount) 'account_id': targetAccountId,
      if (touchesCategory) 'category_id': nextCategoryId ?? existing.categoryId,
      if (touchesCategory) 'sub_category_id': nextSubCategoryId,
      if (tagsChanged) 'tags': nextTags,
    };
    await database.transaction(() async {
      if (touchesAccount && appliesToBalance) {
        await _updateAccountLedger(userId, oldAccount!.id, oldLedger!, now);
        await _updateAccountLedger(userId, newAccount!.id, newLedger!, now);
      }
      await (database.update(database.moneyTransactions)..where(
            (row) =>
                row.id.equals(transactionId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyTransactionsCompanion(
              accountId: touchesAccount
                  ? Value(targetAccountId!)
                  : const Value.absent(),
              categoryId: touchesCategory
                  ? Value(nextCategoryId ?? existing.categoryId)
                  : const Value.absent(),
              subCategoryId: touchesCategory
                  ? Value<String?>(nextSubCategoryId)
                  : const Value.absent(),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      if (tagsChanged) {
        await _replaceTransactionTags(existing.id, nextTags);
      }
      await _recordTransactionChange(
        userId: userId,
        recordId: transactionId,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
    });

    final afterTags = tagsChanged ? nextTags : existingTags;
    impacts.add(
      _BudgetTransactionImpact(
        type: type,
        accountId: existing.accountId,
        categoryId: existing.categoryId,
        subCategoryId: existing.subCategoryId,
        ledgerIds: ledgerIds,
        tags: existingTags,
      ),
    );
    // 同一条流水的前后两个状态都要重算预算快照：少了「改之前」这一条，
    // 原分类 / 原账户下的额度不会被释放。
    impacts.add(
      _BudgetTransactionImpact(
        type: type,
        accountId: touchesAccount ? targetAccountId! : existing.accountId,
        categoryId: nextCategoryId ?? existing.categoryId,
        subCategoryId: touchesCategory
            ? nextSubCategoryId
            : existing.subCategoryId,
        ledgerIds: ledgerIds,
        tags: afterTags,
      ),
    );
    accountIds.add(existing.accountId);
    if (touchesAccount) {
      accountIds.add(targetAccountId!);
    }
    return true;
  }

  @override
  Future<int> deleteTransactions(
    String userId,
    List<String> transactionIds,
  ) async {
    final uniqueIds = _uniqueTransactionIds(transactionIds);
    if (uniqueIds.isEmpty) {
      return 0;
    }

    try {
      await ensureReadyForUser(userId);
      final impacts = <_BudgetTransactionImpact>[];
      final accountIds = <String>{};
      var applied = 0;
      for (final transactionId in uniqueIds) {
        final changed = await _applyTransactionDelete(
          userId: userId,
          transactionId: transactionId,
          impacts: impacts,
          accountIds: accountIds,
        );
        if (changed) {
          applied += 1;
        }
      }
      if (applied == 0) {
        return 0;
      }
      if (impacts.isNotEmpty) {
        await _refreshBudgetSnapshotsForTransactionImpacts(userId, impacts);
      }
      if (accountIds.isNotEmpty) {
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds.toList(),
        );
      }
      await _tryRebuildUsageStatsForUser(userId);
      return applied;
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
  Future<void> deleteTransaction(String userId, String transactionId) async {
    try {
      final transaction = await _getTransactionForUser(userId, transactionId);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(transaction)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentStatus,
        );
      }
      final impacts = <_BudgetTransactionImpact>[];
      final accountIds = <String>{};
      final deleted = await _applyTransactionDelete(
        userId: userId,
        transactionId: transactionId,
        impacts: impacts,
        accountIds: accountIds,
      );
      if (!deleted) {
        return;
      }
      if (impacts.isNotEmpty) {
        await _refreshBudgetSnapshotsForTransactionImpacts(userId, impacts);
      }
      if (accountIds.isNotEmpty) {
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds.toList(),
        );
      }
      await _tryRebuildUsageStatsForUser(userId);
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
  Future<int> restoreTransactions(
    String userId,
    List<String> transactionIds,
  ) async {
    final uniqueIds = _uniqueTransactionIds(transactionIds);
    if (uniqueIds.isEmpty) {
      return 0;
    }

    try {
      await ensureReadyForUser(userId);
      final impacts = <_BudgetTransactionImpact>[];
      final accountIds = <String>{};
      var applied = 0;
      for (final transactionId in uniqueIds) {
        final changed = await _applyTransactionRestore(
          userId: userId,
          transactionId: transactionId,
          impacts: impacts,
          accountIds: accountIds,
        );
        if (changed) {
          applied += 1;
        }
      }
      if (applied == 0) {
        return 0;
      }
      if (impacts.isNotEmpty) {
        await _refreshBudgetSnapshotsForTransactionImpacts(userId, impacts);
      }
      if (accountIds.isNotEmpty) {
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds.toList(),
        );
      }
      await _tryRebuildUsageStatsForUser(userId);
      return applied;
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
  Future<List<MoneyTransactionEntity>> listDeletedTransactions(
    String userId, {
    DateTime? deletedAfter,
    int limit = 100,
  }) async {
    await ensureReadyForUser(userId);
    final query = database.select(database.moneyTransactions)
      ..where((row) => row.userId.equals(userId) & row.isDeleted.equals(true))
      ..orderBy([(row) => OrderingTerm.desc(row.deletedAt)])
      ..limit(limit < 1 ? 1 : limit);
    final rows = await query.get();

    // 时间窗在 Dart 侧过滤：deletedAt 可空，写进 SQL 谓词要处理一堆 nullable
    // 比较分支，而回收站最多也就几十条。
    final after = deletedAfter?.toUtc();
    final kept = rows
        .where((row) {
          final deletedAt = row.deletedAt;
          if (after == null || deletedAt == null) {
            return true;
          }
          return !deletedAt.isBefore(after);
        })
        .toList(growable: false);
    if (kept.isEmpty) {
      return const <MoneyTransactionEntity>[];
    }

    final tagsByTransactionId = await _getTagsForTransactions(
      kept.map((row) => row.id),
    );
    return kept
        .map(
          (row) => _mapTransaction(
            row,
            tags: tagsByTransactionId[row.id] ?? const <String>[],
          ),
        )
        .toList(growable: false);
  }

  /// 单条恢复的核心逻辑，返回是否真的恢复。
  ///
  /// 恢复是删除的严格逆操作：账户余额加回去、分期 run 状态撤回、预算快照重算。
  /// 恢复不了的情况（账户已被删、分期入账流水、转账的另一半找不到）一律**跳过**
  /// 而不是让整批失败——和批量删除保持同一套语义。
  Future<bool> _applyTransactionRestore({
    required String userId,
    required String transactionId,
    required List<_BudgetTransactionImpact> impacts,
    required Set<String> accountIds,
  }) async {
    final transaction =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    if (transaction == null) {
      return false;
    }
    // 分期入账流水由分期计划驱动：计划那边记着「已还」，把流水恢复出来会
    // 变成计划与流水互相矛盾，宁可不恢复。
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(transaction)) {
      return false;
    }

    final type = MoneyTransactionType.fromStorageValue(transaction.type);
    final now = _utcNow();

    if (type == MoneyTransactionType.transfer) {
      final relatedId = transaction.relatedTransactionId;
      if (relatedId == null) {
        return false;
      }
      final related =
          await (database.select(database.moneyTransactions)
                ..where(
                  (row) =>
                      row.id.equals(relatedId) &
                      row.userId.equals(userId) &
                      row.isDeleted.equals(true),
                )
                ..limit(1))
              .getSingleOrNull();
      if (related == null) {
        return false;
      }
      final outgoing =
          transaction.actualPayerAccount ==
              _DriftMoneyRepositoryBase._transferOutMarker
          ? transaction
          : related;
      final incoming = identical(outgoing, transaction) ? related : transaction;

      final fromAccount = await _findAccountForUser(userId, outgoing.accountId);
      final toAccount = await _findAccountForUser(userId, incoming.accountId);
      if (fromAccount == null || toAccount == null) {
        return false;
      }
      final fromLedger = _MutableAccountLedger.fromAccount(fromAccount)
        ..applyTransferOutgoing(outgoing.amountMinor)
        ..validate();
      final toLedger = _MutableAccountLedger.fromAccount(toAccount)
        ..applyTransferIncoming(incoming.amountMinor)
        ..validate();

      await database.transaction(() async {
        await _updateAccountLedger(userId, fromAccount.id, fromLedger, now);
        await _updateAccountLedger(userId, toAccount.id, toLedger, now);
        await _unmarkTransactionDeleted(
          userId,
          outgoing.id,
          outgoing.version,
          now,
        );
        await _unmarkTransactionDeleted(
          userId,
          incoming.id,
          incoming.version,
          now,
        );
      });
      // 转账不进预算口径，删除时也没记 impact，这里保持一致。
      accountIds.add(outgoing.accountId);
      accountIds.add(incoming.accountId);
      return true;
    }

    final account = await _findAccountForUser(userId, transaction.accountId);
    if (account == null) {
      return false;
    }
    final transactionStatus = MoneyTransactionStatus.fromStorageValue(
      transaction.status,
    );
    final ledger = _MutableAccountLedger.fromAccount(account);
    if (transactionStatus == MoneyTransactionStatus.completed) {
      ledger.applyTransactionCreate(
        type,
        _effectiveTransactionAmountMinor(transaction),
      );
    }
    ledger.validate();

    final ledgerIds = await _ledgerIdsForTransactionRow(userId, transaction.id);
    final transactionTags = await _getTagsForTransaction(transaction.id);
    await database.transaction(() async {
      await _updateAccountLedger(userId, account.id, ledger, now);
      await _unmarkTransactionDeleted(
        userId,
        transaction.id,
        transaction.version,
        now,
      );
      await _restoreAutoPostingRunForTransaction(
        userId: userId,
        transaction: transaction,
        now: now,
      );
    });

    impacts.add(
      _BudgetTransactionImpact(
        type: type,
        accountId: transaction.accountId,
        categoryId: transaction.categoryId,
        subCategoryId: transaction.subCategoryId,
        ledgerIds: ledgerIds,
        tags: transactionTags,
      ),
    );
    accountIds.add(transaction.accountId);
    return true;
  }

  /// 找账户但不抛异常——恢复一条流水时，它的账户可能已经在回收站里了，
  /// 这种情况应该跳过这条，而不是让整批恢复失败。
  Future<MoneyAccount?> _findAccountForUser(
    String userId,
    String accountId,
  ) async {
    return (database.select(database.moneyAccounts)
          ..where(
            (row) =>
                row.id.equals(accountId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> _unmarkTransactionDeleted(
    String userId,
    String transactionId,
    int beforeVersion,
    DateTime now,
  ) async {
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(true),
        ))
        .write(
          MoneyTransactionsCompanion(
            isDeleted: const Value(false),
            deletedAt: const Value<DateTime?>(null),
            version: Value(beforeVersion + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordTransactionChange(
      userId: userId,
      recordId: transactionId,
      operation: SyncChangeOperation.update,
      changedFields: _restoreSyncFields(),
      beforeVersion: beforeVersion,
      afterVersion: beforeVersion + 1,
    );
  }

  /// 删除流水时把对应的自动记账 run 标成了 userDeleted（否则下一轮还会补记），
  /// 恢复时要把状态退回去，不然这一次执行就永久消失了。
  Future<void> _restoreAutoPostingRunForTransaction({
    required String userId,
    required MoneyTransaction transaction,
    required DateTime now,
  }) async {
    final runId = transaction.sourceTemplateRunId;
    if (runId == null || runId.trim().isEmpty) {
      return;
    }
    final runRow = await _getAutoPostingRunById(userId, runId);
    if (runRow == null) {
      return;
    }
    final run = _mapAutoPostingRun(runRow);
    if (run.status != MoneyAutoPostingRunStatus.userDeleted) {
      return;
    }
    await _writeAutoPostingRunState(
      existing: run,
      status: MoneyAutoPostingRunStatus.posted,
      transactionId: transaction.id,
      postedAt: run.postedAt ?? now,
      errorCode: null,
      errorMessage: null,
      updatedAt: now,
    );
  }

  /// 单条删除的核心逻辑，返回是否真的删除。
  ///
  /// 与 [deleteTransaction] 的区别只在不抛「分期入账」而直接跳过——
  /// 批量删除里混进一条分期流水不该让整批失败。
  Future<bool> _applyTransactionDelete({
    required String userId,
    required String transactionId,
    required List<_BudgetTransactionImpact> impacts,
    required Set<String> accountIds,
  }) async {
    final transaction =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (transaction == null) {
      return false;
    }
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(transaction)) {
      return false;
    }

    final type = MoneyTransactionType.fromStorageValue(transaction.type);
    if (type == MoneyTransactionType.transfer) {
      final pair = await _getTransferPair(userId, transaction);
      await database.transaction(() async {
        await _deleteTransferPair(userId, transaction);
      });
      accountIds.add(pair.outgoing.accountId);
      accountIds.add(pair.incoming.accountId);
      return true;
    }

    final account = await _getAccountForUser(userId, transaction.accountId);
    final transactionStatus = MoneyTransactionStatus.fromStorageValue(
      transaction.status,
    );
    final ledger = _MutableAccountLedger.fromAccount(account);
    if (transactionStatus == MoneyTransactionStatus.completed) {
      ledger.applyTransactionRollback(
        type,
        _effectiveTransactionAmountMinor(transaction),
      );
    }
    ledger.validate();
    final ledgerIds = await _ledgerIdsForTransaction(userId, transaction.id);
    final transactionTags = await _getTagsForTransaction(transaction.id);
    final now = _utcNow();
    await database.transaction(() async {
      await _updateAccountLedger(userId, account.id, ledger, now);
      await _markTransactionDeleted(
        userId,
        transaction.id,
        now,
        beforeVersion: transaction.version,
      );
      if ((transaction.sourceTemplateRunId?.trim().isNotEmpty ?? false)) {
        await _markAutoPostingRunUserDeleted(
          userId: userId,
          runId: transaction.sourceTemplateRunId!,
          deletedAt: now,
        );
      }
    });
    impacts.add(
      _BudgetTransactionImpact(
        type: type,
        accountId: transaction.accountId,
        categoryId: transaction.categoryId,
        subCategoryId: transaction.subCategoryId,
        ledgerIds: ledgerIds,
        tags: transactionTags,
      ),
    );
    accountIds.add(transaction.accountId);
    return true;
  }

  List<String> _uniqueTransactionIds(List<String> transactionIds) {
    final uniqueIds = <String>[];
    final seen = <String>{};
    for (final id in transactionIds) {
      final trimmed = id.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      uniqueIds.add(trimmed);
    }
    return uniqueIds;
  }

  /// 在已有标签上应用「添加 / 移除」补丁（去重、去空、忽略重复添加）。
  List<String> _mergeTransactionTags(
    List<String> existingTags,
    MoneyTransactionBatchUpdate patch,
  ) {
    final removeSet = <String>{
      for (final tag in patch.tagsToRemove)
        if (tag.trim().isNotEmpty) tag.trim(),
    };
    final merged = <String>[];
    final seen = <String>{};
    void append(String value) {
      final tag = value.trim();
      if (tag.isEmpty || removeSet.contains(tag) || !seen.add(tag)) {
        return;
      }
      merged.add(tag);
    }

    for (final tag in existingTags) {
      append(tag);
    }
    for (final tag in patch.tagsToAdd) {
      append(tag);
    }
    return merged;
  }

  /// 只看集合是否相同：标签在库里按字典序存，补丁后的顺序是「旧 + 新增」，
  /// 逐位比较会把「没变化」误判成「变了」。
  bool _sameTagSets(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    final set = <String>{...left};
    for (final tag in right) {
      if (!set.contains(tag)) {
        return false;
      }
    }
    return true;
  }

  @override
  Future<MoneyTransactionPage> listTransactions(
    String userId,
    MoneyTransactionQuery query,
  ) async {
    try {
      final page = query.page < 1 ? 1 : query.page;
      final pageSize = query.pageSize < 1 ? 20 : query.pageSize;
      final transactionIds = query.ledgerId == null
          ? null
          : await _transactionIdsForLedger(userId, query.ledgerId!);
      final accountType = query.accountType;
      final accountIdsForType = accountType == null
          ? null
          : await _accountIdsForType(userId, accountType);
      final totalExp = database.moneyTransactions.id.count();
      final countQuery = database.selectOnly(database.moneyTransactions)
        ..addColumns([totalExp])
        ..where(
          _transactionPredicate(
            database.moneyTransactions,
            userId,
            query,
            transactionIds: transactionIds,
            accountIdsForType: accountIdsForType,
          ),
        );
      final total = (await countQuery.getSingle()).read(totalExp) ?? 0;

      final rows =
          await (database.select(database.moneyTransactions)
                ..where(
                  (row) => _transactionPredicate(
                    row,
                    userId,
                    query,
                    transactionIds: transactionIds,
                    accountIdsForType: accountIdsForType,
                  ),
                )
                ..orderBy(_transactionOrderTerms(query))
                ..limit(pageSize, offset: (page - 1) * pageSize))
              .get();

      final tagsByTransactionId = await _getTagsForTransactions(
        rows.map((row) => row.id),
      );
      final items = [
        for (final row in rows)
          _mapTransaction(row, tags: tagsByTransactionId[row.id] ?? const []),
      ];

      return MoneyTransactionPage(
        items: items,
        page: page,
        pageSize: pageSize,
        hasMore: page * pageSize < total,
        total: total,
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  /// 流水排序：主字段可切换（时间 / 金额），次字段固定为创建时间，
  /// 保证同一批数据的顺序稳定。
  List<OrderingTerm Function($MoneyTransactionsTable)> _transactionOrderTerms(
    MoneyTransactionQuery query,
  ) {
    final mode = query.sortAscending ? OrderingMode.asc : OrderingMode.desc;
    return [
      if (query.sortField == MoneyTransactionSortField.amount)
        (row) => OrderingTerm(
          expression: row.amountMinor - row.refundAmountMinor,
          mode: mode,
        )
      else
        (row) => OrderingTerm(expression: row.transactionAt, mode: mode),
      (row) => OrderingTerm.desc(row.createdAt),
    ];
  }

  @override
  Future<MoneyTransactionSummary> summarizeTransactions(
    String userId,
    MoneyTransactionQuery query,
  ) async {
    try {
      final transactionIds = query.ledgerId == null
          ? null
          : await _transactionIdsForLedger(userId, query.ledgerId!);
      final accountType = query.accountType;
      final accountIdsForType = accountType == null
          ? null
          : await _accountIdsForType(userId, accountType);

      final table = database.moneyTransactions;
      final basePredicate = _transactionPredicate(
        table,
        userId,
        query,
        transactionIds: transactionIds,
        accountIdsForType: accountIdsForType,
      );

      Future<int> countOf(Expression<bool> predicate) async {
        final countExp = table.id.count();
        final statement = database.selectOnly(table)
          ..addColumns([countExp])
          ..where(predicate);
        return (await statement.getSingle()).read(countExp) ?? 0;
      }

      /// 与列表里的有效金额保持一致：金额扣除退款。
      Future<int> netSumOf(Expression<bool> predicate) async {
        final amountExp = table.amountMinor.sum();
        final refundExp = table.refundAmountMinor.sum();
        final statement = database.selectOnly(table)
          ..addColumns([amountExp, refundExp])
          ..where(predicate);
        final row = await statement.getSingle();
        return (row.read(amountExp) ?? 0) - (row.read(refundExp) ?? 0);
      }

      // 转账不算收支：显式按 type 限定，再排除转账分类（历史数据里可能存在
      // 「用转账分类记的支出/收入」，统计页与账户余额同样排除）。
      Expression<bool> excludingTransferCategory(Expression<bool> predicate) {
        return predicate &
            table.categoryId.isNotIn(
              _DriftMoneyRepositoryBase._transferCategoryIds,
            );
      }

      final expensePredicate = excludingTransferCategory(
        basePredicate &
            table.type.equals(MoneyTransactionType.expense.storageValue),
      );
      final incomePredicate = excludingTransferCategory(
        basePredicate &
            table.type.equals(MoneyTransactionType.income.storageValue),
      );

      final results = await Future.wait([
        countOf(expensePredicate | incomePredicate),
        netSumOf(expensePredicate),
        netSumOf(incomePredicate),
      ]);

      return MoneyTransactionSummary(
        count: results[0],
        expenseMinor: results[1],
        incomeMinor: results[2],
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
  Stream<List<MoneyTransactionEntity>> watchRecentTransactionsForUser(
    String userId, {
    int limit = 20,
    String? ledgerId,
  }) async* {
    final transactionIds = ledgerId == null
        ? null
        : await _transactionIdsForLedger(userId, ledgerId);
    final query = database.select(database.moneyTransactions)
      ..where(
        (row) =>
            row.userId.equals(userId) &
            row.isDeleted.equals(false) &
            (transactionIds == null
                ? const Constant(true)
                : transactionIds.isEmpty
                ? row.id.equals('__no_recent_ledger_tx__')
                : row.id.isIn(transactionIds)) &
            row.actualPayerAccount.isNotIn([
              _DriftMoneyRepositoryBase._transferInMarker,
            ]),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.transactionAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ])
      ..limit(limit);

    yield* query.watch().asyncMap((rows) async {
      final tagsByTransactionId = await _getTagsForTransactions(
        rows.map((row) => row.id),
      );
      return [
        for (final row in rows)
          _mapTransaction(row, tags: tagsByTransactionId[row.id] ?? const []),
      ];
    });
  }

  @override
  Future<MoneyEntrySuggestions> getEntrySuggestionsForUser(
    String userId, {
    int merchantLimit = 8,
    int paymentMethodLimit = 6,
  }) async {
    await ensureReadyForUser(userId);
    final merchants = <String>[];
    final customPaymentMethods = <String>[];

    final merchantRows =
        await (database.selectOnly(database.moneyTransactions)
              ..addColumns([
                database.moneyTransactions.merchant,
                database.moneyTransactions.transactionAt.max(),
              ])
              ..where(
                database.moneyTransactions.userId.equals(userId) &
                    database.moneyTransactions.merchant.isNotNull() &
                    database.moneyTransactions.merchant.isNotValue('') &
                    database.moneyTransactions.isDeleted.equals(false) &
                    database.moneyTransactions.status.equals(
                      MoneyTransactionStatus.completed.storageValue,
                    ),
              )
              ..groupBy([database.moneyTransactions.merchant])
              ..orderBy([
                OrderingTerm.desc(
                  database.moneyTransactions.transactionAt.max(),
                ),
              ])
              ..limit(merchantLimit))
            .get();
    for (final row in merchantRows) {
      final name = row.read(database.moneyTransactions.merchant)?.trim();
      if (name != null && name.isNotEmpty) {
        merchants.add(name);
      }
    }

    final methodRows =
        await (database.selectOnly(database.moneyTransactions)
              ..addColumns([
                database.moneyTransactions.customPaymentMethodName,
                database.moneyTransactions.transactionAt.max(),
              ])
              ..where(
                database.moneyTransactions.userId.equals(userId) &
                    database.moneyTransactions.customPaymentMethodName
                        .isNotNull() &
                    database.moneyTransactions.customPaymentMethodName
                        .isNotValue('') &
                    database.moneyTransactions.isDeleted.equals(false) &
                    database.moneyTransactions.status.equals(
                      MoneyTransactionStatus.completed.storageValue,
                    ),
              )
              ..groupBy([database.moneyTransactions.customPaymentMethodName])
              ..orderBy([
                OrderingTerm.desc(
                  database.moneyTransactions.transactionAt.max(),
                ),
              ])
              ..limit(paymentMethodLimit))
            .get();
    for (final row in methodRows) {
      final name = row
          .read(database.moneyTransactions.customPaymentMethodName)
          ?.trim();
      if (name != null && name.isNotEmpty) {
        customPaymentMethods.add(name);
      }
    }

    return MoneyEntrySuggestions(
      merchants: merchants,
      customPaymentMethods: customPaymentMethods,
    );
  }

  Future<void> _markAutoPostingRunUserDeleted({
    required String userId,
    required String runId,
    required DateTime deletedAt,
  }) async {
    final runRow = await _getAutoPostingRunById(userId, runId);
    if (runRow == null) {
      return;
    }
    final run = _mapAutoPostingRun(runRow);
    if (run.status == MoneyAutoPostingRunStatus.userDeleted) {
      return;
    }
    await _writeAutoPostingRunState(
      existing: run,
      status: MoneyAutoPostingRunStatus.userDeleted,
      transactionId: run.transactionId,
      postedAt: run.postedAt,
      errorCode: null,
      errorMessage: null,
      updatedAt: deletedAt,
    );
  }

  Future<List<String>> _ledgerIdsForTransaction(
    String userId,
    String transactionId,
  ) async {
    await _getTransactionForUser(userId, transactionId);
    return _ledgerIdsForTransactionRow(userId, transactionId);
  }

  /// 与 [_ledgerIdsForTransaction] 相同，但不校验流水是否还在——
  /// 恢复一条已删除的流水时，它此刻确实还是 `isDeleted = true`。
  Future<List<String>> _ledgerIdsForTransactionRow(
    String userId,
    String transactionId,
  ) async {
    final links = await (database.select(
      database.moneyLedgerTransactions,
    )..where((link) => link.transactionId.equals(transactionId))).get();
    if (links.isEmpty) {
      return <String>[(await _getDefaultLedgerForUser(userId)).id];
    }

    final linkedIds = links.map((link) => link.ledgerId).toSet().toList();
    final ledgers =
        await (database.select(database.moneyLedgers)..where(
              (ledger) =>
                  ledger.userId.equals(userId) &
                  ledger.id.isIn(linkedIds) &
                  ledger.isDeleted.equals(false),
            ))
            .get();
    if (ledgers.isEmpty) {
      return <String>[(await _getDefaultLedgerForUser(userId)).id];
    }
    return [for (final ledger in ledgers) ledger.id];
  }

  Map<String, Object?> _transactionUpdateSyncFields(
    MoneyTransactionUpdate update, {
    int refundAmountMinor = 0,
    List<String>? ledgerIds,
  }) {
    final fields = <String, Object?>{
      'type': update.type.storageValue,
      'transaction_at': update.transactionAt.toUtc().toIso8601String(),
      'amount_minor': update.amountMinor,
      'refund_amount_minor': refundAmountMinor,
      'currency_code': update.currencyCode,
      'description': _transactionUpdateDescription(update),
      'notes': _blankToNull(update.notes),
      'merchant': _blankToNull(update.merchant),
      'location': _blankToNull(update.location),
      'account_id': update.accountId,
      'category_id': update.categoryId,
      'sub_category_id': update.subCategoryId,
      'payment_method': update.paymentMethod.storageValue,
      'custom_payment_method_name': _blankToNull(
        update.customPaymentMethodName,
      ),
      'tags': update.tags,
    };
    if (ledgerIds != null) {
      fields['ledger_ids'] = ledgerIds;
    }
    return fields;
  }

  Map<String, Object?> _transactionSnapshotSyncFields(
    MoneyTransaction transaction, {
    required int refundAmountMinor,
    required List<String> ledgerIds,
    required List<String> tags,
  }) {
    return {
      'type': transaction.type,
      'status': transaction.status,
      'transaction_at': transaction.transactionAt.toUtc().toIso8601String(),
      'amount_minor': transaction.amountMinor,
      'refund_amount_minor': refundAmountMinor,
      'currency_code': transaction.currencyCode,
      'description': transaction.description,
      'notes': transaction.notes,
      'merchant': transaction.merchant,
      'location': transaction.location,
      'account_id': transaction.accountId,
      'category_id': transaction.categoryId,
      'sub_category_id': transaction.subCategoryId,
      'payment_method': transaction.paymentMethod,
      'custom_payment_method_name': transaction.customPaymentMethodName,
      'actual_payer_account': transaction.actualPayerAccount,
      'source_template_run_id': transaction.sourceTemplateRunId,
      'tags': tags,
      'ledger_ids': ledgerIds,
    };
  }

  Map<String, Object?> _transferTransactionSyncFields({
    required MoneyTransactionType type,
    required MoneyTransactionStatus status,
    required DateTime transactionAt,
    required int amountMinor,
    required String currencyCode,
    required String description,
    required String? notes,
    required String accountId,
    required String toAccountId,
    required String categoryId,
    required String? subCategoryId,
    required MoneyPaymentMethod paymentMethod,
    required String? customPaymentMethodName,
    required String? actualPayerAccount,
    required String? relatedTransactionId,
    List<String>? ledgerIds,
  }) {
    final fields = <String, Object?>{
      'type': type.storageValue,
      'status': status.storageValue,
      'transaction_at': transactionAt.toUtc().toIso8601String(),
      'amount_minor': amountMinor,
      'currency_code': currencyCode,
      'description': description,
      'notes': _blankToNull(notes),
      'account_id': accountId,
      'to_account_id': toAccountId,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'payment_method': paymentMethod.storageValue,
      'custom_payment_method_name': _blankToNull(customPaymentMethodName),
    };
    if (actualPayerAccount != null) {
      fields['actual_payer_account'] = actualPayerAccount;
    }
    if (relatedTransactionId != null) {
      fields['related_transaction_id'] = relatedTransactionId;
    }
    if (ledgerIds != null) {
      fields['ledger_ids'] = ledgerIds;
    }
    return fields;
  }

  Map<String, Object?> _transactionDeleteSyncFields(DateTime deletedAt) {
    return {
      'is_deleted': true,
      'deleted_at': deletedAt.toUtc().toIso8601String(),
    };
  }

  Future<String> _getTransferCategoryId() async {
    final category =
        await (database.select(database.moneyCategories)
              ..where(
                (category) =>
                    category.id.equals(
                      _DriftMoneyRepositoryBase._transferCategoryId,
                    ) &
                    category.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (category == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.categoryNotFound,
      );
    }
    return category.id;
  }

  Future<void> _deleteTransferPair(
    String userId,
    MoneyTransaction selected,
  ) async {
    final pair = await _getTransferPair(userId, selected);
    final outgoing = pair.outgoing;
    final incoming = pair.incoming;

    final fromAccount = await _getAccountForUser(userId, outgoing.accountId);
    final toAccount = await _getAccountForUser(userId, incoming.accountId);
    final fromLedger = _MutableAccountLedger.fromAccount(fromAccount)
      ..applyTransferOutgoingRollback(outgoing.amountMinor)
      ..validate();
    final toLedger = _MutableAccountLedger.fromAccount(toAccount)
      ..applyTransferIncomingRollback(incoming.amountMinor)
      ..validate();

    final now = DateTime.now().toUtc();
    await _updateAccountLedger(userId, fromAccount.id, fromLedger, now);
    await _updateAccountLedger(userId, toAccount.id, toLedger, now);
    await _markTransactionDeleted(
      userId,
      outgoing.id,
      now,
      beforeVersion: outgoing.version,
    );
    await _markTransactionDeleted(
      userId,
      incoming.id,
      now,
      beforeVersion: incoming.version,
    );
  }

  Future<_TransferPair> _getTransferPair(
    String userId,
    MoneyTransaction selected,
  ) async {
    final relatedId = selected.relatedTransactionId;
    if (relatedId == null ||
        MoneyTransactionType.fromStorageValue(selected.type) !=
            MoneyTransactionType.transfer) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }

    final related = await _getTransactionForUser(userId, relatedId);
    if (MoneyTransactionType.fromStorageValue(related.type) !=
            MoneyTransactionType.transfer ||
        related.relatedTransactionId != selected.id ||
        related.amountMinor != selected.amountMinor) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }

    final outgoing =
        selected.actualPayerAccount ==
            _DriftMoneyRepositoryBase._transferInMarker
        ? related
        : selected;
    final incoming =
        selected.actualPayerAccount ==
            _DriftMoneyRepositoryBase._transferInMarker
        ? selected
        : related;

    if (outgoing.actualPayerAccount !=
            _DriftMoneyRepositoryBase._transferOutMarker ||
        incoming.actualPayerAccount !=
            _DriftMoneyRepositoryBase._transferInMarker) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }

    return _TransferPair(outgoing: outgoing, incoming: incoming);
  }

  Future<void> _writeTransferRowUpdate({
    required String userId,
    required String transactionId,
    required DateTime transactionAt,
    required int amountMinor,
    required String currencyCode,
    required String description,
    required String? notes,
    required String accountId,
    required String toAccountId,
    required String categoryId,
    required String? subCategoryId,
    required MoneyPaymentMethod paymentMethod,
    required String? customPaymentMethodName,
    required int beforeVersion,
    required DateTime now,
  }) async {
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            transactionAt: Value(transactionAt.toUtc()),
            amountMinor: Value(amountMinor),
            currencyCode: Value(currencyCode),
            description: Value(description),
            notes: Value<String?>(_blankToNull(notes)),
            accountId: Value(accountId),
            toAccountId: Value<String?>(toAccountId),
            categoryId: Value(categoryId),
            subCategoryId: Value<String?>(subCategoryId),
            paymentMethod: Value(paymentMethod.storageValue),
            customPaymentMethodName: Value<String?>(
              _blankToNull(customPaymentMethodName),
            ),
            version: Value(beforeVersion + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordTransactionChange(
      userId: userId,
      recordId: transactionId,
      operation: SyncChangeOperation.update,
      changedFields: _transferTransactionSyncFields(
        type: MoneyTransactionType.transfer,
        status: MoneyTransactionStatus.completed,
        transactionAt: transactionAt,
        amountMinor: amountMinor,
        currencyCode: currencyCode,
        description: description,
        notes: notes,
        accountId: accountId,
        toAccountId: toAccountId,
        categoryId: categoryId,
        subCategoryId: subCategoryId,
        paymentMethod: paymentMethod,
        customPaymentMethodName: customPaymentMethodName,
        actualPayerAccount: null,
        relatedTransactionId: null,
      ),
      beforeVersion: beforeVersion,
      afterVersion: beforeVersion + 1,
    );
  }

  Future<void> _markTransactionDeleted(
    String userId,
    String transactionId,
    DateTime now, {
    required int beforeVersion,
  }) async {
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(now),
            version: Value(beforeVersion + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordTransactionChange(
      userId: userId,
      recordId: transactionId,
      operation: SyncChangeOperation.delete,
      changedFields: _transactionDeleteSyncFields(now),
      beforeVersion: beforeVersion,
      afterVersion: beforeVersion + 1,
    );
  }

  Expression<bool> _transactionPredicate(
    $MoneyTransactionsTable table,
    String userId,
    MoneyTransactionQuery query, {
    List<String>? transactionIds,
    List<String>? accountIdsForType,
  }) {
    var predicate = table.userId.equals(userId) & table.isDeleted.equals(false);

    if (transactionIds != null) {
      predicate =
          predicate &
          (transactionIds.isEmpty
              ? table.id.equals('__no_transaction_for_ledger__')
              : table.id.isIn(transactionIds));
    }

    final status = query.status;
    if (status != null) {
      predicate = predicate & table.status.equals(status.storageValue);
    }
    final type = query.type;
    if (type != null) {
      predicate = predicate & table.type.equals(type.storageValue);
      if (type == MoneyTransactionType.income ||
          type == MoneyTransactionType.expense) {
        predicate =
            predicate &
            table.categoryId.isNotIn(
              _DriftMoneyRepositoryBase._transferCategoryIds,
            );
      }
    }
    final accountId = query.accountId;
    if (accountId != null) {
      predicate = predicate & table.accountId.equals(accountId);
    } else {
      predicate =
          predicate &
          table.actualPayerAccount.isNotIn([
            _DriftMoneyRepositoryBase._transferInMarker,
          ]);
    }
    final accountType = query.accountType;
    if (accountType != null) {
      final ids = accountIdsForType;
      predicate =
          predicate &
          table.accountId.isIn(
            ids == null || ids.isEmpty ? const ['__no_account_of_type__'] : ids,
          );
    }
    final categoryId = query.categoryId;
    if (categoryId != null) {
      predicate = predicate & table.categoryId.equals(categoryId);
    }
    final subCategoryId = query.subCategoryId;
    if (subCategoryId != null) {
      predicate = predicate & table.subCategoryId.equals(subCategoryId);
    }
    final paymentMethod = query.paymentMethod;
    if (paymentMethod != null) {
      predicate =
          predicate & table.paymentMethod.equals(paymentMethod.storageValue);
    }
    final merchant = query.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      predicate = predicate & table.merchant.like('%$merchant%');
    }
    final customPaymentMethodName = query.customPaymentMethodName?.trim();
    if (customPaymentMethodName != null && customPaymentMethodName.isNotEmpty) {
      predicate =
          predicate &
          table.customPaymentMethodName.like('%$customPaymentMethodName%');
    }
    final dateStart = query.dateStart;
    if (dateStart != null) {
      predicate =
          predicate & table.transactionAt.isBiggerOrEqualValue(dateStart);
    }
    final dateEnd = query.dateEnd;
    if (dateEnd != null) {
      predicate =
          predicate & table.transactionAt.isSmallerOrEqualValue(dateEnd);
    }
    final keyword = query.keyword?.trim();
    if (keyword != null && keyword.isNotEmpty) {
      // 顶部搜索框的提示是「搜索名称、备注、商家」，这里必须真的把 merchant
      // 算进去，否则按商家名搜不到（之前只 LIKE description / notes）。
      final pattern = '%$keyword%';
      predicate =
          predicate &
          (table.description.like(pattern) |
              table.notes.like(pattern) |
              table.merchant.like(pattern));
    }
    final tags = query.tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
    if (tags.isNotEmpty) {
      // 标签存在独立的表里，只能用 EXISTS 子查询关联。
      // OR 语义：命中任意一个标签即可（AND 会让多选变成几乎查不出东西）。
      final tagSubQuery = database.selectOnly(database.moneyTransactionTags)
        ..addColumns([database.moneyTransactionTags.transactionId])
        ..where(
          database.moneyTransactionTags.transactionId.equalsExp(table.id) &
              database.moneyTransactionTags.tag.isIn(tags),
        );
      predicate = predicate & existsQuery(tagSubQuery);
    }

    return predicate;
  }
}
