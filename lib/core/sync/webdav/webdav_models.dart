enum WebDavProviderType {
  nutstore,
  teraCloud,
  nextcloud,
  custom;

  String get label {
    return switch (this) {
      WebDavProviderType.nutstore => '坚果云',
      WebDavProviderType.teraCloud => 'TeraCloud',
      WebDavProviderType.nextcloud => 'Nextcloud / ownCloud',
      WebDavProviderType.custom => '自定义 WebDAV',
    };
  }

  String get defaultEndpointUrl {
    return switch (this) {
      WebDavProviderType.nutstore => 'https://dav.jianguoyun.com/dav/',
      WebDavProviderType.teraCloud => '',
      WebDavProviderType.nextcloud => '',
      WebDavProviderType.custom => '',
    };
  }

  bool get needsEndpointInput {
    return switch (this) {
      WebDavProviderType.nutstore => false,
      WebDavProviderType.teraCloud => true,
      WebDavProviderType.nextcloud => true,
      WebDavProviderType.custom => true,
    };
  }

  static WebDavProviderType fromName(String? value) {
    for (final type in WebDavProviderType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return WebDavProviderType.custom;
  }
}

class WebDavConfig {
  const WebDavConfig({
    required this.providerType,
    required this.endpointUrl,
    required this.username,
    required this.password,
    required this.remoteDirectory,
  });

  final WebDavProviderType providerType;
  final String endpointUrl;
  final String username;
  final String password;
  final String remoteDirectory;

  String get effectiveEndpointUrl {
    final defaultUrl = providerType.defaultEndpointUrl;
    if (defaultUrl.isNotEmpty) {
      return defaultUrl;
    }
    return endpointUrl.trim();
  }

  bool get isConfigured =>
      effectiveEndpointUrl.isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;

  Map<String, Object?> toJson() {
    return {
      'providerType': providerType.name,
      'endpointUrl': endpointUrl,
      'username': username,
      'password': password,
      'remoteDirectory': _normalizeRemoteDirectory(remoteDirectory),
    };
  }

  factory WebDavConfig.fromJson(Map<String, Object?> json) {
    final providerType = WebDavProviderType.fromName(
      json['providerType'] as String?,
    );
    return WebDavConfig(
      providerType: providerType,
      endpointUrl: (json['endpointUrl'] as String?)?.trim() ?? '',
      username: (json['username'] as String?)?.trim() ?? '',
      password: json['password'] as String? ?? '',
      remoteDirectory: _normalizeRemoteDirectory(
        json['remoteDirectory'] as String?,
      ),
    );
  }

  static const empty = WebDavConfig(
    providerType: WebDavProviderType.nutstore,
    endpointUrl: '',
    username: '',
    password: '',
    remoteDirectory: '.miji/snapshots',
  );
}

String _normalizeRemoteDirectory(String? value) {
  final directory = (value ?? '').trim();
  if (directory.isEmpty) {
    return '.miji/snapshots';
  }

  final normalized = directory.replaceAll('\\', '/').toLowerCase();
  if (normalized == '.miji' ||
      normalized == '/.miji' ||
      normalized == '.miji/' ||
      normalized == '/.miji/' ||
      normalized == 'miji' ||
      normalized == '/miji' ||
      normalized == 'miji/' ||
      normalized == '/miji/' ||
      normalized == '.miji/snapshots' ||
      normalized == '/.miji/snapshots' ||
      normalized == '.miji/snapshots/' ||
      normalized == '/.miji/snapshots/' ||
      normalized == 'miji/snapshots' ||
      normalized == '/miji/snapshots' ||
      normalized == 'miji/snapshots/' ||
      normalized == '/miji/snapshots/') {
    return '.miji/snapshots';
  }

  return directory;
}

class WebDavRemoteSnapshotInfo {
  const WebDavRemoteSnapshotInfo({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.updatedAt,
  });

  final String fileName;
  final Uri url;
  final int sizeBytes;
  final DateTime? updatedAt;
}

class WebDavRemoteFileInfo {
  const WebDavRemoteFileInfo({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.updatedAt,
  });

  final String fileName;
  final Uri url;
  final int sizeBytes;
  final DateTime? updatedAt;
}

class WebDavRemoteSnapshotStatus {
  const WebDavRemoteSnapshotStatus({
    required this.config,
    required this.snapshots,
  });

  final WebDavConfig config;
  final List<WebDavRemoteSnapshotInfo> snapshots;

  bool get isConfigured => config.isConfigured;
  WebDavRemoteSnapshotInfo? get latestSnapshot =>
      snapshots.isEmpty ? null : snapshots.first;
}

enum WebDavSyncErrorCode {
  configMissing,
  invalidConfig,
  connectionFailed,
  remoteDirectoryUnavailable,
  passwordMissing,
  uploadFailed,
  downloadFailed,
  deleteFailed,
  restoreTimedOut,
  noLocalSnapshot,
  noRemoteSnapshot,
}

class WebDavSyncException implements Exception {
  const WebDavSyncException(this.code, [this.cause]);

  final WebDavSyncErrorCode code;
  final Object? cause;

  @override
  String toString() => 'WebDavSyncException($code, $cause)';
}
