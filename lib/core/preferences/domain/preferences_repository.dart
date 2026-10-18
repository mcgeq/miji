import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';

abstract class PreferencesRepository {
  Future<UserPreferencesEntity?> getPreferencesForUser(String userId);

  Future<void> updateThemeMode(String userId, AppThemeModePreference themeMode);

  Future<void> updateCurrencyCode(String userId, String currencyCode);

  Future<void> updateSensitiveAccessTtl(
    String userId,
    SensitiveAccessTtlOption ttlOption,
  );

  Future<void> updateShowHomeTodayAction(String userId, bool show);

  Future<void> updateMaskMoneyAmounts(String userId, bool mask);

  Future<void> updateShowHomeHealthStrip(String userId, bool show);

  Future<void> updateHomeBlockVisibility(String userId, String? json);

  Future<void> updateHomeBlockOrder(String userId, String? json);

  Future<void> updateHomeLayoutMode(String userId, String mode);

  Future<void> updateHomePagerTabs(String userId, bool show);

  /// 时薪面板的界面偏好（JSON）。传 null 表示清空、回到默认。
  Future<void> updateLifeEnergyPrefs(String userId, String? json);
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
