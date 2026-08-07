import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';

abstract class PreferencesRepository {
  Future<UserPreferencesEntity?> getPreferencesForUser(String userId);

  Future<void> updateThemeMode(String userId, AppThemeModePreference themeMode);

  Future<void> updateThemeSeedColor(String userId, int themeSeedColor);

  Future<void> updateCurrencyCode(String userId, String currencyCode);

  Future<void> updateSensitiveAccessTtl(
    String userId,
    SensitiveAccessTtlOption ttlOption,
  );

  Future<void> updateShowHomeTodayAction(String userId, bool show);
}

enum PreferencesRepositoryErrorCode {
  preferencesNotFound,
  databaseReadFailed,
  databaseWriteFailed,
}

class PreferencesRepositoryException implements Exception {
  const PreferencesRepositoryException(this.code, [this.cause]);

  final PreferencesRepositoryErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'PreferencesRepositoryException($code, cause: $cause)';
  }
}
