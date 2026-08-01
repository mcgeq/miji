import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('records transaction change with sync identity metadata', () async {
    final changedAt = DateTime.utc(2026, 7, 11, 8);
    final logger = SyncChangeLogger(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      createId: () => 'change-1',
      now: () => changedAt,
    );

    await logger.recordTransactionChange(
      userId: 'user-1',
      recordId: 'tx-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'amount_minor': 1200, 'notes': 'dinner'},
      beforeVersion: 1,
      afterVersion: 2,
    );

    final rows = await database.select(database.syncChangeLogs).get();
    expect(rows, hasLength(1));

    final row = rows.single;
    expect(row.id, 'change-1');
    expect(row.datasetId, 'dataset-a');
    expect(row.deviceId, 'device-a');
    expect(row.userId, 'user-1');
    expect(row.targetTable, 'money_transactions');
    expect(row.recordId, 'tx-1');
    expect(row.operation, 'update');
    expect(row.beforeVersion, 1);
    expect(row.afterVersion, 2);
    expect(row.changedAt.toUtc(), changedAt);
    expect(jsonDecode(row.changedFieldsJson), {
      'amount_minor': 1200,
      'notes': 'dinner',
    });
  });

  test('records money base entity changes with table names', () async {
    var nextId = 0;
    final logger = SyncChangeLogger(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      createId: () => 'change-${nextId += 1}',
      now: () => DateTime.utc(2026, 7, 11, 8),
    );

    await logger.recordAccountChange(
      userId: 'user-1',
      recordId: 'account-1',
      operation: SyncChangeOperation.insert,
      changedFields: const {'name': 'Cash'},
      afterVersion: 1,
    );
    await logger.recordCategoryChange(
      userId: 'user-1',
      recordId: 'category-1',
      operation: SyncChangeOperation.insert,
      changedFields: const {'name': 'Pet'},
      afterVersion: 1,
    );
    await logger.recordSubCategoryChange(
      userId: 'user-1',
      recordId: 'sub-category-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'name': 'Cat food'},
      beforeVersion: 1,
      afterVersion: 2,
    );
    await logger.recordBudgetChange(
      userId: 'user-1',
      recordId: 'budget-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'amount_minor': 50000},
      beforeVersion: 1,
      afterVersion: 2,
    );
    await logger.recordLedgerChange(
      userId: 'user-1',
      recordId: 'ledger-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'name': 'Family'},
      beforeVersion: 1,
      afterVersion: 2,
    );
    await logger.recordMemberChange(
      userId: 'user-1',
      recordId: 'member-1',
      operation: SyncChangeOperation.delete,
      changedFields: const {'is_deleted': true},
      beforeVersion: 2,
      afterVersion: 3,
    );
    await logger.recordInstallmentPlanChange(
      userId: 'user-1',
      recordId: 'installment-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'remaining_periods': 2},
      beforeVersion: 1,
      afterVersion: 2,
    );
    await logger.recordBudgetAllocationChange(
      userId: 'user-1',
      recordId: 'allocation-1',
      operation: SyncChangeOperation.insert,
      changedFields: const {'allocated_amount_minor': 20000},
      afterVersion: 1,
    );
    await logger.recordSplitRuleChange(
      userId: 'user-1',
      recordId: 'split-rule-1',
      operation: SyncChangeOperation.update,
      changedFields: const {'name': 'AA'},
      beforeVersion: 1,
      afterVersion: 2,
    );
    await logger.recordLedgerAccountChange(
      userId: 'user-1',
      recordId: 'ledger-1::account-1',
      operation: SyncChangeOperation.insert,
      changedFields: const {'ledger_id': 'ledger-1', 'account_id': 'account-1'},
    );

    final rows = await database.select(database.syncChangeLogs).get();

    expect(rows.map((row) => row.targetTable), [
      'money_accounts',
      'money_categories',
      'money_sub_categories',
      'money_budgets',
      'money_ledgers',
      'money_members',
      'money_installment_plans',
      'money_budget_allocations',
      'money_split_rules',
      'money_ledger_accounts',
    ]);
  });
}
