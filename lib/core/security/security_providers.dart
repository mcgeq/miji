import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/security/credential_hasher.dart';

const appLockCredentialIterations = 30000;

final credentialHasherProvider = Provider<CredentialHasher>((ref) {
  return CredentialHasher();
});

final appLockCredentialHasherProvider = Provider<CredentialHasher>((ref) {
  return CredentialHasher(iterations: appLockCredentialIterations);
});
