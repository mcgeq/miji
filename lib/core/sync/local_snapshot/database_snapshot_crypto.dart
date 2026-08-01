import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'package:miji/core/sync/local_snapshot/database_snapshot_models.dart';

class DatabaseSnapshotCrypto {
  DatabaseSnapshotCrypto({Random? random})
    : _random = random ?? Random.secure();

  static const format = 'miji.snapshot.v1';
  static const kdfAlgorithm = 'pbkdf2-hmac-sha256';
  static const cipherAlgorithm = 'aes-gcm-256';
  static const kdfIterations = 210000;
  static const keyBits = 256;

  final Random _random;

  Future<Map<String, Object?>> encrypt({
    required List<int> databaseBytes,
    required String password,
    required int schemaVersion,
    required DateTime createdAt,
  }) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveKey(password: password, salt: salt);
    final secretBox = await AesGcm.with256bits().encrypt(
      databaseBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    return {
      'format': format,
      'createdAt': createdAt.toIso8601String(),
      'schemaVersion': schemaVersion,
      'kdf': {
        'algorithm': kdfAlgorithm,
        'iterations': kdfIterations,
        'salt': base64Encode(salt),
      },
      'cipher': {
        'algorithm': cipherAlgorithm,
        'nonce': base64Encode(nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      },
      'payload': base64Encode(secretBox.cipherText),
    };
  }

  Future<List<int>> decrypt({
    required Map<String, Object?> envelope,
    required String password,
  }) async {
    if (envelope['format'] != format) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    final kdf = _stringMap(envelope['kdf']);
    final cipher = _stringMap(envelope['cipher']);
    final payload = envelope['payload'] as String?;
    if (payload == null) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    if (kdf['algorithm'] != kdfAlgorithm ||
        cipher['algorithm'] != cipherAlgorithm) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    try {
      final salt = base64Decode(kdf['salt'] as String);
      final nonce = base64Decode(cipher['nonce'] as String);
      final mac = Mac(base64Decode(cipher['mac'] as String));
      final cipherText = base64Decode(payload);
      final secretKey = await _deriveKey(password: password, salt: salt);

      return await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: secretKey,
      );
    } on SecretBoxAuthenticationError catch (error) {
      throw DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidPassword,
        error,
      );
    } on FormatException catch (error) {
      throw DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
        error,
      );
    } on TypeError catch (error) {
      throw DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
        error,
      );
    }
  }

  Map<String, Object?> _stringMap(Object? value) {
    if (value is! Map) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    return value.map((key, value) {
      if (key is! String) {
        throw const DatabaseSnapshotException(
          DatabaseSnapshotErrorCode.invalidSnapshotFormat,
        );
      }
      return MapEntry(key, value as Object?);
    });
  }

  Future<SecretKey> _deriveKey({
    required String password,
    required List<int> salt,
  }) {
    return Pbkdf2.hmacSha256(
      iterations: kdfIterations,
      bits: keyBits,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}
