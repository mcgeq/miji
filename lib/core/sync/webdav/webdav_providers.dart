import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/sync/delta_sync/delta_package_store.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_service.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_providers.dart';
import 'package:miji/core/sync/webdav/webdav_auto_sync_executor.dart';
import 'package:miji/core/sync/webdav/webdav_client.dart';
import 'package:miji/core/sync/webdav/webdav_config_store.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_restore_timeout.dart';
import 'package:miji/core/sync/webdav/webdav_sync_metadata_store.dart';
import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';
import 'package:miji/core/sync/webdav/webdav_sync_secret_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

final webDavConfigStoreProvider = Provider<WebDavConfigStore>((ref) {
  return const FlutterSecureWebDavConfigStore();
});

final webDavClientProvider = Provider<WebDavClient>((ref) {
  return WebDavClient();
});

final webDavSyncPreferencesStoreProvider = Provider<WebDavSyncPreferencesStore>(
  (ref) {
    return const SharedPreferencesWebDavSyncPreferencesStore();
  },
);

final webDavSyncPreferencesProvider = FutureProvider<WebDavSyncPreferences>((
  ref,
) {
  return ref.watch(webDavSyncPreferencesStoreProvider).readPreferences();
});

final webDavSyncSecretStoreProvider = Provider<WebDavSyncSecretStore>((ref) {
  return const FlutterSecureWebDavSyncSecretStore();
});

final webDavSyncPasswordSavedProvider = FutureProvider<bool>((ref) {
  return ref.watch(webDavSyncSecretStoreProvider).hasSnapshotPassword();
});
final webDavSyncMetadataStoreProvider = Provider<WebDavSyncMetadataStore>((
  ref,
) {
  return const SharedPreferencesWebDavSyncMetadataStore();
});

final webDavSyncMetadataProvider = FutureProvider<WebDavSyncMetadata>((ref) {
  return ref.watch(webDavSyncMetadataStoreProvider).readMetadata();
});

final webDavSyncDiagnosticsProvider = FutureProvider<WebDavSyncDiagnostics>((
  ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  final session = ref.watch(authSessionControllerProvider);
  final identity = await ref.watch(syncIdentityResolverProvider).readIdentity();
  final metadata = await ref.watch(webDavSyncMetadataProvider.future);
  final userId = session.isUnlocked ? session.userId : null;

  final pendingUploadChanges = userId == null
      ? 0
      : await _countPendingSyncChanges(database, userId);
  final openConflicts = userId == null
      ? 0
      : await _countOpenDeltaConflicts(database, userId);
  final remoteCursors = await _readRemoteDeltaCursors(database);

  return WebDavSyncDiagnostics(
    deviceId: identity.deviceId,
    datasetId: identity.datasetId,
    currentUserId: userId,
    pendingUploadChanges: pendingUploadChanges,
    openConflicts: openConflicts,
    remoteCursorDeviceCount: remoteCursors.length,
    remoteCursorMaxSequence: remoteCursors.isEmpty
        ? null
        : remoteCursors.reduce((a, b) => a > b ? a : b),
    latestActivity: metadata.recentSyncActivities.isEmpty
        ? null
        : metadata.recentSyncActivities.first,
  );
});

class WebDavSyncDiagnostics {
  const WebDavSyncDiagnostics({
    required this.deviceId,
    required this.datasetId,
    required this.currentUserId,
    required this.pendingUploadChanges,
    required this.openConflicts,
    required this.remoteCursorDeviceCount,
    required this.remoteCursorMaxSequence,
    required this.latestActivity,
  });

  final String deviceId;
  final String datasetId;
  final String? currentUserId;
  final int pendingUploadChanges;
  final int openConflicts;
  final int remoteCursorDeviceCount;
  final int? remoteCursorMaxSequence;
  final WebDavSyncActivityEntry? latestActivity;
}

Future<int> _countPendingSyncChanges(
  AppDatabase database,
  String userId,
) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM sync_change_logs '
        'WHERE user_id = ? AND synced_at IS NULL',
        variables: [Variable<String>(userId)],
        readsFrom: {database.syncChangeLogs},
      )
      .getSingle();
  return row.read<int>('count');
}

