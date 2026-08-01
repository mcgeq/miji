part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Installments on _DriftMoneyRepositoryBase {
  @override
  Stream<List<MoneyInstallmentPlanEntity>> watchInstallmentPlansForUser(
    String userId, {
    String? ledgerId,
  }) async* {
    await ensureReadyForUser(userId);
    final resolvedLedgerId = ledgerId == null
        ? null
        : await _resolveLedgerId(userId, ledgerId);

    final query = database.select(database.moneyInstallmentPlans)
      ..where(
        (plan) =>
            plan.userId.equals(userId) &
            plan.isDeleted.equals(false) &
            (resolvedLedgerId == null
                ? const Constant(true)
                : _installmentLedgerPredicate(plan, resolvedLedgerId, userId)),
      )
      ..orderBy([
        (plan) => OrderingTerm.desc(plan.createdAt),
        (plan) => OrderingTerm.desc(plan.updatedAt),
      ]);

    yield* query.watch().map((rows) => rows.map(_mapInstallmentPlan).toList());
  }

  @override
  Future<void> repairInstallmentPlanStatuses(
    String userId, {
    String? ledgerId,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = ledgerId == null
          ? null
          : await _resolveLedgerId(userId, ledgerId);

      await database.transaction(() async {
        final query = database.select(database.moneyInstallmentPlans)
          ..where(
            (plan) =>
                plan.userId.equals(userId) &
                plan.isDeleted.equals(false) &
                (resolvedLedgerId == null
                    ? const Constant(true)
                    : _installmentLedgerPredicate(
                        plan,
                        resolvedLedgerId,
                        userId,
                      )),
          );
        final plans = await query.get();

        for (final plan in plans) {
          final currentStatus = MoneyInstallmentPlanStatus.fromStorageValue(
            plan.status,
          );
          if (currentStatus == MoneyInstallmentPlanStatus.cancelled) {
            continue;
          }

          final progress = await _installmentPlanProgress(userId, plan.id);
          final desiredStatus = progress.allPosted
              ? MoneyInstallmentPlanStatus.completed
              : MoneyInstallmentPlanStatus.active;
          final desiredRemaining = progress.pendingCount
              .clamp(0, plan.totalPeriods)
              .toInt();
          if (plan.status == desiredStatus.storageValue &&
              plan.remainingPeriods == desiredRemaining) {
            continue;
          }

          final now = _utcNow();
          await (database.update(database.moneyInstallmentPlans)..where(
                (row) =>
                    row.id.equals(plan.id) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              ))
              .write(
                MoneyInstallmentPlansCompanion(
                  remainingPeriods: Value(desiredRemaining),
                  status: Value(desiredStatus.storageValue),
                  version: Value(plan.version + 1),
                  updatedAt: Value(now),
                ),
              );

          final updatedPlan = await _getInstallmentPlanForUser(userId, plan.id);
          await _recordInstallmentPlanChange(
            userId: userId,
            recordId: plan.id,
            operation: SyncChangeOperation.update,
            changedFields: await _installmentPlanSyncFields(updatedPlan),
            beforeVersion: plan.version,
            afterVersion: updatedPlan.version,
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
  Stream<List<MoneyInstallmentDetailEntity>> watchInstallmentDetailsForPlan(
    String userId,
    String planId,
  ) async* {
    await ensureReadyForUser(userId);

    final query = database.select(database.moneyInstallmentDetails)
      ..where(
        (detail) =>
            detail.userId.equals(userId) &
            detail.planId.equals(planId) &
            detail.isDeleted.equals(false),
      )
      ..orderBy([(detail) => OrderingTerm.asc(detail.periodNumber)]);

    yield* query.watch().map(
      (rows) => rows.map(_mapInstallmentDetail).toList(),
    );
  }

  @override
  Future<MoneyInstallmentPlanEntity> createInstallmentPlan(
    String userId,
    MoneyInstallmentPlanDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateInstallmentDraft(draft);

      return await database.transaction(() async {
        final ledgerId = await _resolveLedgerId(userId, draft.ledgerId);
        final account = await _getWritableAccountForUser(
          userId,
          draft.accountId,
        );
        final accountType = MoneyAccountType.fromStorageValue(account.type);
        if (!accountType.isCreditLike) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidInstallmentAccount,
          );
        }
        await _assertCategoryForUser(
          userId,
          draft.categoryId,
          MoneyCategoryKind.expense,
        );
        if (draft.subCategoryId != null) {
          await _assertSubCategoryForUser(
            userId,
            draft.categoryId,
            draft.subCategoryId!,
            MoneyCategoryKind.expense,
          );
        }

        final ledger = _MutableAccountLedger.fromAccount(account)
          ..freezeCredit(draft.totalPrincipalMinor)
          ..validate();

        final now = DateTime.now().toUtc();
        final planId = _uuid.v4();
        final principalParts = _splitMinorAmount(
          draft.totalPrincipalMinor,
          draft.totalPeriods,
        );
        final interestParts = _splitMinorAmount(
          draft.totalInterestMinor,
          draft.totalPeriods,
        );
        final firstDueDate = _dateOnly(draft.firstDueDate);
        final endDate = _addMonths(firstDueDate, draft.totalPeriods - 1);
        final totalPayableMinor =
            draft.totalPrincipalMinor + draft.totalInterestMinor;

        await database
            .into(database.moneyInstallmentPlans)
            .insert(
              MoneyInstallmentPlansCompanion.insert(
                id: planId,
                userId: userId,
                accountId: draft.accountId,
                transactionId: const Value<String?>(null),
                ledgerId: Value<String?>(ledgerId),
                name: draft.name.trim(),
                description: Value<String?>(_blankToNull(draft.description)),
                categoryId: draft.categoryId,
                subCategoryId: Value<String?>(draft.subCategoryId),
                totalAmountMinor: draft.totalPrincipalMinor,
                totalPeriods: draft.totalPeriods,
                remainingPeriods: draft.totalPeriods,
                periodAmountMinor:
                    (totalPayableMinor + draft.totalPeriods - 1) ~/
                    draft.totalPeriods,
                currencyCode: draft.currencyCode,
                startDate: _dateKey(firstDueDate),
                endDate: _dateKey(endDate),
                firstDueDate: _dateKey(firstDueDate),
                status: MoneyInstallmentPlanStatus.active.storageValue,
                interestRateBasisPoints: const Value<int?>(null),
                totalInterestMinor: Value<int?>(draft.totalInterestMinor),
                calcMethod: const Value<String?>('flat'),
                notes: Value<String?>(_blankToNull(draft.notes)),
                createdAt: now,
                updatedAt: now,
              ),
            );

        for (var index = 0; index < draft.totalPeriods; index += 1) {
          final principalMinor = principalParts[index];
          final interestMinor = interestParts[index];
          await database
              .into(database.moneyInstallmentDetails)
              .insert(
                MoneyInstallmentDetailsCompanion.insert(
                  id: _uuid.v4(),
                  userId: userId,
                  planId: planId,
                  accountId: draft.accountId,
                  periodNumber: index + 1,
                  amountMinor: principalMinor + interestMinor,
                  principalMinor: principalMinor,
                  interestMinor: interestMinor,
                  dueDate: _dateKey(_addMonths(firstDueDate, index)),
                  paidDate: const Value<int?>(null),
                  status: MoneyInstallmentDetailStatus.pending.storageValue,
                  transactionId: const Value<String?>(null),
                  notes: const Value<String?>(null),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        await _updateAccountLedger(userId, account.id, ledger, now);
        final plan = await _getInstallmentPlanForUser(userId, planId);
        await _recordInstallmentPlanChange(
          userId: userId,
          recordId: planId,
          operation: SyncChangeOperation.insert,
          changedFields: await _installmentPlanSyncFields(plan),
          afterVersion: plan.version,
        );
        return _mapInstallmentPlan(plan);
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
  Future<void> cancelInstallmentPlan(String userId, String planId) async {
    try {
      await ensureReadyForUser(userId);

      await database.transaction(() async {
        final plan = await _getInstallmentPlanForUser(userId, planId);
        if (MoneyInstallmentPlanStatus.fromStorageValue(plan.status) !=
            MoneyInstallmentPlanStatus.active) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.installmentPlanNotFound,
          );
        }

        final pendingDetails =
            await (database.select(database.moneyInstallmentDetails)..where(
                  (detail) =>
                      detail.userId.equals(userId) &
                      detail.planId.equals(planId) &
                      detail.status.equals(
                        MoneyInstallmentDetailStatus.pending.storageValue,
                      ) &
                      detail.isDeleted.equals(false),
                ))
                .get();
        final releasePrincipalMinor = pendingDetails.fold<int>(
          0,
          (sum, detail) => sum + detail.principalMinor,
        );
        final account = await _getAccountForUser(userId, plan.accountId);
        final ledger = _MutableAccountLedger.fromAccount(account)
          ..releaseFrozenCredit(releasePrincipalMinor)
          ..validate();

        final now = DateTime.now().toUtc();
        await _updateAccountLedger(userId, account.id, ledger, now);
        await (database.update(database.moneyInstallmentPlans)..where(
              (row) =>
                  row.id.equals(planId) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyInstallmentPlansCompanion(
                status: Value(
                  MoneyInstallmentPlanStatus.cancelled.storageValue,
                ),
                remainingPeriods: const Value(0),
                version: Value(plan.version + 1),
                updatedAt: Value(now),
              ),
            );
        await (database.update(database.moneyInstallmentDetails)..where(
              (detail) =>
                  detail.userId.equals(userId) &
                  detail.planId.equals(planId) &
                  detail.status.equals(
                    MoneyInstallmentDetailStatus.pending.storageValue,
                  ) &
                  detail.isDeleted.equals(false),
            ))
            .write(
              MoneyInstallmentDetailsCompanion(
                status: Value(
                  MoneyInstallmentDetailStatus.skipped.storageValue,
                ),
                updatedAt: Value(now),
              ),
            );
        final updatedPlan = await _getInstallmentPlanForUser(userId, planId);
        await _recordInstallmentPlanChange(
          userId: userId,
          recordId: planId,
          operation: SyncChangeOperation.update,
          changedFields: await _installmentPlanSyncFields(updatedPlan),
          beforeVersion: plan.version,
          afterVersion: updatedPlan.version,
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
  Future<MoneyTransactionEntity> postInstallmentDetail(
    String userId,
    String detailId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      late List<String> ledgerIds;
      final transaction = await database.transaction(() async {
        final detail = await _getInstallmentDetailForUser(userId, detailId);
        if (MoneyInstallmentDetailStatus.fromStorageValue(detail.status) !=
            MoneyInstallmentDetailStatus.pending) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidInstallmentStatus,
          );
        }

        final plan = await _getInstallmentPlanForUser(userId, detail.planId);
        if (MoneyInstallmentPlanStatus.fromStorageValue(plan.status) !=
            MoneyInstallmentPlanStatus.active) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidInstallmentStatus,
          );
        }

        final account = await _getWritableAccountForUser(
          userId,
          detail.accountId,
        );
        final ledger = _MutableAccountLedger.fromAccount(account)
          ..postInstallmentExpense(
            principalMinor: detail.principalMinor,
            amountMinor: detail.amountMinor,
          )
          ..validate();

        final now = _utcNow();
        final transactionId = _uuid.v4();
        final transactionAt = _dateFromKey(detail.dueDate);
        final description = '${plan.name} 第${detail.periodNumber}期';
        final accountType = MoneyAccountType.fromStorageValue(account.type);
        await database
            .into(database.moneyTransactions)
            .insert(
              MoneyTransactionsCompanion.insert(
                id: transactionId,
                userId: userId,
                type: MoneyTransactionType.expense.storageValue,
                status: MoneyTransactionStatus.completed.storageValue,
                transactionAt: transactionAt,
                amountMinor: detail.amountMinor,
                currencyCode: plan.currencyCode,
                description: description,
                notes: Value<String?>(_blankToNull(detail.notes ?? plan.notes)),
                accountId: detail.accountId,
                categoryId: plan.categoryId,
                subCategoryId: Value<String?>(plan.subCategoryId),
                paymentMethod: _paymentMethodForAccountType(
                  accountType,
                ).storageValue,
                actualPayerAccount: 'installment',
                installmentPlanId: Value<String?>(plan.id),
                totalInterestMinor: Value(detail.interestMinor),
                calcMethod: Value<String?>(plan.calcMethod),
                createdAt: now,
                updatedAt: now,
              ),
            );

        ledgerIds = await _resolveTransactionLedgerIds(userId, plan.ledgerId);
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: transactionId,
        );
        await _updateAccountLedger(userId, account.id, ledger, now);
        await (database.update(database.moneyInstallmentDetails)..where(
              (row) =>
                  row.id.equals(detail.id) &
                  row.userId.equals(userId) &
                  row.status.equals(
                    MoneyInstallmentDetailStatus.pending.storageValue,
                  ) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyInstallmentDetailsCompanion(
                status: Value(MoneyInstallmentDetailStatus.posted.storageValue),
                paidDate: Value(_dateKey(transactionAt)),
                transactionId: Value<String?>(transactionId),
                updatedAt: Value(now),
              ),
            );

        final progress = await _installmentPlanProgress(userId, plan.id);
        final remainingPeriods = progress.pendingCount
            .clamp(0, plan.totalPeriods)
            .toInt();
        await (database.update(database.moneyInstallmentPlans)..where(
              (row) =>
                  row.id.equals(plan.id) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .write(
              MoneyInstallmentPlansCompanion(
                remainingPeriods: Value(remainingPeriods),
                status: Value(
                  progress.allPosted
                      ? MoneyInstallmentPlanStatus.completed.storageValue
                      : MoneyInstallmentPlanStatus.active.storageValue,
                ),
                version: Value(plan.version + 1),
                updatedAt: Value(now),
              ),
            );

        final updatedPlan = await _getInstallmentPlanForUser(userId, plan.id);
        await _recordInstallmentPlanChange(
          userId: userId,
          recordId: plan.id,
          operation: SyncChangeOperation.update,
          changedFields: await _installmentPlanSyncFields(updatedPlan),
          beforeVersion: plan.version,
          afterVersion: updatedPlan.version,
        );

        return _mapTransaction(
          await _getTransactionForUser(userId, transactionId),
          tags: const <String>[],
        );
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

  Future<void> _recordInstallmentPlanChange({
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

    await logger.recordInstallmentPlanChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<Map<String, Object?>> _installmentPlanSyncFields(
    MoneyInstallmentPlan plan,
  ) async {
    final details =
        await (database.select(database.moneyInstallmentDetails)
              ..where((row) => row.planId.equals(plan.id))
              ..orderBy([(row) => OrderingTerm.asc(row.periodNumber)]))
            .get();
    return {
      'account_id': plan.accountId,
      'transaction_id': plan.transactionId,
      'ledger_id': plan.ledgerId ?? _defaultLedgerId(plan.userId),
      'name': plan.name,
      'description': plan.description,
      'category_id': plan.categoryId,
      'sub_category_id': plan.subCategoryId,
      'total_amount_minor': plan.totalAmountMinor,
      'total_periods': plan.totalPeriods,
      'remaining_periods': plan.remainingPeriods,
      'period_amount_minor': plan.periodAmountMinor,
      'currency_code': plan.currencyCode,
      'start_date': plan.startDate,
      'end_date': plan.endDate,
      'first_due_date': plan.firstDueDate,
      'status': plan.status,
      'interest_rate_basis_points': plan.interestRateBasisPoints,
      'total_interest_minor': plan.totalInterestMinor,
      'calc_method': plan.calcMethod,
      'notes': plan.notes,
      'details': details
          .map(
            (detail) => {
              'id': detail.id,
              'account_id': detail.accountId,
              'period_number': detail.periodNumber,
              'amount_minor': detail.amountMinor,
              'principal_minor': detail.principalMinor,
              'interest_minor': detail.interestMinor,
              'due_date': detail.dueDate,
              'paid_date': detail.paidDate,
              'status': detail.status,
              'transaction_id': detail.transactionId,
              'notes': detail.notes,
            },
          )
          .toList(growable: false),
    };
  }

  Future<MoneyInstallmentDetail> _getInstallmentDetailForUser(
    String userId,
    String detailId,
  ) async {
    final detail =
        await (database.select(database.moneyInstallmentDetails)
              ..where(
                (row) =>
                    row.id.equals(detailId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (detail == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.installmentPlanNotFound,
      );
    }

    return detail;
  }
}
