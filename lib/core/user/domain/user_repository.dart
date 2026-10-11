import 'package:miji/core/user/domain/user_entity.dart';

abstract class UserRepository {
  Future<UserEntity?> getActiveUser();

  Future<UserEntity?> getUserById(String userId);

  Future<void> updateAvatarUri(String userId, String? avatarUri);
}

enum UserRepositoryErrorCode { databaseReadFailed, databaseWriteFailed }

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.code, [this.cause]);

  final UserRepositoryErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'UserRepositoryException($code, cause: $cause)';
  }
}
