part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Accounts on _DriftMoneyRepositoryBase {
  @override
  Stream<List<MoneyAccountEntity>> watchVisibleAccountsForUser(String userId) {
    final query = database.select(database.moneyAccounts)
      ..where(
        (account) =>
            account.userId.equals(userId) &
            account.isVirtual.equals(false) &
            account.isDeleted.equals(false),
      )
      ..orderBy([
        (account) => OrderingTerm.desc(account.updatedAt),
        (account) => OrderingTerm.desc(account.createdAt),
      ]);

    return query.watch().asyncMap((rows) async {
      final usageRanks = await _accountUsageRanks(userId);
      final accounts = rows.map(_mapAccount).toList();
      _sortAccountsByUsage(accounts, usageRanks);
      return accounts;
    });
  }

  @override
  Stream<List<MoneyAccountEntity>> watchAccountsForLedger(
    String userId,
    String ledgerId,
  ) async* {
    await ensureReadyForUser(userId);
    final ledger = await _getLedgerForUser(userId, ledgerId);
    if (ledger.ledgerType == 'personal') {
      yield* watchVisibleAccountsForUser(userId);
      return;
    }

    final query =
        database.select(database.moneyAccounts).join([
            innerJoin(
              database.moneyLedgerAccounts,
              database.moneyLedgerAccounts.accountId.equalsExp(
                database.moneyAccounts.id,
              ),
            ),
          ])
          ..where(
            database.moneyAccounts.userId.equals(userId) &
                database.moneyAccounts.isVirtual.equals(false) &
                database.moneyAccounts.isDeleted.equals(false) &
                database.moneyLedgerAccounts.ledgerId.equals(ledgerId),
          )
          ..orderBy([
            OrderingTerm.desc(database.moneyAccounts.updatedAt),
            OrderingTerm.desc(database.moneyAccounts.createdAt),
          ]);

    yield* query.watch().asyncMap((rows) async {
      final usageRanks = await _accountUsageRanks(userId);
      final accounts = rows
          .map((row) => _mapAccount(row.readTable(database.moneyAccounts)))
          .toList();
      _sortAccountsByUsage(accounts, usageRanks);
      return accounts;
    });
  }

  @override
  Stream<List<MoneyAccountEntity>> watchTransferAccountsForLedger(
    String userId,
    String ledgerId,
  ) async* {
    await ensureReadyForUser(userId);
    final ledger = await _getLedgerForUser(userId, ledgerId);
    final isInternalAccount =
        database.moneyAccounts.type.equals(
          MoneyAccountType.internal.storageValue,
        ) &
        database.moneyAccounts.isVirtual.equals(true);

    if (ledger.ledgerType == 'personal') {
      final query = database.select(database.moneyAccounts)
        ..where((account) {
          final accountIsInternal =
              account.type.equals(MoneyAccountType.internal.storageValue) &
              account.isVirtual.equals(true);
          return account.userId.equals(userId) &
              account.isDeleted.equals(false) &
              (account.isVirtual.equals(false) | accountIsInternal);
        })
        ..orderBy([
          (account) => OrderingTerm.desc(account.updatedAt),
          (account) => OrderingTerm.desc(account.createdAt),
        ]);

      yield* query.watch().asyncMap((rows) async {
        final usageRanks = await _accountUsageRanks(userId);
        final accounts = rows.map(_mapAccount).toList();
        _sortAccountsByUsage(accounts, usageRanks);
        return accounts;
      });
      return;
    }

    final query =
        database.select(database.moneyAccounts).join([
            leftOuterJoin(
              database.moneyLedgerAccounts,
              database.moneyLedgerAccounts.accountId.equalsExp(
                database.moneyAccounts.id,
              ),
            ),
          ])
          ..where(
            database.moneyAccounts.userId.equals(userId) &
                database.moneyAccounts.isDeleted.equals(false) &
                (isInternalAccount |
                    (database.moneyAccounts.isVirtual.equals(false) &
                        database.moneyLedgerAccounts.ledgerId.equals(
                          ledgerId,
                        ))),
          )
          ..orderBy([
            OrderingTerm.desc(database.moneyAccounts.updatedAt),
            OrderingTerm.desc(database.moneyAccounts.createdAt),
          ]);

    yield* query.watch().asyncMap((rows) async {
      final usageRanks = await _accountUsageRanks(userId);
      final accounts = rows
          .map((row) => _mapAccount(row.readTable(database.moneyAccounts)))
          .toList();
      _sortAccountsByUsage(accounts, usageRanks);
      return accounts;
    });
  }

  @override
  Future<void> addAccountToLedger(
    String userId,
    String ledgerId,
    String accountId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await database.transaction(() async {
        final ledger = await _getLedgerForUser(userId, ledgerId);
        if (ledger.ledgerType == 'personal') {
          return;
        }
        await _getAccountForUser(userId, accountId);
        final existing = await _getLedgerAccountLink(ledgerId, accountId);
        if (existing != null) {
          return;
        }

        final now = DateTime.now().toUtc();
        await database
            .into(database.moneyLedgerAccounts)
            .insert(
              MoneyLedgerAccountsCompanion.insert(
                ledgerId: ledgerId,
                accountId: accountId,
                createdAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _recordLedgerAccountChange(
          userId: userId,
          recordId: _ledgerAccountRecordId(ledgerId, accountId),
          operation: SyncChangeOperation.insert,
          changedFields: {
            'ledger_id': ledgerId,
            'account_id': accountId,
            'created_at': now.toIso8601String(),
          },
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
  Future<void> removeAccountFromLedger(
    String userId,
    String ledgerId,
    String accountId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      await database.transaction(() async {
        final ledger = await _getLedgerForUser(userId, ledgerId);
        if (ledger.ledgerType == 'personal') {
          return;
        }
        await _getAccountForUser(userId, accountId);
        final deleted =
            await (database.delete(database.moneyLedgerAccounts)..where(
                  (row) =>
                      row.ledgerId.equals(ledgerId) &
                      row.accountId.equals(accountId),
                ))
                .go();
        if (deleted <= 0) {
          return;
        }
        await _recordLedgerAccountChange(
          userId: userId,
          recordId: _ledgerAccountRecordId(ledgerId, accountId),
          operation: SyncChangeOperation.delete,
          changedFields: {'ledger_id': ledgerId, 'account_id': accountId},
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
  Future<Map<String, MoneyAccountMonthlySummary>>
  getAccountMonthlySummariesForUser(String userId, {String? ledgerId}) async {
    try {
      final transactionIds = ledgerId == null
          ? null
          : await _transactionIdsForLedger(userId, ledgerId);
      final currentStart = _currentMonthStart();
      final nextMonthStart = _nextMonthStart(currentStart);
      final rangeEndInclusive = nextMonthStart.subtract(
        const Duration(milliseconds: 1),
      );
      final previousStart = _previousMonthStart(currentStart);
      final rows =
          await (database.select(database.moneyTransactions)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.status.equals(
                      MoneyTransactionStatus.completed.storageValue,
                    ) &
                    row.actualPayerAccount.isNotIn([
                      _DriftMoneyRepositoryBase._transferInMarker,
                    ]) &
                    (transactionIds == null
                        ? const Constant(true)
                        : transactionIds.isEmpty
                        ? row.id.equals('__no_account_summary_ledger_tx__')
                        : row.id.isIn(transactionIds)) &
                    row.type.isIn([
                      MoneyTransactionType.income.storageValue,
                      MoneyTransactionType.expense.storageValue,
                    ]) &
                    row.categoryId.isNotIn(
                      _DriftMoneyRepositoryBase._transferCategoryIds,
                    ) &
                    row.transactionAt.isBiggerOrEqualValue(
                      previousStart.toUtc(),
                    ) &
                    row.transactionAt.isSmallerOrEqualValue(
                      rangeEndInclusive.toUtc(),
                    ),
              ))
              .get();

      final summaries = <String, _MutableAccountMonthlySummary>{};
      for (final row in rows) {
        final summary = summaries.putIfAbsent(
          row.accountId,
          () => _MutableAccountMonthlySummary(row.accountId),
        );
        final type = MoneyTransactionType.fromStorageValue(row.type);
        final transactionAt = row.transactionAt.toLocal();
        final isCurrentMonth =
            !transactionAt.isBefore(currentStart) &&
            transactionAt.isBefore(nextMonthStart);

        if (isCurrentMonth) {
          if (type == MoneyTransactionType.income) {
            summary.currentIncomeMinor += _effectiveTransactionAmountMinor(row);
          } else if (type == MoneyTransactionType.expense) {
            summary.currentExpenseMinor += _effectiveTransactionAmountMinor(
              row,
            );
          }
          continue;
        }

        if (type == MoneyTransactionType.income) {
          summary.previousIncomeMinor += _effectiveTransactionAmountMinor(row);
        } else if (type == MoneyTransactionType.expense) {
          summary.previousExpenseMinor += _effectiveTransactionAmountMinor(row);
        }
      }

      return summaries.map(
        (accountId, summary) => MapEntry(accountId, summary.toEntity()),
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyCreditCardStatement?> getCreditCardStatementForAccount(
    String userId,
    String accountId, {
    DateTime? asOf,
  }) async {
    final bill = await getCurrentCreditCardBillViewForAccount(
      userId,
      accountId,
      asOf: asOf,
    );
    return bill?.toStatement();
  }

  @override
  Future<MoneyAccountEntity> createAccount(
    String userId,
    MoneyAccountDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final ledger = _MutableAccountLedger.fromDraft(draft)..validate();

      final now = DateTime.now().toUtc();
      final accountId = _uuid.v4();
      final companion = MoneyAccountsCompanion.insert(
        id: accountId,
        userId: userId,
        name: draft.name.trim(),
        description: Value<String?>(draft.description?.trim()),
        type: draft.type.storageValue,
        balanceMinor: ledger.balanceMinor,
        initialBalanceMinor: ledger.initialBalanceMinor,
        creditLimitMinor: Value<int?>(ledger.creditLimitMinor),
        postedDebtMinor: Value<int?>(ledger.postedDebtMinor),
        frozenCreditMinor: Value<int?>(ledger.frozenCreditMinor),
        statementDay: Value<int?>(_draftStatementDay(draft)),
        budgetCycleStartDay: Value<int?>(_draftBudgetCycleStartDay(draft)),
        repaymentDay: Value<int?>(_draftRepaymentDay(draft)),
        autoRepaymentReminderEnabled: Value(
          draft.type.isCreditLike && draft.autoRepaymentReminderEnabled,
        ),
        currencyCode: draft.currencyCode,
        isShared: const Value(false),
        isVirtual: const Value(false),
        color: Value<String?>(draft.color),
        icon: Value<String?>(draft.icon),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      );

      await database.into(database.moneyAccounts).insert(companion);
      await _recordAccountChange(
        userId: userId,
        recordId: accountId,
        operation: SyncChangeOperation.insert,
        changedFields: _accountDraftSyncFields(draft, ledger),
        afterVersion: 1,
      );
      final account = await _getAccountForUser(userId, accountId);
      await _syncCreditAccountRepaymentReminder(userId, account);
      return _mapAccount(account);
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
  Future<MoneyAccountEntity> updateAccount(
    String userId,
    MoneyAccountUpdate update,
  ) async {
    try {
      final existing = await _getAccountForUser(userId, update.id);
      if (existing.isVirtual) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
        );
      }
      final ledger = _MutableAccountLedger.fromAccount(existing)
        ..applyAccountUpdate(update)
        ..validate();
      final changedFields = _accountUpdateSyncFields(existing, update, ledger);
      if (changedFields.isEmpty) {
        return _mapAccount(existing);
      }
      final now = DateTime.now().toUtc();

      await (database.update(database.moneyAccounts)..where(
            (account) =>
                account.id.equals(update.id) &
                account.userId.equals(userId) &
                account.isVirtual.equals(false) &
                account.isDeleted.equals(false),
          ))
          .write(
            MoneyAccountsCompanion(
              name: Value(update.name.trim()),
              description: Value<String?>(update.description?.trim()),
              type: Value(update.type.storageValue),
              initialBalanceMinor: Value(ledger.initialBalanceMinor),
              balanceMinor: Value(ledger.balanceMinor),
              creditLimitMinor: Value<int?>(ledger.creditLimitMinor),
              postedDebtMinor: Value<int?>(ledger.postedDebtMinor),
              frozenCreditMinor: Value<int?>(ledger.frozenCreditMinor),
              statementDay: Value<int?>(_updateStatementDay(update)),
              budgetCycleStartDay: Value<int?>(
                _updateBudgetCycleStartDay(update),
              ),
              repaymentDay: Value<int?>(_updateRepaymentDay(update)),
              autoRepaymentReminderEnabled: Value(
                update.type.isCreditLike && update.autoRepaymentReminderEnabled,
              ),
              currencyCode: Value(update.currencyCode),
              color: Value<String?>(update.color),
              icon: Value<String?>(update.icon),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordAccountChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );

      final account = await _getAccountForUser(userId, update.id);
      await _syncCreditAccountRepaymentReminder(userId, account);
      return _mapAccount(account);
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
  Future<void> setAccountActive(
    String userId,
    String accountId,
    bool isActive,
  ) async {
    try {
      final existing = await _getAccountForUser(userId, accountId);
      if (existing.isActive == isActive) {
        return;
      }
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyAccounts)..where(
            (account) =>
                account.id.equals(accountId) &
                account.userId.equals(userId) &
                account.isVirtual.equals(false) &
                account.isDeleted.equals(false),
          ))
          .write(
            MoneyAccountsCompanion(
              isActive: Value(isActive),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordAccountChange(
        userId: userId,
        recordId: accountId,
        operation: SyncChangeOperation.update,
        changedFields: {'is_active': isActive},
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      await _syncCreditAccountRepaymentReminder(
        userId,
        await _getAccountForUser(userId, accountId),
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> deleteAccount(String userId, String accountId) async {
    try {
      final existing = await _getAccountForUser(userId, accountId);
      final now = DateTime.now().toUtc();
      await (database.update(database.moneyAccounts)..where(
            (account) =>
                account.id.equals(accountId) &
                account.userId.equals(userId) &
                account.isVirtual.equals(false) &
                account.isDeleted.equals(false),
          ))
          .write(
            MoneyAccountsCompanion(
              isDeleted: const Value(true),
              deletedAt: Value(now),
              isActive: const Value(false),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await _recordAccountChange(
        userId: userId,
        recordId: accountId,
        operation: SyncChangeOperation.delete,
        changedFields: _deleteSyncFields(now),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
      await _syncCreditAccountRepaymentReminder(
        userId,
        await _getAccountForUser(userId, accountId),
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<MoneyLedgerAccount?> _getLedgerAccountLink(
    String ledgerId,
    String accountId,
  ) {
    return (database.select(database.moneyLedgerAccounts)..where(
          (row) =>
              row.ledgerId.equals(ledgerId) & row.accountId.equals(accountId),
        ))
        .getSingleOrNull();
  }

  Future<void> _recordLedgerAccountChange({
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

    await logger.recordLedgerAccountChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Map<String, Object?> _accountDraftSyncFields(
    MoneyAccountDraft draft,
    _MutableAccountLedger ledger,
  ) {
    return {
      'name': draft.name.trim(),
      'description': _blankToNull(draft.description),
      'type': draft.type.storageValue,
      'balance_minor': ledger.balanceMinor,
      'initial_balance_minor': ledger.initialBalanceMinor,
      'credit_limit_minor': ledger.creditLimitMinor,
      'posted_debt_minor': ledger.postedDebtMinor,
      'frozen_credit_minor': ledger.frozenCreditMinor,
      'statement_day': _draftStatementDay(draft),
      'budget_cycle_start_day': _draftBudgetCycleStartDay(draft),
      'repayment_day': _draftRepaymentDay(draft),
      'auto_repayment_reminder_enabled':
          draft.type.isCreditLike && draft.autoRepaymentReminderEnabled,
      'currency_code': draft.currencyCode,
      'color': _blankToNull(draft.color),
      'icon': _blankToNull(draft.icon),
      'is_active': true,
    };
  }

  Map<String, Object?> _accountUpdateSyncFields(
    MoneyAccount existing,
    MoneyAccountUpdate update,
    _MutableAccountLedger ledger,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(fields, 'name', existing.name, update.name.trim());
    _putIfChanged(
      fields,
      'description',
      existing.description,
      _blankToNull(update.description),
    );
    _putIfChanged(
      fields,
      'currency_code',
      existing.currencyCode,
      update.currencyCode,
    );
    _putIfChanged(fields, 'color', existing.color, _blankToNull(update.color));
    _putIfChanged(fields, 'icon', existing.icon, _blankToNull(update.icon));
    _putIfChanged(
      fields,
      'statement_day',
      existing.statementDay,
      _updateStatementDay(update),
    );
    _putIfChanged(
      fields,
      'budget_cycle_start_day',
      existing.budgetCycleStartDay,
      _updateBudgetCycleStartDay(update),
    );
    _putIfChanged(
      fields,
      'repayment_day',
      existing.repaymentDay,
      _updateRepaymentDay(update),
    );
    _putIfChanged(
      fields,
      'auto_repayment_reminder_enabled',
      existing.autoRepaymentReminderEnabled,
      update.type.isCreditLike && update.autoRepaymentReminderEnabled,
    );
    final ledgerShapeChanged =
        existing.type != update.type.storageValue ||
        existing.initialBalanceMinor != update.initialBalanceMinor;
    if (ledgerShapeChanged) {
      fields.addAll({
        'type': update.type.storageValue,
        'balance_minor': ledger.balanceMinor,
        'initial_balance_minor': ledger.initialBalanceMinor,
        'credit_limit_minor': ledger.creditLimitMinor,
        'posted_debt_minor': ledger.postedDebtMinor,
        'frozen_credit_minor': ledger.frozenCreditMinor,
        'statement_day': _updateStatementDay(update),
        'budget_cycle_start_day': _updateBudgetCycleStartDay(update),
        'repayment_day': _updateRepaymentDay(update),
        'auto_repayment_reminder_enabled':
            update.type.isCreditLike && update.autoRepaymentReminderEnabled,
      });
    }
    return fields;
  }

  Future<Map<String, _UsageStat>> _accountUsageRanks(String userId) async {
    final rows = await (database.select(
      database.moneyAccountUsageStats,
    )..where((row) => row.userId.equals(userId))).get();
    return {
      for (final row in rows)
        row.accountId: _UsageStat(
          useCount: row.useCount,
          totalAmountMinor: row.totalAmountMinor,
          lastUsedAt: row.lastUsedAt,
        ),
    };
  }
}
