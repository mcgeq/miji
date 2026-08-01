import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/local_snapshot/database_snapshot_models.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_providers.dart';
import 'package:miji/core/sync/webdav/webdav_client.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';
import 'package:miji/core/sync/webdav/webdav_sync_metadata_store.dart';
import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';
import 'package:miji/features/settings/presentation/data_sync_section.dart';

void main() {
  testWidgets('shows prominent auto sync failure status and recent history', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseSnapshotStatusProvider.overrideWith(
            (ref) async => const LocalDatabaseSnapshotStatus(
              databasePath: 'F:/mcgeq/miji/miji.sqlite',
              snapshots: [],
            ),
          ),
          webDavConfigProvider.overrideWith((ref) async => _configuredWebDav),
          webDavRemoteSnapshotStatusProvider.overrideWith(
            (ref) async => const WebDavRemoteSnapshotStatus(
              config: _configuredWebDav,
              snapshots: [],
            ),
          ),
          webDavSyncMetadataProvider.overrideWith(
            (ref) async => WebDavSyncMetadata(
              lastUploadedAt: null,
              lastRestoredAt: null,
              lastDeletedAt: null,
              lastAutoSyncStartedAt: DateTime.utc(2026, 7, 11, 8),
              lastAutoSyncSucceededAt: null,
              lastAutoSyncFailedAt: DateTime.utc(2026, 7, 11, 8, 1),
              lastAutoSyncError: 'WebDavSyncException(connectionFailed)',
              recentSyncActivities: [
                WebDavSyncActivityEntry(
                  finishedAt: DateTime.utc(2026, 7, 11, 8, 1),
                  outcome: 'failed',
                  reason: 'conflictResolved',
                  errorMessage: 'WebDavSyncException(connectionFailed)',
                  uploadedChanges: 2,
                  uploadedPackages: 1,
                  downloadedPackages: 3,
                  appliedRemoteChanges: 4,
                  remoteConflicts: 1,
                ),
                WebDavSyncActivityEntry(
                  finishedAt: DateTime.utc(2026, 7, 11, 7, 30),
                  outcome: 'success',
                ),
              ],
            ),
          ),
          webDavSyncPreferencesProvider.overrideWith(
            (ref) async => WebDavSyncPreferences.defaults,
          ),
          webDavSyncDiagnosticsProvider.overrideWith(
            (ref) async => _diagnostics,
          ),
          webDavSyncPasswordSavedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSyncSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('最近一次自动同步失败'), findsOneWidget);

    await tester.ensureVisible(find.text('同步记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同步记录'));
    await tester.pumpAndSettle();

    expect(find.text('自动同步失败'), findsOneWidget);
    expect(find.text('最近同步记录'), findsOneWidget);
    expect(find.text('2026-07-11 16:01'), findsWidgets);
    expect(find.textContaining('冲突处理后同步'), findsOneWidget);
    expect(find.textContaining('上传 2 条'), findsOneWidget);
    expect(find.textContaining('下载 3 包'), findsOneWidget);
    expect(find.textContaining('冲突 1 条'), findsOneWidget);
    expect(
      find.textContaining('WebDavSyncException(connectionFailed)'),
      findsWidgets,
    );
  });
  testWidgets('refreshes remote snapshots when opening the picker', (
    tester,
  ) async {
    final client = _RefreshableWebDavClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseSnapshotStatusProvider.overrideWith(
            (ref) async => const LocalDatabaseSnapshotStatus(
              databasePath: 'F:/mcgeq/miji/miji.sqlite',
              snapshots: [],
            ),
          ),
          webDavConfigProvider.overrideWith((ref) async => _configuredWebDav),
          webDavClientProvider.overrideWith((ref) => client),
          webDavSyncMetadataProvider.overrideWith(
            (ref) async => WebDavSyncMetadata.empty,
          ),
          webDavSyncPreferencesProvider.overrideWith(
            (ref) async => WebDavSyncPreferences.defaults,
          ),
          webDavSyncDiagnosticsProvider.overrideWith(
            (ref) async => _diagnostics,
          ),
          webDavSyncPasswordSavedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSyncSection())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('云端快照'), findsWidgets);

    await tester.ensureVisible(find.text('查看云端快照'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看云端快照'));

    await tester.pumpAndSettle();

    expect(client.listSnapshotCallCount, 2);
    expect(find.text('云端快照'), findsWidgets);
    expect(
      find.textContaining('remote-from-device-a.miji-snapshot'),
      findsWidgets,
    );
  });
  testWidgets('shows cloud snapshot creation entry for configured WebDAV', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseSnapshotStatusProvider.overrideWith(
            (ref) async => const LocalDatabaseSnapshotStatus(
              databasePath: 'F:/mcgeq/miji/miji.sqlite',
              snapshots: [],
            ),
          ),
          webDavConfigProvider.overrideWith((ref) async => _configuredWebDav),
          webDavRemoteSnapshotStatusProvider.overrideWith(
            (ref) async => const WebDavRemoteSnapshotStatus(
              config: _configuredWebDav,
              snapshots: [],
            ),
          ),
          webDavSyncMetadataProvider.overrideWith(
            (ref) async => WebDavSyncMetadata.empty,
          ),
          webDavSyncPreferencesProvider.overrideWith(
            (ref) async => WebDavSyncPreferences.defaults,
          ),
          webDavSyncDiagnosticsProvider.overrideWith(
            (ref) async => _diagnostics,
          ),
          webDavSyncPasswordSavedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSyncSection())),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('创建云端快照'), findsOneWidget);
    expect(find.text('请先设置同步密码'), findsOneWidget);
  });
  testWidgets('uses sync wording for saved sync password dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseSnapshotStatusProvider.overrideWith(
            (ref) async => const LocalDatabaseSnapshotStatus(
              databasePath: 'F:/mcgeq/miji/miji.sqlite',
              snapshots: [],
            ),
          ),
          webDavConfigProvider.overrideWith((ref) async => _configuredWebDav),
          webDavRemoteSnapshotStatusProvider.overrideWith(
            (ref) async => const WebDavRemoteSnapshotStatus(
              config: _configuredWebDav,
              snapshots: [],
            ),
          ),
          webDavSyncMetadataProvider.overrideWith(
            (ref) async => WebDavSyncMetadata.empty,
          ),
          webDavSyncPreferencesProvider.overrideWith(
            (ref) async => WebDavSyncPreferences.defaults,
          ),
          webDavSyncDiagnosticsProvider.overrideWith(
            (ref) async => _diagnostics,
          ),
          webDavSyncPasswordSavedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSyncSection())),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('设置同步密码'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置同步密码'));
    await tester.pumpAndSettle();

    expect(find.text('同步密码'), findsWidgets);
    expect(find.text('快照密码'), findsNothing);
    expect(find.text('再次输入快照密码'), findsNothing);
    expect(find.text('再次输入同步密码'), findsOneWidget);
    expect(find.byTooltip('保存'), findsOneWidget);
  });
  testWidgets('uses snapshot wording for local snapshot creation dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localDatabaseSnapshotStatusProvider.overrideWith(
            (ref) async => const LocalDatabaseSnapshotStatus(
              databasePath: 'F:/mcgeq/miji/miji.sqlite',
              snapshots: [],
            ),
          ),
          webDavConfigProvider.overrideWith((ref) async => _configuredWebDav),
          webDavRemoteSnapshotStatusProvider.overrideWith(
            (ref) async => const WebDavRemoteSnapshotStatus(
              config: _configuredWebDav,
              snapshots: [],
            ),
          ),
          webDavSyncMetadataProvider.overrideWith(
            (ref) async => WebDavSyncMetadata.empty,
          ),
          webDavSyncPreferencesProvider.overrideWith(
            (ref) async => WebDavSyncPreferences.defaults,
          ),
          webDavSyncDiagnosticsProvider.overrideWith(
            (ref) async => _diagnostics,
          ),
          webDavSyncPasswordSavedProvider.overrideWith((ref) async => false),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: DataSyncSection())),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('快照备份与恢复'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('快照备份与恢复'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('仅创建本机快照'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仅创建本机快照'));
    await tester.pumpAndSettle();

    expect(find.text('创建加密快照'), findsOneWidget);
    expect(find.text('快照密码'), findsOneWidget);
    expect(find.text('再次输入快照密码'), findsOneWidget);
  });
}

