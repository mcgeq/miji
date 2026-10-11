import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/webdav/webdav_models.dart';

void main() {
  group('WebDavConfig', () {
    test('normalizes legacy remote directory values when reading config', () {
      for (final value in const [
        '',
        '.miji',
        '/.miji',
        '.miji/',
        '/.miji/',
        'miji',
        '/miji',
        'miji/',
        '/miji/',
        '.miji/snapshots',
        '/.miji/snapshots',
        '.miji/snapshots/',
        '/.miji/snapshots/',
        'miji/snapshots',
        '/miji/snapshots',
        'miji/snapshots/',
        '/miji/snapshots/',
      ]) {
        final config = WebDavConfig.fromJson({
          'providerType': WebDavProviderType.nutstore.name,
          'endpointUrl': '',
          'username': 'user',
          'password': 'password',
          'remoteDirectory': value,
        });

        expect(config.remoteDirectory, '.miji/snapshots');
      }
    });

    test('stores normalized remote directory values', () {
      const config = WebDavConfig(
        providerType: WebDavProviderType.nutstore,
        endpointUrl: '',
        username: 'user',
        password: 'password',
        remoteDirectory: 'miji',
      );

      expect(config.toJson()['remoteDirectory'], '.miji/snapshots');
    });
  });
}
