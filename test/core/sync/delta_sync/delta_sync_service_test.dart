import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_store.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_service.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('uploads pending change logs and marks them synced', () async {
    final changedAt = DateTime.utc(2026, 7, 11, 9);
    await database
        .into(database.syncChangeLogs)
        .insert(
          SyncChangeLogsCompanion.insert(
            id: 'change-1',
            datasetId: 'dataset-a',
            userId: 'user-1',
            targetTable: 'money_transactions',
            recordId: 'tx-1',
            operation: 'update',
            changedFieldsJson: '{"amount_minor":1200}',
            beforeVersion: const Value(1),
            afterVersion: const Value(2),
            deviceId: const Value('device-a'),
            changedAt: changedAt,
          ),
        );

    final packageStore = _FakeDeltaPackageStore();
    final service = DeltaSyncService(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      packageStore: packageStore,
      readConfig: () async => _config,
      now: () => changedAt,
    );

    final result = await service.syncNow('delta-password');

    expect(result.uploadedChanges, 1);
    expect(result.uploadedPackages, 1);
    expect(packageStore.uploadedPackages, hasLength(1));
    expect(packageStore.uploadedPasswords, ['delta-password']);
    expect(
      packageStore.uploadedPackages.single.payload.changes.single.table,
      'money_transactions',
    );

    final rows = await database.select(database.syncChangeLogs).get();
    expect(rows.single.syncedAt?.toUtc(), changedAt);
  });

  test('uploads account change with full local record snapshot', () async {
    final changedAt = DateTime.utc(2026, 7, 11, 9);
    final createdAt = DateTime.utc(2026, 7, 10, 9);
    await _insertUser(database, userId: 'user-1', now: createdAt);
    await _insertCurrency(database, now: createdAt);
    await database
        .into(database.moneyAccounts)
        .insert(
          MoneyAccountsCompanion.insert(
            id: 'account-1',
            userId: 'user-1',
            name: 'Cash',
            type: 'cash',
            balanceMinor: 12000,
            initialBalanceMinor: 10000,
            currencyCode: 'CNY',
            version: const Value(2),
            createdAt: createdAt,
            updatedAt: changedAt,
          ),
        );
    await database
        .into(database.syncChangeLogs)
        .insert(
          SyncChangeLogsCompanion.insert(
            id: 'change-1',
            datasetId: 'dataset-a',
            userId: 'user-1',
            targetTable: 'money_accounts',
            recordId: 'account-1',
            operation: 'update',
            changedFieldsJson: '{"name":"Cash"}',
            beforeVersion: const Value(1),
            afterVersion: const Value(2),
            deviceId: const Value('device-a'),
            changedAt: changedAt,
          ),
        );

    final packageStore = _FakeDeltaPackageStore();
    final service = DeltaSyncService(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      packageStore: packageStore,
      readConfig: () async => _config,
      now: () => changedAt,
    );

    await service.syncNow('delta-password');

    final change = packageStore.uploadedPackages.single.payload.changes.single;
    expect(change.table, 'money_accounts');
    expect(change.recordSnapshot['id'], 'account-1');
    expect(change.recordSnapshot['user_id'], 'user-1');
    expect(change.recordSnapshot['name'], 'Cash');
    expect(change.recordSnapshot['balance_minor'], 12000);
    expect(change.recordSnapshot['version'], 2);
    expect(change.recordSnapshot['updated_at'], changedAt.toIso8601String());
  });

  test('uploads category change with full local record snapshot', () async {
    final changedAt = DateTime.utc(2026, 7, 11, 9);
    final createdAt = DateTime.utc(2026, 7, 10, 9);
    await _insertUser(database, userId: 'user-1', now: createdAt);
    await database
        .into(database.moneyCategories)
        .insert(
          MoneyCategoriesCompanion.insert(
            id: 'category-1',
            userId: const Value('user-1'),
            name: 'Pet',
            kind: 'expense',
            color: const Value('#22C55E'),
            icon: const Value('pets'),
            isSystem: const Value(false),
            version: const Value(2),
            createdAt: createdAt,
            updatedAt: changedAt,
          ),
        );
    await database
        .into(database.syncChangeLogs)
        .insert(
          SyncChangeLogsCompanion.insert(
            id: 'change-1',
            datasetId: 'dataset-a',
            userId: 'user-1',
            targetTable: 'money_categories',
            recordId: 'category-1',
            operation: 'update',
            changedFieldsJson: '{"name":"Pet"}',
            beforeVersion: const Value(1),
            afterVersion: const Value(2),
            deviceId: const Value('device-a'),
            changedAt: changedAt,
          ),
        );

    final packageStore = _FakeDeltaPackageStore();
    final service = DeltaSyncService(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      packageStore: packageStore,
      readConfig: () async => _config,
      now: () => changedAt,
    );

    await service.syncNow('delta-password');

    final change = packageStore.uploadedPackages.single.payload.changes.single;
    expect(change.table, 'money_categories');
    expect(change.recordSnapshot['id'], 'category-1');
    expect(change.recordSnapshot['user_id'], 'user-1');
    expect(change.recordSnapshot['name'], 'Pet');
    expect(change.recordSnapshot['kind'], 'expense');
    expect(change.recordSnapshot['color'], '#22C55E');
    expect(change.recordSnapshot['is_system'], isFalse);
    expect(change.recordSnapshot['version'], 2);
    expect(change.recordSnapshot['updated_at'], changedAt.toIso8601String());
  });
  test(
    'downloads remote packages and persists transaction conflicts',
    () async {
      final packageStore = _FakeDeltaPackageStore()
        ..remotePackages.add(
          DeltaPackage(
            metadata: DeltaPackageMetadata(
              datasetId: 'dataset-a',
              deviceId: 'device-b',
              sequence: 9,
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
                  recordSnapshot: {
                    'id': 'tx-1',
                    'user_id': 'user-1',
                    'amount_minor': 1200,
                    'notes': 'remote',
                  },
                ),
              ],
            ),
          ),
        );
      final conflictStore = DriftDeltaConflictStore(database: database);
      final service = DeltaSyncService(
        database: database,
        identityResolver: const FixedSyncIdentityResolver(
          SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
        ),
        packageStore: packageStore,
        conflictStore: conflictStore,
        readConfig: () async => _config,
        readLocalRecord: (change) async => const DeltaLocalRecord(
          table: 'money_transactions',
          recordId: 'tx-1',
          version: 2,
          snapshot: {'id': 'tx-1', 'user_id': 'user-1', 'notes': 'local'},
        ),
        now: () => DateTime.utc(2026, 7, 11, 12),
      );

      final result = await service.syncNow('delta-password');

      expect(result.uploadedChanges, 0);
      expect(result.downloadedPackages, 1);
      expect(result.remoteConflicts, 1);

      final conflicts = await conflictStore.listOpenConflicts('user-1');
      expect(conflicts, hasLength(1));
      expect(conflicts.single.recordId, 'tx-1');
      expect(conflicts.single.fieldGroups, {
        TransactionConflictFieldGroup.basic,
        TransactionConflictFieldGroup.text,
      });

      final second = await service.syncNow('delta-password');
      expect(second.downloadedPackages, 0);
      expect((await conflictStore.listOpenConflicts('user-1')), hasLength(1));
    },
  );

  test('concurrent syncNow calls share a single in-flight sync', () async {
    final changedAt = DateTime.utc(2026, 7, 11, 9);
    await database
        .into(database.syncChangeLogs)
        .insert(
          SyncChangeLogsCompanion.insert(
            id: 'change-1',
            datasetId: 'dataset-a',
            userId: 'user-1',
            targetTable: 'money_transactions',
            recordId: 'tx-1',
            operation: 'update',
            changedFieldsJson: '{"amount_minor":1200}',
            beforeVersion: const Value(1),
            afterVersion: const Value(2),
            deviceId: const Value('device-a'),
            changedAt: changedAt,
          ),
        );

    final packageStore = _BlockingDeltaPackageStore();
    final service = DeltaSyncService(
      database: database,
      identityResolver: const FixedSyncIdentityResolver(
        SyncIdentity(deviceId: 'device-a', datasetId: 'dataset-a'),
      ),
      packageStore: packageStore,
      readConfig: () async => _config,
      now: () => changedAt,
    );

    final first = service.syncNow('delta-password');
    final second = service.syncNow('delta-password');

    await packageStore.uploadStarted.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(packageStore.uploadStartedCount, 1);

    packageStore.completeUpload();
    final results = await Future.wait([first, second]);

    expect(results[0].uploadedChanges, 1);
    expect(results[1].uploadedChanges, 1);
    expect(packageStore.uploadedPackages, hasLength(1));
  });
}

