import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/security/credential_hasher.dart';
import 'package:miji/core/auth/domain/auth_repository.dart';

class DriftAuthRepository implements AuthRepository {
  DriftAuthRepository({
    required this.database,
    CredentialHasher? credentialHasher,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _credentialHasher = credentialHasher ?? CredentialHasher(),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  static const _credentialType = 'passcode';
  static const _defaultThemeSeedColor = 0xFFE45F4F;

  final AppDatabase database;
  final CredentialHasher _credentialHasher;
  final Uuid _uuid;
  final DateTime Function() _now;

  @override
  Future<bool> isOnboardingRequired() async {
    return !(await _hasActiveUserWhere((user) => user.isDeleted.equals(false)));
  }

  @override
  Future<bool> isUsernameAvailable(String username) async {
    final normalized = _normalizeUsername(username);
    return !(await _hasActiveUserWhere(
      (user) => user.username.equals(normalized) & user.isDeleted.equals(false),
    ));
  }

  @override
  Future<bool> isEmailAvailable(String email) async {
    final normalized = _normalizeRequired(email);
    return !(await _hasActiveUserWhere(
      (user) => user.email.equals(normalized) & user.isDeleted.equals(false),
    ));
  }

  @override
  Future<LocalRegistrationResult> registerLocalUser(
    LocalRegistrationRequest request,
  ) async {
    await _ensureNoActiveUser();

    final username = _normalizeUsername(request.username);
    final email = _normalizeRequired(request.email);
    final phoneNumber = _normalizeOptional(request.phoneNumber);
    final displayName = request.displayName.trim();

    await _ensureUsernameAvailable(username);
    await _ensureEmailAvailable(email);
    await _ensurePhoneAvailable(phoneNumber);

    final userId = _uuid.v4();
    final credentialId = _uuid.v4();
    final createdAt = _now().toUtc();
    final verifier = await _credentialHasher.createVerifier(request.passcode);

    try {
      await database.transaction(() async {
        await database
            .into(database.users)
            .insert(
              UsersCompanion.insert(
                id: userId,
                username: username,
                email: email,
                phoneNumber: Value(phoneNumber),
                displayName: displayName,
                deviceId: Value(request.deviceId),
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            );

        await database
            .into(database.authCredentials)
            .insert(
              AuthCredentialsCompanion.insert(
                id: credentialId,
                userId: userId,
                credentialType: _credentialType,
                algorithm: verifier.algorithm,
                iterations: verifier.iterations,
                salt: verifier.salt,
                verifier: verifier.verifier,
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            );

        await database
            .into(database.userPreferences)
            .insert(
              UserPreferencesCompanion.insert(
                userId: userId,
                themeSeedColor: _defaultThemeSeedColor,
                currencyCode: const Value('CNY'),
                createdAt: createdAt,
                updatedAt: createdAt,
              ),
            );
      });
    } catch (error) {
      throw AuthRepositoryException(
        AuthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }

    return LocalRegistrationResult(userId: userId);
  }

  @override
  Future<LocalLoginResult> loginLocalUser(LocalLoginRequest request) async {
    final email = _normalizeRequired(request.email);
    final user =
        await (database.select(database.users)
              ..where(
                (user) =>
                    user.email.equals(email) & user.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (user == null) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.invalidCredential,
      );
    }

    await _verifyPasscodeForUser(user.id, request.passcode);

    return LocalLoginResult(userId: user.id);
  }

  @override
  Future<LocalUnlockResult> unlockLocalUser(LocalUnlockRequest request) async {
    final user =
        await (database.select(database.users)
              ..where(
                (user) =>
                    user.id.equals(request.userId) &
                    user.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (user == null) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.invalidCredential,
      );
    }

    await _verifyPasscodeForUser(user.id, request.passcode);

    return LocalUnlockResult(userId: user.id);
  }

  @override
  Future<void> changeLocalPassword(LocalPasswordChangeRequest request) async {
    final user =
        await (database.select(database.users)
              ..where(
                (user) =>
                    user.id.equals(request.userId) &
                    user.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (user == null) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.invalidCredential,
      );
    }

    final credential = await _verifiedCredentialForUser(
      user.id,
      request.currentPasscode,
    );
    final verifier = await _credentialHasher.createVerifier(
      request.newPasscode,
    );
    final updatedAt = _now().toUtc();

    try {
      final updatedRows =
          await (database.update(database.authCredentials)..where(
                (credentialTable) => credentialTable.id.equals(credential.id),
              ))
              .write(
                AuthCredentialsCompanion(
                  algorithm: Value(verifier.algorithm),
                  iterations: Value(verifier.iterations),
                  salt: Value(verifier.salt),
                  verifier: Value(verifier.verifier),
                  updatedAt: Value(updatedAt),
                ),
              );

      if (updatedRows == 0) {
        throw const AuthRepositoryException(
          AuthRepositoryErrorCode.invalidCredential,
        );
      }
    } on AuthRepositoryException {
      rethrow;
    } catch (error) {
      throw AuthRepositoryException(
        AuthRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<void> _verifyPasscodeForUser(String userId, String passcode) async {
    await _verifiedCredentialForUser(userId, passcode);
  }

  Future<AuthCredential> _verifiedCredentialForUser(
    String userId,
    String passcode,
  ) async {
    final credential =
        await (database.select(database.authCredentials)
              ..where(
                (credential) =>
                    credential.userId.equals(userId) &
                    credential.credentialType.equals(_credentialType),
              )
              ..limit(1))
            .getSingleOrNull();

    if (credential == null) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.invalidCredential,
      );
    }

    final verifier = CredentialVerifier(
      algorithm: credential.algorithm,
      iterations: credential.iterations,
      salt: credential.salt,
      verifier: credential.verifier,
    );

    final isValid = await _credentialHasher.verify(
      credential: passcode,
      verifier: verifier,
    );

    if (!isValid) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.invalidCredential,
      );
    }

    return credential;
  }

  Future<void> _ensureNoActiveUser() async {
    final hasActiveUser = await _hasActiveUserWhere(
      (user) => user.isDeleted.equals(false),
    );

    if (hasActiveUser) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.userAlreadyExists,
      );
    }
  }

  Future<void> _ensureUsernameAvailable(String username) async {
    final isAvailable = await isUsernameAvailable(username);

    if (!isAvailable) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.usernameAlreadyExists,
      );
    }
  }

  Future<void> _ensureEmailAvailable(String email) async {
    final isAvailable = await isEmailAvailable(email);

    if (!isAvailable) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.emailAlreadyExists,
      );
    }
  }

  Future<void> _ensurePhoneAvailable(String? phoneNumber) async {
    if (phoneNumber == null) {
      return;
    }

    final existingUser =
        await (database.select(database.users)
              ..where(
                (user) =>
                    user.phoneNumber.equals(phoneNumber) &
                    user.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existingUser != null) {
      throw const AuthRepositoryException(
        AuthRepositoryErrorCode.phoneAlreadyExists,
      );
    }
  }

  Future<bool> _hasActiveUserWhere(
    Expression<bool> Function($UsersTable user) predicate,
  ) async {
    final existingUser =
        await (database.select(database.users)
              ..where(predicate)
              ..limit(1))
            .getSingleOrNull();

    return existingUser != null;
  }

  String _normalizeUsername(String value) {
    return value.trim().toLowerCase();
  }

  String _normalizeRequired(String value) {
    return value.trim().toLowerCase();
  }

  String? _normalizeOptional(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
