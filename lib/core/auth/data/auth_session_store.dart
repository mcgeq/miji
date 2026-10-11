import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AuthSessionStore {
  Future<String?> readLastUserId();

  Future<void> writeLastUserId(String userId);

  Future<void> clearLastUserId();
}

class FlutterSecureAuthSessionStore implements AuthSessionStore {
  const FlutterSecureAuthSessionStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _lastUserIdKey = 'auth.last_user_id';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readLastUserId() {
    return _storage.read(key: _lastUserIdKey);
  }

  @override
  Future<void> writeLastUserId(String userId) {
    return _storage.write(key: _lastUserIdKey, value: userId);
  }

  @override
  Future<void> clearLastUserId() {
    return _storage.delete(key: _lastUserIdKey);
  }
}