Future<int> _countOpenDeltaConflicts(
  AppDatabase database,
  String userId,
) async {
  final row = await database
      .customSelect(
        'SELECT COUNT(*) AS count FROM delta_conflicts '
        'WHERE user_id = ? AND resolved_at IS NULL',
        variables: [Variable<String>(userId)],
        readsFrom: {database.deltaConflicts},
      )
      .getSingle();
  return row.read<int>('count');
}

Future<List<int>> _readRemoteDeltaCursors(AppDatabase database) async {
  final rows = await database
      .customSelect(
        "SELECT value FROM sync_metadata WHERE key LIKE 'sync.delta.remoteCursor.%'",
        readsFrom: {database.syncMetadata},
      )
      .get();
  return rows
      .map((row) => int.tryParse(row.read<String>('value')))
      .nonNulls
      .toList(growable: false);
}

final webDavDeltaPackageStoreProvider = Provider<WebDavDeltaPackageStore>((
  ref,
) {
  return WebDavDeltaPackageStore(client: ref.watch(webDavClientProvider));
});

final deltaSyncServiceProvider = Provider<DeltaSyncService>((ref) {
  final moneyRepository = DriftMoneyRepository(
    database: ref.watch(appDatabaseProvider),
    seedRunner: ref.watch(databaseSeedRunnerProvider),
  );
  return DeltaSyncService(
    database: ref.watch(appDatabaseProvider),
    identityResolver: ref.watch(syncIdentityResolverProvider),
    packageStore: ref.watch(webDavDeltaPackageStoreProvider),
    conflictStore: ref.watch(deltaConflictStoreProvider),
    readConfig: () => ref.read(webDavConfigProvider.future),
    applyRemoteChange: moneyRepository.applyRemoteMoneyChange,
  );
});

void _refreshMoneyAfterDeltaSync(Ref ref, DeltaSyncResult result) {
  if (result.appliedRemoteChanges <= 0 && result.remoteConflicts <= 0) {
    return;
  }

  ref.read(moneyDataRefreshCoordinatorProvider).refreshAllMoneyData();
}

final webDavConfigProvider = FutureProvider<WebDavConfig>((ref) {
  return ref.watch(webDavConfigStoreProvider).readConfig();
});

final webDavRemoteSnapshotStatusProvider =
    FutureProvider<WebDavRemoteSnapshotStatus>((ref) async {
      final config = await ref.watch(webDavConfigProvider.future);
      if (!config.isConfigured) {
        return WebDavRemoteSnapshotStatus(config: config, snapshots: const []);
      }

      final snapshots = await ref
          .watch(webDavClientProvider)
          .listSnapshots(config);
      return WebDavRemoteSnapshotStatus(config: config, snapshots: snapshots);
    });

final webDavSyncActionProvider =
    NotifierProvider<WebDavSyncActionController, WebDavSyncActionState>(
      WebDavSyncActionController.new,
    );

final webDavAutoSyncControllerProvider =
    NotifierProvider<WebDavAutoSyncController, WebDavAutoSyncStatus>(
      WebDavAutoSyncController.new,
    );

enum WebDavSyncActionOperation {
  idle,
  saveConfig,
  clearConfig,
  saveSyncPreferences,
  saveAutoSyncPassword,
  clearAutoSyncPassword,
  testConnection,
  deltaSyncNow,
  uploadLatestLocalSnapshot,
  downloadRemoteSnapshot,
  exportAndUploadSnapshot,
  restoreRemoteSnapshot,
  deleteRemoteSnapshot,
}

class WebDavSyncActionState {
  const WebDavSyncActionState({
    required this.operation,
    required this.isLoading,
    this.error,
  });

  final WebDavSyncActionOperation operation;
  final bool isLoading;
  final Object? error;

  static const idle = WebDavSyncActionState(
    operation: WebDavSyncActionOperation.idle,
    isLoading: false,
  );

  factory WebDavSyncActionState.loading(WebDavSyncActionOperation operation) {
    return WebDavSyncActionState(operation: operation, isLoading: true);
  }

  factory WebDavSyncActionState.failure(
    WebDavSyncActionOperation operation,
    Object error,
  ) {
    return WebDavSyncActionState(
      operation: operation,
      isLoading: false,
      error: error,
    );
  }
}

