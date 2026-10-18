import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class CredentialHasher {
  CredentialHasher({this.iterations = 120000, this.bits = 256, Random? random})
    : _random = random ?? Random.secure();

  static const algorithm = 'pbkdf2-hmac-sha256';

  final int iterations;
  final int bits;
  final Random _random;

  Future<CredentialVerifier> createVerifier(String credential) async {
    final salt = _randomBytes(16);
    final verifier = await _derive(credential: credential, salt: salt);

    return CredentialVerifier(
      algorithm: algorithm,
      iterations: iterations,
      salt: base64Encode(salt),
      verifier: base64Encode(verifier),
    );
  }

  Future<bool> verify({
    required String credential,
    required CredentialVerifier verifier,
  }) async {
    if (verifier.algorithm != algorithm) {
      return false;
    }

    final salt = base64Decode(verifier.salt);
    final expected = base64Decode(verifier.verifier);
    final actual = await _derive(
      credential: credential,
      salt: salt,
      iterationsOverride: verifier.iterations,
    );

    return _constantTimeEquals(actual, expected);
  }

  List<int> _randomBytes(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }

  Future<List<int>> _derive({
    required String credential,
    required List<int> salt,
    int? iterationsOverride,
  }) async {
    final pbkdf2 = Pbkdf2.hmacSha256(
      iterations: iterationsOverride ?? iterations,
      bits: bits,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: credential,
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }
}

class CredentialVerifier {
  const CredentialVerifier({
    required this.algorithm,
    required this.iterations,
    required this.salt,
    required this.verifier,
  });

  final String algorithm;
  final int iterations;
  final String salt;
  final String verifier;

  Map<String, Object?> toJson() {
    return {
      'algorithm': algorithm,
      'iterations': iterations,
      'salt': salt,
      'verifier': verifier,
    };
  }

  factory CredentialVerifier.fromJson(Map<String, Object?> json) {
    return CredentialVerifier(
      algorithm: json['algorithm'] as String,
      iterations: json['iterations'] as int,
      salt: json['salt'] as String,
      verifier: json['verifier'] as String,
    );
  }
}
