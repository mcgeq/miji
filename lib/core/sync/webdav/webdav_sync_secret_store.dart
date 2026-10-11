import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class WebDavSyncSecretStore {
  Future<String?> readSnapshotPassword();

  Future<bool> hasSnapshotPassword();

  Future<void> writeSnapshotPassword(String password);

  Future<void> clearSnapshotPassword();
}

class FlutterSecureWebDavSyncSecretStore implements WebDavSyncSecretStore {
  const FlutterSecureWebDavSyncSecretStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _snapshotPasswordKey = 'sync.webdav.snapshotPassword';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readSnapshotPassword() async {
    final value = await _storage.read(key: _snapshotPasswordKey);
    final password = value?.trim();
    return password == null || password.isEmpty ? null : password;
  }

  @override
  Future<bool> hasSnapshotPassword() async {
    return await readSnapshotPassword() != null;
  }

  @override
  Future<void> writeSnapshotPassword(String password) {
    return _storage.write(key: _snapshotPasswordKey, value: password.trim());
  }

  @override
  Future<void> clearSnapshotPassword() {
    return _storage.delete(key: _snapshotPasswordKey);
  }
}
