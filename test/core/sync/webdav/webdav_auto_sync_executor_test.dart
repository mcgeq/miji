import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/webdav/webdav_auto_sync_executor.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';

void main() {
  const configured = WebDavConfig(
    providerType: WebDavProviderType.nutstore,
    endpointUrl: '',
    username: 'user',
    password: 'password',
    remoteDirectory: '.miji/snapshots',
  );

  test('skips when WebDAV is not configured', () async {
    var syncCount = 0;
    final executor = WebDavAutoSyncExecutor(
      readConfig: () async => WebDavConfig.empty,
      readPreferences: () async =>
          WebDavSyncPreferences.defaults.copyWith(autoUploadEnabled: true),
      readPassword: () async => 'snapshot-password',
      syncNow: (_) async => syncCount += 1,
    );

    final result = await executor.run(WebDavAutoSyncReason.interval);

    expect(result.outcome, WebDavAutoSyncOutcome.configMissing);
    expect(syncCount, 0);
  });

  test('skips automatic runs when auto upload is disabled', () async {
    var syncCount = 0;
    final executor = WebDavAutoSyncExecutor(
      readConfig: () async => configured,
      readPreferences: () async => WebDavSyncPreferences.defaults,
      readPassword: () async => 'snapshot-password',
      syncNow: (_) async => syncCount += 1,
    );

    final result = await executor.run(WebDavAutoSyncReason.interval);

    expect(result.outcome, WebDavAutoSyncOutcome.autoUploadDisabled);
    expect(syncCount, 0);
  });

  test('skips when snapshot password was not saved', () async {
    var syncCount = 0;
    final executor = WebDavAutoSyncExecutor(
      readConfig: () async => configured,
      readPreferences: () async =>
          WebDavSyncPreferences.defaults.copyWith(autoUploadEnabled: true),
      readPassword: () async => null,
      syncNow: (_) async => syncCount += 1,
    );

    final result = await executor.run(WebDavAutoSyncReason.interval);

    expect(result.outcome, WebDavAutoSyncOutcome.passwordMissing);
    expect(syncCount, 0);
  });

  test('runs sync with saved snapshot password', () async {
    final passwords = <String>[];
    final executor = WebDavAutoSyncExecutor(
      readConfig: () async => configured,
      readPreferences: () async =>
          WebDavSyncPreferences.defaults.copyWith(autoUploadEnabled: true),
      readPassword: () async => 'snapshot-password',
      syncNow: (password) async => passwords.add(password),
    );

    final result = await executor.run(WebDavAutoSyncReason.interval);

    expect(result.outcome, WebDavAutoSyncOutcome.success);
    expect(passwords, ['snapshot-password']);
  });

  test(
    'runs conflict resolved sync even when auto upload is disabled',
    () async {
      var syncCount = 0;
      final executor = WebDavAutoSyncExecutor(
        readConfig: () async => configured,
        readPreferences: () async => WebDavSyncPreferences.defaults,
        readPassword: () async => 'snapshot-password',
        syncNow: (_) async {
          syncCount += 1;
          return 'delta-result';
        },
      );

      final result = await executor.run(WebDavAutoSyncReason.conflictResolved);

      expect(result.outcome, WebDavAutoSyncOutcome.success);
      expect(result.syncResult, 'delta-result');
      expect(syncCount, 1);
    },
  );
  test('does not run concurrent sync jobs', () async {
    final completer = Completer<void>();
    var syncCount = 0;
    final executor = WebDavAutoSyncExecutor(
      readConfig: () async => configured,
      readPreferences: () async =>
          WebDavSyncPreferences.defaults.copyWith(autoUploadEnabled: true),
      readPassword: () async => 'snapshot-password',
      syncNow: (_) async {
        syncCount += 1;
        await completer.future;
        return null;
      },
    );

    final first = executor.run(WebDavAutoSyncReason.interval);
    final second = await executor.run(WebDavAutoSyncReason.interval);
    completer.complete();

    expect(second.outcome, WebDavAutoSyncOutcome.alreadyRunning);
    expect((await first).outcome, WebDavAutoSyncOutcome.success);
    expect(syncCount, 1);
  });
}
