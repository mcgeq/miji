import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_store.dart';
import 'package:miji/core/sync/webdav/webdav_client.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';

void main() {
  test('uploads, lists, and downloads encrypted delta packages', () async {
    final adapter = _DeltaPackageHttpClientAdapter();
    final client = WebDavClient(dio: Dio()..httpClientAdapter = adapter);
    final store = WebDavDeltaPackageStore(client: client);

    final package = DeltaPackage(
      metadata: DeltaPackageMetadata(
        datasetId: 'dataset-a',
        deviceId: 'device-a',
        sequence: 42,
        createdAt: DateTime.utc(2026, 7, 11, 9),
      ),
      payload: const DeltaPackagePayload(
        changes: [
          DeltaChangeRecord(
            table: 'money_transactions',
            recordId: 'tx-1',
            operation: 'update',
            baseVersion: 1,
            newVersion: 2,
            changedFields: {'amount_minor': 1200},
            recordSnapshot: {'id': 'tx-1', 'amount_minor': 1200},
          ),
        ],
      ),
    );

    await store.upload(
      config: _config,
      password: 'delta-password',
      package: package,
    );

    final files = await store.listPackages(
      config: _config,
      datasetId: 'dataset-a',
      deviceId: 'device-a',
    );
    expect(files, hasLength(1));
    expect(files.single.sequence, 42);

    final downloaded = await store.download(
      config: _config,
      password: 'delta-password',
      remotePackage: files.single,
    );

    expect(downloaded.metadata.datasetId, 'dataset-a');
    expect(downloaded.metadata.deviceId, 'device-a');
    expect(downloaded.metadata.sequence, 42);
    expect(downloaded.payload.changes.single.recordId, 'tx-1');
    expect(downloaded.payload.changes.single.changedFields, {
      'amount_minor': 1200,
    });

    final remotePackages = await store.listRemotePackages(
      config: _config,
      datasetId: 'dataset-a',
      localDeviceId: 'device-local',
    );
    expect(remotePackages, hasLength(1));
    expect(remotePackages.single.deviceId, 'device-a');

    final ownPackages = await store.listRemotePackages(
      config: _config,
      datasetId: 'dataset-a',
      localDeviceId: 'device-a',
    );
    expect(ownPackages, isEmpty);
  });
}

const _config = WebDavConfig(
  providerType: WebDavProviderType.custom,
  endpointUrl: 'https://example.com/dav/',
  username: 'user',
  password: 'pass',
  remoteDirectory: '.miji/snapshots',
);

class _DeltaPackageHttpClientAdapter implements HttpClientAdapter {
  final files = <String, List<int>>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.method == 'MKCOL') {
      return ResponseBody.fromString('', 201);
    }

    if (options.method == 'PUT') {
      final builder = BytesBuilder();
      if (requestStream != null) {
        await for (final chunk in requestStream) {
          builder.add(chunk);
        }
      }
      files[options.uri.path] = builder.takeBytes();
      return ResponseBody.fromString('', 201);
    }

    if (options.method == 'PROPFIND') {
      return ResponseBody.fromString(_listXml(options.uri.path), 207);
    }

    if (options.method == 'GET') {
      return ResponseBody.fromBytes(files[options.uri.path]!, 200);
    }

    return ResponseBody.fromString('', 405);
  }

  @override
  void close({bool force = false}) {}

  String _listXml(String directoryPath) {
    final buffer = StringBuffer(
      '<?xml version="1.0" encoding="utf-8" ?><d:multistatus xmlns:d="DAV:">',
    );
    final directoryNames = <String>{};
    for (final entry in files.entries) {
      if (!entry.key.startsWith(directoryPath)) {
        continue;
      }
      final relative = entry.key.substring(directoryPath.length);
      final parts = relative.split('/').where((part) => part.isNotEmpty);
      if (parts.length > 1) {
        directoryNames.add(parts.first);
      }
      if (!entry.key.endsWith('.miji-delta')) {
        continue;
      }
      if (parts.length != 1) {
        continue;
      }
      final fileName = Uri.encodeComponent(entry.key.split('/').last);
      buffer.write('''
  <d:response>
    <d:href>$directoryPath/$fileName</d:href>
    <d:propstat><d:prop>
      <d:getcontentlength>${entry.value.length}</d:getcontentlength>
      <d:getlastmodified>Sat, 11 Jul 2026 09:00:00 GMT</d:getlastmodified>
    </d:prop></d:propstat>
  </d:response>''');
    }
    for (final directoryName in directoryNames) {
      buffer.write('''
  <d:response>
    <d:href>$directoryPath/$directoryName/</d:href>
    <d:propstat><d:prop>
      <d:resourcetype><d:collection /></d:resourcetype>
    </d:prop></d:propstat>
  </d:response>''');
    }
    buffer.write('</d:multistatus>');
    return buffer.toString();
  }
}
