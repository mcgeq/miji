import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/data/app_lock_store.dart';
import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/security/credential_hasher.dart';

void main() {
  test('verify reads the stored verifier only once', () async {
    final storage = _CountingSecureValueStore();
    final store = FlutterSecureAppLockStore(
      storage: storage,
      credentialHasher: CredentialHasher(iterations: 1),
    );

    await store.setEnabled('user-1', true);
    await store.saveCredential(
      userId: 'user-1',
      method: AppLockMethod.pin,
      secret: '123456',
    );

    final verified = await store.verify(userId: 'user-1', secret: '123456');

    expect(verified, isTrue);
    expect(storage.readCountFor('app_lock.user-1.verifier'), 1);
  });
}

class _CountingSecureValueStore implements SecureValueStore {
  final _values = <String, String>{};
  final _readCounts = <String, int>{};

  @override
  Future<String?> read({required String key}) async {
    _readCounts[key] = (_readCounts[key] ?? 0) + 1;
    return _values[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _values[key] = value;
  }

  int readCountFor(String key) => _readCounts[key] ?? 0;
}
