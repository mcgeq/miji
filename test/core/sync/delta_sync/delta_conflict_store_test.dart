import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';

void main() {
  late AppDatabase database;
  late DriftDeltaConflictStore store;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    store = DriftDeltaConflictStore(
      database: database,
      now: () => DateTime.utc(2026, 7, 11, 12),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('saves and lists unresolved delta conflicts for a user', () async {
    await store.saveConflict(
      userId: 'user-1',
      datasetId: 'dataset-1',
      deviceId: 'device-1',
      localSnapshotJson: '{"amount_minor":900,"notes":"local"}',
      conflict: _conflict(),
    );

    final conflicts = await store.listOpenConflicts('user-1');

    expect(conflicts, hasLength(1));
    expect(conflicts.single.datasetId, 'dataset-1');
    expect(conflicts.single.userId, 'user-1');
    expect(conflicts.single.tableName, 'money_transactions');
    expect(conflicts.single.recordId, 'tx-1');
    expect(conflicts.single.fieldGroups, {
      TransactionConflictFieldGroup.basic,
      TransactionConflictFieldGroup.text,
    });
    expect(conflicts.single.localSnapshot['notes'], 'local');
    expect(conflicts.single.remoteChange.changedFields['notes'], 'remote');
  });

  test('resolved conflicts are not returned as open conflicts', () async {
    await store.saveConflict(
      userId: 'user-1',
      datasetId: 'dataset-1',
      deviceId: 'device-1',
      localSnapshotJson: '{"amount_minor":900,"notes":"local"}',
      conflict: _conflict(),
    );
    final conflict = (await store.listOpenConflicts('user-1')).single;

    await store.markResolved(
      id: conflict.id,
      resolution: DeltaConflictResolution.remote,
      deviceId: 'device-1',
    );

    expect(await store.listOpenConflicts('user-1'), isEmpty);
  });
}

DeltaDetectedConflict _conflict() {
  return const DeltaDetectedConflict(
    table: 'money_transactions',
    recordId: 'tx-1',
    localRecord: DeltaLocalRecord(
      table: 'money_transactions',
      recordId: 'tx-1',
      version: 2,
      snapshot: {'amount_minor': 900, 'notes': 'local'},
    ),
    remoteChange: DeltaChangeRecord(
      table: 'money_transactions',
      recordId: 'tx-1',
      operation: 'update',
      baseVersion: 1,
      newVersion: 2,
      changedFields: {'amount_minor': 1200, 'notes': 'remote'},
      recordSnapshot: {'amount_minor': 1200, 'notes': 'remote'},
    ),
    fieldGroups: {
      TransactionConflictFieldGroup.basic,
      TransactionConflictFieldGroup.text,
    },
  );
}
