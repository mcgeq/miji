import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';

enum SyncChangeOperation {
  insert,
  update,
  delete;

  String get storageValue {
    return switch (this) {
      SyncChangeOperation.insert => 'insert',
      SyncChangeOperation.update => 'update',
      SyncChangeOperation.delete => 'delete',
    };
  }
}

class SyncChangeLogger {
  SyncChangeLogger({
    required this.database,
    required this.identityResolver,
    String Function()? createId,
    DateTime Function()? now,
  }) : _createId = createId ?? const Uuid().v4,
       _now = now ?? (() => DateTime.now().toUtc());

  static const moneyTransactionsTableName = 'money_transactions';
  static const moneyAccountsTableName = 'money_accounts';
  static const moneyBudgetsTableName = 'money_budgets';
  static const moneyBudgetSnapshotsTableName = 'money_budget_snapshots';
  static const moneyBudgetAllocationSnapshotsTableName =
      'money_budget_allocation_snapshots';
  static const moneyCategoriesTableName = 'money_categories';
  static const moneySubCategoriesTableName = 'money_sub_categories';
  static const moneyLedgersTableName = 'money_ledgers';
  static const moneyMembersTableName = 'money_members';
  static const moneySplitRecordsTableName = 'money_split_records';
  static const moneyInstallmentPlansTableName = 'money_installment_plans';
  static const moneyBudgetAllocationsTableName = 'money_budget_allocations';
  static const moneySplitRulesTableName = 'money_split_rules';
  static const moneyLedgerAccountsTableName = 'money_ledger_accounts';
  static const moneyBillRemindersTableName = 'money_bill_reminders';
  static const moneyAutoPostingTemplatesTableName =
      'money_auto_posting_templates';
  static const moneyAutoPostingRunsTableName = 'money_auto_posting_runs';

  // Checkin tables
  static const checkinPlansTableName = 'checkin_plans';
  static const checkinRecordsTableName = 'checkin_records';
  static const checkinPhotosTableName = 'checkin_photos';

  // Todo tables (V1.1)
  static const todoTasksTableName = 'todo_tasks';
  static const todoTagsTableName = 'todo_tags';
  static const todoRecurrenceRulesTableName = 'todo_recurrence_rules';

  final AppDatabase database;
  final SyncIdentityResolver identityResolver;
  final String Function() _createId;
  final DateTime Function() _now;

  Future<void> recordTransactionChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyTransactionsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordAccountChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyAccountsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordCategoryChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyCategoriesTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordSubCategoryChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneySubCategoriesTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordBudgetChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyBudgetsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordBudgetSnapshotChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyBudgetSnapshotsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordBudgetAllocationSnapshotChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyBudgetAllocationSnapshotsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordLedgerChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyLedgersTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordMemberChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyMembersTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordSplitRecordChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneySplitRecordsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordInstallmentPlanChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyInstallmentPlansTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordBudgetAllocationChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyBudgetAllocationsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordSplitRuleChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneySplitRulesTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordLedgerAccountChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyLedgerAccountsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordBillReminderChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyBillRemindersTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordAutoPostingTemplateChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyAutoPostingTemplatesTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordAutoPostingRunChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: moneyAutoPostingRunsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordCheckinPlanChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: checkinPlansTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordCheckinRecordChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: checkinRecordsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordCheckinPhotoChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: checkinPhotosTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  // ---- Todo (V1.1) ----

  Future<void> recordTodoTaskChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: todoTasksTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordTodoTagChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: todoTagsTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordTodoRecurrenceRuleChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    await recordChange(
      userId: userId,
      tableName: todoRecurrenceRulesTableName,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> recordChange({
    required String userId,
    required String tableName,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final identity = await identityResolver.readIdentity();
    await database
        .into(database.syncChangeLogs)
        .insert(
          SyncChangeLogsCompanion.insert(
            id: _createId(),
            datasetId: identity.datasetId,
            userId: userId,
            targetTable: tableName,
            recordId: recordId,
            operation: operation.storageValue,
            changedFieldsJson: jsonEncode(changedFields),
            beforeVersion: Value<int?>(beforeVersion),
            afterVersion: Value<int?>(afterVersion),
            deviceId: Value<String?>(identity.deviceId),
            changedAt: _now(),
          ),
        );
  }
}
