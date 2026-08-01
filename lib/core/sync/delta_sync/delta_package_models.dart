import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class DeltaPackageMetadata {
  const DeltaPackageMetadata({
    required this.datasetId,
    required this.deviceId,
    required this.sequence,
    required this.createdAt,
  });

  final String datasetId;
  final String deviceId;
  final int sequence;
  final DateTime createdAt;

  Map<String, Object?> toJson() {
    return {
      'datasetId': datasetId,
      'deviceId': deviceId,
      'sequence': sequence,
      'createdAt': createdAt.toUtc().toIso8601String(),
    };
  }

  factory DeltaPackageMetadata.fromJson(Map<String, Object?> json) {
    return DeltaPackageMetadata(
      datasetId: json['datasetId'] as String,
      deviceId: json['deviceId'] as String,
      sequence: json['sequence'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }
}

class DeltaChangeRecord {
  const DeltaChangeRecord({
    required this.table,
    required this.recordId,
    required this.operation,
    required this.baseVersion,
    required this.newVersion,
    required this.changedFields,
    required this.recordSnapshot,
  });

  final String table;
  final String recordId;
  final String operation;
  final int? baseVersion;
  final int? newVersion;
  final Map<String, Object?> changedFields;
  final Map<String, Object?> recordSnapshot;

  Map<String, Object?> toJson() {
    return {
      'table': table,
      'recordId': recordId,
      'operation': operation,
      'baseVersion': baseVersion,
      'newVersion': newVersion,
      'changedFields': changedFields,
      'recordSnapshot': recordSnapshot,
    };
  }

  factory DeltaChangeRecord.fromJson(Map<String, Object?> json) {
    return DeltaChangeRecord(
      table: json['table'] as String,
      recordId: json['recordId'] as String,
      operation: json['operation'] as String,
      baseVersion: json['baseVersion'] as int?,
      newVersion: json['newVersion'] as int?,
      changedFields: _objectMap(json['changedFields']),
      recordSnapshot: _objectMap(json['recordSnapshot']),
    );
  }
}

class DeltaPackagePayload {
  const DeltaPackagePayload({required this.changes});

  final List<DeltaChangeRecord> changes;

  Map<String, Object?> toJson() {
    return {'changes': changes.map((change) => change.toJson()).toList()};
  }

  factory DeltaPackagePayload.fromJson(Map<String, Object?> json) {
    final changes = json['changes'] as List<dynamic>? ?? const <dynamic>[];
    return DeltaPackagePayload(
      changes: changes
          .map((change) => DeltaChangeRecord.fromJson(_objectMap(change)))
          .toList(growable: false),
    );
  }
}

class DeltaPackage {
  const DeltaPackage({required this.metadata, required this.payload});

  final DeltaPackageMetadata metadata;
  final DeltaPackagePayload payload;
}

class DeltaPackageCodec {
  DeltaPackageCodec({Random? random}) : _random = random ?? Random.secure();

  static const format = 'miji.delta.v1';
  static const kdfAlgorithm = 'pbkdf2-hmac-sha256';
  static const cipherAlgorithm = 'aes-gcm-256';
  static const kdfIterations = 210000;
  static const keyBits = 256;

  final Random _random;

  Future<List<int>> encode({
    required DeltaPackage package,
    required String password,
  }) async {
    final payloadBytes = utf8.encode(jsonEncode(package.payload.toJson()));
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final secretKey = await _deriveKey(password: password, salt: salt);
    final secretBox = await AesGcm.with256bits().encrypt(
      payloadBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final envelope = {
      'format': format,
      ...package.metadata.toJson(),
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
    return utf8.encode(jsonEncode(envelope));
  }

  Future<DeltaPackage> decode({
    required List<int> bytes,
    required String password,
  }) async {
    final envelope = _objectMap(jsonDecode(utf8.decode(bytes)));
    if (envelope['format'] != format) {
      throw const DeltaPackageFormatException('Invalid delta package format');
    }

    final kdf = _objectMap(envelope['kdf']);
    final cipher = _objectMap(envelope['cipher']);
    if (kdf['algorithm'] != kdfAlgorithm ||
        cipher['algorithm'] != cipherAlgorithm) {
      throw const DeltaPackageFormatException('Invalid delta package cipher');
    }

    final salt = base64Decode(kdf['salt'] as String);
    final nonce = base64Decode(cipher['nonce'] as String);
    final mac = Mac(base64Decode(cipher['mac'] as String));
    final cipherText = base64Decode(envelope['payload'] as String);
    final secretKey = await _deriveKey(password: password, salt: salt);
    final payloadBytes = await AesGcm.with256bits().decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: secretKey,
    );
    final payload = DeltaPackagePayload.fromJson(
      _objectMap(jsonDecode(utf8.decode(payloadBytes))),
    );

    return DeltaPackage(
      metadata: DeltaPackageMetadata.fromJson(envelope),
      payload: payload,
    );
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

class DeltaPackageFormatException implements Exception {
  const DeltaPackageFormatException(this.message);

  final String message;

  @override
  String toString() => 'DeltaPackageFormatException($message)';
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map) {
    throw const DeltaPackageFormatException('Expected JSON object');
  }
  return value.map((key, value) {
    if (key is! String) {
      throw const DeltaPackageFormatException('Expected string JSON key');
    }
    return MapEntry(key, value as Object?);
  });
}