const _diagnostics = WebDavSyncDiagnostics(
  deviceId: 'device_1',
  datasetId: 'dataset_1',
  currentUserId: null,
  pendingUploadChanges: 0,
  openConflicts: 0,
  remoteCursorDeviceCount: 0,
  remoteCursorMaxSequence: null,
  latestActivity: null,
);

const _configuredWebDav = WebDavConfig(
  providerType: WebDavProviderType.nutstore,
  endpointUrl: '',
  username: 'sync-user',
  password: 'sync-password',
  remoteDirectory: '.miji/snapshots',
);

class _RefreshableWebDavClient extends WebDavClient {
  int listSnapshotCallCount = 0;

  @override
  Future<List<WebDavRemoteSnapshotInfo>> listSnapshots(
    WebDavConfig config,
  ) async {
    listSnapshotCallCount += 1;
    if (listSnapshotCallCount == 1) {
      return const <WebDavRemoteSnapshotInfo>[];
    }

    return [
      WebDavRemoteSnapshotInfo(
        fileName: 'remote-from-device-a.miji-snapshot',
        url: Uri.parse(
          'https://example.com/dav/.miji/snapshots/remote-from-device-a.miji-snapshot',
        ),
        sizeBytes: 128,
        updatedAt: DateTime.utc(2026, 7, 11, 8),
      ),
    ];
  }
}
