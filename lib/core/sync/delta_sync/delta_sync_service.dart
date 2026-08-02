import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_store.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_applier.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';

class DeltaSyncResult {
  const DeltaSyncResult({
    required this.uploadedChanges,
    required this.uploadedPackages,
    this.downloadedPackages = 0,
    this.appliedRemoteChanges = 0,
    this.remoteConflicts = 0,
  });

  final int uploadedChanges;
  final int uploadedPackages;
  final int downloadedPackages;
  final int appliedRemoteChanges;
  final int remoteConflicts;

  bool get hasChanges => uploadedChanges > 0;

  static const empty = DeltaSyncResult(uploadedChanges: 0, uploadedPackages: 0);
}

typedef WebDavConfigReader = Future<WebDavConfig> Function();

class DeltaSyncService {
  DeltaSyncService({
    required this.database,
    required this.identityResolver,
    required this.packageStore,
    required this.readConfig,
    this.conflictStore,
    this.readLocalRecord,
    this.applyRemoteChange,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase database;
  final SyncIdentityResolver identityResolver;
  final DeltaPackageStore packageStore;
  final WebDavConfigReader readConfig;
  final DeltaConflictStore? conflictStore;
  final DeltaLocalRecordReader? readLocalRecord;
  final DeltaRemoteChangeApplier? applyRemoteChange;
  final DateTime Function() _now;
  Future<DeltaSyncResult>? _runningSync;

  Future<DeltaSyncResult> syncNow(String password) {
    final running = _runningSync;
    if (running != null) {
      return running;
    }

    final future = _syncNow(password);
    _runningSync = future;
    return future.whenComplete(() {
      if (identical(_runningSync, future)) {
        _runningSync = null;
      }
    });
  }

  Future<DeltaSyncResult> _syncNow(String password) async {
    final identity = await identityResolver.readIdentity();
    final config = await readConfig();
    final pullResult = await _pullRemotePackages(
      config: config,
      password: password,
      identity: identity,
    );

    final pendingChanges =
        await (database.select(database.syncChangeLogs)
              ..where((row) => row.syncedAt.isNull())
              ..orderBy([(row) => OrderingTerm.asc(row.changedAt)]))
            .get();
    if (pendingChanges.isEmpty) {
      return DeltaSyncResult(
        uploadedChanges: 0,
        uploadedPackages: 0,
        downloadedPackages: pullResult.downloadedPackages,
        appliedRemoteChanges: pullResult.appliedRemoteChanges,
        remoteConflicts: pullResult.remoteConflicts,
      );
    }

    final createdAt = _now().toUtc();
    final package = DeltaPackage(
      metadata: DeltaPackageMetadata(
        datasetId: identity.datasetId,
        deviceId: identity.deviceId,
        sequence: createdAt.microsecondsSinceEpoch,
        createdAt: createdAt,
      ),
      payload: DeltaPackagePayload(
        changes: await Future.wait(pendingChanges.map(_changeRecordFromRow)),
      ),
    );

    await packageStore.upload(
      config: config,
      password: password,
      package: package,
    );

    await (database.update(database.syncChangeLogs)
          ..where((row) => row.id.isIn(pendingChanges.map((row) => row.id))))
        .write(SyncChangeLogsCompanion(syncedAt: Value(createdAt)));

    return DeltaSyncResult(
      uploadedChanges: pendingChanges.length,
      uploadedPackages: 1,
      downloadedPackages: pullResult.downloadedPackages,
      appliedRemoteChanges: pullResult.appliedRemoteChanges,
      remoteConflicts: pullResult.remoteConflicts,
    );
  }

  Future<_DeltaPullResult> _pullRemotePackages({
    required WebDavConfig config,
    required String password,
    required SyncIdentity identity,
  }) async {
    final remotePackages = await packageStore.listRemotePackages(
      config: config,
      datasetId: identity.datasetId,
      localDeviceId: identity.deviceId,
    );
    if (remotePackages.isEmpty) {
      return const _DeltaPullResult.empty();
    }

    var downloadedPackages = 0;
    var appliedRemoteChanges = 0;
    var remoteConflicts = 0;

    for (final remotePackage in remotePackages) {
      final cursor = await _readRemoteCursor(remotePackage.deviceId);
      if (remotePackage.sequence <= cursor) {
        continue;
      }

      final package = await packageStore.download(
        config: config,
        password: password,
        remotePackage: remotePackage,
      );
      downloadedPackages += 1;

      final applier = DeltaSyncApplier(
        readLocalRecord: readLocalRecord ?? _readLocalRecordFromDatabase,
        applyRemoteChange: applyRemoteChange ?? _recordRemoteChangeApplied,
        writeConflict: (conflict) => _writeConflict(
          conflict: conflict,
          identity: identity,
          remoteDeviceId: remotePackage.deviceId,
        ),
      );
      final applyResult = await applier.applyRemotePackage(package);
      appliedRemoteChanges += applyResult.appliedCount;
      remoteConflicts += applyResult.conflictCount;

      await _writeRemoteCursor(remotePackage.deviceId, remotePackage.sequence);
    }

    return _DeltaPullResult(
      downloadedPackages: downloadedPackages,
      appliedRemoteChanges: appliedRemoteChanges,
      remoteConflicts: remoteConflicts,
    );
  }

  Future<DeltaChangeRecord> _changeRecordFromRow(SyncChangeLog row) async {
    final changedFields = _decodeJsonObject(row.changedFieldsJson);
    final recordSnapshot = await _recordSnapshotForRow(row, changedFields);
    return DeltaChangeRecord(
      table: row.targetTable,
      recordId: row.recordId,
      operation: row.operation,
      baseVersion: row.beforeVersion,
      newVersion: row.afterVersion,
      changedFields: changedFields,
      recordSnapshot: recordSnapshot,
    );
  }

  Future<Map<String, Object?>> _recordSnapshotForRow(
    SyncChangeLog row,
    Map<String, Object?> changedFields,
  ) async {
    if (_isSupportedMoneyTable(row.targetTable)) {
      final local = await _readLocalRecordFromDatabase(
        DeltaChangeRecord(
          table: row.targetTable,
          recordId: row.recordId,
          operation: row.operation,
          baseVersion: row.beforeVersion,
          newVersion: row.afterVersion,
          changedFields: changedFields,
          recordSnapshot: const <String, Object?>{},
        ),
      );
      if (local != null) {
        return local.snapshot;
      }
    }

    return <String, Object?>{
      'id': row.recordId,
      'user_id': row.userId,
      ...changedFields,
    };
  }

  Future<DeltaLocalRecord?> _readLocalRecordFromDatabase(
    DeltaChangeRecord change,
  ) async {
    switch (change.table) {
      case SyncChangeLogger.moneyTransactionsTableName:
        return _readLocalTransactionRecord(change);
      case SyncChangeLogger.moneyAccountsTableName:
        return _readLocalAccountRecord(change);
      case SyncChangeLogger.moneyBudgetsTableName:
        return _readLocalBudgetRecord(change);
      case SyncChangeLogger.moneyBudgetSnapshotsTableName:
        return _readLocalBudgetSnapshotRecord(change);
      case SyncChangeLogger.moneyBudgetAllocationSnapshotsTableName:
        return _readLocalBudgetAllocationSnapshotRecord(change);
      case SyncChangeLogger.moneyCategoriesTableName:
        return _readLocalCategoryRecord(change);
      case SyncChangeLogger.moneySubCategoriesTableName:
        return _readLocalSubCategoryRecord(change);
      case SyncChangeLogger.moneyLedgersTableName:
        return _readLocalLedgerRecord(change);
      case SyncChangeLogger.moneyMembersTableName:
        return _readLocalMemberRecord(change);
      case SyncChangeLogger.moneySplitRecordsTableName:
        return _readLocalSplitRecord(change);
      case SyncChangeLogger.moneyInstallmentPlansTableName:
        return _readLocalInstallmentPlanRecord(change);
      case SyncChangeLogger.moneyBudgetAllocationsTableName:
        return _readLocalBudgetAllocationRecord(change);
      case SyncChangeLogger.moneySplitRulesTableName:
        return _readLocalSplitRuleRecord(change);
      case SyncChangeLogger.moneyLedgerAccountsTableName:
        return _readLocalLedgerAccountRecord(change);
      case SyncChangeLogger.moneyBillRemindersTableName:
        return _readLocalBillReminderRecord(change);
      // V1.1: Todo tables
      case SyncChangeLogger.todoTasksTableName:
        return _readLocalTodoTaskRecord(change);
      case SyncChangeLogger.todoTagsTableName:
        return _readLocalTodoTagRecord(change);
      case SyncChangeLogger.todoRecurrenceRulesTableName:
        return _readLocalTodoRecurrenceRuleRecord(change);
    }
    return null;
  }

  Future<DeltaLocalRecord?> _readLocalTransactionRecord(
    DeltaChangeRecord change,
  ) async {
    final transaction = await (database.select(
      database.moneyTransactions,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (transaction == null) {
      return null;
    }
    final tags = await (database.select(
      database.moneyTransactionTags,
    )..where((row) => row.transactionId.equals(transaction.id))).get();
    final ledgerLinks = await (database.select(
      database.moneyLedgerTransactions,
    )..where((row) => row.transactionId.equals(transaction.id))).get();
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: transaction.version,
      snapshot: {
        'id': transaction.id,
        'user_id': transaction.userId,
        'type': transaction.type,
        'status': transaction.status,
        'transaction_at': transaction.transactionAt.toUtc().toIso8601String(),
        'amount_minor': transaction.amountMinor,
        'currency_code': transaction.currencyCode,
        'description': transaction.description,
        'notes': transaction.notes,
        'merchant': transaction.merchant,
        'location': transaction.location,
        'account_id': transaction.accountId,
        'to_account_id': transaction.toAccountId,
        'category_id': transaction.categoryId,
        'sub_category_id': transaction.subCategoryId,
        'payment_method': transaction.paymentMethod,
        'custom_payment_method_name': transaction.customPaymentMethodName,
        'actual_payer_account': transaction.actualPayerAccount,
        'related_transaction_id': transaction.relatedTransactionId,
        'installment_plan_id': transaction.installmentPlanId,
        'interest_rate_basis_points': transaction.interestRateBasisPoints,
        'total_interest_minor': transaction.totalInterestMinor,
        'calc_method': transaction.calcMethod,
        'tags': tags.map((row) => row.tag).toList(growable: false),
        'ledger_ids': ledgerLinks
            .map((row) => row.ledgerId)
            .toList(growable: false),
        'is_deleted': transaction.isDeleted,
        'deleted_at': transaction.deletedAt?.toUtc().toIso8601String(),
        'created_at': transaction.createdAt.toUtc().toIso8601String(),
        'updated_at': transaction.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalAccountRecord(
    DeltaChangeRecord change,
  ) async {
    final account = await (database.select(
      database.moneyAccounts,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (account == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: account.version,
      snapshot: {
        'id': account.id,
        'user_id': account.userId,
        'name': account.name,
        'description': account.description,
        'type': account.type,
        'balance_minor': account.balanceMinor,
        'initial_balance_minor': account.initialBalanceMinor,
        'credit_limit_minor': account.creditLimitMinor,
        'posted_debt_minor': account.postedDebtMinor,
        'frozen_credit_minor': account.frozenCreditMinor,
        'statement_day': account.statementDay,
        'budget_cycle_start_day': account.budgetCycleStartDay,
        'repayment_day': account.repaymentDay,
        'currency_code': account.currencyCode,
        'is_shared': account.isShared,
        'is_virtual': account.isVirtual,
        'owner_member_id': account.ownerMemberId,
        'color': account.color,
        'icon': account.icon,
        'is_active': account.isActive,
        'device_id': account.deviceId,
        'version': account.version,
        'is_deleted': account.isDeleted,
        'deleted_at': account.deletedAt?.toUtc().toIso8601String(),
        'created_at': account.createdAt.toUtc().toIso8601String(),
        'updated_at': account.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalBudgetRecord(
    DeltaChangeRecord change,
  ) async {
    final budget = await (database.select(
      database.moneyBudgets,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (budget == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: budget.version,
      snapshot: {
        'id': budget.id,
        'user_id': budget.userId,
        'account_id': budget.accountId,
        'ledger_id': budget.ledgerId,
        'created_by_member_id': budget.createdByMemberId,
        'name': budget.name,
        'description': budget.description,
        'amount_minor': budget.amountMinor,
        'currency_code': budget.currencyCode,
        'repeat_period_type': budget.repeatPeriodType,
        'repeat_interval': budget.repeatInterval,
        'repeat_days': budget.repeatDays,
        'start_date': budget.startDate,
        'end_date': budget.endDate,
        'used_amount_minor': budget.usedAmountMinor,
        'is_active': budget.isActive,
        'alert_enabled': budget.alertEnabled,
        'alert_threshold_percent': budget.alertThresholdPercent,
        'color': budget.color,
        'current_period_used_minor': budget.currentPeriodUsedMinor,
        'current_period_start_date': budget.currentPeriodStartDate,
        'last_reset_at': budget.lastResetAt.toUtc().toIso8601String(),
        'budget_type': budget.budgetType,
        'tracking_type': budget.trackingType,
        'progress_minor': budget.progressMinor,
        'linked_goal': budget.linkedGoal,
        'priority': budget.priority,
        'auto_rollover': budget.autoRollover,
        'scope_type': budget.scopeType,
        'account_scope_json': budget.accountScopeJson,
        'category_scope_json': budget.categoryScopeJson,
        'advanced_rules_json': budget.advancedRulesJson,
        'tags_json': budget.tagsJson,
        'device_id': budget.deviceId,
        'version': budget.version,
        'is_deleted': budget.isDeleted,
        'deleted_at': budget.deletedAt?.toUtc().toIso8601String(),
        'created_at': budget.createdAt.toUtc().toIso8601String(),
        'updated_at': budget.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalBudgetSnapshotRecord(
    DeltaChangeRecord change,
  ) async {
    final snapshot = await (database.select(
      database.moneyBudgetSnapshots,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (snapshot == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: snapshot.sourceBudgetVersion,
      snapshot: {
        'id': snapshot.id,
        'user_id': snapshot.userId,
        'budget_id': snapshot.budgetId,
        'ledger_id': snapshot.ledgerId,
        'tracking_type': snapshot.trackingType,
        'period_type': snapshot.periodType,
        'repeat_interval': snapshot.repeatInterval,
        'period_start_date': snapshot.periodStartDate,
        'period_end_date': snapshot.periodEndDate,
        'budget_amount_minor': snapshot.budgetAmountMinor,
        'used_amount_minor': snapshot.usedAmountMinor,
        'remaining_amount_minor': snapshot.remainingAmountMinor,
        'currency_code': snapshot.currencyCode,
        'status': snapshot.status,
        'captured_at': snapshot.capturedAt.toUtc().toIso8601String(),
        'source_budget_version': snapshot.sourceBudgetVersion,
        'created_at': snapshot.createdAt.toUtc().toIso8601String(),
        'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalBudgetAllocationSnapshotRecord(
    DeltaChangeRecord change,
  ) async {
    final snapshot = await (database.select(
      database.moneyBudgetAllocationSnapshots,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (snapshot == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: snapshot.sourceAllocationVersion,
      snapshot: {
        'id': snapshot.id,
        'user_id': snapshot.userId,
        'budget_snapshot_id': snapshot.budgetSnapshotId,
        'budget_id': snapshot.budgetId,
        'allocation_id': snapshot.allocationId,
        'category_id': snapshot.categoryId,
        'member_id': snapshot.memberId,
        'allocated_amount_minor': snapshot.allocatedAmountMinor,
        'used_amount_minor': snapshot.usedAmountMinor,
        'remaining_amount_minor': snapshot.remainingAmountMinor,
        'currency_code': snapshot.currencyCode,
        'status': snapshot.status,
        'captured_at': snapshot.capturedAt.toUtc().toIso8601String(),
        'source_allocation_version': snapshot.sourceAllocationVersion,
        'created_at': snapshot.createdAt.toUtc().toIso8601String(),
        'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalLedgerRecord(
    DeltaChangeRecord change,
  ) async {
    final ledger = await (database.select(
      database.moneyLedgers,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (ledger == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: ledger.version,
      snapshot: {
        'id': ledger.id,
        'user_id': ledger.userId,
        'name': ledger.name,
        'description': ledger.description,
        'created_by_member_id': ledger.createdByMemberId,
        'ledger_type': ledger.ledgerType,
        'status': ledger.status,
        'base_currency_code': ledger.baseCurrencyCode,
        'settlement_cycle': ledger.settlementCycle,
        'settlement_day': ledger.settlementDay,
        'icon': ledger.icon,
        'color': ledger.color,
        'device_id': ledger.deviceId,
        'version': ledger.version,
        'is_deleted': ledger.isDeleted,
        'deleted_at': ledger.deletedAt?.toUtc().toIso8601String(),
        'created_at': ledger.createdAt.toUtc().toIso8601String(),
        'updated_at': ledger.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalMemberRecord(
    DeltaChangeRecord change,
  ) async {
    final member = await (database.select(
      database.moneyMembers,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (member == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: member.version,
      snapshot: {
        'id': member.id,
        'user_id': member.userId,
        'name': member.name,
        'role': member.role,
        'status': member.status,
        'avatar_uri': member.avatarUri,
        'color': member.color,
        'device_id': member.deviceId,
        'version': member.version,
        'is_deleted': member.isDeleted,
        'deleted_at': member.deletedAt?.toUtc().toIso8601String(),
        'created_at': member.createdAt.toUtc().toIso8601String(),
        'updated_at': member.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalSplitRecord(
    DeltaChangeRecord change,
  ) async {
    final record = await (database.select(
      database.moneySplitRecords,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (record == null) {
      return null;
    }
    final details =
        await (database.select(database.moneySplitRecordDetails)
              ..where((row) => row.splitRecordId.equals(record.id))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: record.version,
      snapshot: {
        'id': record.id,
        'user_id': record.userId,
        'ledger_id': record.ledgerId,
        'transaction_id': record.transactionId,
        'split_rule_id': record.splitRuleId,
        'status': record.status,
        'split_type': record.splitType,
        'total_amount_minor': record.totalAmountMinor,
        'currency_code': record.currencyCode,
        'payer_member_id': record.payerMemberId,
        'notes': record.notes,
        'device_id': record.deviceId,
        'version': record.version,
        'is_deleted': record.isDeleted,
        'deleted_at': record.deletedAt?.toUtc().toIso8601String(),
        'created_at': record.createdAt.toUtc().toIso8601String(),
        'updated_at': record.updatedAt.toUtc().toIso8601String(),
        'details': details
            .map(
              (detail) => {
                'id': detail.id,
                'user_id': detail.userId,
                'split_record_id': detail.splitRecordId,
                'member_id': detail.memberId,
                'amount_minor': detail.amountMinor,
                'percentage_basis_points': detail.percentageBasisPoints,
                'notes': detail.notes,
                'device_id': detail.deviceId,
                'version': detail.version,
                'is_deleted': detail.isDeleted,
                'deleted_at': detail.deletedAt?.toUtc().toIso8601String(),
                'created_at': detail.createdAt.toUtc().toIso8601String(),
                'updated_at': detail.updatedAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalInstallmentPlanRecord(
    DeltaChangeRecord change,
  ) async {
    final plan = await (database.select(
      database.moneyInstallmentPlans,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (plan == null) {
      return null;
    }
    final details =
        await (database.select(database.moneyInstallmentDetails)
              ..where((row) => row.planId.equals(plan.id))
              ..orderBy([(row) => OrderingTerm.asc(row.periodNumber)]))
            .get();
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: plan.version,
      snapshot: {
        'id': plan.id,
        'user_id': plan.userId,
        'account_id': plan.accountId,
        'transaction_id': plan.transactionId,
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
        'device_id': plan.deviceId,
        'version': plan.version,
        'is_deleted': plan.isDeleted,
        'deleted_at': plan.deletedAt?.toUtc().toIso8601String(),
        'created_at': plan.createdAt.toUtc().toIso8601String(),
        'updated_at': plan.updatedAt.toUtc().toIso8601String(),
        'details': details
            .map(
              (detail) => {
                'id': detail.id,
                'user_id': detail.userId,
                'plan_id': detail.planId,
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
                'device_id': detail.deviceId,
                'version': detail.version,
                'is_deleted': detail.isDeleted,
                'deleted_at': detail.deletedAt?.toUtc().toIso8601String(),
                'created_at': detail.createdAt.toUtc().toIso8601String(),
                'updated_at': detail.updatedAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalBudgetAllocationRecord(
    DeltaChangeRecord change,
  ) async {
    final allocation = await (database.select(
      database.moneyBudgetAllocations,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (allocation == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: allocation.version,
      snapshot: {
        'id': allocation.id,
        'user_id': allocation.userId,
        'budget_id': allocation.budgetId,
        'category_id': allocation.categoryId,
        'member_id': allocation.memberId,
        'allocated_amount_minor': allocation.allocatedAmountMinor,
        'used_amount_minor': allocation.usedAmountMinor,
        'remaining_amount_minor': allocation.remainingAmountMinor,
        'percentage_basis_points': allocation.percentageBasisPoints,
        'allocation_type': allocation.allocationType,
        'rule_config_json': allocation.ruleConfigJson,
        'allow_overspend': allocation.allowOverspend,
        'overspend_limit_type': allocation.overspendLimitType,
        'overspend_limit_minor': allocation.overspendLimitMinor,
        'alert_enabled': allocation.alertEnabled,
        'alert_threshold_percent': allocation.alertThresholdPercent,
        'alert_config_json': allocation.alertConfigJson,
        'priority': allocation.priority,
        'is_mandatory': allocation.isMandatory,
        'status': allocation.status,
        'notes': allocation.notes,
        'device_id': allocation.deviceId,
        'version': allocation.version,
        'is_deleted': allocation.isDeleted,
        'deleted_at': allocation.deletedAt?.toUtc().toIso8601String(),
        'created_at': allocation.createdAt.toUtc().toIso8601String(),
        'updated_at': allocation.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalSplitRuleRecord(
    DeltaChangeRecord change,
  ) async {
    final rule = await (database.select(
      database.moneySplitRules,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (rule == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: rule.version,
      snapshot: {
        'id': rule.id,
        'user_id': rule.userId,
        'ledger_id': rule.ledgerId,
        'name': rule.name,
        'rule_type': rule.ruleType,
        'rule_config_json': rule.ruleConfigJson,
        'is_active': rule.isActive,
        'priority': rule.priority,
        'device_id': rule.deviceId,
        'version': rule.version,
        'is_deleted': rule.isDeleted,
        'deleted_at': rule.deletedAt?.toUtc().toIso8601String(),
        'created_at': rule.createdAt.toUtc().toIso8601String(),
        'updated_at': rule.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalBillReminderRecord(
    DeltaChangeRecord change,
  ) async {
    final reminder = await (database.select(
      database.moneyBillReminders,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (reminder == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: reminder.version,
      snapshot: {
        'id': reminder.id,
        'user_id': reminder.userId,
        'name': reminder.name,
        'amount_minor': reminder.amountMinor,
        'currency_code': reminder.currencyCode,
        'due_date': reminder.dueDate,
        'remind_before_days': reminder.remindBeforeDays,
        'repeat_period_type': reminder.repeatPeriodType,
        'repeat_interval': reminder.repeatInterval,
        'account_id': reminder.accountId,
        'ledger_id': reminder.ledgerId,
        'category_id': reminder.categoryId,
        'related_transaction_id': reminder.relatedTransactionId,
        'status': reminder.status,
        'notes': reminder.notes,
        'device_id': reminder.deviceId,
        'version': reminder.version,
        'is_deleted': reminder.isDeleted,
        'deleted_at': reminder.deletedAt?.toUtc().toIso8601String(),
        'created_at': reminder.createdAt.toUtc().toIso8601String(),
        'updated_at': reminder.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalCategoryRecord(
    DeltaChangeRecord change,
  ) async {
    final category = await (database.select(
      database.moneyCategories,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (category == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: category.version,
      snapshot: {
        'id': category.id,
        'user_id': category.userId,
        'name': category.name,
        'kind': category.kind,
        'color': category.color,
        'icon': category.icon,
        'is_system': category.isSystem,
        'device_id': category.deviceId,
        'version': category.version,
        'is_deleted': category.isDeleted,
        'deleted_at': category.deletedAt?.toUtc().toIso8601String(),
        'created_at': category.createdAt.toUtc().toIso8601String(),
        'updated_at': category.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalSubCategoryRecord(
    DeltaChangeRecord change,
  ) async {
    final subCategory = await (database.select(
      database.moneySubCategories,
    )..where((row) => row.id.equals(change.recordId))).getSingleOrNull();
    if (subCategory == null) {
      return null;
    }
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: subCategory.version,
      snapshot: {
        'id': subCategory.id,
        'category_id': subCategory.categoryId,
        'user_id': subCategory.userId,
        'name': subCategory.name,
        'kind': subCategory.kind,
        'color': subCategory.color,
        'icon': subCategory.icon,
        'is_system': subCategory.isSystem,
        'device_id': subCategory.deviceId,
        'version': subCategory.version,
        'is_deleted': subCategory.isDeleted,
        'deleted_at': subCategory.deletedAt?.toUtc().toIso8601String(),
        'created_at': subCategory.createdAt.toUtc().toIso8601String(),
        'updated_at': subCategory.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalLedgerAccountRecord(
    DeltaChangeRecord change,
  ) async {
    final ids = _ledgerAccountIdsFromChange(change);
    if (ids == null) {
      return null;
    }
    final relation =
        await (database.select(database.moneyLedgerAccounts)..where(
              (row) =>
                  row.ledgerId.equals(ids.ledgerId) &
                  row.accountId.equals(ids.accountId),
            ))
            .getSingleOrNull();
    if (relation == null) {
      return null;
    }
    final ledger = await (database.select(
      database.moneyLedgers,
    )..where((row) => row.id.equals(relation.ledgerId))).getSingleOrNull();
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: 1,
      snapshot: {
        'id': change.recordId,
        'user_id': ledger?.userId,
        'ledger_id': relation.ledgerId,
        'account_id': relation.accountId,
        'created_at': relation.createdAt.toUtc().toIso8601String(),
      },
    );
  }

  ({String ledgerId, String accountId})? _ledgerAccountIdsFromChange(
    DeltaChangeRecord change,
  ) {
    final ledgerId =
        change.changedFields['ledger_id'] ?? change.recordSnapshot['ledger_id'];
    final accountId =
        change.changedFields['account_id'] ??
        change.recordSnapshot['account_id'];
    if (ledgerId is String &&
        ledgerId.isNotEmpty &&
        accountId is String &&
        accountId.isNotEmpty) {
      return (ledgerId: ledgerId, accountId: accountId);
    }

    final parts = change.recordId.split('::');
    if (parts.length == 2 && parts.first.isNotEmpty && parts.last.isNotEmpty) {
      return (ledgerId: parts.first, accountId: parts.last);
    }
    return null;
  }

  // ---- V1.1: Todo reader methods ----

  Future<DeltaLocalRecord?> _readLocalTodoTaskRecord(
    DeltaChangeRecord change,
  ) async {
    final row = await (database.select(
      database.todoTasks,
    )..where((r) => r.id.equals(change.recordId))).getSingleOrNull();
    if (row == null) return null;
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: row.version,
      snapshot: {
        'id': row.id,
        'user_id': row.userId,
        'title': row.title,
        'notes': row.notes,
        'status': row.status,
        'priority': row.priority,
        'scheduled_date': row.scheduledDate,
        'due_at': row.dueAt?.toUtc().toIso8601String(),
        'category_id': row.categoryId,
        'parent_task_id': row.parentTaskId,
        'sort_order': row.sortOrder,
        'is_recurrence_template': row.isRecurrenceTemplate,
        'recurrence_rule_id': row.recurrenceRuleId,
        'occurrence_date': row.occurrenceDate,
        'reminder_at': row.reminderAt?.toUtc().toIso8601String(),
        'device_id': row.deviceId,
        'version': row.version,
        'is_deleted': row.isDeleted,
        'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalTodoTagRecord(
    DeltaChangeRecord change,
  ) async {
    final row = await (database.select(
      database.todoTags,
    )..where((r) => r.id.equals(change.recordId))).getSingleOrNull();
    if (row == null) return null;
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: row.version,
      snapshot: {
        'id': row.id,
        'user_id': row.userId,
        'name': row.name,
        'color': row.color,
        'device_id': row.deviceId,
        'version': row.version,
        'is_deleted': row.isDeleted,
        'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<DeltaLocalRecord?> _readLocalTodoRecurrenceRuleRecord(
    DeltaChangeRecord change,
  ) async {
    final row = await (database.select(
      database.todoRecurrenceRules,
    )..where((r) => r.id.equals(change.recordId))).getSingleOrNull();
    if (row == null) return null;
    return DeltaLocalRecord(
      table: change.table,
      recordId: change.recordId,
      version: row.version,
      snapshot: {
        'id': row.id,
        'user_id': row.userId,
        'template_task_id': row.templateTaskId,
        'frequency_type': row.frequencyType,
        'interval': row.interval_,
        'days_of_week_json': row.daysOfWeekJson,
        'day_of_month': row.dayOfMonth,
        'month_of_year': row.monthOfYear,
        'day_of_year': row.dayOfYear,
        'ends_at': row.endsAt?.toUtc().toIso8601String(),
        'reminder_mode': row.reminderMode,
        'reminder_config_json': row.reminderConfigJson,
        'device_id': row.deviceId,
        'version': row.version,
        'is_deleted': row.isDeleted,
        'deleted_at': row.deletedAt?.toUtc().toIso8601String(),
        'created_at': row.createdAt.toUtc().toIso8601String(),
        'updated_at': row.updatedAt.toUtc().toIso8601String(),
      },
    );
  }

  bool _isSupportedMoneyTable(String tableName) {
    return switch (tableName) {
      SyncChangeLogger.moneyTransactionsTableName ||
      SyncChangeLogger.moneyAccountsTableName ||
      SyncChangeLogger.moneyBudgetsTableName ||
      SyncChangeLogger.moneyBudgetSnapshotsTableName ||
      SyncChangeLogger.moneyBudgetAllocationSnapshotsTableName ||
      SyncChangeLogger.moneyCategoriesTableName ||
      SyncChangeLogger.moneySubCategoriesTableName ||
      SyncChangeLogger.moneyLedgersTableName ||
      SyncChangeLogger.moneyMembersTableName ||
      SyncChangeLogger.moneySplitRecordsTableName ||
      SyncChangeLogger.moneyInstallmentPlansTableName ||
      SyncChangeLogger.moneyBudgetAllocationsTableName ||
      SyncChangeLogger.moneySplitRulesTableName ||
      SyncChangeLogger.moneyLedgerAccountsTableName ||
      SyncChangeLogger.moneyBillRemindersTableName ||
      SyncChangeLogger.todoTasksTableName ||
      SyncChangeLogger.todoTagsTableName ||
      SyncChangeLogger.todoRecurrenceRulesTableName => true,
      _ => false,
    };
  }

  Future<void> _recordRemoteChangeApplied(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) async {
    // Applying money changes must go through bookkeeping repository logic so
    // account balances stay correct. Until that path is wired, non-conflicting
    // remote changes are only acknowledged by cursor advancement.
  }

  Future<void> _writeConflict({
    required DeltaDetectedConflict conflict,
    required SyncIdentity identity,
    required String remoteDeviceId,
  }) async {
    final userId = _userIdForConflict(conflict);
    if (userId == null || userId.isEmpty) {
      return;
    }
    await (conflictStore ?? DriftDeltaConflictStore(database: database))
        .saveConflict(
          userId: userId,
          datasetId: identity.datasetId,
          conflict: conflict,
          localSnapshotJson: jsonEncode(conflict.localRecord?.snapshot ?? {}),
          deviceId: remoteDeviceId,
          createdAt: _now().toUtc(),
        );
  }

  String? _userIdForConflict(DeltaDetectedConflict conflict) {
    final localUserId = conflict.localRecord?.snapshot['user_id'];
    if (localUserId is String && localUserId.isNotEmpty) {
      return localUserId;
    }
    final remoteUserId = conflict.remoteChange.recordSnapshot['user_id'];
    if (remoteUserId is String && remoteUserId.isNotEmpty) {
      return remoteUserId;
    }
    final changedUserId = conflict.remoteChange.changedFields['user_id'];
    if (changedUserId is String && changedUserId.isNotEmpty) {
      return changedUserId;
    }
    return null;
  }

  Future<int> _readRemoteCursor(String deviceId) async {
    final row =
        await (database.select(database.syncMetadata)
              ..where((table) => table.key.equals(_remoteCursorKey(deviceId))))
            .getSingleOrNull();
    return int.tryParse(row?.value ?? '') ?? 0;
  }

  Future<void> _writeRemoteCursor(String deviceId, int sequence) async {
    await database
        .into(database.syncMetadata)
        .insert(
          SyncMetadataCompanion.insert(
            key: _remoteCursorKey(deviceId),
            value: sequence.toString(),
            updatedAt: _now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
  }

  String _remoteCursorKey(String deviceId) {
    return 'sync.delta.remoteCursor.$deviceId';
  }

  Map<String, Object?> _decodeJsonObject(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return const <String, Object?>{};
    }
    return decoded.map((key, value) {
      if (key is! String) {
        return const MapEntry('', null);
      }
      return MapEntry(key, value as Object?);
    })..remove('');
  }
}

class _DeltaPullResult {
  const _DeltaPullResult({
    required this.downloadedPackages,
    required this.appliedRemoteChanges,
    required this.remoteConflicts,
  });

  const _DeltaPullResult.empty()
    : downloadedPackages = 0,
      appliedRemoteChanges = 0,
      remoteConflicts = 0;

  final int downloadedPackages;
  final int appliedRemoteChanges;
  final int remoteConflicts;
}
