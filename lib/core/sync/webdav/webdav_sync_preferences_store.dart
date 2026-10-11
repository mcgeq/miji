import 'package:shared_preferences/shared_preferences.dart';

class WebDavSyncPreferences {
  const WebDavSyncPreferences({
    required this.autoUploadEnabled,
    required this.uploadOnStartupEnabled,
    required this.uploadIntervalMinutes,
  });

  final bool autoUploadEnabled;
  final bool uploadOnStartupEnabled;
  final int uploadIntervalMinutes;

  static const supportedIntervals = [15, 30, 60, 180, 360, 720, 1440];

  static const defaults = WebDavSyncPreferences(
    autoUploadEnabled: false,
    uploadOnStartupEnabled: false,
    uploadIntervalMinutes: 60,
  );

  WebDavSyncPreferences copyWith({
    bool? autoUploadEnabled,
    bool? uploadOnStartupEnabled,
    int? uploadIntervalMinutes,
  }) {
    return WebDavSyncPreferences(
      autoUploadEnabled: autoUploadEnabled ?? this.autoUploadEnabled,
      uploadOnStartupEnabled:
          uploadOnStartupEnabled ?? this.uploadOnStartupEnabled,
      uploadIntervalMinutes: _normalizeInterval(
        uploadIntervalMinutes ?? this.uploadIntervalMinutes,
      ),
    );
  }

  static int _normalizeInterval(int value) {
    return supportedIntervals.contains(value)
        ? value
        : defaults.uploadIntervalMinutes;
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is WebDavSyncPreferences &&
            other.autoUploadEnabled == autoUploadEnabled &&
            other.uploadOnStartupEnabled == uploadOnStartupEnabled &&
            other.uploadIntervalMinutes == uploadIntervalMinutes;
  }

  @override
  int get hashCode => Object.hash(
    autoUploadEnabled,
    uploadOnStartupEnabled,
    uploadIntervalMinutes,
  );
}

abstract class WebDavSyncPreferencesStore {
  Future<WebDavSyncPreferences> readPreferences();

  Future<void> writePreferences(WebDavSyncPreferences preferences);

  Future<void> clearPreferences();
}

class SharedPreferencesWebDavSyncPreferencesStore
    implements WebDavSyncPreferencesStore {
  const SharedPreferencesWebDavSyncPreferencesStore();

  static const _autoUploadEnabledKey = 'sync.webdav.autoUploadEnabled';
  static const _uploadOnStartupEnabledKey =
      'sync.webdav.uploadOnStartupEnabled';
  static const _uploadIntervalMinutesKey = 'sync.webdav.uploadIntervalMinutes';

  @override
  Future<WebDavSyncPreferences> readPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    return WebDavSyncPreferences.defaults.copyWith(
      autoUploadEnabled:
          preferences.getBool(_autoUploadEnabledKey) ??
          WebDavSyncPreferences.defaults.autoUploadEnabled,
      uploadOnStartupEnabled:
          preferences.getBool(_uploadOnStartupEnabledKey) ??
          WebDavSyncPreferences.defaults.uploadOnStartupEnabled,
      uploadIntervalMinutes:
          preferences.getInt(_uploadIntervalMinutesKey) ??
          WebDavSyncPreferences.defaults.uploadIntervalMinutes,
    );
  }

  @override
  Future<void> writePreferences(WebDavSyncPreferences preferences) async {
    final storage = await SharedPreferences.getInstance();
    final normalized = preferences.copyWith();
    await storage.setBool(_autoUploadEnabledKey, normalized.autoUploadEnabled);
    await storage.setBool(
      _uploadOnStartupEnabledKey,
      normalized.uploadOnStartupEnabled,
    );
    await storage.setInt(
      _uploadIntervalMinutesKey,
      normalized.uploadIntervalMinutes,
    );
  }

  @override
  Future<void> clearPreferences() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_autoUploadEnabledKey);
    await preferences.remove(_uploadOnStartupEnabledKey);
    await preferences.remove(_uploadIntervalMinutesKey);
  }
}