class WebDavAutoSyncStatus {
  const WebDavAutoSyncStatus({
    required this.isConfigured,
    required this.autoUploadEnabled,
    required this.uploadOnStartupEnabled,
    required this.passwordSaved,
    required this.isRunning,
    required this.startupAttempted,
    required this.lastOutcome,
    required this.lastErrorMessage,
    required this.lastStartedAt,
    required this.lastSucceededAt,
    required this.lastFailedAt,
    required this.nextRunAt,
  });

  final bool isConfigured;
  final bool autoUploadEnabled;
  final bool uploadOnStartupEnabled;
  final bool passwordSaved;
  final bool isRunning;
  final bool startupAttempted;
  final WebDavAutoSyncOutcome? lastOutcome;
  final String? lastErrorMessage;
  final DateTime? lastStartedAt;
  final DateTime? lastSucceededAt;
  final DateTime? lastFailedAt;
  final DateTime? nextRunAt;

  static const initial = WebDavAutoSyncStatus(
    isConfigured: false,
    autoUploadEnabled: false,
    uploadOnStartupEnabled: false,
    passwordSaved: false,
    isRunning: false,
    startupAttempted: false,
    lastOutcome: null,
    lastErrorMessage: null,
    lastStartedAt: null,
    lastSucceededAt: null,
    lastFailedAt: null,
    nextRunAt: null,
  );

  WebDavAutoSyncStatus copyWith({
    bool? isConfigured,
    bool? autoUploadEnabled,
    bool? uploadOnStartupEnabled,
    bool? passwordSaved,
    bool? isRunning,
    bool? startupAttempted,
    WebDavAutoSyncOutcome? lastOutcome,
    String? lastErrorMessage,
    DateTime? lastStartedAt,
    DateTime? lastSucceededAt,
    DateTime? lastFailedAt,
    DateTime? nextRunAt,
    bool clearLastErrorMessage = false,
    bool clearNextRunAt = false,
  }) {
    return WebDavAutoSyncStatus(
      isConfigured: isConfigured ?? this.isConfigured,
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      uploadOnStartupEnabled:
          uploadOnStartupEnabled ?? this.uploadOnStartupEnabled,
      passwordSaved: passwordSaved ?? this.passwordSaved,
      isRunning: isRunning ?? this.isRunning,
      startupAttempted: startupAttempted ?? this.startupAttempted,
      lastOutcome: lastOutcome ?? this.lastOutcome,
      lastErrorMessage: clearLastErrorMessage
          ? null
          : lastErrorMessage ?? this.lastErrorMessage,
      lastStartedAt: lastStartedAt ?? this.lastStartedAt,
      lastSucceededAt: lastSucceededAt ?? this.lastSucceededAt,
      lastFailedAt: lastFailedAt ?? this.lastFailedAt,
      nextRunAt: clearNextRunAt ? null : nextRunAt ?? this.nextRunAt,
    );
  }
}

class WebDavAutoSyncController extends Notifier<WebDavAutoSyncStatus> {
  Timer? _timer;
  bool _startupAttempted = false;

  @override
  WebDavAutoSyncStatus build() {
    ref.onDispose(_cancelTimer);
    Future<void>.microtask(refresh);
    return WebDavAutoSyncStatus.initial;
  }

  Future<void> refresh() async {
    if (state.isRunning) {
      return;
    }

    _cancelTimer();

    final config = await ref.read(webDavConfigProvider.future);
    final preferences = await ref.read(webDavSyncPreferencesProvider.future);
    final passwordSaved = await ref.read(
      webDavSyncPasswordSavedProvider.future,
    );

    state = state.copyWith(
      isConfigured: config.isConfigured,
      autoUploadEnabled: preferences.autoUploadEnabled,
      uploadOnStartupEnabled: preferences.uploadOnStartupEnabled,
      passwordSaved: passwordSaved,
      startupAttempted: _startupAttempted,
      clearNextRunAt: true,
    );

    if (!config.isConfigured ||
        !preferences.autoUploadEnabled ||
        !passwordSaved) {
      return;
    }

    if (preferences.uploadOnStartupEnabled && !_startupAttempted) {
      _startupAttempted = true;
      await run(WebDavAutoSyncReason.startup);
    }

    _scheduleNext(preferences.uploadIntervalMinutes);
  }

