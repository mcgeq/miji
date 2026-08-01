import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';

final databaseSeedRunnerProvider = Provider<DatabaseSeedRunner>((ref) {
  return DatabaseSeedRunner(database: ref.watch(appDatabaseProvider));
});

final globalDatabaseSeedProvider = FutureProvider<void>((ref) {
  if (ref.watch(databaseRestoreModeProvider)) {
    return Future.value();
  }

  return ref.watch(databaseSeedRunnerProvider).seedGlobalDefaults();
});

final currentUserDatabaseSeedProvider = FutureProvider<void>((ref) {
  if (ref.watch(databaseRestoreModeProvider)) {
    return Future.value();
  }

  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return Future.value();
  }

  return ref
      .watch(databaseSeedRunnerProvider)
      .seedUserDefaults(session.userId!);
});
