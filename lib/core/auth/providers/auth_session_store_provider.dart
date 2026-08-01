import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/data/auth_session_store.dart';

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return const FlutterSecureAuthSessionStore();
});
