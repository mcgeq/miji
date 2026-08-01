import 'package:drift/drift.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/user/domain/user_entity.dart';
import 'package:miji/core/user/domain/user_repository.dart';

class DriftUserRepository implements UserRepository {
  const DriftUserRepository({required this.database});

  final AppDatabase database;

  @override
  Future<UserEntity?> getActiveUser() async {
    try {
      final user =
          await (database.select(database.users)
                ..where((user) => user.isDeleted.equals(false))
                ..limit(1))
              .getSingleOrNull();

      return user == null ? null : _mapUser(user);
    } catch (error) {
      throw UserRepositoryException(
        UserRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<UserEntity?> getUserById(String userId) async {
    try {
      final user =
          await (database.select(database.users)
                ..where(
                  (user) =>
                      user.id.equals(userId) & user.isDeleted.equals(false),
                )
                ..limit(1))
              .getSingleOrNull();

      return user == null ? null : _mapUser(user);
    } catch (error) {
      throw UserRepositoryException(
        UserRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateAvatarUri(String userId, String? avatarUri) async {
    try {
      final updated =
          await (database.update(database.users)..where(
                (user) => user.id.equals(userId) & user.isDeleted.equals(false),
              ))
              .write(
                UsersCompanion(
                  avatarUri: Value<String?>(avatarUri),
                  updatedAt: Value(DateTime.now().toUtc()),
                ),
              );

      if (updated == 0) {
        throw const UserRepositoryException(
          UserRepositoryErrorCode.databaseWriteFailed,
        );
      }
    } on UserRepositoryException {
      rethrow;
    } catch (error) {
      throw UserRepositoryException(
        UserRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  UserEntity _mapUser(User user) {
    return UserEntity(
      id: user.id,
      username: user.username,
      email: user.email,
      emailVerifiedAt: user.emailVerifiedAt,
      phoneNumber: user.phoneNumber,
      phoneVerifiedAt: user.phoneVerifiedAt,
      displayName: user.displayName,
      avatarUri: user.avatarUri,
      remoteUserId: user.remoteUserId,
      syncEnabled: user.syncEnabled,
      lastSyncedAt: user.lastSyncedAt,
      deviceId: user.deviceId,
      version: user.version,
      isDeleted: user.isDeleted,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
}
