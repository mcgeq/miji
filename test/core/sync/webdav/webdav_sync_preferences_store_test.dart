import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:miji/core/sync/webdav/webdav_sync_preferences_store.dart';

void main() {
  group('SharedPreferencesWebDavSyncPreferencesStore', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns default preferences when nothing was saved', () async {
      final store = SharedPreferencesWebDavSyncPreferencesStore();

      final preferences = await store.readPreferences();

      expect(preferences.autoUploadEnabled, isFalse);
      expect(preferences.uploadOnStartupEnabled, isFalse);
      expect(preferences.uploadIntervalMinutes, 60);
    });

    test('saves and reads sync preferences', () async {
      final store = SharedPreferencesWebDavSyncPreferencesStore();
      const preferences = WebDavSyncPreferences(
        autoUploadEnabled: true,
        uploadOnStartupEnabled: true,
        uploadIntervalMinutes: 180,
      );

      await store.writePreferences(preferences);

      final saved = await store.readPreferences();
      expect(saved.autoUploadEnabled, isTrue);
      expect(saved.uploadOnStartupEnabled, isTrue);
      expect(saved.uploadIntervalMinutes, 180);
    });

    test('normalizes unsupported intervals to default interval', () async {
      final store = SharedPreferencesWebDavSyncPreferencesStore();
      const preferences = WebDavSyncPreferences(
        autoUploadEnabled: true,
        uploadOnStartupEnabled: true,
        uploadIntervalMinutes: 999,
      );

      await store.writePreferences(preferences);

      final saved = await store.readPreferences();
      expect(saved.uploadIntervalMinutes, 60);
    });

    test('clears preferences', () async {
      final store = SharedPreferencesWebDavSyncPreferencesStore();
      await store.writePreferences(
        const WebDavSyncPreferences(
          autoUploadEnabled: true,
          uploadOnStartupEnabled: true,
          uploadIntervalMinutes: 180,
        ),
      );

      await store.clearPreferences();

      final preferences = await store.readPreferences();
      expect(preferences, WebDavSyncPreferences.defaults);
    });
  });
}
