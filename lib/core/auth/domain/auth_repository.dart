class LocalRegistrationRequest {
  const LocalRegistrationRequest({
    required this.username,
    required this.displayName,
    required this.passcode,
    required this.email,
    this.phoneNumber,
    this.deviceId,
  });

  final String username;
  final String displayName;
  final String passcode;
  final String email;
  final String? phoneNumber;
  final String? deviceId;
}

class LocalRegistrationResult {
  const LocalRegistrationResult({required this.userId});

  final String userId;
}

class LocalLoginRequest {
  const LocalLoginRequest({required this.email, required this.passcode});

  final String email;
  final String passcode;
}

class LocalLoginResult {
  const LocalLoginResult({required this.userId});

  final String userId;
}

class LocalUnlockRequest {
  const LocalUnlockRequest({required this.userId, required this.passcode});

  final String userId;
  final String passcode;
}

class LocalUnlockResult {
  const LocalUnlockResult({required this.userId});

  final String userId;
}

class LocalPasswordChangeRequest {
  const LocalPasswordChangeRequest({
    required this.userId,
    required this.currentPasscode,
    required this.newPasscode,
  });

  final String userId;
  final String currentPasscode;
  final String newPasscode;
}

abstract class AuthRepository {
  Future<bool> isOnboardingRequired();

  Future<bool> isUsernameAvailable(String username);

  Future<bool> isEmailAvailable(String email);

  Future<LocalRegistrationResult> registerLocalUser(
    LocalRegistrationRequest request,
  );

  Future<LocalLoginResult> loginLocalUser(LocalLoginRequest request);

  Future<LocalUnlockResult> unlockLocalUser(LocalUnlockRequest request);

  Future<void> changeLocalPassword(LocalPasswordChangeRequest request);
}

enum AuthRepositoryErrorCode {
  userAlreadyExists,
  usernameAlreadyExists,
  emailAlreadyExists,
  phoneAlreadyExists,
  invalidCredential,
  databaseWriteFailed,
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException(this.code, [this.cause]);

  final AuthRepositoryErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'AuthRepositoryException($code, cause: $cause)';
  }
}
