import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/security/credential_hasher.dart';

abstract class AppLockStore {
  Future<AppLockSettings> readSettings(String userId);

  Future<void> setEnabled(String userId, bool enabled);

  Future<void> saveCredential({
    required String userId,
    required AppLockMethod method,
    required String secret,
  });

  Future<bool> verify({required String userId, required String secret});
}

abstract class SecureValueStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});
}

class FlutterSecureValueStore implements SecureValueStore {
  const FlutterSecureValueStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) {
    return _storage.read(key: key);
  }

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class FlutterSecureAppLockStore implements AppLockStore {
  FlutterSecureAppLockStore({
    SecureValueStore storage = const FlutterSecureValueStore(),
    CredentialHasher? credentialHasher,
  }) : this._(storage, credentialHasher ?? CredentialHasher());

  const FlutterSecureAppLockStore._(this._storage, this._credentialHasher);

  final SecureValueStore _storage;
  final CredentialHasher _credentialHasher;

  @override
  Future<AppLockSettings> readSettings(String userId) async {
    final enabled = await _storage.read(key: _enabledKey(userId)) == 'true';
    final method = AppLockMethod.fromStorageValue(
      await _storage.read(key: _methodKey(userId)),
    );
    final verifier = await _storage.read(key: _verifierKey(userId));

    return AppLockSettings(
      enabled: enabled,
      method: method,
      hasCredential: verifier != null && verifier.isNotEmpty,
    );
  }

  @override
  Future<void> setEnabled(String userId, bool enabled) {
    return _storage.write(key: _enabledKey(userId), value: enabled.toString());
  }

  @override
  Future<void> saveCredential({
    required String userId,
    required AppLockMethod method,
    required String secret,
  }) async {
    final validationError = validateAppLockSecret(method, secret);
    if (validationError != null) {
      throw AppLockStoreException(validationError);
    }

    final verifier = await _credentialHasher.createVerifier(
      normalizeAppLockSecret(method, secret),
    );
    await _storage.write(key: _methodKey(userId), value: method.storageValue);
    await _storage.write(
      key: _verifierKey(userId),
      value: jsonEncode(verifier.toJson()),
    );
  }

  @override
  Future<bool> verify({required String userId, required String secret}) async {
    final lockState = await _readLockState(userId);
    final settings = lockState.settings;
    if (!settings.canLock) {
      return true;
    }
    final validationError = validateAppLockSecret(settings.method, secret);
    if (validationError != null) {
      return false;
    }

    final encodedVerifier = lockState.encodedVerifier;
    if (encodedVerifier == null || encodedVerifier.isEmpty) {
      return false;
    }
    final decoded = jsonDecode(encodedVerifier);
    if (decoded is! Map) {
      return false;
    }
    final verifierJson = <String, Object?>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };

    return _credentialHasher.verify(
      credential: normalizeAppLockSecret(settings.method, secret),
      verifier: CredentialVerifier.fromJson(verifierJson),
    );
  }

  String _enabledKey(String userId) => 'app_lock.$userId.enabled';

  String _methodKey(String userId) => 'app_lock.$userId.method';

  String _verifierKey(String userId) => 'app_lock.$userId.verifier';

  Future<_StoredAppLockState> _readLockState(String userId) async {
    final encodedVerifier = await _storage.read(key: _verifierKey(userId));
    final settings = AppLockSettings(
      enabled: await _storage.read(key: _enabledKey(userId)) == 'true',
      method: AppLockMethod.fromStorageValue(
        await _storage.read(key: _methodKey(userId)),
      ),
      hasCredential: encodedVerifier != null && encodedVerifier.isNotEmpty,
    );

    return _StoredAppLockState(
      settings: settings,
      encodedVerifier: encodedVerifier,
    );
  }
}

class AppLockStoreException implements Exception {
  const AppLockStoreException(this.validationError);

  final AppLockValidationError validationError;
}

class _StoredAppLockState {
  const _StoredAppLockState({
    required this.settings,
    required this.encodedVerifier,
  });

  final AppLockSettings settings;
  final String? encodedVerifier;
}
