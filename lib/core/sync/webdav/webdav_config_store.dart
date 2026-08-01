import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:miji/core/sync/webdav/webdav_models.dart';

abstract class WebDavConfigStore {
  Future<WebDavConfig> readConfig();

  Future<void> writeConfig(WebDavConfig config);

  Future<void> clearConfig();
}

class FlutterSecureWebDavConfigStore implements WebDavConfigStore {
  const FlutterSecureWebDavConfigStore([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const _configKey = 'sync.webdav.config';

  final FlutterSecureStorage _storage;

  @override
  Future<WebDavConfig> readConfig() async {
    final value = await _storage.read(key: _configKey);
    if (value == null || value.trim().isEmpty) {
      return WebDavConfig.empty;
    }

    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      return WebDavConfig.empty;
    }

    return WebDavConfig.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<void> writeConfig(WebDavConfig config) {
    return _storage.write(key: _configKey, value: jsonEncode(config.toJson()));
  }

  @override
  Future<void> clearConfig() {
    return _storage.delete(key: _configKey);
  }
}
