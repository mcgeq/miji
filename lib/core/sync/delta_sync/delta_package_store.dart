import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/webdav/webdav_client.dart';
import 'package:miji/core/sync/webdav/webdav_models.dart';

class DeltaRemotePackageInfo {
  const DeltaRemotePackageInfo({
    required this.file,
    required this.datasetId,
    required this.deviceId,
    required this.sequence,
  });

  final WebDavRemoteFileInfo file;
  final String datasetId;
  final String deviceId;
  final int sequence;

  String get fileName => file.fileName;
  Uri get url => file.url;
  int get sizeBytes => file.sizeBytes;
  DateTime? get updatedAt => file.updatedAt;
}

abstract class DeltaPackageStore {
  Future<DeltaRemotePackageInfo> upload({
    required WebDavConfig config,
    required String password,
    required DeltaPackage package,
  });

  Future<List<DeltaRemotePackageInfo>> listPackages({
    required WebDavConfig config,
    required String datasetId,
    required String deviceId,
  });

  Future<List<DeltaRemotePackageInfo>> listRemotePackages({
    required WebDavConfig config,
    required String datasetId,
    required String localDeviceId,
  });

  Future<DeltaPackage> download({
    required WebDavConfig config,
    required String password,
    required DeltaRemotePackageInfo remotePackage,
  });
}

class WebDavDeltaPackageStore implements DeltaPackageStore {
  WebDavDeltaPackageStore({required this.client, DeltaPackageCodec? codec})
    : _codec = codec ?? DeltaPackageCodec();

  static const deltaRootDirectory = '.miji/delta';
  static const fileExtension = '.miji-delta';

  final WebDavClient client;
  final DeltaPackageCodec _codec;

  @override
  Future<DeltaRemotePackageInfo> upload({
    required WebDavConfig config,
    required String password,
    required DeltaPackage package,
  }) async {
    final metadata = package.metadata;
    final bytes = await _codec.encode(package: package, password: password);
    final file = await client.uploadBytes(
      config: config,
      remoteDirectory: _deviceDirectory(
        datasetId: metadata.datasetId,
        deviceId: metadata.deviceId,
      ),
      fileName: _fileName(metadata.sequence),
      bytes: bytes,
    );
    return DeltaRemotePackageInfo(
      file: file,
      datasetId: metadata.datasetId,
      deviceId: metadata.deviceId,
      sequence: metadata.sequence,
    );
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listPackages({
    required WebDavConfig config,
    required String datasetId,
    required String deviceId,
  }) async {
    final files = await client.listFiles(
      config: config,
      remoteDirectory: _deviceDirectory(
        datasetId: datasetId,
        deviceId: deviceId,
      ),
      extension: fileExtension,
    );
    return files
        .map(
          (file) => DeltaRemotePackageInfo(
            file: file,
            datasetId: datasetId,
            deviceId: deviceId,
            sequence: _sequenceFromFileName(file.fileName),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DeltaRemotePackageInfo>> listRemotePackages({
    required WebDavConfig config,
    required String datasetId,
    required String localDeviceId,
  }) async {
    final deviceIds = await client.listDirectoryNames(
      config: config,
      remoteDirectory: _datasetDirectory(datasetId),
    );
    final packages = <DeltaRemotePackageInfo>[];
    for (final deviceId in deviceIds.where((value) => value != localDeviceId)) {
      packages.addAll(
        await listPackages(
          config: config,
          datasetId: datasetId,
          deviceId: deviceId,
        ),
      );
    }
    packages.sort((left, right) {
      final sequenceCompare = left.sequence.compareTo(right.sequence);
      if (sequenceCompare != 0) {
        return sequenceCompare;
      }
      return left.deviceId.compareTo(right.deviceId);
    });
    return packages;
  }

  @override
  Future<DeltaPackage> download({
    required WebDavConfig config,
    required String password,
    required DeltaRemotePackageInfo remotePackage,
  }) async {
    final bytes = await client.downloadBytes(
      config: config,
      file: remotePackage.file,
    );
    return _codec.decode(bytes: bytes, password: password);
  }

  static String _deviceDirectory({
    required String datasetId,
    required String deviceId,
  }) {
    return '${_datasetDirectory(datasetId)}/$deviceId';
  }

  static String _datasetDirectory(String datasetId) {
    return '$deltaRootDirectory/$datasetId';
  }

  static String _fileName(int sequence) {
    return '${sequence.toString().padLeft(20, '0')}$fileExtension';
  }

  static int _sequenceFromFileName(String fileName) {
    final value = fileName.replaceFirst(fileExtension, '');
    return int.tryParse(value) ?? 0;
  }
}
