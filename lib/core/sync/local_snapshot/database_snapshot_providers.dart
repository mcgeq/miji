import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/core/sync/local_snapshot/database_file_resolver.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_crypto.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_models.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_service.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

final databaseFileResolverProvider = Provider<DatabaseFileResolver>((ref) {
  return const DatabaseFileResolver();
});

final databaseSnapshotCryptoProvider = Provider<DatabaseSnapshotCrypto>((ref) {
  return DatabaseSnapshotCrypto();
});

final databaseSnapshotServiceProvider = Provider<DatabaseSnapshotService>((
  ref,
) {
  return DatabaseSnapshotService(
    database: ref.watch(appDatabaseProvider),
    resolver: ref.watch(databaseFileResolverProvider),
    crypto: ref.watch(databaseSnapshotCryptoProvider),
  );
});

final localDatabaseSnapshotStatusProvider =
    FutureProvider<LocalDatabaseSnapshotStatus>((ref) {
      return ref.watch(databaseSnapshotServiceProvider).loadStatus();
    });

final databaseSnapshotActionProvider =
    NotifierProvider<DatabaseSnapshotActionController, AsyncValue<void>>(
      DatabaseSnapshotActionController.new,
    );

class DatabaseSnapshotActionController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncData<void>(null);
  }

  Future<ExportDatabaseSnapshotResult> exportSnapshot(String password) async {
    state = const AsyncLoading();
    try {
      await ref.read(syncIdentityResolverProvider).readIdentity();
      final result = await ref
          .read(databaseSnapshotServiceProvider)
          .exportSnapshot(password);
      ref.invalidate(localDatabaseSnapshotStatusProvider);
      state = const AsyncData<void>(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<RestoreDatabaseSnapshotResult> restoreLatestSnapshot(
    String password,
  ) async {
    final status = await ref.read(localDatabaseSnapshotStatusProvider.future);
    final snapshot = status.latestSnapshot;
    if (snapshot == null) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    return restoreSnapshot(snapshot.file, password);
  }

  Future<RestoreDatabaseSnapshotResult> restoreSnapshot(
    File snapshotFile,
    String password,
  ) async {
    state = const AsyncLoading();
    var enteredRestoreMode = false;
    try {
      final result = await ref
          .read(databaseSnapshotServiceProvider)
          .restoreSnapshot(
            snapshotFile: snapshotFile,
            password: password,
            beforeDatabaseClose: () async {
              enteredRestoreMode = true;
              ref.read(databaseRestoreModeProvider.notifier).enter();
              ref.read(authSessionControllerProvider.notifier).clear();
              ref.invalidate(globalDatabaseSeedProvider);
              ref.invalidate(currentUserDatabaseSeedProvider);
            },
          );

      if (enteredRestoreMode) {
        ref.read(databaseRestoreModeProvider.notifier).leave();
      }
      ref.invalidate(appDatabaseProvider);
      final restoredDatabase = ref.read(appDatabaseProvider);
      await _resetSyncRuntimeState(restoredDatabase);
      await _refreshDerivedMoneyData();
      ref.invalidate(globalDatabaseSeedProvider);
      ref.invalidate(currentUserDatabaseSeedProvider);
      ref.invalidate(localDatabaseSnapshotStatusProvider);

      state = const AsyncData<void>(null);
      return result;
    } catch (error, stackTrace) {
      if (enteredRestoreMode) {
        ref.read(databaseRestoreModeProvider.notifier).leave();
        ref.invalidate(globalDatabaseSeedProvider);
        ref.invalidate(currentUserDatabaseSeedProvider);
      }
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _resetSyncRuntimeState(AppDatabase database) async {
    await database.customStatement('DELETE FROM sync_change_logs');
    await database.customStatement('DELETE FROM delta_conflicts');
    await database.customStatement(
      "DELETE FROM sync_metadata WHERE key LIKE 'sync.delta.remoteCursor.%'",
    );
  }

  Future<void> _refreshDerivedMoneyData() async {
    try {
      ref.invalidate(moneyRepositoryProvider);
      await ref.read(moneyRepositoryProvider).refreshUsageStatsForAllUsers();
    } catch (_) {
      // Usage stats are derived cache. Snapshot restore must not depend on it.
    }
  }
}
