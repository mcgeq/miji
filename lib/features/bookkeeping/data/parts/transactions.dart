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
      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: ledgerIds,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
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
      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: ledgerIds,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
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
      final oldLedger = _MutableAccountLedger.fromAccount(oldAccount)
        ..applyTransactionRollback(
          existingType,
          _effectiveTransactionAmountMinor(existing),
        );
      final newLedger = oldAccount.id == newAccount.id
          ? oldLedger
          : _MutableAccountLedger.fromAccount(newAccount);
      newLedger
        ..applyTransactionCreate(
          update.type,
          _effectiveAmountMinor(
            amountMinor: update.amountMinor,
            refundAmountMinor: refundAmountMinor,
          ),
        )
        ..validate();
      if (oldAccount.id != newAccount.id) {
        oldLedger.validate();
      }

      final ledgerIds = await _ledgerIdsForTransaction(userId, existing.id);

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
                description: Value(update.type.label),
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
        ),
        _BudgetTransactionImpact(
          type: updated.type,
          accountId: updated.accountId,
          categoryId: updated.categoryId,
          subCategoryId: updated.subCategoryId,
          ledgerIds: ledgerIds,
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
  Future<void> deleteTransaction(String userId, String transactionId) async {
    try {
      final transaction = await _getTransactionForUser(userId, transactionId);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(transaction)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentStatus,
        );
      }
      if (MoneyTransactionType.fromStorageValue(transaction.type) ==
          MoneyTransactionType.transfer) {
        final pair = await _getTransferPair(userId, transaction);
        final accountIds = [pair.outgoing.accountId, pair.incoming.accountId];
        await database.transaction(() async {
          await _deleteTransferPair(userId, transaction);
        });
        await _syncCreditAccountRepaymentRemindersForAccounts(
          userId,
          accountIds,
        );
        return;
      }

      final account = await _getAccountForUser(userId, transaction.accountId);
      final ledger = _MutableAccountLedger.fromAccount(account)
        ..applyTransactionRollback(
          MoneyTransactionType.fromStorageValue(transaction.type),
          _effectiveTransactionAmountMinor(transaction),
        )
        ..validate();
      final ledgerIds = await _ledgerIdsForTransaction(userId, transaction.id);
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
      await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
        _BudgetTransactionImpact(
          type: MoneyTransactionType.fromStorageValue(transaction.type),
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: ledgerIds,
        ),
      ]);
      await _syncCreditAccountRepaymentRemindersForAccounts(userId, [
        transaction.accountId,
      ]);
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
                ..orderBy([
                  (row) => OrderingTerm.desc(row.transactionAt),
                  (row) => OrderingTerm.desc(row.createdAt),
                ])
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
      'description': update.type.label,
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

  Future<Map<String, List<String>>> _getTagsForTransactions(
    Iterable<String> transactionIds,
  ) async {
    final ids = transactionIds.toSet().toList();
    if (ids.isEmpty) {
      return const <String, List<String>>{};
    }

    final rows =
        await (database.select(database.moneyTransactionTags)
              ..where((row) => row.transactionId.isIn(ids))
              ..orderBy([
                (row) => OrderingTerm.asc(row.transactionId),
                (row) => OrderingTerm.asc(row.tag),
              ]))
            .get();
    final tagsByTransactionId = <String, List<String>>{};
    for (final row in rows) {
      tagsByTransactionId
          .putIfAbsent(row.transactionId, () => <String>[])
          .add(row.tag);
    }
    return tagsByTransactionId;
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
      final pattern = '%$keyword%';
      predicate =
          predicate &
          (table.description.like(pattern) | table.notes.like(pattern));
    }

    return predicate;
  }
}