  Future<WebDavAutoSyncResult> run(WebDavAutoSyncReason reason) async {
    if (state.isRunning) {
      return WebDavAutoSyncResult(
        reason: reason,
        outcome: WebDavAutoSyncOutcome.alreadyRunning,
      );
    }

    final startedAt = DateTime.now().toUtc();
    await ref
        .read(webDavSyncMetadataStoreProvider)
        .markAutoSyncStarted(startedAt);
    ref.invalidate(webDavSyncMetadataProvider);
    state = state.copyWith(
      isRunning: true,
      startupAttempted: _startupAttempted,
      lastStartedAt: startedAt,
      clearLastErrorMessage: true,
    );

    final executor = WebDavAutoSyncExecutor(
      readConfig: () => ref.read(webDavConfigProvider.future),
      readPreferences: () => ref.read(webDavSyncPreferencesProvider.future),
      readPassword: () =>
          ref.read(webDavSyncSecretStoreProvider).readSnapshotPassword(),
      syncNow: (password) =>
          ref.read(deltaSyncServiceProvider).syncNow(password),
    );
    final result = await executor.run(reason);
    final finishedAt = DateTime.now().toUtc();

    if (result.outcome == WebDavAutoSyncOutcome.success) {
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markAutoSyncSucceeded(
            finishedAt,
            reason: result.reason.name,
            uploadedChanges: _deltaResult(result).uploadedChanges,
            uploadedPackages: _deltaResult(result).uploadedPackages,
            downloadedPackages: _deltaResult(result).downloadedPackages,
            appliedRemoteChanges: _deltaResult(result).appliedRemoteChanges,
            remoteConflicts: _deltaResult(result).remoteConflicts,
          );
    } else if (result.outcome == WebDavAutoSyncOutcome.failed) {
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markAutoSyncFailed(
            finishedAt,
            result.error?.toString() ?? '自动同步失败',
            reason: result.reason.name,
          );
    }

    state = state.copyWith(
      isRunning: false,
      lastOutcome: result.outcome,
      lastErrorMessage: result.error?.toString(),
      lastSucceededAt: result.outcome == WebDavAutoSyncOutcome.success
          ? finishedAt
          : null,
      lastFailedAt: result.outcome == WebDavAutoSyncOutcome.failed
          ? finishedAt
          : null,
      clearLastErrorMessage: result.error == null,
    );

    if (result.outcome == WebDavAutoSyncOutcome.success) {
      _refreshMoneyAfterDeltaSync(ref, _deltaResult(result));
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
    }
    ref.invalidate(webDavSyncMetadataProvider);

    return result;
  }

