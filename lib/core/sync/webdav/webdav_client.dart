import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:miji/core/sync/webdav/webdav_models.dart';

class WebDavClient {
  WebDavClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 12),
              receiveTimeout: const Duration(seconds: 20),
              sendTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  final Dio _dio;

  Future<void> testConnection(WebDavConfig config) async {
    _ensureConfigured(config);
    await ensureRemoteDirectory(config);
    await listSnapshots(config);
  }

  Future<void> ensureRemoteDirectory(WebDavConfig config) async {
    _ensureConfigured(config);
    await ensureRemoteDirectoryPath(
      config: config,
      remoteDirectory: config.remoteDirectory,
    );
  }

  Future<void> ensureRemoteDirectoryPath({
    required WebDavConfig config,
    required String remoteDirectory,
  }) async {
    _ensureConfigured(config);
    final segments = _remoteDirectorySegments(remoteDirectory);
    var currentPath = '';

    for (final segment in segments) {
      currentPath = '$currentPath/$segment';
      final response = await _dio.request<void>(
        _resolve(config.effectiveEndpointUrl, currentPath).toString(),
        options: Options(method: 'MKCOL', headers: _headers(config)),
      );

      final status = response.statusCode ?? 0;
      if (status == 201 || status == 405) {
        continue;
      }
      if (status == 401 || status == 403 || status >= 400) {
        throw WebDavSyncException(
          WebDavSyncErrorCode.remoteDirectoryUnavailable,
          status,
        );
      }
    }
  }

  Future<WebDavRemoteFileInfo> uploadBytes({
    required WebDavConfig config,
    required String remoteDirectory,
    required String fileName,
    required List<int> bytes,
  }) async {
    _ensureConfigured(config);
    await ensureRemoteDirectoryPath(
      config: config,
      remoteDirectory: remoteDirectory,
    );

    final targetUrl = _remoteFileUrlForDirectory(
      config: config,
      remoteDirectory: remoteDirectory,
      fileName: fileName,
    );
    final response = await _dio.put<List<int>>(
      targetUrl.toString(),
      data: bytes,
      options: Options(
        headers: {
          ..._headers(config),
          Headers.contentLengthHeader: bytes.length,
          Headers.contentTypeHeader: 'application/octet-stream',
        },
      ),
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.uploadFailed, status);
    }

    return WebDavRemoteFileInfo(
      fileName: fileName,
      url: targetUrl,
      sizeBytes: bytes.length,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<List<WebDavRemoteFileInfo>> listFiles({
    required WebDavConfig config,
    required String remoteDirectory,
    String? extension,
  }) async {
    _ensureConfigured(config);
    final directoryUrl = _remoteDirectoryUrlForPath(config, remoteDirectory);
    final response = await _dio.request<String>(
      directoryUrl.toString(),
      data: '''<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength />
    <getlastmodified />
    <resourcetype />
  </prop>
</propfind>''',
      options: Options(
        method: 'PROPFIND',
        headers: {..._headers(config), 'Depth': '1'},
        responseType: ResponseType.plain,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 404) {
      return const [];
    }
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.connectionFailed, status);
    }

    final files = _parseRemoteFiles(
      response.data ?? '',
      directoryUrl: directoryUrl,
      config: config,
      extension: extension,
    );
    files.sort((a, b) {
      final sequenceCompare = a.fileName.compareTo(b.fileName);
      if (sequenceCompare != 0) {
        return sequenceCompare;
      }
      return a.url.toString().compareTo(b.url.toString());
    });
    return files;
  }

  Future<List<String>> listDirectoryNames({
    required WebDavConfig config,
    required String remoteDirectory,
  }) async {
    _ensureConfigured(config);
    final directoryUrl = _remoteDirectoryUrlForPath(config, remoteDirectory);
    final response = await _dio.request<String>(
      directoryUrl.toString(),
      data: '''<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <resourcetype />
  </prop>
</propfind>''',
      options: Options(
        method: 'PROPFIND',
        headers: {..._headers(config), 'Depth': '1'},
        responseType: ResponseType.plain,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 404) {
      return const [];
    }
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.connectionFailed, status);
    }

    final directories = _parseRemoteDirectoryNames(
      response.data ?? '',
      directoryUrl: directoryUrl,
    );
    directories.sort();
    return directories;
  }

  Future<List<int>> downloadBytes({
    required WebDavConfig config,
    required WebDavRemoteFileInfo file,
  }) async {
    _ensureConfigured(config);
    final response = await _dio.getUri<List<int>>(
      file.url,
      options: Options(
        headers: _headers(config),
        responseType: ResponseType.bytes,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.downloadFailed, status);
    }
    return response.data ?? const <int>[];
  }

  Future<List<WebDavRemoteSnapshotInfo>> listSnapshots(
    WebDavConfig config,
  ) async {
    _ensureConfigured(config);
    final directoryUrl = _remoteDirectoryUrl(config);
    final response = await _dio.request<String>(
      directoryUrl.toString(),
      data: '''<?xml version="1.0" encoding="utf-8" ?>
<propfind xmlns="DAV:">
  <prop>
    <getcontentlength />
    <getlastmodified />
    <resourcetype />
  </prop>
</propfind>''',
      options: Options(
        method: 'PROPFIND',
        headers: {..._headers(config), 'Depth': '1'},
        responseType: ResponseType.plain,
      ),
    );

    final status = response.statusCode ?? 0;
    if (status == 404) {
      return const [];
    }
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.connectionFailed, status);
    }

    final snapshots = _parseSnapshots(
      response.data ?? '',
      directoryUrl: directoryUrl,
      config: config,
    );
    snapshots.sort((a, b) {
      final left = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = right.compareTo(left);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return b.fileName.compareTo(a.fileName);
    });
    return snapshots;
  }

  Future<WebDavRemoteSnapshotInfo> uploadSnapshot({
    required WebDavConfig config,
    required File file,
  }) async {
    _ensureConfigured(config);
    if (!await file.exists()) {
      throw const WebDavSyncException(WebDavSyncErrorCode.noLocalSnapshot);
    }

    await ensureRemoteDirectory(config);
    final fileName = _fileName(file.path);
    final targetUrl = _remoteFileUrl(config, fileName);
    final response = await _dio.put<List<int>>(
      targetUrl.toString(),
      data: file.openRead(),
      options: Options(
        headers: {
          ..._headers(config),
          Headers.contentLengthHeader: await file.length(),
          Headers.contentTypeHeader: 'application/octet-stream',
        },
      ),
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.uploadFailed, status);
    }

    final stat = await file.stat();
    return WebDavRemoteSnapshotInfo(
      fileName: fileName,
      url: targetUrl,
      sizeBytes: stat.size,
      updatedAt: stat.modified.toUtc(),
    );
  }

  Future<File> downloadSnapshot({
    required WebDavConfig config,
    required WebDavRemoteSnapshotInfo snapshot,
    required Directory targetDirectory,
  }) async {
    _ensureConfigured(config);
    await targetDirectory.create(recursive: true);
    final targetFile = File(
      '${targetDirectory.path}${Platform.pathSeparator}${snapshot.fileName}',
    );
    final response = await _dio.downloadUri(
      snapshot.url,
      targetFile.path,
      options: Options(headers: _headers(config)),
    );

    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw WebDavSyncException(WebDavSyncErrorCode.downloadFailed, status);
    }
    return targetFile;
  }

  Future<void> deleteSnapshot({
    required WebDavConfig config,
    required WebDavRemoteSnapshotInfo snapshot,
  }) async {
    _ensureConfigured(config);
    try {
      final response = await _dio.deleteUri<void>(
        snapshot.url,
        options: Options(headers: _headers(config)),
      );

      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw WebDavSyncException(WebDavSyncErrorCode.deleteFailed, status);
      }
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      throw WebDavSyncException(
        WebDavSyncErrorCode.deleteFailed,
        status ?? error,
      );
    }
  }

  Future<void> pruneSnapshots({
    required WebDavConfig config,
    required int maxSnapshots,
  }) async {
    final snapshots = await listSnapshots(config);
    if (snapshots.length <= maxSnapshots) {
      return;
    }

    for (final snapshot in snapshots.skip(maxSnapshots)) {
      await deleteSnapshot(config: config, snapshot: snapshot);
    }
  }

  Map<String, String> _headers(WebDavConfig config) {
    final token = base64Encode(
      utf8.encode('${config.username}:${config.password}'),
    );
    return {'Authorization': 'Basic $token'};
  }

  Uri _remoteDirectoryUrl(WebDavConfig config) {
    return _remoteDirectoryUrlForPath(config, config.remoteDirectory);
  }

  Uri _remoteFileUrl(WebDavConfig config, String fileName) {
    return _remoteDirectoryUrl(config).resolve(Uri.encodeComponent(fileName));
  }

  Uri _remoteDirectoryUrlForPath(WebDavConfig config, String remoteDirectory) {
    return _resolve(
      config.effectiveEndpointUrl,
      _normalizeDirectory(remoteDirectory),
    );
  }

  Uri _remoteFileUrlForDirectory({
    required WebDavConfig config,
    required String remoteDirectory,
    required String fileName,
  }) {
    return _remoteDirectoryUrlForPath(
      config,
      remoteDirectory,
    ).resolve(Uri.encodeComponent(fileName));
  }

  Uri _resolve(String endpointUrl, String remotePath) {
    final base = endpointUrl.trim().endsWith('/')
        ? Uri.parse(endpointUrl.trim())
        : Uri.parse('${endpointUrl.trim()}/');
    final normalized = remotePath.startsWith('/')
        ? remotePath.substring(1)
        : remotePath;
    return base.resolve(normalized);
  }

  List<String> _remoteDirectorySegments(String remoteDirectory) {
    return remoteDirectory
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  String _normalizeDirectory(String value) {
    final segments = _remoteDirectorySegments(value);
    if (segments.isEmpty) {
      return '';
    }
    return '${segments.join('/')}/';
  }

  void _ensureConfigured(WebDavConfig config) {
    if (!config.isConfigured) {
      throw const WebDavSyncException(WebDavSyncErrorCode.configMissing);
    }
    final uri = Uri.tryParse(config.effectiveEndpointUrl.trim());
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const WebDavSyncException(WebDavSyncErrorCode.invalidConfig);
    }
  }

  List<WebDavRemoteSnapshotInfo> _parseSnapshots(
    String xml, {
    required Uri directoryUrl,
    required WebDavConfig config,
  }) {
    final responses = RegExp(
      r'<(?:d:)?response[\s\S]*?</(?:d:)?response>',
      caseSensitive: false,
    ).allMatches(xml);

    final snapshots = <WebDavRemoteSnapshotInfo>[];
    for (final response in responses) {
      final block = response.group(0) ?? '';
      final href = _tagText(block, 'href');
      if (href == null || href.endsWith('/')) {
        continue;
      }

      final fileName = Uri.decodeComponent(_fileName(href));
      if (!fileName.endsWith('.miji-snapshot')) {
        continue;
      }

      final lengthText = _tagText(block, 'getcontentlength');
      final modifiedText = _tagText(block, 'getlastmodified');
      snapshots.add(
        WebDavRemoteSnapshotInfo(
          fileName: fileName,
          url: _snapshotUrl(href, directoryUrl, config, fileName),
          sizeBytes: int.tryParse(lengthText ?? '') ?? 0,
          updatedAt: modifiedText == null
              ? null
              : HttpDate.parse(modifiedText).toUtc(),
        ),
      );
    }
    return snapshots;
  }

  List<WebDavRemoteFileInfo> _parseRemoteFiles(
    String xml, {
    required Uri directoryUrl,
    required WebDavConfig config,
    String? extension,
  }) {
    final responses = RegExp(
      r'<(?:d:)?response[\s\S]*?</(?:d:)?response>',
      caseSensitive: false,
    ).allMatches(xml);

    final files = <WebDavRemoteFileInfo>[];
    for (final response in responses) {
      final block = response.group(0) ?? '';
      final href = _tagText(block, 'href');
      if (href == null || href.endsWith('/')) {
        continue;
      }

      final fileName = Uri.decodeComponent(_fileName(href));
      if (extension != null && !fileName.endsWith(extension)) {
        continue;
      }

      final lengthText = _tagText(block, 'getcontentlength');
      final modifiedText = _tagText(block, 'getlastmodified');
      files.add(
        WebDavRemoteFileInfo(
          fileName: fileName,
          url: _fileUrl(href, directoryUrl, config, fileName),
          sizeBytes: int.tryParse(lengthText ?? '') ?? 0,
          updatedAt: modifiedText == null
              ? null
              : HttpDate.parse(modifiedText).toUtc(),
        ),
      );
    }
    return files;
  }

  List<String> _parseRemoteDirectoryNames(
    String xml, {
    required Uri directoryUrl,
  }) {
    final responses = RegExp(
      r'<(?:d:)?response[\s\S]*?</(?:d:)?response>',
      caseSensitive: false,
    ).allMatches(xml);

    final basePath = directoryUrl.path.endsWith('/')
        ? directoryUrl.path
        : '${directoryUrl.path}/';
    final directories = <String>[];
    for (final response in responses) {
      final block = response.group(0) ?? '';
      final href = _tagText(block, 'href');
      if (href == null) {
        continue;
      }

      final isCollection =
          href.endsWith('/') ||
          RegExp(
            r'<(?:d:)?collection\s*/?>',
            caseSensitive: false,
          ).hasMatch(block);
      if (!isCollection) {
        continue;
      }

      final path = Uri.tryParse(href)?.path ?? href;
      if (_normalizeHrefPath(path) == _normalizeHrefPath(basePath)) {
        continue;
      }

      final name = Uri.decodeComponent(
        path.split('/').where((part) => part.isNotEmpty).last,
      );
      if (name.isNotEmpty) {
        directories.add(name);
      }
    }
    return directories;
  }

  String _normalizeHrefPath(String value) {
    final path = value.split('?').first;
    final segments = path
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return '/${segments.join('/')}';
  }

  Uri _snapshotUrl(
    String href,
    Uri directoryUrl,
    WebDavConfig config,
    String fileName,
  ) {
    return _fileUrl(href, directoryUrl, config, fileName);
  }

  Uri _fileUrl(
    String href,
    Uri directoryUrl,
    WebDavConfig config,
    String fileName,
  ) {
    final uri = Uri.tryParse(href);
    if (uri != null && uri.hasScheme) {
      return uri;
    }
    return directoryUrl.resolve(Uri.encodeComponent(fileName));
  }

  String? _tagText(String xml, String tag) {
    final match = RegExp(
      '<(?:d:)?$tag[^>]*>([\\s\\S]*?)</(?:d:)?$tag>',
      caseSensitive: false,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  String _fileName(String path) {
    final normalized = path.split('?').first;
    return normalized
        .split(RegExp(r'[\\/]'))
        .where((part) => part.isNotEmpty)
        .last;
  }
}
