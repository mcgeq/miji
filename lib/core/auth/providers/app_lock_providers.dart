import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/data/app_lock_store.dart';
import 'package:miji/core/auth/domain/app_lock.dart';
import 'package:miji/core/security/security_providers.dart';

final appLockStoreProvider = Provider<AppLockStore>((ref) {
  return FlutterSecureAppLockStore(
    credentialHasher: ref.watch(appLockCredentialHasherProvider),
  );
});

final appLockSettingsProvider = FutureProvider.family<AppLockSettings, String>((
  ref,
  userId,
) {
  return ref.watch(appLockStoreProvider).readSettings(userId);
});
