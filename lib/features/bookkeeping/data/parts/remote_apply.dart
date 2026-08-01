part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _RemoteApply on _DriftMoneyRepositoryBase {
  @override
  Future<void> applyRemoteMoneyChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    try {
      switch (change.table) {
        case SyncChangeLogger.moneyTransactionsTableName:
          await applyRemoteTransactionChange(change, local);
        case SyncChangeLogger.moneyAccountsTableName:
          await _applyRemoteAccountChange(change, local);
        case SyncChangeLogger.moneyBudgetsTableName:
          await _applyRemoteBudgetChange(change, local);
        case SyncChangeLogger.moneyBudgetSnapshotsTableName:
          await _applyRemoteBudgetSnapshotChange(change, local);
        case SyncChangeLogger.moneyBudgetAllocationSnapshotsTableName:
          await _applyRemoteBudgetAllocationSnapshotChange(change, local);
        case SyncChangeLogger.moneyCategoriesTableName:
          await _applyRemoteCategoryChange(change, local);
        case SyncChangeLogger.moneySubCategoriesTableName:
          await _applyRemoteSubCategoryChange(change, local);
        case SyncChangeLogger.moneyLedgersTableName:
          await _applyRemoteLedgerChange(change, local);
        case SyncChangeLogger.moneyMembersTableName:
          await _applyRemoteMemberChange(change, local);
        case SyncChangeLogger.moneySplitRecordsTableName:
          await _applyRemoteSplitRecordChange(change, local);
        case SyncChangeLogger.moneyInstallmentPlansTableName:
          await _applyRemoteInstallmentPlanChange(change, local);
        case SyncChangeLogger.moneyBudgetAllocationsTableName:
          await _applyRemoteBudgetAllocationChange(change, local);
        case SyncChangeLogger.moneySplitRulesTableName:
          await _applyRemoteSplitRuleChange(change, local);
        case SyncChangeLogger.moneyLedgerAccountsTableName:
          await _applyRemoteLedgerAccountChange(change, local);
        case SyncChangeLogger.moneyBillRemindersTableName:
          await _applyRemoteBillReminderChange(change, local);
        case SyncChangeLogger.moneyAutoPostingTemplatesTableName:
          await _applyRemoteAutoPostingTemplateChange(change, local);
        case SyncChangeLogger.moneyAutoPostingRunsTableName:
          await _applyRemoteAutoPostingRunChange(change, local);
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

  Future<void> applyRemoteTransactionChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    if (change.table != SyncChangeLogger.moneyTransactionsTableName) {
      return;
    }

    try {
      final fields = <String, Object?>{
        ...change.recordSnapshot,
        ...change.changedFields,
      };
      final userId = _remoteUserId(fields, local);
      await ensureReadyForUser(userId);

      await database.transaction(() async {
        switch (change.operation) {
          case 'insert':
            await _applyRemoteTransactionInsert(
              userId: userId,
              transactionId: change.recordId,
              fields: fields,
              version: change.newVersion ?? 1,
            );
          case 'update':
            await _applyRemoteTransactionUpdate(
              userId: userId,
              transactionId: change.recordId,
              fields: fields,
              version: change.newVersion,
            );
          case 'delete':
            await _applyRemoteTransactionDelete(
              userId: userId,
              transactionId: change.recordId,
              fields: fields,
              version: change.newVersion,
            );
        }
      });
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

  Future<void> _applyRemoteTransactionInsert({
    required String userId,
    required String transactionId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }

    final rawType = MoneyTransactionType.fromStorageValue(
      _remoteString(fields, 'type'),
    );
    if (rawType == MoneyTransactionType.transfer) {
      await _applyRemoteTransferTransactionInsert(
        userId: userId,
        transactionId: transactionId,
        fields: fields,
        version: version,
      );
      return;
    }

    final type = _remoteOrdinaryTransactionType(fields);
    if (type == null) {
      return;
    }
    final status = _remoteTransactionStatus(fields, fallback: null);
    if (status != MoneyTransactionStatus.completed) {
      return;
    }
    if (_remoteNullableString(fields, 'installment_plan_id') != null ||
        _remoteNullableString(fields, 'actual_payer_account') ==
            'installment' ||
        _remoteNullableString(fields, 'related_transaction_id') != null) {
      return;
    }

    final accountId = _remoteString(fields, 'account_id');
    final account = await _getWritableAccountForUser(userId, accountId);
    await _assertRemoteTransactionCategory(userId, type, fields);
    _assertTransactionAccountRules(type, account);

    final amountMinor = _remoteInt(fields, 'amount_minor');
    final refundAmountMinor = _remoteIntOr(fields, 'refund_amount_minor', 0);
    final ledger = _MutableAccountLedger.fromAccount(account)
      ..applyTransactionCreate(
        type,
        _effectiveAmountMinor(
          amountMinor: amountMinor,
          refundAmountMinor: refundAmountMinor,
        ),
      )
      ..validate();
    final now = DateTime.now().toUtc();
    final createdAt = _remoteDateTime(fields, 'created_at', fallback: now);
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);

    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            id: transactionId,
            userId: userId,
            type: type.storageValue,
            status: status.storageValue,
            transactionAt: _remoteDateTime(fields, 'transaction_at'),
            amountMinor: amountMinor,
            refundAmountMinor: Value(refundAmountMinor),
            currencyCode: _remoteString(fields, 'currency_code'),
            description: _remoteString(fields, 'description'),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            merchant: Value<String?>(_remoteNullableString(fields, 'merchant')),
            location: Value<String?>(_remoteNullableString(fields, 'location')),
            accountId: accountId,
            categoryId: _remoteString(fields, 'category_id'),
            subCategoryId: Value<String?>(
              _remoteNullableString(fields, 'sub_category_id'),
            ),
            paymentMethod: _remotePaymentMethod(fields).storageValue,
            customPaymentMethodName: Value<String?>(
              _remoteNullableString(fields, 'custom_payment_method_name'),
            ),
            actualPayerAccount:
                _remoteNullableString(fields, 'actual_payer_account') ??
                'default',
            sourceTemplateRunId: Value<String?>(
              _remoteNullableString(fields, 'source_template_run_id'),
            ),
            version: Value(version),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );

    if (fields.containsKey('tags')) {
      await _replaceTransactionTags(
        transactionId,
        _remoteStringList(fields, 'tags'),
      );
    }
    await _updateAccountLedger(userId, account.id, ledger, updatedAt);
    await _linkTransactionToLedgersUnchecked(
      ledgerIds: await _remoteLedgerIds(userId, fields),
      transactionId: transactionId,
    );
  }

  Future<void> _applyRemoteTransactionUpdate({
    required String userId,
    required String transactionId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getTransactionForUser(userId, transactionId);
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(existing)) {
      return;
    }
    final existingType = MoneyTransactionType.fromStorageValue(existing.type);
    if (existingType == MoneyTransactionType.transfer) {
      await _applyRemoteTransferTransactionUpdate(
        userId: userId,
        transactionId: transactionId,
        fields: fields,
        version: version,
      );
      return;
    }
    final type = _remoteOrdinaryTransactionType(fields);
    if (type == null || existingType != type) {
      return;
    }

    final accountId = _remoteString(fields, 'account_id');
    final oldAccount = await _getAccountForUser(userId, existing.accountId);
    final newAccount = await _getWritableAccountForUser(userId, accountId);
    await _assertRemoteTransactionCategory(userId, type, fields);
    _assertTransactionAccountRules(type, newAccount);

    final amountMinor = _remoteInt(fields, 'amount_minor');
    final refundAmountMinor = _remoteIntOr(
      fields,
      'refund_amount_minor',
      existing.refundAmountMinor,
    );
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
        type,
        _effectiveAmountMinor(
          amountMinor: amountMinor,
          refundAmountMinor: refundAmountMinor,
        ),
      )
      ..validate();
    if (oldAccount.id != newAccount.id) {
      oldLedger.validate();
    }

    final now = DateTime.now().toUtc();
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);
    if (oldAccount.id != newAccount.id) {
      await _updateAccountLedger(userId, oldAccount.id, oldLedger, updatedAt);
    }
    await _updateAccountLedger(userId, newAccount.id, newLedger, updatedAt);

    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            status: Value(
              _remoteTransactionStatus(
                fields,
                fallback: MoneyTransactionStatus.fromStorageValue(
                  existing.status,
                ),
              ).storageValue,
            ),
            transactionAt: Value(_remoteDateTime(fields, 'transaction_at')),
            amountMinor: Value(amountMinor),
            refundAmountMinor: Value(refundAmountMinor),
            currencyCode: Value(_remoteString(fields, 'currency_code')),
            description: Value(
              _remoteStringOr(fields, 'description', existing.description),
            ),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            merchant: Value<String?>(
              _remoteNullableStringOr(fields, 'merchant', existing.merchant),
            ),
            location: Value<String?>(
              _remoteNullableStringOr(fields, 'location', existing.location),
            ),
            accountId: Value(accountId),
            categoryId: Value(_remoteString(fields, 'category_id')),
            subCategoryId: Value<String?>(
              _remoteNullableString(fields, 'sub_category_id'),
            ),
            paymentMethod: Value(_remotePaymentMethod(fields).storageValue),
            customPaymentMethodName: Value<String?>(
              _remoteNullableString(fields, 'custom_payment_method_name'),
            ),
            actualPayerAccount: Value(
              _remoteNullableString(fields, 'actual_payer_account') ??
                  existing.actualPayerAccount,
            ),
            sourceTemplateRunId: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'source_template_run_id',
                existing.sourceTemplateRunId,
              ),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(updatedAt),
          ),
        );
    if (fields.containsKey('tags')) {
      await _replaceTransactionTags(
        transactionId,
        _remoteStringList(fields, 'tags'),
      );
    }
    if (fields.containsKey('ledger_ids')) {
      await _replaceTransactionLedgerLinks(
        transactionId: transactionId,
        ledgerIds: await _remoteLedgerIds(userId, fields),
      );
    }
  }

  Future<void> _applyRemoteTransactionDelete({
    required String userId,
    required String transactionId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final transaction =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (transaction == null || transaction.isDeleted) {
      return;
    }
    if (_DriftMoneyRepositoryBase._isInstallmentPosting(transaction)) {
      return;
    }
    if (MoneyTransactionType.fromStorageValue(transaction.type) ==
        MoneyTransactionType.transfer) {
      await _applyRemoteTransferTransactionDelete(
        userId: userId,
        transaction: transaction,
        fields: fields,
        version: version,
      );
      return;
    }

    final type = MoneyTransactionType.fromStorageValue(transaction.type);
    final account = await _getAccountForUser(userId, transaction.accountId);
    final ledger = _MutableAccountLedger.fromAccount(account)
      ..applyTransactionRollback(
        type,
        _effectiveTransactionAmountMinor(transaction),
      )
      ..validate();
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );

    await _updateAccountLedger(userId, account.id, ledger, deletedAt);
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? transaction.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteTransferTransactionInsert({
    required String userId,
    required String transactionId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final status = _remoteTransactionStatus(fields, fallback: null);
    if (status != MoneyTransactionStatus.completed) {
      return;
    }
    final accountId = _remoteString(fields, 'account_id');
    final account = await _getWritableAccountForUser(userId, accountId);
    final amountMinor = _remoteInt(fields, 'amount_minor');
    final direction = _remoteString(fields, 'actual_payer_account');
    final ledger = _MutableAccountLedger.fromAccount(account);
    _applyTransferDirection(
      ledger: ledger,
      direction: direction,
      amountMinor: amountMinor,
      rollback: false,
    );
    ledger.validate();

    final now = DateTime.now().toUtc();
    final createdAt = _remoteDateTime(fields, 'created_at', fallback: now);
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);
    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            id: transactionId,
            userId: userId,
            type: MoneyTransactionType.transfer.storageValue,
            status: status.storageValue,
            transactionAt: _remoteDateTime(fields, 'transaction_at'),
            amountMinor: amountMinor,
            currencyCode: _remoteString(fields, 'currency_code'),
            description: _remoteString(fields, 'description'),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            accountId: accountId,
            toAccountId: Value<String?>(
              _remoteNullableString(fields, 'to_account_id'),
            ),
            categoryId: _remoteString(fields, 'category_id'),
            paymentMethod: _remotePaymentMethod(fields).storageValue,
            customPaymentMethodName: Value<String?>(
              _remoteNullableString(fields, 'custom_payment_method_name'),
            ),
            actualPayerAccount: direction,
            relatedTransactionId: Value<String?>(
              _remoteNullableString(fields, 'related_transaction_id'),
            ),
            version: Value(version),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );

    await _updateAccountLedger(userId, account.id, ledger, updatedAt);
    await _linkTransactionToLedgersUnchecked(
      ledgerIds: await _remoteLedgerIds(userId, fields),
      transactionId: transactionId,
    );
  }

  Future<void> _applyRemoteTransferTransactionUpdate({
    required String userId,
    required String transactionId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getTransactionForUser(userId, transactionId);
    final existingDirection = existing.actualPayerAccount;
    final nextDirection = _remoteStringOr(
      fields,
      'actual_payer_account',
      existing.actualPayerAccount,
    );
    final accountId = _remoteString(fields, 'account_id');
    final oldAccount = await _getAccountForUser(userId, existing.accountId);
    final newAccount = await _getWritableAccountForUser(userId, accountId);
    final amountMinor = _remoteInt(fields, 'amount_minor');

    final oldLedger = _MutableAccountLedger.fromAccount(oldAccount);
    _applyTransferDirection(
      ledger: oldLedger,
      direction: existingDirection,
      amountMinor: existing.amountMinor,
      rollback: true,
    );
    final newLedger = oldAccount.id == newAccount.id
        ? oldLedger
        : _MutableAccountLedger.fromAccount(newAccount);
    _applyTransferDirection(
      ledger: newLedger,
      direction: nextDirection,
      amountMinor: amountMinor,
      rollback: false,
    );
    newLedger.validate();
    if (oldAccount.id != newAccount.id) {
      oldLedger.validate();
    }

    final now = DateTime.now().toUtc();
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);
    if (oldAccount.id != newAccount.id) {
      await _updateAccountLedger(userId, oldAccount.id, oldLedger, updatedAt);
    }
    await _updateAccountLedger(userId, newAccount.id, newLedger, updatedAt);
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transactionId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            status: Value(
              _remoteTransactionStatus(
                fields,
                fallback: MoneyTransactionStatus.fromStorageValue(
                  existing.status,
                ),
              ).storageValue,
            ),
            transactionAt: Value(_remoteDateTime(fields, 'transaction_at')),
            amountMinor: Value(amountMinor),
            currencyCode: Value(_remoteString(fields, 'currency_code')),
            description: Value(
              _remoteStringOr(fields, 'description', existing.description),
            ),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            accountId: Value(accountId),
            toAccountId: Value<String?>(
              _remoteNullableString(fields, 'to_account_id'),
            ),
            categoryId: Value(_remoteString(fields, 'category_id')),
            paymentMethod: Value(_remotePaymentMethod(fields).storageValue),
            customPaymentMethodName: Value<String?>(
              _remoteNullableString(fields, 'custom_payment_method_name'),
            ),
            actualPayerAccount: Value(nextDirection),
            relatedTransactionId: Value<String?>(
              _remoteNullableString(fields, 'related_transaction_id'),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(updatedAt),
          ),
        );
    if (fields.containsKey('ledger_ids')) {
      await _replaceTransactionLedgerLinks(
        transactionId: transactionId,
        ledgerIds: await _remoteLedgerIds(userId, fields),
      );
    }
  }

  Future<void> _applyRemoteTransferTransactionDelete({
    required String userId,
    required MoneyTransaction transaction,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    if (transaction.isDeleted) {
      return;
    }
    final account = await _getAccountForUser(userId, transaction.accountId);
    final ledger = _MutableAccountLedger.fromAccount(account);
    _applyTransferDirection(
      ledger: ledger,
      direction: transaction.actualPayerAccount,
      amountMinor: transaction.amountMinor,
      rollback: true,
    );
    ledger.validate();
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await _updateAccountLedger(userId, account.id, ledger, deletedAt);
    await (database.update(database.moneyTransactions)..where(
          (row) =>
              row.id.equals(transaction.id) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyTransactionsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? transaction.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteAccountChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteAccountInsert(
          userId: userId,
          accountId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteAccountUpdate(
          userId: userId,
          accountId: change.recordId,
          fields: change.changedFields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteAccountDelete(
          userId: userId,
          accountId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteAccountInsert({
    required String userId,
    required String accountId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyAccounts)
              ..where((row) => row.id.equals(accountId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyAccounts)
        .insert(
          MoneyAccountsCompanion.insert(
            id: accountId,
            userId: userId,
            name: _remoteString(fields, 'name'),
            description: Value<String?>(
              _remoteNullableString(fields, 'description'),
            ),
            type: _remoteString(fields, 'type'),
            balanceMinor: _remoteInt(fields, 'balance_minor'),
            initialBalanceMinor: _remoteInt(fields, 'initial_balance_minor'),
            creditLimitMinor: Value<int?>(
              _remoteNullableInt(fields, 'credit_limit_minor'),
            ),
            postedDebtMinor: Value<int?>(
              _remoteNullableInt(fields, 'posted_debt_minor'),
            ),
            frozenCreditMinor: Value<int?>(
              _remoteNullableInt(fields, 'frozen_credit_minor'),
            ),
            statementDay: Value<int?>(
              _remoteNullableInt(fields, 'statement_day'),
            ),
            repaymentDay: Value<int?>(
              _remoteNullableInt(fields, 'repayment_day'),
            ),
            autoRepaymentReminderEnabled: Value(
              _remoteBool(
                fields,
                'auto_repayment_reminder_enabled',
                fallback: true,
              ),
            ),
            currencyCode: _remoteString(fields, 'currency_code'),
            isShared: Value(_remoteBool(fields, 'is_shared', fallback: false)),
            isVirtual: Value(
              _remoteBool(fields, 'is_virtual', fallback: false),
            ),
            ownerMemberId: Value<String?>(
              _remoteNullableString(fields, 'owner_member_id'),
            ),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            icon: Value<String?>(_remoteNullableString(fields, 'icon')),
            isActive: Value(_remoteBool(fields, 'is_active', fallback: true)),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _applyRemoteAccountUpdate({
    required String userId,
    required String accountId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getAccountForUser(userId, accountId);
    final now = DateTime.now().toUtc();
    await (database.update(database.moneyAccounts)..where(
          (row) =>
              row.id.equals(accountId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyAccountsCompanion(
            name: Value(_remoteStringOr(fields, 'name', existing.name)),
            description: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'description',
                existing.description,
              ),
            ),
            type: Value(_remoteStringOr(fields, 'type', existing.type)),
            balanceMinor: Value(
              _remoteIntOr(fields, 'balance_minor', existing.balanceMinor),
            ),
            initialBalanceMinor: Value(
              _remoteIntOr(
                fields,
                'initial_balance_minor',
                existing.initialBalanceMinor,
              ),
            ),
            creditLimitMinor: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'credit_limit_minor',
                existing.creditLimitMinor,
              ),
            ),
            postedDebtMinor: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'posted_debt_minor',
                existing.postedDebtMinor,
              ),
            ),
            frozenCreditMinor: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'frozen_credit_minor',
                existing.frozenCreditMinor,
              ),
            ),
            statementDay: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'statement_day',
                existing.statementDay,
              ),
            ),
            repaymentDay: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'repayment_day',
                existing.repaymentDay,
              ),
            ),
            autoRepaymentReminderEnabled: Value(
              _remoteBoolOr(
                fields,
                'auto_repayment_reminder_enabled',
                existing.autoRepaymentReminderEnabled,
              ),
            ),
            currencyCode: Value(
              _remoteStringOr(fields, 'currency_code', existing.currencyCode),
            ),
            color: Value<String?>(
              _remoteNullableStringOr(fields, 'color', existing.color),
            ),
            icon: Value<String?>(
              _remoteNullableStringOr(fields, 'icon', existing.icon),
            ),
            isActive: Value(
              _remoteBoolOr(fields, 'is_active', existing.isActive),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(
              _remoteDateTime(fields, 'updated_at', fallback: now),
            ),
          ),
        );
  }

  Future<void> _applyRemoteAccountDelete({
    required String userId,
    required String accountId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneyAccounts)
              ..where(
                (row) => row.id.equals(accountId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyAccounts)..where(
          (row) =>
              row.id.equals(accountId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyAccountsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            isActive: const Value(false),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteBudgetChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteBudgetInsert(
          userId: userId,
          budgetId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteBudgetUpdate(
          userId: userId,
          budgetId: change.recordId,
          fields: change.changedFields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteBudgetDelete(
          userId: userId,
          budgetId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteBudgetSnapshotChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteBudgetSnapshot(
          userId: userId,
          snapshotId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteBudgetSnapshot(
          userId: userId,
          snapshotId: change.recordId,
        );
    }
  }

  Future<void> _upsertRemoteBudgetSnapshot({
    required String userId,
    required String snapshotId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyBudgetSnapshots)
        .insertOnConflictUpdate(
          MoneyBudgetSnapshotsCompanion.insert(
            id: snapshotId,
            userId: userId,
            budgetId: _remoteString(fields, 'budget_id'),
            ledgerId: Value<String?>(
              _remoteNullableString(fields, 'ledger_id'),
            ),
            trackingType: _remoteString(fields, 'tracking_type'),
            periodType: _remoteString(fields, 'period_type'),
            repeatInterval: _remoteInt(fields, 'repeat_interval'),
            periodStartDate: _remoteInt(fields, 'period_start_date'),
            periodEndDate: _remoteInt(fields, 'period_end_date'),
            budgetAmountMinor: _remoteInt(fields, 'budget_amount_minor'),
            usedAmountMinor: _remoteInt(fields, 'used_amount_minor'),
            remainingAmountMinor: _remoteInt(fields, 'remaining_amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            status: _remoteString(fields, 'status'),
            capturedAt: _remoteDateTime(fields, 'captured_at', fallback: now),
            sourceBudgetVersion: _remoteIntOr(
              fields,
              'source_budget_version',
              version ?? 1,
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteBudgetSnapshot({
    required String userId,
    required String snapshotId,
  }) async {
    await (database.delete(database.moneyBudgetSnapshots)..where(
          (row) => row.id.equals(snapshotId) & row.userId.equals(userId),
        ))
        .go();
  }

  Future<void> _applyRemoteBudgetAllocationSnapshotChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteBudgetAllocationSnapshot(
          userId: userId,
          snapshotId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteBudgetAllocationSnapshot(
          userId: userId,
          snapshotId: change.recordId,
        );
    }
  }

  Future<void> _upsertRemoteBudgetAllocationSnapshot({
    required String userId,
    required String snapshotId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyBudgetAllocationSnapshots)
        .insertOnConflictUpdate(
          MoneyBudgetAllocationSnapshotsCompanion.insert(
            id: snapshotId,
            userId: userId,
            budgetSnapshotId: _remoteString(fields, 'budget_snapshot_id'),
            budgetId: _remoteString(fields, 'budget_id'),
            allocationId: _remoteString(fields, 'allocation_id'),
            categoryId: Value<String?>(
              _remoteNullableString(fields, 'category_id'),
            ),
            memberId: Value<String?>(
              _remoteNullableString(fields, 'member_id'),
            ),
            allocatedAmountMinor: _remoteInt(fields, 'allocated_amount_minor'),
            usedAmountMinor: _remoteInt(fields, 'used_amount_minor'),
            remainingAmountMinor: _remoteInt(fields, 'remaining_amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            status: _remoteString(fields, 'status'),
            capturedAt: _remoteDateTime(fields, 'captured_at', fallback: now),
            sourceAllocationVersion: _remoteIntOr(
              fields,
              'source_allocation_version',
              version ?? 1,
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteBudgetAllocationSnapshot({
    required String userId,
    required String snapshotId,
  }) async {
    await (database.delete(database.moneyBudgetAllocationSnapshots)..where(
          (row) => row.id.equals(snapshotId) & row.userId.equals(userId),
        ))
        .go();
  }

  Future<void> _applyRemoteBudgetInsert({
    required String userId,
    required String budgetId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyBudgets)
              ..where((row) => row.id.equals(budgetId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyBudgets)
        .insert(
          MoneyBudgetsCompanion.insert(
            id: budgetId,
            userId: userId,
            accountId: Value<String?>(
              _remoteNullableString(fields, 'account_id'),
            ),
            ledgerId: Value<String?>(
              _remoteNullableString(fields, 'ledger_id'),
            ),
            createdByMemberId: Value<String?>(
              _remoteNullableString(fields, 'created_by_member_id'),
            ),
            name: _remoteString(fields, 'name'),
            description: Value<String?>(
              _remoteNullableString(fields, 'description'),
            ),
            amountMinor: _remoteInt(fields, 'amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            repeatPeriodType: _remoteString(fields, 'repeat_period_type'),
            repeatInterval: _remoteInt(fields, 'repeat_interval'),
            repeatDays: Value<String?>(
              _remoteNullableString(fields, 'repeat_days'),
            ),
            startDate: _remoteInt(fields, 'start_date'),
            endDate: _remoteInt(fields, 'end_date'),
            usedAmountMinor: Value(
              _remoteIntOr(fields, 'used_amount_minor', 0),
            ),
            isActive: Value(_remoteBool(fields, 'is_active', fallback: true)),
            alertEnabled: Value(
              _remoteBool(fields, 'alert_enabled', fallback: false),
            ),
            alertThresholdPercent: Value<int?>(
              _remoteNullableInt(fields, 'alert_threshold_percent'),
            ),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            currentPeriodUsedMinor: Value(
              _remoteIntOr(fields, 'current_period_used_minor', 0),
            ),
            currentPeriodStartDate: _remoteInt(
              fields,
              'current_period_start_date',
            ),
            lastResetAt: _remoteDateTime(
              fields,
              'last_reset_at',
              fallback: now,
            ),
            budgetType: _remoteStringOr(
              fields,
              'budget_type',
              _DriftMoneyRepositoryBase._budgetTypeStandard,
            ),
            trackingType: Value(
              _remoteStringOr(fields, 'tracking_type', 'expense_limit'),
            ),
            progressMinor: Value(_remoteIntOr(fields, 'progress_minor', 0)),
            linkedGoal: Value<String?>(
              _remoteNullableString(fields, 'linked_goal'),
            ),
            priority: Value(_remoteIntOr(fields, 'priority', 0)),
            autoRollover: Value(
              _remoteBool(fields, 'auto_rollover', fallback: false),
            ),
            scopeType: _remoteString(fields, 'scope_type'),
            accountScopeJson: Value<String?>(
              _remoteNullableString(fields, 'account_scope_json'),
            ),
            categoryScopeJson: Value<String?>(
              _remoteNullableString(fields, 'category_scope_json'),
            ),
            advancedRulesJson: Value<String?>(
              _remoteNullableString(fields, 'advanced_rules_json'),
            ),
            tagsJson: Value<String?>(
              _remoteNullableString(fields, 'tags_json'),
            ),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _applyRemoteBudgetUpdate({
    required String userId,
    required String budgetId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getBudgetForUser(userId, budgetId);
    final now = DateTime.now().toUtc();
    await (database.update(database.moneyBudgets)..where(
          (row) =>
              row.id.equals(budgetId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyBudgetsCompanion(
            accountId: Value<String?>(
              _remoteNullableStringOr(fields, 'account_id', existing.accountId),
            ),
            ledgerId: Value<String?>(
              _remoteNullableStringOr(fields, 'ledger_id', existing.ledgerId),
            ),
            name: Value(_remoteStringOr(fields, 'name', existing.name)),
            description: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'description',
                existing.description,
              ),
            ),
            amountMinor: Value(
              _remoteIntOr(fields, 'amount_minor', existing.amountMinor),
            ),
            currencyCode: Value(
              _remoteStringOr(fields, 'currency_code', existing.currencyCode),
            ),
            repeatPeriodType: Value(
              _remoteStringOr(
                fields,
                'repeat_period_type',
                existing.repeatPeriodType,
              ),
            ),
            repeatInterval: Value(
              _remoteIntOr(fields, 'repeat_interval', existing.repeatInterval),
            ),
            startDate: Value(
              _remoteIntOr(fields, 'start_date', existing.startDate),
            ),
            endDate: Value(_remoteIntOr(fields, 'end_date', existing.endDate)),
            currentPeriodStartDate: Value(
              _remoteIntOr(
                fields,
                'current_period_start_date',
                existing.currentPeriodStartDate,
              ),
            ),
            isActive: Value(
              _remoteBoolOr(fields, 'is_active', existing.isActive),
            ),
            alertEnabled: Value(
              _remoteBoolOr(fields, 'alert_enabled', existing.alertEnabled),
            ),
            alertThresholdPercent: Value<int?>(
              _remoteNullableIntOr(
                fields,
                'alert_threshold_percent',
                existing.alertThresholdPercent,
              ),
            ),
            color: Value<String?>(
              _remoteNullableStringOr(fields, 'color', existing.color),
            ),
            trackingType: Value(
              _remoteStringOr(fields, 'tracking_type', existing.trackingType),
            ),
            scopeType: Value(
              _remoteStringOr(fields, 'scope_type', existing.scopeType),
            ),
            categoryScopeJson: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'category_scope_json',
                existing.categoryScopeJson,
              ),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(
              _remoteDateTime(fields, 'updated_at', fallback: now),
            ),
          ),
        );
  }

  Future<void> _applyRemoteBudgetDelete({
    required String userId,
    required String budgetId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneyBudgets)
              ..where(
                (row) => row.id.equals(budgetId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyBudgets)..where(
          (row) =>
              row.id.equals(budgetId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyBudgetsCompanion(
            isActive: const Value(false),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteInstallmentPlanChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteInstallmentPlanInsert(
          userId: userId,
          planId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteInstallmentPlanUpdate(
          userId: userId,
          planId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteInstallmentPlanDelete(
          userId: userId,
          planId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteInstallmentPlanInsert({
    required String userId,
    required String planId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyInstallmentPlans)
              ..where((row) => row.id.equals(planId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }

    final accountId = _remoteString(fields, 'account_id');
    final account = await _getWritableAccountForUser(userId, accountId);
    final ledgerId =
        _remoteNullableString(fields, 'ledger_id') ?? _defaultLedgerId(userId);
    await _getLedgerForUser(userId, ledgerId);
    final accountType = MoneyAccountType.fromStorageValue(account.type);
    if (!accountType.isCreditLike) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidInstallmentAccount,
      );
    }
    await _assertCategoryForUser(
      userId,
      _remoteString(fields, 'category_id'),
      MoneyCategoryKind.expense,
    );
    final subCategoryId = _remoteNullableString(fields, 'sub_category_id');
    if (subCategoryId != null) {
      await _assertSubCategoryForUser(
        userId,
        _remoteString(fields, 'category_id'),
        subCategoryId,
        MoneyCategoryKind.expense,
      );
    }

    final details = _remoteObjectList(fields, 'details');
    final now = DateTime.now().toUtc();
    final createdAt = _remoteDateTime(fields, 'created_at', fallback: now);
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);
    final ledger = _MutableAccountLedger.fromAccount(account)
      ..freezeCredit(_remoteInt(fields, 'total_amount_minor'));

    await database
        .into(database.moneyInstallmentPlans)
        .insert(
          MoneyInstallmentPlansCompanion.insert(
            id: planId,
            userId: userId,
            accountId: accountId,
            transactionId: Value<String?>(
              _remoteNullableString(fields, 'transaction_id'),
            ),
            ledgerId: Value<String?>(ledgerId),
            name: _remoteString(fields, 'name'),
            description: Value<String?>(
              _remoteNullableString(fields, 'description'),
            ),
            categoryId: _remoteString(fields, 'category_id'),
            subCategoryId: Value<String?>(subCategoryId),
            totalAmountMinor: _remoteInt(fields, 'total_amount_minor'),
            totalPeriods: _remoteInt(fields, 'total_periods'),
            remainingPeriods: _remoteInt(fields, 'remaining_periods'),
            periodAmountMinor: _remoteInt(fields, 'period_amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            startDate: _remoteInt(fields, 'start_date'),
            endDate: _remoteInt(fields, 'end_date'),
            firstDueDate: _remoteInt(fields, 'first_due_date'),
            status: _remoteString(fields, 'status'),
            interestRateBasisPoints: Value<int?>(
              _remoteNullableInt(fields, 'interest_rate_basis_points'),
            ),
            totalInterestMinor: Value<int?>(
              _remoteNullableInt(fields, 'total_interest_minor'),
            ),
            calcMethod: Value<String?>(
              _remoteNullableString(fields, 'calc_method'),
            ),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );

    for (final detail in details) {
      await _insertRemoteInstallmentDetail(
        userId: userId,
        planId: planId,
        planFields: fields,
        detail: detail,
        fallbackNow: now,
        ledger: ledger,
      );
    }
    ledger.validate();
    await _updateAccountLedger(userId, account.id, ledger, updatedAt);
  }

  Future<void> _applyRemoteInstallmentPlanUpdate({
    required String userId,
    required String planId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getInstallmentPlanForUser(userId, planId);
    final ledgerId = _remoteNullableStringOr(
      fields,
      'ledger_id',
      existing.ledgerId ?? _defaultLedgerId(userId),
    );
    if (ledgerId != null) {
      await _getLedgerForUser(userId, ledgerId);
    }
    final account = await _getWritableAccountForUser(
      userId,
      existing.accountId,
    );
    final ledger = _MutableAccountLedger.fromAccount(account);
    final details = _remoteObjectList(fields, 'details');
    final existingDetails =
        await (database.select(database.moneyInstallmentDetails)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.planId.equals(planId) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final existingById = {
      for (final detail in existingDetails) detail.id: detail,
    };
    final now = DateTime.now().toUtc();
    final updatedAt = _remoteDateTime(fields, 'updated_at', fallback: now);

    for (final detail in details) {
      final detailId = _remoteString(detail, 'id');
      final current = existingById[detailId];
      if (current == null) {
        await _insertRemoteInstallmentDetail(
          userId: userId,
          planId: planId,
          planFields: fields,
          detail: detail,
          fallbackNow: now,
          ledger: ledger,
        );
        continue;
      }
      await _applyRemoteInstallmentDetailTransition(
        userId: userId,
        planFields: fields,
        existing: current,
        remote: detail,
        ledger: ledger,
        fallbackNow: now,
      );
      await _updateRemoteInstallmentDetail(
        userId: userId,
        planId: planId,
        detail: detail,
        fallbackNow: now,
      );
    }

    ledger.validate();
    await _updateAccountLedger(userId, account.id, ledger, updatedAt);
    await (database.update(database.moneyInstallmentPlans)..where(
          (row) =>
              row.id.equals(planId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyInstallmentPlansCompanion(
            remainingPeriods: Value(
              _remoteIntOr(
                fields,
                'remaining_periods',
                existing.remainingPeriods,
              ),
            ),
            status: Value(_remoteStringOr(fields, 'status', existing.status)),
            transactionId: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'transaction_id',
                existing.transactionId,
              ),
            ),
            ledgerId: Value<String?>(ledgerId),
            notes: Value<String?>(
              _remoteNullableStringOr(fields, 'notes', existing.notes),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(updatedAt),
          ),
        );
  }

  Future<void> _applyRemoteInstallmentPlanDelete({
    required String userId,
    required String planId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneyInstallmentPlans)
              ..where(
                (row) => row.id.equals(planId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final pendingDetails =
        await (database.select(database.moneyInstallmentDetails)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.planId.equals(planId) &
                  row.status.equals(
                    MoneyInstallmentDetailStatus.pending.storageValue,
                  ) &
                  row.isDeleted.equals(false),
            ))
            .get();
    final releasePrincipalMinor = pendingDetails.fold<int>(
      0,
      (sum, detail) => sum + detail.principalMinor,
    );
    final account = await _getWritableAccountForUser(
      userId,
      existing.accountId,
    );
    final ledger = _MutableAccountLedger.fromAccount(account)
      ..releaseFrozenCredit(releasePrincipalMinor)
      ..validate();
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await _updateAccountLedger(userId, account.id, ledger, deletedAt);
    await (database.update(database.moneyInstallmentPlans)..where(
          (row) =>
              row.id.equals(planId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyInstallmentPlansCompanion(
            status: Value(MoneyInstallmentPlanStatus.cancelled.storageValue),
            remainingPeriods: const Value(0),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
    await (database.update(database.moneyInstallmentDetails)..where(
          (row) =>
              row.userId.equals(userId) &
              row.planId.equals(planId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyInstallmentDetailsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _insertRemoteInstallmentDetail({
    required String userId,
    required String planId,
    required Map<String, Object?> planFields,
    required Map<String, Object?> detail,
    required DateTime fallbackNow,
    required _MutableAccountLedger ledger,
  }) async {
    final status = MoneyInstallmentDetailStatus.fromStorageValue(
      _remoteString(detail, 'status'),
    );
    if (status == MoneyInstallmentDetailStatus.posted) {
      await _createRemoteInstallmentTransactionIfNeeded(
        userId: userId,
        planId: planId,
        planFields: planFields,
        detail: detail,
        fallbackNow: fallbackNow,
      );
      ledger.postInstallmentExpense(
        principalMinor: _remoteInt(detail, 'principal_minor'),
        amountMinor: _remoteInt(detail, 'amount_minor'),
      );
    } else if (status == MoneyInstallmentDetailStatus.skipped) {
      ledger.releaseFrozenCredit(_remoteInt(detail, 'principal_minor'));
    }

    await database
        .into(database.moneyInstallmentDetails)
        .insert(
          MoneyInstallmentDetailsCompanion.insert(
            id: _remoteString(detail, 'id'),
            userId: userId,
            planId: planId,
            accountId: _remoteString(detail, 'account_id'),
            periodNumber: _remoteInt(detail, 'period_number'),
            amountMinor: _remoteInt(detail, 'amount_minor'),
            principalMinor: _remoteInt(detail, 'principal_minor'),
            interestMinor: _remoteInt(detail, 'interest_minor'),
            dueDate: _remoteInt(detail, 'due_date'),
            paidDate: Value<int?>(_remoteNullableInt(detail, 'paid_date')),
            status: status.storageValue,
            transactionId: Value<String?>(
              _remoteNullableString(detail, 'transaction_id'),
            ),
            notes: Value<String?>(_remoteNullableString(detail, 'notes')),
            deviceId: Value<String?>(
              _remoteNullableString(detail, 'device_id'),
            ),
            version: Value(_remoteIntOr(detail, 'version', 1)),
            isDeleted: Value(
              _remoteBool(detail, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(detail, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(
              detail,
              'created_at',
              fallback: fallbackNow,
            ),
            updatedAt: _remoteDateTime(
              detail,
              'updated_at',
              fallback: fallbackNow,
            ),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _applyRemoteInstallmentDetailTransition({
    required String userId,
    required Map<String, Object?> planFields,
    required MoneyInstallmentDetail existing,
    required Map<String, Object?> remote,
    required _MutableAccountLedger ledger,
    required DateTime fallbackNow,
  }) async {
    final existingStatus = MoneyInstallmentDetailStatus.fromStorageValue(
      existing.status,
    );
    final remoteStatus = MoneyInstallmentDetailStatus.fromStorageValue(
      _remoteString(remote, 'status'),
    );
    if (existingStatus != MoneyInstallmentDetailStatus.pending ||
        existingStatus == remoteStatus) {
      return;
    }
    if (remoteStatus == MoneyInstallmentDetailStatus.posted) {
      await _createRemoteInstallmentTransactionIfNeeded(
        userId: userId,
        planId: existing.planId,
        planFields: planFields,
        detail: remote,
        fallbackNow: fallbackNow,
      );
      ledger.postInstallmentExpense(
        principalMinor: existing.principalMinor,
        amountMinor: existing.amountMinor,
      );
    } else if (remoteStatus == MoneyInstallmentDetailStatus.skipped) {
      ledger.releaseFrozenCredit(existing.principalMinor);
    }
  }

  Future<void> _updateRemoteInstallmentDetail({
    required String userId,
    required String planId,
    required Map<String, Object?> detail,
    required DateTime fallbackNow,
  }) async {
    await (database.update(database.moneyInstallmentDetails)..where(
          (row) =>
              row.id.equals(_remoteString(detail, 'id')) &
              row.userId.equals(userId) &
              row.planId.equals(planId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyInstallmentDetailsCompanion(
            paidDate: Value<int?>(_remoteNullableInt(detail, 'paid_date')),
            status: Value(_remoteString(detail, 'status')),
            transactionId: Value<String?>(
              _remoteNullableString(detail, 'transaction_id'),
            ),
            notes: Value<String?>(_remoteNullableString(detail, 'notes')),
            version: Value(_remoteIntOr(detail, 'version', 1)),
            updatedAt: Value(
              _remoteDateTime(detail, 'updated_at', fallback: fallbackNow),
            ),
          ),
        );
  }

  Future<void> _createRemoteInstallmentTransactionIfNeeded({
    required String userId,
    required String planId,
    required Map<String, Object?> planFields,
    required Map<String, Object?> detail,
    required DateTime fallbackNow,
  }) async {
    final transactionId = _remoteNullableString(detail, 'transaction_id');
    if (transactionId == null) {
      return;
    }
    final existing =
        await (database.select(database.moneyTransactions)
              ..where((row) => row.id.equals(transactionId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final account = await _getAccountForUser(
      userId,
      _remoteString(detail, 'account_id'),
    );
    final accountType = MoneyAccountType.fromStorageValue(account.type);
    final transactionAt = _dateFromKey(_remoteInt(detail, 'due_date'));
    final createdAt = _remoteDateTime(
      detail,
      'created_at',
      fallback: fallbackNow,
    );
    final updatedAt = _remoteDateTime(
      detail,
      'updated_at',
      fallback: fallbackNow,
    );
    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            id: transactionId,
            userId: userId,
            type: MoneyTransactionType.expense.storageValue,
            status: MoneyTransactionStatus.completed.storageValue,
            transactionAt: transactionAt,
            amountMinor: _remoteInt(detail, 'amount_minor'),
            currencyCode: _remoteString(planFields, 'currency_code'),
            description:
                '${_remoteString(planFields, 'name')} 第${_remoteInt(detail, 'period_number')}期',
            notes: Value<String?>(
              _remoteNullableString(detail, 'notes') ??
                  _remoteNullableString(planFields, 'notes'),
            ),
            accountId: _remoteString(detail, 'account_id'),
            categoryId: _remoteString(planFields, 'category_id'),
            subCategoryId: Value<String?>(
              _remoteNullableString(planFields, 'sub_category_id'),
            ),
            paymentMethod: _paymentMethodForAccountType(
              accountType,
            ).storageValue,
            actualPayerAccount: 'installment',
            installmentPlanId: Value<String?>(planId),
            totalInterestMinor: Value(_remoteInt(detail, 'interest_minor')),
            calcMethod: Value<String?>(
              _remoteNullableString(planFields, 'calc_method'),
            ),
            version: Value(_remoteIntOr(detail, 'version', 1)),
            createdAt: createdAt,
            updatedAt: updatedAt,
          ),
        );
  }

  Future<void> _applyRemoteCategoryChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteCategory(
          userId: userId,
          categoryId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteCategory(
          userId: userId,
          categoryId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteCategory({
    required String userId,
    required String categoryId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyCategories)
        .insertOnConflictUpdate(
          MoneyCategoriesCompanion.insert(
            id: categoryId,
            userId: Value<String?>(userId),
            name: _remoteString(fields, 'name'),
            kind: _remoteString(fields, 'kind'),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            icon: Value<String?>(_remoteNullableString(fields, 'icon')),
            isSystem: Value(_remoteBool(fields, 'is_system', fallback: false)),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteCategory({
    required String userId,
    required String categoryId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyCategories)..where(
          (row) => row.id.equals(categoryId) & row.userId.equals(userId),
        ))
        .write(
          MoneyCategoriesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteSubCategoryChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteSubCategory(
          userId: userId,
          subCategoryId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteSubCategory(
          userId: userId,
          subCategoryId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteSubCategory({
    required String userId,
    required String subCategoryId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    final categoryId = _remoteString(fields, 'category_id');
    await _assertCategoryForUser(
      userId,
      categoryId,
      MoneyCategoryKind.fromStorageValue(_remoteString(fields, 'kind')),
    );
    await database
        .into(database.moneySubCategories)
        .insertOnConflictUpdate(
          MoneySubCategoriesCompanion.insert(
            id: subCategoryId,
            categoryId: categoryId,
            userId: Value<String?>(userId),
            name: _remoteString(fields, 'name'),
            kind: _remoteString(fields, 'kind'),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            icon: Value<String?>(_remoteNullableString(fields, 'icon')),
            isSystem: Value(_remoteBool(fields, 'is_system', fallback: false)),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteSubCategory({
    required String userId,
    required String subCategoryId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneySubCategories)..where(
          (row) => row.id.equals(subCategoryId) & row.userId.equals(userId),
        ))
        .write(
          MoneySubCategoriesCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteBudgetAllocationChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _upsertRemoteBudgetAllocation(
          userId: userId,
          allocationId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _upsertRemoteBudgetAllocation(
          userId: userId,
          allocationId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteBudgetAllocation(
          userId: userId,
          allocationId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteBudgetAllocation({
    required String userId,
    required String allocationId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyBudgetAllocations)
        .insertOnConflictUpdate(
          MoneyBudgetAllocationsCompanion.insert(
            id: allocationId,
            userId: userId,
            budgetId: _remoteString(fields, 'budget_id'),
            categoryId: Value<String?>(
              _remoteNullableString(fields, 'category_id'),
            ),
            memberId: Value<String?>(
              _remoteNullableString(fields, 'member_id'),
            ),
            allocatedAmountMinor: _remoteInt(fields, 'allocated_amount_minor'),
            usedAmountMinor: Value(
              _remoteIntOr(fields, 'used_amount_minor', 0),
            ),
            remainingAmountMinor: _remoteInt(fields, 'remaining_amount_minor'),
            percentageBasisPoints: Value<int?>(
              _remoteNullableInt(fields, 'percentage_basis_points'),
            ),
            allocationType: _remoteString(fields, 'allocation_type'),
            ruleConfigJson: Value<String?>(
              _remoteNullableString(fields, 'rule_config_json'),
            ),
            allowOverspend: Value(
              _remoteBool(fields, 'allow_overspend', fallback: false),
            ),
            overspendLimitType: Value<String?>(
              _remoteNullableString(fields, 'overspend_limit_type'),
            ),
            overspendLimitMinor: Value<int?>(
              _remoteNullableInt(fields, 'overspend_limit_minor'),
            ),
            alertEnabled: Value(
              _remoteBool(fields, 'alert_enabled', fallback: false),
            ),
            alertThresholdPercent: _remoteInt(
              fields,
              'alert_threshold_percent',
            ),
            alertConfigJson: Value<String?>(
              _remoteNullableString(fields, 'alert_config_json'),
            ),
            priority: Value(_remoteIntOr(fields, 'priority', 0)),
            isMandatory: Value(
              _remoteBool(fields, 'is_mandatory', fallback: false),
            ),
            status: _remoteString(fields, 'status'),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteBudgetAllocation({
    required String userId,
    required String allocationId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyBudgetAllocations)..where(
          (row) => row.id.equals(allocationId) & row.userId.equals(userId),
        ))
        .write(
          MoneyBudgetAllocationsCompanion(
            status: const Value('inactive'),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteBillReminderChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteBillReminder(
          userId: userId,
          reminderId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteBillReminder(
          userId: userId,
          reminderId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteBillReminder({
    required String userId,
    required String reminderId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyBillReminders)
        .insertOnConflictUpdate(
          MoneyBillRemindersCompanion.insert(
            id: reminderId,
            userId: userId,
            name: _remoteString(fields, 'name'),
            amountMinor: _remoteInt(fields, 'amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            dueDate: _remoteInt(fields, 'due_date'),
            remindBeforeDays: _remoteIntOr(fields, 'remind_before_days', 1),
            repeatPeriodType: Value<String?>(
              _remoteNullableString(fields, 'repeat_period_type'),
            ),
            repeatInterval: Value<int?>(
              _remoteNullableInt(fields, 'repeat_interval'),
            ),
            accountId: Value<String?>(
              _remoteNullableString(fields, 'account_id'),
            ),
            ledgerId: Value<String?>(
              _remoteNullableString(fields, 'ledger_id'),
            ),
            categoryId: Value<String?>(
              _remoteNullableString(fields, 'category_id'),
            ),
            relatedTransactionId: Value<String?>(
              _remoteNullableString(fields, 'related_transaction_id'),
            ),
            status: _remoteStringOr(
              fields,
              'status',
              MoneyBillReminderStatus.pending.storageValue,
            ),
            sourceType: Value(
              _remoteStringOr(
                fields,
                'source_type',
                MoneyBillReminderSourceType.manual.storageValue,
              ),
            ),
            sourceKey: Value<String?>(
              _remoteNullableString(fields, 'source_key'),
            ),
            amountSource: Value(
              _remoteStringOr(
                fields,
                'amount_source',
                MoneyBillReminderAmountSource.staticAmount.storageValue,
              ),
            ),
            autoManaged: Value(
              _remoteBool(fields, 'auto_managed', fallback: false),
            ),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteBillReminder({
    required String userId,
    required String reminderId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyBillReminders)..where(
          (row) => row.id.equals(reminderId) & row.userId.equals(userId),
        ))
        .write(
          MoneyBillRemindersCompanion(
            status: Value(
              _remoteStringOr(
                fields,
                'status',
                MoneyBillReminderStatus.cancelled.storageValue,
              ),
            ),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteAutoPostingTemplateChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteAutoPostingTemplate(
          userId: userId,
          templateId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteAutoPostingTemplate(
          userId: userId,
          templateId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteAutoPostingTemplate({
    required String userId,
    required String templateId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyAutoPostingTemplates)
        .insertOnConflictUpdate(
          MoneyAutoPostingTemplatesCompanion.insert(
            id: templateId,
            userId: userId,
            name: _remoteString(fields, 'name'),
            type: _remoteString(fields, 'type'),
            amountMinor: _remoteInt(fields, 'amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            description: _remoteString(fields, 'description'),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            merchant: Value<String?>(_remoteNullableString(fields, 'merchant')),
            accountId: _remoteString(fields, 'account_id'),
            categoryId: _remoteString(fields, 'category_id'),
            subCategoryId: Value<String?>(
              _remoteNullableString(fields, 'sub_category_id'),
            ),
            paymentMethod: _remoteString(fields, 'payment_method'),
            customPaymentMethodName: Value<String?>(
              _remoteNullableString(fields, 'custom_payment_method_name'),
            ),
            actualPayerAccount: Value(
              _remoteStringOr(fields, 'actual_payer_account', 'default'),
            ),
            ledgerId: Value<String?>(
              _remoteNullableString(fields, 'ledger_id'),
            ),
            frequency: _remoteString(fields, 'frequency'),
            dayOfMonth: Value<int?>(_remoteNullableInt(fields, 'day_of_month')),
            weekday: Value<int?>(_remoteNullableInt(fields, 'weekday')),
            timeOfDayMinutes: Value(
              _remoteIntOr(fields, 'time_of_day_minutes', 0),
            ),
            startsOn: _remoteDateTime(fields, 'starts_on', fallback: now),
            endsOn: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'ends_on'),
            ),
            isActive: Value(_remoteBool(fields, 'is_active', fallback: true)),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteAutoPostingTemplate({
    required String userId,
    required String templateId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyAutoPostingTemplates)..where(
          (row) => row.id.equals(templateId) & row.userId.equals(userId),
        ))
        .write(
          MoneyAutoPostingTemplatesCompanion(
            isActive: const Value(false),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteAutoPostingRunChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteAutoPostingRun(
          userId: userId,
          runId: change.recordId,
          fields: fields,
        );
      case 'delete':
        await _deleteRemoteAutoPostingRun(
          userId: userId,
          runId: change.recordId,
        );
    }
  }

  Future<void> _upsertRemoteAutoPostingRun({
    required String userId,
    required String runId,
    required Map<String, Object?> fields,
  }) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyAutoPostingRuns)
        .insertOnConflictUpdate(
          MoneyAutoPostingRunsCompanion.insert(
            id: runId,
            userId: userId,
            templateId: _remoteString(fields, 'template_id'),
            occurrenceKey: _remoteString(fields, 'occurrence_key'),
            status: _remoteString(fields, 'status'),
            transactionId: Value<String?>(
              _remoteNullableString(fields, 'transaction_id'),
            ),
            scheduledFor: _remoteDateTime(
              fields,
              'scheduled_for',
              fallback: now,
            ),
            postedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'posted_at'),
            ),
            templateVersion: _remoteIntOr(fields, 'template_version', 1),
            errorCode: Value<String?>(
              _remoteNullableString(fields, 'error_code'),
            ),
            errorMessage: Value<String?>(
              _remoteNullableString(fields, 'error_message'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteAutoPostingRun({
    required String userId,
    required String runId,
  }) async {
    await (database.delete(
      database.moneyAutoPostingRuns,
    )..where((row) => row.id.equals(runId) & row.userId.equals(userId))).go();
  }

  Future<void> _applyRemoteLedgerChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteLedgerInsert(
          userId: userId,
          ledgerId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteLedgerUpdate(
          userId: userId,
          ledgerId: change.recordId,
          fields: change.changedFields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteLedgerDelete(
          userId: userId,
          ledgerId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteLedgerInsert({
    required String userId,
    required String ledgerId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyLedgers)
              ..where((row) => row.id.equals(ledgerId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final createdByMemberId = _remoteString(fields, 'created_by_member_id');
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: ledgerId,
            userId: userId,
            name: _remoteString(fields, 'name'),
            description: Value<String?>(
              _remoteNullableString(fields, 'description'),
            ),
            createdByMemberId: createdByMemberId,
            ledgerType: _remoteString(fields, 'ledger_type'),
            status: _remoteStringOr(fields, 'status', 'active'),
            baseCurrencyCode: _remoteString(fields, 'base_currency_code'),
            settlementCycle: _remoteStringOr(
              fields,
              'settlement_cycle',
              'manual',
            ),
            settlementDay: _remoteIntOr(fields, 'settlement_day', 1),
            icon: Value<String?>(_remoteNullableString(fields, 'icon')),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: ledgerId,
            memberId: createdByMemberId,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _applyRemoteLedgerUpdate({
    required String userId,
    required String ledgerId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getLedgerForUser(userId, ledgerId);
    final now = DateTime.now().toUtc();
    await (database.update(database.moneyLedgers)..where(
          (row) =>
              row.id.equals(ledgerId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyLedgersCompanion(
            name: Value(_remoteStringOr(fields, 'name', existing.name)),
            description: Value<String?>(
              _remoteNullableStringOr(
                fields,
                'description',
                existing.description,
              ),
            ),
            icon: Value<String?>(
              _remoteNullableStringOr(fields, 'icon', existing.icon),
            ),
            color: Value<String?>(
              _remoteNullableStringOr(fields, 'color', existing.color),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(
              _remoteDateTime(fields, 'updated_at', fallback: now),
            ),
          ),
        );
  }

  Future<void> _applyRemoteLedgerDelete({
    required String userId,
    required String ledgerId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneyLedgers)
              ..where(
                (row) => row.id.equals(ledgerId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyLedgers)..where(
          (row) =>
              row.id.equals(ledgerId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyLedgersCompanion(
            status: const Value('archived'),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteMemberChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteMemberInsert(
          userId: userId,
          memberId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteMemberUpdate(
          userId: userId,
          memberId: change.recordId,
          fields: change.changedFields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteMemberDelete(
          userId: userId,
          memberId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteMemberInsert({
    required String userId,
    required String memberId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneyMembers)
              ..where((row) => row.id.equals(memberId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final now = DateTime.now().toUtc();
    await database
        .into(database.moneyMembers)
        .insert(
          MoneyMembersCompanion.insert(
            id: memberId,
            userId: userId,
            name: _remoteString(fields, 'name'),
            role: _remoteStringOr(fields, 'role', 'participant'),
            status: _remoteStringOr(fields, 'status', 'active'),
            avatarUri: Value<String?>(
              _remoteNullableString(fields, 'avatar_uri'),
            ),
            color: Value<String?>(_remoteNullableString(fields, 'color')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
    final ledgerId = _remoteNullableString(fields, 'ledger_id');
    if (ledgerId != null) {
      await database
          .into(database.moneyLedgerMembers)
          .insert(
            MoneyLedgerMembersCompanion.insert(
              ledgerId: ledgerId,
              memberId: memberId,
              createdAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _applyRemoteMemberUpdate({
    required String userId,
    required String memberId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getMemberForUser(userId, memberId);
    final now = DateTime.now().toUtc();
    await (database.update(database.moneyMembers)..where(
          (row) =>
              row.id.equals(memberId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyMembersCompanion(
            name: Value(_remoteStringOr(fields, 'name', existing.name)),
            role: Value(_remoteStringOr(fields, 'role', existing.role)),
            color: Value<String?>(
              _remoteNullableStringOr(fields, 'color', existing.color),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(
              _remoteDateTime(fields, 'updated_at', fallback: now),
            ),
          ),
        );
    final ledgerId = _remoteNullableString(fields, 'ledger_id');
    if (ledgerId != null) {
      await database
          .into(database.moneyLedgerMembers)
          .insert(
            MoneyLedgerMembersCompanion.insert(
              ledgerId: ledgerId,
              memberId: memberId,
              createdAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }
  }

  Future<void> _applyRemoteMemberDelete({
    required String userId,
    required String memberId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneyMembers)
              ..where(
                (row) => row.id.equals(memberId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneyMembers)..where(
          (row) =>
              row.id.equals(memberId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyMembersCompanion(
            status: const Value('inactive'),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _applyRemoteLedgerAccountChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final ledgerId = _remoteString(fields, 'ledger_id');
    final accountId = _remoteString(fields, 'account_id');
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);
    await _getLedgerForUser(userId, ledgerId);
    await _getAccountForUser(userId, accountId);

    switch (change.operation) {
      case 'insert' || 'update':
        await database
            .into(database.moneyLedgerAccounts)
            .insert(
              MoneyLedgerAccountsCompanion.insert(
                ledgerId: ledgerId,
                accountId: accountId,
                createdAt: _remoteDateTime(
                  fields,
                  'created_at',
                  fallback: DateTime.now().toUtc(),
                ),
              ),
              mode: InsertMode.insertOrIgnore,
            );
      case 'delete':
        await (database.delete(database.moneyLedgerAccounts)..where(
              (row) =>
                  row.ledgerId.equals(ledgerId) &
                  row.accountId.equals(accountId),
            ))
            .go();
    }
  }

  Future<void> _applyRemoteSplitRecordChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert':
        await _applyRemoteSplitRecordInsert(
          userId: userId,
          splitRecordId: change.recordId,
          fields: fields,
          version: change.newVersion ?? 1,
        );
      case 'update':
        await _applyRemoteSplitRecordUpdate(
          userId: userId,
          splitRecordId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _applyRemoteSplitRecordDelete(
          userId: userId,
          splitRecordId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _applyRemoteSplitRecordInsert({
    required String userId,
    required String splitRecordId,
    required Map<String, Object?> fields,
    required int version,
  }) async {
    final existing =
        await (database.select(database.moneySplitRecords)
              ..where((row) => row.id.equals(splitRecordId))
              ..limit(1))
            .getSingleOrNull();
    if (existing != null) {
      return;
    }
    final now = DateTime.now().toUtc();
    final ledgerId = _remoteString(fields, 'ledger_id');
    await _getLedgerForUser(userId, ledgerId);
    final transactionId = _remoteNullableString(fields, 'transaction_id');
    if (transactionId != null) {
      await _getTransactionForUser(userId, transactionId);
      await _linkTransactionToLedgerUnchecked(
        ledgerId: ledgerId,
        transactionId: transactionId,
      );
    }
    await _getMemberForUser(userId, _remoteString(fields, 'payer_member_id'));

    await database
        .into(database.moneySplitRecords)
        .insert(
          MoneySplitRecordsCompanion.insert(
            id: splitRecordId,
            userId: userId,
            ledgerId: ledgerId,
            transactionId: Value<String?>(transactionId),
            splitRuleId: Value<String?>(
              _remoteNullableString(fields, 'split_rule_id'),
            ),
            status: _remoteStringOr(fields, 'status', 'active'),
            splitType: _remoteStringOr(fields, 'split_type', 'equal'),
            totalAmountMinor: _remoteInt(fields, 'total_amount_minor'),
            currencyCode: _remoteString(fields, 'currency_code'),
            payerMemberId: _remoteString(fields, 'payer_member_id'),
            notes: Value<String?>(_remoteNullableString(fields, 'notes')),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
    await _replaceRemoteSplitRecordDetails(
      userId: userId,
      splitRecordId: splitRecordId,
      details: _remoteObjectList(fields, 'details'),
      fallbackNow: now,
    );
  }

  Future<void> _applyRemoteSplitRecordUpdate({
    required String userId,
    required String splitRecordId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing = await _getSplitRecordForUser(userId, splitRecordId);
    final now = DateTime.now().toUtc();
    await (database.update(database.moneySplitRecords)..where(
          (row) =>
              row.id.equals(splitRecordId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneySplitRecordsCompanion(
            status: Value(_remoteStringOr(fields, 'status', existing.status)),
            notes: Value<String?>(
              _remoteNullableStringOr(fields, 'notes', existing.notes),
            ),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(
              _remoteDateTime(fields, 'updated_at', fallback: now),
            ),
          ),
        );
    if (fields.containsKey('details')) {
      await _replaceRemoteSplitRecordDetails(
        userId: userId,
        splitRecordId: splitRecordId,
        details: _remoteObjectList(fields, 'details'),
        fallbackNow: now,
      );
    }
  }

  Future<void> _applyRemoteSplitRecordDelete({
    required String userId,
    required String splitRecordId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final existing =
        await (database.select(database.moneySplitRecords)
              ..where(
                (row) =>
                    row.id.equals(splitRecordId) & row.userId.equals(userId),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null || existing.isDeleted) {
      return;
    }
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(database.moneySplitRecords)..where(
          (row) =>
              row.id.equals(splitRecordId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneySplitRecordsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            version: Value(version ?? existing.version + 1),
            updatedAt: Value(deletedAt),
          ),
        );
    await (database.update(database.moneySplitRecordDetails)..where(
          (row) =>
              row.splitRecordId.equals(splitRecordId) &
              row.userId.equals(userId) &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneySplitRecordDetailsCompanion(
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(deletedAt),
            updatedAt: Value(deletedAt),
          ),
        );
  }

  Future<void> _replaceRemoteSplitRecordDetails({
    required String userId,
    required String splitRecordId,
    required List<Map<String, Object?>> details,
    required DateTime fallbackNow,
  }) async {
    await (database.delete(database.moneySplitRecordDetails)..where(
          (row) =>
              row.splitRecordId.equals(splitRecordId) &
              row.userId.equals(userId),
        ))
        .go();
    for (final detail in details) {
      await _getMemberForUser(userId, _remoteString(detail, 'member_id'));
      await database
          .into(database.moneySplitRecordDetails)
          .insert(
            MoneySplitRecordDetailsCompanion.insert(
              id: _remoteString(detail, 'id'),
              userId: userId,
              splitRecordId: splitRecordId,
              memberId: _remoteString(detail, 'member_id'),
              amountMinor: _remoteInt(detail, 'amount_minor'),
              percentageBasisPoints: Value<int?>(
                _remoteNullableInt(detail, 'percentage_basis_points'),
              ),
              notes: Value<String?>(_remoteNullableString(detail, 'notes')),
              deviceId: Value<String?>(
                _remoteNullableString(detail, 'device_id'),
              ),
              version: Value(_remoteIntOr(detail, 'version', 1)),
              isDeleted: Value(
                _remoteBool(detail, 'is_deleted', fallback: false),
              ),
              deletedAt: Value<DateTime?>(
                _remoteNullableDateTime(detail, 'deleted_at'),
              ),
              createdAt: _remoteDateTime(
                detail,
                'created_at',
                fallback: fallbackNow,
              ),
              updatedAt: _remoteDateTime(
                detail,
                'updated_at',
                fallback: fallbackNow,
              ),
            ),
          );
    }
  }

  Future<void> _applyRemoteSplitRuleChange(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    final fields = <String, Object?>{
      ...change.recordSnapshot,
      ...change.changedFields,
    };
    final userId = _remoteUserId(fields, local);
    await ensureReadyForUser(userId);

    switch (change.operation) {
      case 'insert' || 'update':
        await _upsertRemoteSplitRule(
          userId: userId,
          ruleId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
      case 'delete':
        await _deleteRemoteSplitRule(
          userId: userId,
          ruleId: change.recordId,
          fields: fields,
          version: change.newVersion,
        );
    }
  }

  Future<void> _upsertRemoteSplitRule({
    required String userId,
    required String ruleId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final now = DateTime.now().toUtc();
    await _getLedgerForUser(userId, _remoteString(fields, 'ledger_id'));
    await database
        .into(database.moneySplitRules)
        .insertOnConflictUpdate(
          MoneySplitRulesCompanion.insert(
            id: ruleId,
            userId: userId,
            ledgerId: _remoteString(fields, 'ledger_id'),
            name: _remoteString(fields, 'name'),
            ruleType: _remoteString(fields, 'rule_type'),
            ruleConfigJson: _remoteString(fields, 'rule_config_json'),
            isActive: Value(_remoteBool(fields, 'is_active', fallback: true)),
            priority: Value(_remoteIntOr(fields, 'priority', 0)),
            deviceId: Value<String?>(
              _remoteNullableString(fields, 'device_id'),
            ),
            version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
            isDeleted: Value(
              _remoteBool(fields, 'is_deleted', fallback: false),
            ),
            deletedAt: Value<DateTime?>(
              _remoteNullableDateTime(fields, 'deleted_at'),
            ),
            createdAt: _remoteDateTime(fields, 'created_at', fallback: now),
            updatedAt: _remoteDateTime(fields, 'updated_at', fallback: now),
          ),
        );
  }

  Future<void> _deleteRemoteSplitRule({
    required String userId,
    required String ruleId,
    required Map<String, Object?> fields,
    required int? version,
  }) async {
    final deletedAt = _remoteDateTime(
      fields,
      'deleted_at',
      fallback: DateTime.now().toUtc(),
    );
    await (database.update(
      database.moneySplitRules,
    )..where((row) => row.id.equals(ruleId) & row.userId.equals(userId))).write(
      MoneySplitRulesCompanion(
        isActive: const Value(false),
        isDeleted: const Value(true),
        deletedAt: Value<DateTime?>(deletedAt),
        version: Value(version ?? _remoteIntOr(fields, 'version', 1)),
        updatedAt: Value(deletedAt),
      ),
    );
  }

  void _applyTransferDirection({
    required _MutableAccountLedger ledger,
    required String direction,
    required int amountMinor,
    required bool rollback,
  }) {
    switch (direction) {
      case _DriftMoneyRepositoryBase._transferOutMarker:
        if (rollback) {
          ledger.applyTransferOutgoingRollback(amountMinor);
        } else {
          ledger.applyTransferOutgoing(amountMinor);
        }
      case _DriftMoneyRepositoryBase._transferInMarker:
        if (rollback) {
          ledger.applyTransferIncomingRollback(amountMinor);
        } else {
          ledger.applyTransferIncoming(amountMinor);
        }
      default:
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransferAccounts,
        );
    }
  }

  Future<void> _assertRemoteTransactionCategory(
    String userId,
    MoneyTransactionType type,
    Map<String, Object?> fields,
  ) async {
    final expectedKind = type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
    final categoryId = _remoteString(fields, 'category_id');
    await _assertCategoryForUser(userId, categoryId, expectedKind);
    final subCategoryId = _remoteNullableString(fields, 'sub_category_id');
    if (subCategoryId != null) {
      await _assertSubCategoryForUser(
        userId,
        categoryId,
        subCategoryId,
        expectedKind,
      );
    }
  }

  MoneyTransactionType? _remoteOrdinaryTransactionType(
    Map<String, Object?> fields,
  ) {
    final type = MoneyTransactionType.fromStorageValue(
      _remoteString(fields, 'type'),
    );
    if (type == MoneyTransactionType.transfer) {
      return null;
    }
    return type;
  }

  MoneyTransactionStatus _remoteTransactionStatus(
    Map<String, Object?> fields, {
    required MoneyTransactionStatus? fallback,
  }) {
    final value = fields['status'];
    if (value == null) {
      if (fallback != null) {
        return fallback;
      }
      return MoneyTransactionStatus.completed;
    }
    return MoneyTransactionStatus.fromStorageValue(value.toString());
  }

  MoneyPaymentMethod _remotePaymentMethod(Map<String, Object?> fields) {
    return MoneyPaymentMethod.fromStorageValue(
      _remoteString(fields, 'payment_method'),
    );
  }

  String _remoteUserId(Map<String, Object?> fields, DeltaLocalRecord? local) {
    final value = fields['user_id'] ?? local?.snapshot['user_id'];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw const MoneyRepositoryException(
      MoneyRepositoryErrorCode.databaseWriteFailed,
    );
  }

  String _remoteString(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    throw MoneyRepositoryException(
      MoneyRepositoryErrorCode.databaseWriteFailed,
      'Missing remote field: $key',
    );
  }

  String _remoteStringOr(
    Map<String, Object?> fields,
    String key,
    String fallback,
  ) {
    final value = fields[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    return fallback;
  }

  String? _remoteNullableString(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value == null) {
      return null;
    }
    final stringValue = value.toString();
    return stringValue.isEmpty ? null : stringValue;
  }

  String? _remoteNullableStringOr(
    Map<String, Object?> fields,
    String key,
    String? fallback,
  ) {
    if (!fields.containsKey(key)) {
      return fallback;
    }
    return _remoteNullableString(fields, key);
  }

  int _remoteInt(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    throw MoneyRepositoryException(
      MoneyRepositoryErrorCode.databaseWriteFailed,
      'Missing remote field: $key',
    );
  }

  int _remoteIntOr(Map<String, Object?> fields, String key, int fallback) {
    if (!fields.containsKey(key)) {
      return fallback;
    }
    final value = fields[key];
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  int? _remoteNullableInt(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value.toString());
  }

  int? _remoteNullableIntOr(
    Map<String, Object?> fields,
    String key,
    int? fallback,
  ) {
    if (!fields.containsKey(key)) {
      return fallback;
    }
    return _remoteNullableInt(fields, key);
  }

  bool _remoteBool(
    Map<String, Object?> fields,
    String key, {
    required bool fallback,
  }) {
    if (!fields.containsKey(key)) {
      return fallback;
    }
    final value = fields[key];
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return fallback;
  }

  bool _remoteBoolOr(Map<String, Object?> fields, String key, bool fallback) {
    return _remoteBool(fields, key, fallback: fallback);
  }

  DateTime _remoteDateTime(
    Map<String, Object?> fields,
    String key, {
    DateTime? fallback,
  }) {
    final value = fields[key];
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed.toUtc();
      }
    }
    if (fallback != null) {
      return fallback.toUtc();
    }
    throw MoneyRepositoryException(
      MoneyRepositoryErrorCode.databaseWriteFailed,
      'Missing remote field: $key',
    );
  }

  DateTime? _remoteNullableDateTime(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }
    return null;
  }

  List<String> _remoteStringList(Map<String, Object?> fields, String key) {
    final value = fields[key];
    if (value is List) {
      return value.map((item) => item.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  List<Map<String, Object?>> _remoteObjectList(
    Map<String, Object?> fields,
    String key,
  ) {
    final value = fields[key];
    if (value is! List) {
      return const <Map<String, Object?>>[];
    }
    return value
        .whereType<Map>()
        .map(
          (item) => item.map(
            (key, value) => MapEntry(key.toString(), value as Object?),
          ),
        )
        .toList(growable: false);
  }

  Future<List<String>> _remoteLedgerIds(
    String userId,
    Map<String, Object?> fields,
  ) async {
    final ledgerIds = _remoteStringList(fields, 'ledger_ids')
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (ledgerIds.isEmpty) {
      return _resolveTransactionLedgerIds(userId, null);
    }
    for (final ledgerId in ledgerIds) {
      await _getLedgerForUser(userId, ledgerId);
    }
    return ledgerIds;
  }

  Future<void> _replaceTransactionLedgerLinks({
    required String transactionId,
    required List<String> ledgerIds,
  }) async {
    await (database.delete(
      database.moneyLedgerTransactions,
    )..where((row) => row.transactionId.equals(transactionId))).go();
    await _linkTransactionToLedgersUnchecked(
      ledgerIds: ledgerIds,
      transactionId: transactionId,
    );
  }
}
