import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';

enum DeltaConflictResolution { local, remote, merged }

class StoredDeltaConflict {
  const StoredDeltaConflict({
    required this.id,
    required this.datasetId,
    required this.userId,
    required this.tableName,
    required this.recordId,
    required this.fieldGroups,
    required this.localSnapshot,
    required this.remoteChange,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.resolution,
    this.resolvedByDeviceId,
  });

  final String id;
  final String datasetId;
  final String userId;
  final String tableName;
  final String recordId;
  final Set<TransactionConflictFieldGroup> fieldGroups;
  final Map<String, Object?> localSnapshot;
  final DeltaChangeRecord remoteChange;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DeltaConflictResolution? resolution;
  final String? resolvedByDeviceId;

  bool get isResolved => resolvedAt != null;
}

abstract class DeltaConflictStore {
  Future<List<StoredDeltaConflict>> listOpenConflicts(String userId);

  Future<void> saveConflict({
    required String userId,
    required String datasetId,
    required DeltaDetectedConflict conflict,
    required String localSnapshotJson,
    required String deviceId,
    DateTime? createdAt,
  });

  Future<void> markResolved({
    required String id,
    required DeltaConflictResolution resolution,
    required String deviceId,
    DateTime? resolvedAt,
  });
}

class DriftDeltaConflictStore implements DeltaConflictStore {
  DriftDeltaConflictStore({
    required this.database,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? (() => DateTime.now().toUtc());

  final AppDatabase database;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<List<StoredDeltaConflict>> listOpenConflicts(String userId) async {
    final rows =
        await (database.select(database.deltaConflicts)
              ..where(
                (row) => row.userId.equals(userId) & row.resolvedAt.isNull(),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    return rows.map(_mapRow).toList(growable: false);
  }

  @override
  Future<void> saveConflict({
    required String userId,
    required String datasetId,
    required DeltaDetectedConflict conflict,
    required String localSnapshotJson,
    required String deviceId,
    DateTime? createdAt,
  }) async {
    final now = (createdAt ?? _now()).toUtc();
    await database
        .into(database.deltaConflicts)
        .insert(
          DeltaConflictsCompanion.insert(
            id: _uuid.v4(),
            datasetId: datasetId,
            userId: userId,
            targetTable: conflict.table,
            recordId: conflict.recordId,
            fieldGroupsJson: jsonEncode(
              conflict.fieldGroups.map((group) => group.name).toList(),
            ),
            localSnapshotJson: localSnapshotJson,
            remoteChangeJson: jsonEncode(conflict.remoteChange.toJson()),
            createdAt: now,
            updatedAt: now,
            resolvedByDeviceId: const Value<String?>(null),
            resolvedAt: const Value<DateTime?>(null),
            resolution: const Value<String?>(null),
          ),
        );
  }

  @override
  Future<void> markResolved({
    required String id,
    required DeltaConflictResolution resolution,
    required String deviceId,
    DateTime? resolvedAt,
  }) async {
    final now = (resolvedAt ?? _now()).toUtc();
    await (database.update(
      database.deltaConflicts,
    )..where((row) => row.id.equals(id))).write(
      DeltaConflictsCompanion(
        updatedAt: Value(now),
        resolvedAt: Value(now),
        resolution: Value(resolution.name),
        resolvedByDeviceId: Value(deviceId),
      ),
    );
  }

  StoredDeltaConflict _mapRow(DeltaConflict row) {
    final fieldGroups = (jsonDecode(row.fieldGroupsJson) as List<dynamic>)
        .map(
          (value) =>
              TransactionConflictFieldGroup.values.byName(value as String),
        )
        .toSet();
    final remoteChange = DeltaChangeRecord.fromJson(
      jsonDecode(row.remoteChangeJson) as Map<String, Object?>,
    );
    return StoredDeltaConflict(
      id: row.id,
      datasetId: row.datasetId,
      userId: row.userId,
      tableName: row.targetTable,
      recordId: row.recordId,
      fieldGroups: fieldGroups,
      localSnapshot: jsonDecode(row.localSnapshotJson) as Map<String, Object?>,
      remoteChange: remoteChange,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      resolvedAt: row.resolvedAt,
      resolution: row.resolution == null
          ? null
          : DeltaConflictResolution.values.byName(row.resolution!),
      resolvedByDeviceId: row.resolvedByDeviceId,
    );
  }
}
