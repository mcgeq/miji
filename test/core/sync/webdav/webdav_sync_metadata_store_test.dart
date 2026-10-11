import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/sync/webdav/webdav_sync_metadata_store.dart';

void main() {
  group('SharedPreferencesWebDavSyncMetadataStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test(
      'returns empty metadata when no sync operation has been recorded',
      () async {
        final store = SharedPreferencesWebDavSyncMetadataStore();

        final metadata = await store.readMetadata();

        expect(metadata.lastUploadedAt, isNull);
        expect(metadata.lastRestoredAt, isNull);
        expect(metadata.lastDeletedAt, isNull);
        expect(metadata.lastAutoSyncStartedAt, isNull);
        expect(metadata.lastAutoSyncSucceededAt, isNull);
        expect(metadata.lastAutoSyncFailedAt, isNull);
        expect(metadata.lastAutoSyncError, isNull);
        expect(metadata.recentSyncActivities, isEmpty);
        expect(metadata.recentSyncActivities, isEmpty);
      },
    );

    test(
      'records upload, restore, and delete timestamps independently',
      () async {
        final store = SharedPreferencesWebDavSyncMetadataStore();
        final uploadedAt = DateTime.utc(2026, 7, 10, 8);
        final restoredAt = DateTime.utc(2026, 7, 10, 9);
        final deletedAt = DateTime.utc(2026, 7, 10, 10);

        await store.markUploaded(uploadedAt);
        await store.markRestored(restoredAt);
        await store.markDeleted(deletedAt);

        final metadata = await store.readMetadata();
        expect(metadata.lastUploadedAt, uploadedAt);
        expect(metadata.lastRestoredAt, restoredAt);
        expect(metadata.lastDeletedAt, deletedAt);
      },
    );

    test('records auto sync lifecycle metadata', () async {
      final store = SharedPreferencesWebDavSyncMetadataStore();
      final startedAt = DateTime.utc(2026, 7, 10, 8);
      final succeededAt = DateTime.utc(2026, 7, 10, 8, 1);
      final failedAt = DateTime.utc(2026, 7, 10, 9);

      await store.markAutoSyncStarted(startedAt);
      await store.markAutoSyncSucceeded(
        succeededAt,
        reason: 'interval',
        uploadedChanges: 2,
        uploadedPackages: 1,
        downloadedPackages: 3,
        appliedRemoteChanges: 4,
        remoteConflicts: 1,
      );
      await store.markAutoSyncFailed(failedAt, 'network timeout');

      final metadata = await store.readMetadata();
      expect(metadata.lastAutoSyncStartedAt, startedAt);
      expect(metadata.lastAutoSyncSucceededAt, succeededAt);
      expect(metadata.lastAutoSyncFailedAt, failedAt);
      expect(metadata.lastAutoSyncError, 'network timeout');
      expect(metadata.recentSyncActivities, hasLength(2));
      expect(metadata.recentSyncActivities.first.outcome, 'failed');
      expect(
        metadata.recentSyncActivities.first.errorMessage,
        'network timeout',
      );
      expect(metadata.recentSyncActivities.last.outcome, 'success');
      expect(metadata.recentSyncActivities.last.reason, 'interval');
      expect(metadata.recentSyncActivities.last.uploadedChanges, 2);
      expect(metadata.recentSyncActivities.last.uploadedPackages, 1);
      expect(metadata.recentSyncActivities.last.downloadedPackages, 3);
      expect(metadata.recentSyncActivities.last.appliedRemoteChanges, 4);
      expect(metadata.recentSyncActivities.last.remoteConflicts, 1);
    });

    test('keeps newest sync activity history entries only', () async {
      final store = SharedPreferencesWebDavSyncMetadataStore();

      for (var index = 0; index < 12; index += 1) {
        await store.markAutoSyncSucceeded(
          DateTime.utc(2026, 7, 10, 8, index),
          reason: 'interval',
        );
      }

      final metadata = await store.readMetadata();
      expect(metadata.recentSyncActivities, hasLength(10));
      expect(
        metadata.recentSyncActivities.first.finishedAt,
        DateTime.utc(2026, 7, 10, 8, 11),
      );
      expect(
        metadata.recentSyncActivities.last.finishedAt,
        DateTime.utc(2026, 7, 10, 8, 2),
      );
    });
    test('clears recorded metadata', () async {
      final store = SharedPreferencesWebDavSyncMetadataStore();
      await store.markUploaded(DateTime.utc(2026, 7, 10, 8));
      await store.markRestored(DateTime.utc(2026, 7, 10, 9));
      await store.markDeleted(DateTime.utc(2026, 7, 10, 10));
      await store.markAutoSyncStarted(DateTime.utc(2026, 7, 10, 11));
      await store.markAutoSyncSucceeded(DateTime.utc(2026, 7, 10, 12));
      await store.markAutoSyncFailed(DateTime.utc(2026, 7, 10, 13), 'failed');
      expect((await store.readMetadata()).recentSyncActivities, isNotEmpty);

      await store.clearMetadata();

      final metadata = await store.readMetadata();
      expect(metadata.lastUploadedAt, isNull);
      expect(metadata.lastRestoredAt, isNull);
      expect(metadata.lastDeletedAt, isNull);
      expect(metadata.lastAutoSyncStartedAt, isNull);
      expect(metadata.lastAutoSyncSucceededAt, isNull);
      expect(metadata.lastAutoSyncFailedAt, isNull);
      expect(metadata.lastAutoSyncError, isNull);
      expect(metadata.recentSyncActivities, isEmpty);
    });
  });
}
