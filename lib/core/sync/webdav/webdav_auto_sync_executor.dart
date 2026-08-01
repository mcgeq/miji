import 'package:miji/core/sync/webdav/webdav_models.dart';
import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';

enum WebDavAutoSyncReason { startup, interval, manual, conflictResolved }

enum WebDavAutoSyncOutcome {
  success,
  alreadyRunning,
  configMissing,
  autoUploadDisabled,
  passwordMissing,
  failed,
}

class WebDavAutoSyncResult {
  const WebDavAutoSyncResult({
    required this.reason,
    required this.outcome,
    this.error,
    this.syncResult,
  });

  final WebDavAutoSyncReason reason;
  final WebDavAutoSyncOutcome outcome;
  final Object? error;
  final Object? syncResult;
}

typedef WebDavConfigReader = Future<WebDavConfig> Function();
typedef WebDavSyncPreferencesReader = Future<WebDavSyncPreferences> Function();
typedef WebDavSyncPasswordReader = Future<String?> Function();
typedef WebDavSyncRunner = Future<Object?> Function(String password);

class WebDavAutoSyncExecutor {
  WebDavAutoSyncExecutor({
    required this.readConfig,
    required this.readPreferences,
    required this.readPassword,
    required this.syncNow,
  });

  final WebDavConfigReader readConfig;
  final WebDavSyncPreferencesReader readPreferences;
  final WebDavSyncPasswordReader readPassword;
  final WebDavSyncRunner syncNow;

  bool _running = false;

  bool get isRunning => _running;

  Future<WebDavAutoSyncResult> run(WebDavAutoSyncReason reason) async {
    if (_running) {
      return WebDavAutoSyncResult(
        reason: reason,
        outcome: WebDavAutoSyncOutcome.alreadyRunning,
      );
    }

    _running = true;
    try {
      final config = await readConfig();
      if (!config.isConfigured) {
        return WebDavAutoSyncResult(
          reason: reason,
          outcome: WebDavAutoSyncOutcome.configMissing,
        );
      }

      final preferences = await readPreferences();
      if (!_canRunWhenAutoUploadDisabled(reason) &&
          !preferences.autoUploadEnabled) {
        return WebDavAutoSyncResult(
          reason: reason,
          outcome: WebDavAutoSyncOutcome.autoUploadDisabled,
        );
      }

      final password = (await readPassword())?.trim();
      if (password == null || password.isEmpty) {
        return WebDavAutoSyncResult(
          reason: reason,
          outcome: WebDavAutoSyncOutcome.passwordMissing,
        );
      }

      final syncResult = await syncNow(password);
      return WebDavAutoSyncResult(
        reason: reason,
        outcome: WebDavAutoSyncOutcome.success,
        syncResult: syncResult,
      );
    } catch (error) {
      return WebDavAutoSyncResult(
        reason: reason,
        outcome: WebDavAutoSyncOutcome.failed,
        error: error,
      );
    } finally {
      _running = false;
    }
  }

  bool _canRunWhenAutoUploadDisabled(WebDavAutoSyncReason reason) {
    return reason == WebDavAutoSyncReason.manual ||
        reason == WebDavAutoSyncReason.conflictResolved;
  }
}
