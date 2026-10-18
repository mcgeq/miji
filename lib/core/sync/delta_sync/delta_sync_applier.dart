import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';

typedef DeltaLocalRecordReader =
    Future<DeltaLocalRecord?> Function(DeltaChangeRecord change);

typedef DeltaRemoteChangeApplier =
    Future<void> Function(DeltaChangeRecord change, DeltaLocalRecord? local);

typedef DeltaConflictWriter =
    Future<void> Function(DeltaDetectedConflict conflict);

class DeltaSyncApplier {
  const DeltaSyncApplier({
    required this.readLocalRecord,
    required this.applyRemoteChange,
    required this.writeConflict,
    this.transactionFieldClassifier =
        const TransactionConflictFieldClassifier(),
  });

  final DeltaLocalRecordReader readLocalRecord;
  final DeltaRemoteChangeApplier applyRemoteChange;
  final DeltaConflictWriter writeConflict;
  final TransactionConflictFieldClassifier transactionFieldClassifier;

  Future<DeltaApplyResult> applyRemotePackage(DeltaPackage package) async {
    var appliedCount = 0;
    var conflictCount = 0;
    var skippedCount = 0;

    for (final change in package.payload.changes) {
      final local = await readLocalRecord(change);
      if (_hasConflict(change, local)) {
        await writeConflict(_conflictFor(change, local));
        conflictCount += 1;
        continue;
      }

      if (local == null &&
          change.operation != SyncChangeOperation.insert.storageValue) {
        skippedCount += 1;
        continue;
      }

      await applyRemoteChange(change, local);
      appliedCount += 1;
    }

    return DeltaApplyResult(
      appliedCount: appliedCount,
      conflictCount: conflictCount,
      skippedCount: skippedCount,
    );
  }

  bool _hasConflict(DeltaChangeRecord change, DeltaLocalRecord? local) {
    if (local == null) {
      return false;
    }
    if ((change.table == SyncChangeLogger.moneyBudgetSnapshotsTableName ||
            change.table ==
                SyncChangeLogger.moneyBudgetAllocationSnapshotsTableName) &&
        change.operation == SyncChangeOperation.insert.storageValue) {
      final remoteVersion = change.newVersion;
      return remoteVersion != null && local.version != remoteVersion;
    }
    final baseVersion = change.baseVersion;
    if (baseVersion == null) {
      return true;
    }
    return local.version != baseVersion;
  }

  DeltaDetectedConflict _conflictFor(
    DeltaChangeRecord change,
    DeltaLocalRecord? local,
  ) {
    return DeltaDetectedConflict(
      table: change.table,
      recordId: change.recordId,
      localRecord: local,
      remoteChange: change,
      fieldGroups: _fieldGroupsFor(change),
    );
  }

  Set<TransactionConflictFieldGroup> _fieldGroupsFor(DeltaChangeRecord change) {
    if (change.table != SyncChangeLogger.moneyTransactionsTableName) {
      return const <TransactionConflictFieldGroup>{
        TransactionConflictFieldGroup.record,
      };
    }
    return transactionFieldClassifier.classify(change.changedFields.keys);
  }
}
