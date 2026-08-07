import 'package:drift/drift.dart';

import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/preferences/domain/preferences_repository.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';

class DriftPreferencesRepository implements PreferencesRepository {
  const DriftPreferencesRepository({required this.database});

  final AppDatabase database;

  @override
  Future<UserPreferencesEntity?> getPreferencesForUser(String userId) async {
    try {
      final preferences =
          await (database.select(database.userPreferences)
                ..where((preferences) => preferences.userId.equals(userId))
                ..limit(1))
              .getSingleOrNull();

      return preferences == null ? null : _mapPreferences(preferences);
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateThemeMode(
    String userId,
    AppThemeModePreference themeMode,
  ) async {
    try {
      final updatedRows =
          await (database.update(
            database.userPreferences,
          )..where((preferences) => preferences.userId.equals(userId))).write(
            UserPreferencesCompanion(
              themeMode: Value(themeMode.storageValue),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

      if (updatedRows == 0) {
        throw const PreferencesRepositoryException(
          PreferencesRepositoryErrorCode.preferencesNotFound,
        );
      }
    } on PreferencesRepositoryException {
      rethrow;
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateThemeSeedColor(String userId, int themeSeedColor) async {
    try {
      final updatedRows =
          await (database.update(
            database.userPreferences,
          )..where((preferences) => preferences.userId.equals(userId))).write(
            UserPreferencesCompanion(
              themeSeedColor: Value(themeSeedColor),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

      if (updatedRows == 0) {
        throw const PreferencesRepositoryException(
          PreferencesRepositoryErrorCode.preferencesNotFound,
        );
      }
    } on PreferencesRepositoryException {
      rethrow;
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateCurrencyCode(String userId, String currencyCode) async {
    try {
      final updatedRows =
          await (database.update(
            database.userPreferences,
          )..where((preferences) => preferences.userId.equals(userId))).write(
            UserPreferencesCompanion(
              currencyCode: Value(currencyCode.trim().toUpperCase()),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

      if (updatedRows == 0) {
        throw const PreferencesRepositoryException(
          PreferencesRepositoryErrorCode.preferencesNotFound,
        );
      }
    } on PreferencesRepositoryException {
      rethrow;
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateSensitiveAccessTtl(
    String userId,
    SensitiveAccessTtlOption ttlOption,
  ) async {
    try {
      final updatedRows =
          await (database.update(
            database.userPreferences,
          )..where((preferences) => preferences.userId.equals(userId))).write(
            UserPreferencesCompanion(
              sensitiveAccessTtl: Value(ttlOption.storageValue),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

      if (updatedRows == 0) {
        throw const PreferencesRepositoryException(
          PreferencesRepositoryErrorCode.preferencesNotFound,
        );
      }
    } on PreferencesRepositoryException {
      rethrow;
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateShowHomeTodayAction(String userId, bool show) async {
    try {
      final updatedRows =
          await (database.update(
            database.userPreferences,
          )..where((preferences) => preferences.userId.equals(userId))).write(
            UserPreferencesCompanion(
              showHomeTodayAction: Value(show),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );

      if (updatedRows == 0) {
        throw const PreferencesRepositoryException(
          PreferencesRepositoryErrorCode.preferencesNotFound,
        );
      }
    } on PreferencesRepositoryException {
      rethrow;
    } catch (error) {
      throw PreferencesRepositoryException(
        PreferencesRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  UserPreferencesEntity _mapPreferences(UserPreference preferences) {
    return UserPreferencesEntity(
      userId: preferences.userId,
      themeMode: AppThemeModePreference.fromStorageValue(preferences.themeMode),
      themeSeedColor: preferences.themeSeedColor,
      sensitiveAccessTtl: SensitiveAccessTtlOption.fromStorageValue(
        preferences.sensitiveAccessTtl,
      ),
      locale: preferences.locale,
      timezone: preferences.timezone,
      currencyCode: preferences.currencyCode,
      showHomeTodayAction: preferences.showHomeTodayAction,
      createdAt: preferences.createdAt,
      updatedAt: preferences.updatedAt,
    );
  }
}
