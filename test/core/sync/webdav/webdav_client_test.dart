import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/webdav/webdav_client.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';

void main() {
  group('WebDavClient.deleteSnapshot', () {
    test('sends DELETE request to the snapshot url', () async {
      final adapter = _FakeHttpClientAdapter(statusCode: 204);
      final client = WebDavClient(dio: Dio()..httpClientAdapter = adapter);
      final snapshot = _snapshot('remote-a.miji-snapshot');

      await client.deleteSnapshot(config: _config, snapshot: snapshot);

      expect(adapter.requests, hasLength(1));
      expect(adapter.requests.single.method, 'DELETE');
      expect(adapter.requests.single.uri, snapshot.url);
      expect(
        adapter.requests.single.headers['Authorization'],
        'Basic dXNlcjpwYXNz',
      );
    });

    test(
      'throws deleteFailed when server rejects the delete request',
      () async {
        final adapter = _FakeHttpClientAdapter(statusCode: 500);
        final client = WebDavClient(dio: Dio()..httpClientAdapter = adapter);

        expect(
          () => client.deleteSnapshot(
            config: _config,
            snapshot: _snapshot('remote-a.miji-snapshot'),
          ),
          throwsA(
            isA<WebDavSyncException>().having(
              (error) => error.code,
              'code',
              WebDavSyncErrorCode.deleteFailed,
            ),
          ),
        );
      },
    );
  });

  group('WebDavClient.pruneSnapshots', () {
    test('keeps newest snapshots and deletes older snapshots', () async {
      final adapter = _FakeHttpClientAdapter(
        statusCode: 204,
        listSnapshotsBody: _snapshotListXml,
      );
      final client = WebDavClient(dio: Dio()..httpClientAdapter = adapter);

      await client.pruneSnapshots(config: _config, maxSnapshots: 3);

      final deleteRequests = adapter.requests
          .where((request) => request.method == 'DELETE')
          .toList(growable: false);
      expect(deleteRequests, hasLength(2));
      expect(deleteRequests.map((request) => request.uri.path).toList(), [
        '/dav/.miji/snapshots/remote-old-1.miji-snapshot',
        '/dav/.miji/snapshots/remote-old-2.miji-snapshot',
      ]);
    });

    test(
      'does not delete when remote snapshot count is within limit',
      () async {
        final adapter = _FakeHttpClientAdapter(
          statusCode: 204,
          listSnapshotsBody: _snapshotListXml,
        );
        final client = WebDavClient(dio: Dio()..httpClientAdapter = adapter);

        await client.pruneSnapshots(config: _config, maxSnapshots: 5);

        expect(
          adapter.requests.where((request) => request.method == 'DELETE'),
          isEmpty,
        );
      },
    );
  });
}

const _config = WebDavConfig(
  providerType: WebDavProviderType.custom,
  endpointUrl: 'https://example.com/dav/',
  username: 'user',
  password: 'pass',
  remoteDirectory: '.miji/snapshots',
);

const _snapshotListXml = '''<?xml version="1.0" encoding="utf-8" ?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/.miji/snapshots/remote-new-1.miji-snapshot</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>10</d:getcontentlength>
      <d:getlastmodified>Fri, 10 Jul 2026 08:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/.miji/snapshots/remote-new-2.miji-snapshot</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>10</d:getcontentlength>
      <d:getlastmodified>Fri, 10 Jul 2026 07:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/.miji/snapshots/remote-new-3.miji-snapshot</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>10</d:getcontentlength>
      <d:getlastmodified>Fri, 10 Jul 2026 06:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/.miji/snapshots/remote-old-1.miji-snapshot</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>10</d:getcontentlength>
      <d:getlastmodified>Fri, 10 Jul 2026 05:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/.miji/snapshots/remote-old-2.miji-snapshot</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>10</d:getcontentlength>
      <d:getlastmodified>Fri, 10 Jul 2026 04:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>
</d:multistatus>''';

WebDavRemoteSnapshotInfo _snapshot(String fileName) {
  return WebDavRemoteSnapshotInfo(
    fileName: fileName,
    url: Uri.parse('https://example.com/dav/.miji/snapshots/$fileName'),
    sizeBytes: 128,
    updatedAt: DateTime.utc(2026, 7, 10, 8),
  );
}

class _FakeHttpClientAdapter implements HttpClientAdapter {
  _FakeHttpClientAdapter({required this.statusCode, this.listSnapshotsBody});

  final int statusCode;
  final String? listSnapshotsBody;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'PROPFIND') {
      return ResponseBody.fromString(listSnapshotsBody ?? '', 207);
    }
    return ResponseBody.fromString('', statusCode);
  }

  @override
  void close({bool force = false}) {}
}
