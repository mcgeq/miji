import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/security/security_providers.dart';
import 'package:miji/core/auth/data/drift_auth_repository.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return DriftAuthRepository(
    database: ref.watch(appDatabaseProvider),
    credentialHasher: ref.watch(credentialHasherProvider),
  );
});

final authOnboardingRequiredProvider = FutureProvider<bool>((ref) {
  return ref.watch(authRepositoryProvider).isOnboardingRequired();
});
