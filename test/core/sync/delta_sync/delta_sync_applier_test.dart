import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_applier.dart';

void main() {
  test('divergent transaction edits create field-group conflict', () async {
    final conflicts = <DeltaDetectedConflict>[];
    final applier = DeltaSyncApplier(
      readLocalRecord: (change) async => const DeltaLocalRecord(
        table: 'money_transactions',
        recordId: 'tx-1',
        version: 2,
        snapshot: {'amount_minor': 900, 'notes': 'local'},
      ),
      applyRemoteChange: (change, local) async {},
      writeConflict: (conflict) async => conflicts.add(conflict),
    );

    final result = await applier.applyRemotePackage(_remotePackage());

    expect(result.appliedCount, 0);
    expect(result.conflictCount, 1);
    expect(conflicts, hasLength(1));
    expect(conflicts.single.recordId, 'tx-1');
    expect(conflicts.single.fieldGroups, {
      TransactionConflictFieldGroup.basic,
      TransactionConflictFieldGroup.text,
    });
  });
}

DeltaPackage _remotePackage() {
  return DeltaPackage(
    metadata: DeltaPackageMetadata(
      datasetId: 'dataset-a',
      deviceId: 'device-b',
      sequence: 7,
      createdAt: DateTime.utc(2026, 7, 11, 10),
    ),
    payload: const DeltaPackagePayload(
      changes: [
        DeltaChangeRecord(
          table: 'money_transactions',
          recordId: 'tx-1',
          operation: 'update',
          baseVersion: 1,
          newVersion: 2,
          changedFields: {'amount_minor': 1200, 'notes': 'remote'},
          recordSnapshot: {'amount_minor': 1200, 'notes': 'remote'},
        ),
      ],
    ),
  );
}