  void _scheduleNext(int uploadIntervalMinutes) {
    _cancelTimer();
    final interval = Duration(minutes: uploadIntervalMinutes);
    final nextRunAt = DateTime.now().toUtc().add(interval);
    state = state.copyWith(nextRunAt: nextRunAt);
    _timer = Timer(interval, () async {
      await run(WebDavAutoSyncReason.interval);
      await refresh();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

DeltaSyncResult _deltaResult(WebDavAutoSyncResult result) {
  final syncResult = result.syncResult;
  return syncResult is DeltaSyncResult ? syncResult : DeltaSyncResult.empty;
}

class WebDavSyncActionController extends Notifier<WebDavSyncActionState> {
  static const _maxRemoteSnapshots = 3;

  @override
  WebDavSyncActionState build() {
    return WebDavSyncActionState.idle;
  }

  Future<T> _perform<T>(
    WebDavSyncActionOperation operation,
    Future<T> Function() action,
  ) async {
    state = WebDavSyncActionState.loading(operation);
    try {
      final result = await action();
      state = WebDavSyncActionState.idle;
      return result;
    } catch (error, stackTrace) {
      state = WebDavSyncActionState.failure(operation, error);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> saveConfig(WebDavConfig config) {
    return _perform(WebDavSyncActionOperation.saveConfig, () async {
      await ref.read(webDavConfigStoreProvider).writeConfig(config);
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
    });
  }

  Future<void> clearConfig() {
    return _perform(WebDavSyncActionOperation.clearConfig, () async {
      await ref.read(webDavConfigStoreProvider).clearConfig();
      await ref.read(webDavSyncMetadataStoreProvider).clearMetadata();
      await ref.read(webDavSyncPreferencesStoreProvider).clearPreferences();
      await ref.read(webDavSyncSecretStoreProvider).clearSnapshotPassword();
      ref.invalidate(webDavConfigProvider);
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
      ref.invalidate(webDavSyncMetadataProvider);
      ref.invalidate(webDavSyncPreferencesProvider);
      ref.invalidate(webDavSyncPasswordSavedProvider);
    });
  }

  Future<void> saveSyncPreferences(WebDavSyncPreferences preferences) {
    return _perform(WebDavSyncActionOperation.saveSyncPreferences, () async {
      await ref
          .read(webDavSyncPreferencesStoreProvider)
          .writePreferences(preferences);
      ref.invalidate(webDavSyncPreferencesProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
    });
  }

  Future<void> saveAutoSyncPassword(String password) {
    return _perform(WebDavSyncActionOperation.saveAutoSyncPassword, () async {
      await ref
          .read(webDavSyncSecretStoreProvider)
          .writeSnapshotPassword(password);
      ref.invalidate(webDavSyncPasswordSavedProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
    });
  }

  Future<void> clearAutoSyncPassword() {
    return _perform(WebDavSyncActionOperation.clearAutoSyncPassword, () async {
      await ref.read(webDavSyncSecretStoreProvider).clearSnapshotPassword();
      ref.invalidate(webDavSyncPasswordSavedProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
    });
  }

  Future<void> testConnection() {
    return _perform(WebDavSyncActionOperation.testConnection, () async {
      final config = await ref.read(webDavConfigProvider.future);
      if (!config.isConfigured) {
        throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
      }
      await ref.read(webDavClientProvider).testConnection(config);
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
    });
  }

  Future<void> syncNow() {
    return _perform(WebDavSyncActionOperation.deltaSyncNow, () async {
      final config = await ref.read(webDavConfigProvider.future);
      if (!config.isConfigured) {
        throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
      }

      final password = await ref
          .read(webDavSyncSecretStoreProvider)
          .readSnapshotPassword();
      if (password == null || password.isEmpty) {
        throw const WebDavSyncException(WebDavSyncErrorCode.passwordMissing);
      }

      final result = await ref.read(deltaSyncServiceProvider).syncNow(password);
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markAutoSyncSucceeded(
            DateTime.now().toUtc(),
            reason: WebDavAutoSyncReason.manual.name,
            uploadedChanges: result.uploadedChanges,
            uploadedPackages: result.uploadedPackages,
            downloadedPackages: result.downloadedPackages,
            appliedRemoteChanges: result.appliedRemoteChanges,
            remoteConflicts: result.remoteConflicts,
          );
      ref.invalidate(webDavSyncMetadataProvider);
      ref.invalidate(webDavSyncDiagnosticsProvider);
      ref.invalidate(currentUserOpenDeltaConflictsProvider);
      _refreshMoneyAfterDeltaSync(ref, result);
    });
  }

  Future<void> uploadLatestLocalSnapshot() {
    return _perform(
      WebDavSyncActionOperation.uploadLatestLocalSnapshot,
      () async {
        final config = await ref.read(webDavConfigProvider.future);
        if (!config.isConfigured) {
          throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
        }

        final localStatus = await ref.read(
          localDatabaseSnapshotStatusProvider.future,
        );
        final latest = localStatus.latestSnapshot;
        if (latest == null) {
          throw const WebDavSyncException(WebDavSyncErrorCode.noLocalSnapshot);
        }

        final client = ref.read(webDavClientProvider);
        await client.uploadSnapshot(config: config, file: latest.file);
        await client.pruneSnapshots(
          config: config,
          maxSnapshots: _maxRemoteSnapshots,
        );
        await ref
            .read(webDavSyncMetadataStoreProvider)
            .markUploaded(DateTime.now().toUtc());
        ref.invalidate(webDavRemoteSnapshotStatusProvider);
        ref.invalidate(webDavSyncMetadataProvider);
        ref.invalidate(webDavSyncPreferencesProvider);
        ref.invalidate(webDavSyncPasswordSavedProvider);
        ref.invalidate(webDavAutoSyncControllerProvider);
      },
    );
  }

  Future<void> exportAndUploadSnapshot() {
    return _perform(
      WebDavSyncActionOperation.exportAndUploadSnapshot,
      () async {
        final config = await ref.read(webDavConfigProvider.future);
        if (!config.isConfigured) {
          throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
        }

        final password = await ref
            .read(webDavSyncSecretStoreProvider)
            .readSnapshotPassword();
        if (password == null || password.isEmpty) {
          throw const WebDavSyncException(WebDavSyncErrorCode.passwordMissing);
        }

        final exported = await ref
            .read(databaseSnapshotActionProvider.notifier)
            .exportSnapshot(password);
        final client = ref.read(webDavClientProvider);
        await client.uploadSnapshot(
          config: config,
          file: exported.snapshot.file,
        );
        await client.pruneSnapshots(
          config: config,
          maxSnapshots: _maxRemoteSnapshots,
        );
        await ref
            .read(webDavSyncMetadataStoreProvider)
            .markUploaded(DateTime.now().toUtc());
        ref.invalidate(localDatabaseSnapshotStatusProvider);
        ref.invalidate(webDavRemoteSnapshotStatusProvider);
        ref.invalidate(webDavSyncMetadataProvider);
      },
    );
  }

  Future<void> restoreLatestRemoteSnapshot(String password) async {
    final remoteStatus = await ref.read(
      webDavRemoteSnapshotStatusProvider.future,
    );
    final latest = remoteStatus.latestSnapshot;
    if (latest == null) {
      throw const WebDavSyncException(WebDavSyncErrorCode.noRemoteSnapshot);
    }
    return restoreRemoteSnapshot(snapshot: latest, password: password);
  }

  Future<void> restoreRemoteSnapshot({
    required WebDavRemoteSnapshotInfo snapshot,
    required String password,
  }) async {
    state = WebDavSyncActionState.loading(
      WebDavSyncActionOperation.downloadRemoteSnapshot,
    );
    try {
      final config = await ref.read(webDavConfigProvider.future);
      if (!config.isConfigured) {
        throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
      }

      final tempDir = await ref
          .read(databaseFileResolverProvider)
          .tempDirectory();
      final file = await ref
          .read(webDavClientProvider)
          .downloadSnapshot(
            config: config,
            snapshot: snapshot,
            targetDirectory: tempDir,
          );

      state = WebDavSyncActionState.loading(
        WebDavSyncActionOperation.restoreRemoteSnapshot,
      );
      await withWebDavRestoreApplyTimeout(
        ref
            .read(databaseSnapshotActionProvider.notifier)
            .restoreSnapshot(file, password),
      );
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markRestored(DateTime.now().toUtc());
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
      ref.invalidate(webDavSyncMetadataProvider);
      ref.invalidate(webDavSyncDiagnosticsProvider);
      ref.invalidate(webDavSyncPreferencesProvider);
      ref.invalidate(webDavSyncPasswordSavedProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
      ref.read(moneyDataRefreshCoordinatorProvider).refreshAllMoneyData();
      state = WebDavSyncActionState.idle;
    } catch (error, stackTrace) {
      state = WebDavSyncActionState.failure(
        WebDavSyncActionOperation.restoreRemoteSnapshot,
        error,
      );
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> deleteRemoteSnapshot(WebDavRemoteSnapshotInfo snapshot) {
    return _perform(WebDavSyncActionOperation.deleteRemoteSnapshot, () async {
      final config = await ref.read(webDavConfigProvider.future);
      if (!config.isConfigured) {
        throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
      }

      await ref
          .read(webDavClientProvider)
          .deleteSnapshot(config: config, snapshot: snapshot);
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markDeleted(DateTime.now().toUtc());
      ref.invalidate(webDavRemoteSnapshotStatusProvider);
      ref.invalidate(webDavSyncMetadataProvider);
      ref.invalidate(webDavSyncDiagnosticsProvider);
      ref.invalidate(webDavSyncPreferencesProvider);
      ref.invalidate(webDavSyncPasswordSavedProvider);
      ref.invalidate(webDavAutoSyncControllerProvider);
    });
  }
}
