import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/sync/background_sync/background_sync_dispatcher.dart';
import 'package:miji/core/sync/webdav/webdav_auto_sync_executor.dart';
import 'package:miji/core/sync/webdav/webdav_providers.dart';

final backgroundSyncDispatcherProvider = Provider<BackgroundSyncDispatcher>((
  ref,
) {
  return BackgroundSyncDispatcher(
    runSync: (_) async {
      final result = await ref
          .read(webDavAutoSyncControllerProvider.notifier)
          .run(WebDavAutoSyncReason.conflictResolved);
      if (result.outcome != WebDavAutoSyncOutcome.success) {
        throw BackgroundSyncException(
          'WebDAV sync ended with ${result.outcome.name}',
        );
      }
    },
    onFailure: ({required reason, required error}) async {
      await ref
          .read(webDavSyncMetadataStoreProvider)
          .markAutoSyncFailed(
            DateTime.now().toUtc(),
            error.toString(),
            reason: WebDavAutoSyncReason.conflictResolved.name,
          );
      ref.invalidate(webDavSyncMetadataProvider);
    },
  );
});

final backgroundSyncTriggerProvider =
    Provider<Future<void> Function(BackgroundSyncReason)>((ref) {
      return ref.watch(backgroundSyncDispatcherProvider).trigger;
    });