Future<void> _insertUser(
  AppDatabase database, {
  required String userId,
  required DateTime now,
}) async {
  await database
      .into(database.users)
      .insert(
        UsersCompanion.insert(
          id: userId,
          username: 'user',
          email: 'user@example.com',
          displayName: 'User',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _insertCurrency(AppDatabase database, {required DateTime now}) {
  return database
      .into(database.moneyCurrencies)
      .insert(
        MoneyCurrenciesCompanion.insert(
          code: 'CNY',
          locale: 'zh_CN',
          symbol: '¥',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

const _config = WebDavConfig(
  providerType: WebDavProviderType.custom,
  endpointUrl: 'https://example.com/dav/',
  username: 'user',
  password: 'pass',
  remoteDirectory: '.miji/snapshots',
);

class _FakeDeltaPackageStore implements DeltaPackageStore {
  final uploadedPackages = <DeltaPackage>[];
  final uploadedPasswords = <String>[];
  final remotePackages = <DeltaPackage>[];

  @override
  Future<DeltaRemotePackageInfo> upload({
    required WebDavConfig config,
    required String password,
    required DeltaPackage package,
  }) async {
    uploadedPasswords.add(password);
    uploadedPackages.add(package);
    return DeltaRemotePackageInfo(
      file: WebDavRemoteFileInfo(
        fileName: '${package.metadata.sequence}.miji-delta',
        url: Uri.parse(
          'https://example.com/dav/.miji/delta/package.miji-delta',
        ),
        sizeBytes: 10,
        updatedAt: package.metadata.createdAt,
      ),
      datasetId: package.metadata.datasetId,
      deviceId: package.metadata.deviceId,
      sequence: package.metadata.sequence,
    );
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listPackages({
    required WebDavConfig config,
    required String datasetId,
    required String deviceId,
  }) async {
    return const <DeltaRemotePackageInfo>[];
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listRemotePackages({
    required WebDavConfig config,
    required String datasetId,
    required String localDeviceId,
  }) async {
    return remotePackages
        .where(
          (package) =>
              package.metadata.datasetId == datasetId &&
              package.metadata.deviceId != localDeviceId,
        )
        .map(_remoteInfoFor)
        .toList(growable: false);
  }

  @override
  Future<DeltaPackage> download({
    required WebDavConfig config,
    required String password,
    required DeltaRemotePackageInfo remotePackage,
  }) {
    return Future.value(
      remotePackages.singleWhere(
        (package) =>
            package.metadata.datasetId == remotePackage.datasetId &&
            package.metadata.deviceId == remotePackage.deviceId &&
            package.metadata.sequence == remotePackage.sequence,
      ),
    );
  }

  DeltaRemotePackageInfo _remoteInfoFor(DeltaPackage package) {
    return DeltaRemotePackageInfo(
      file: WebDavRemoteFileInfo(
        fileName: '${package.metadata.sequence}.miji-delta',
        url: Uri.parse(
          'https://example.com/dav/.miji/delta/'
          '${package.metadata.datasetId}/${package.metadata.deviceId}/'
          '${package.metadata.sequence}.miji-delta',
        ),
        sizeBytes: 10,
        updatedAt: package.metadata.createdAt,
      ),
      datasetId: package.metadata.datasetId,
      deviceId: package.metadata.deviceId,
      sequence: package.metadata.sequence,
    );
  }
}

class _BlockingDeltaPackageStore implements DeltaPackageStore {
  final _uploadCompleter = Completer<void>();
  final uploadStarted = Completer<void>();
  final uploadedPackages = <DeltaPackage>[];
  int uploadStartedCount = 0;

  void completeUpload() {
    if (!_uploadCompleter.isCompleted) {
      _uploadCompleter.complete();
    }
  }

  @override
  Future<DeltaRemotePackageInfo> upload({
    required WebDavConfig config,
    required String password,
    required DeltaPackage package,
  }) async {
    uploadStartedCount += 1;
    uploadedPackages.add(package);
    if (!uploadStarted.isCompleted) {
      uploadStarted.complete();
    }
    await _uploadCompleter.future;
    return DeltaRemotePackageInfo(
      file: WebDavRemoteFileInfo(
        fileName: '${package.metadata.sequence}.miji-delta',
        url: Uri.parse(
          'https://example.com/dav/.miji/delta/package.miji-delta',
        ),
        sizeBytes: 10,
        updatedAt: package.metadata.createdAt,
      ),
      datasetId: package.metadata.datasetId,
      deviceId: package.metadata.deviceId,
      sequence: package.metadata.sequence,
    );
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listPackages({
    required WebDavConfig config,
    required String datasetId,
    required String deviceId,
  }) async {
    return const <DeltaRemotePackageInfo>[];
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listRemotePackages({
    required WebDavConfig config,
    required String datasetId,
    required String localDeviceId,
  }) async {
    return const <DeltaRemotePackageInfo>[];
  }

  @override
  Future<DeltaPackage> download({
    required WebDavConfig config,
    required String password,
    required DeltaRemotePackageInfo remotePackage,
  }) {
    throw UnimplementedError();
  }
}
