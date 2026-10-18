import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/user/data/drift_user_repository.dart';
import 'package:miji/core/user/domain/user_entity.dart';
import 'package:miji/core/user/domain/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return DriftUserRepository(database: ref.watch(appDatabaseProvider));
});

final userByIdProvider = FutureProvider.family<UserEntity?, String>((
  ref,
  userId,
) {
  return ref.watch(userRepositoryProvider).getUserById(userId);
});

final currentUserProvider = FutureProvider<UserEntity?>((ref) {
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }

  return ref.watch(userByIdProvider(session.userId!).future);
});
