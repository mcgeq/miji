import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';

class SyncIdentity {
  const SyncIdentity({required this.deviceId, required this.datasetId});

  final String deviceId;
  final String datasetId;
}

abstract class SyncIdentityResolver {
  Future<SyncIdentity> readIdentity();
}

class FixedSyncIdentityResolver implements SyncIdentityResolver {
  const FixedSyncIdentityResolver(this.identity);

  final SyncIdentity identity;

  @override
  Future<SyncIdentity> readIdentity() async => identity;
}

class SharedPreferencesSyncIdentityStore implements SyncIdentityResolver {
  const SharedPreferencesSyncIdentityStore({required this.database, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  static const _deviceIdKey = 'sync.identity.deviceId';
  static const _datasetIdKey = 'sync.datasetId';

  final AppDatabase database;
  final Uuid _uuid;

  @override
  Future<SyncIdentity> readIdentity() async {
    final deviceId = await _readOrCreateDeviceId();
    final datasetId = await _readOrCreateDatasetId();
    return SyncIdentity(deviceId: deviceId, datasetId: datasetId);
  }

  Future<String> _readOrCreateDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final created = _uuid.v4();
    await preferences.setString(_deviceIdKey, created);
    return created;
  }

  Future<String> _readOrCreateDatasetId() async {
    final existing = await (database.select(
      database.syncMetadata,
    )..where((row) => row.key.equals(_datasetIdKey))).getSingleOrNull();
    if (existing != null && existing.value.isNotEmpty) {
      return existing.value;
    }

    final created = _uuid.v4();
    await database
        .into(database.syncMetadata)
        .insert(
          SyncMetadataCompanion.insert(
            key: _datasetIdKey,
            value: created,
            updatedAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrReplace,
        );
    return created;
  }
}
