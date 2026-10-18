import 'package:miji/core/sync/webdav/webdav_models.dart';

const webDavRestoreApplyTimeout = Duration(seconds: 30);

Future<T> withWebDavRestoreApplyTimeout<T>(
  Future<T> operation, {
  Duration timeout = webDavRestoreApplyTimeout,
}) {
  return operation.timeout(
    timeout,
    onTimeout: () {
      throw const WebDavSyncException(WebDavSyncErrorCode.restoreTimedOut);
    },
  );
}
