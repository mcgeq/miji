import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_store.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/core/sync/delta_sync/sync_identity_store.dart';

final syncIdentityResolverProvider = Provider<SyncIdentityResolver>((ref) {
  return SharedPreferencesSyncIdentityStore(
    database: ref.watch(appDatabaseProvider),
  );
});

final syncChangeLoggerProvider = Provider<SyncChangeLogger>((ref) {
  return SyncChangeLogger(
    database: ref.watch(appDatabaseProvider),
    identityResolver: ref.watch(syncIdentityResolverProvider),
  );
});

final deltaConflictStoreProvider = Provider<DeltaConflictStore>((ref) {
  return DriftDeltaConflictStore(database: ref.watch(appDatabaseProvider));
});

final currentUserOpenDeltaConflictsProvider =
    FutureProvider<List<StoredDeltaConflict>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (!session.isUnlocked || userId == null) {
        return const <StoredDeltaConflict>[];
      }

      return ref.watch(deltaConflictStoreProvider).listOpenConflicts(userId);
    });
