import 'dart:convert';
import 'dart:io';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/app_database_path.dart';
import 'package:miji/core/sync/local_snapshot/database_file_resolver.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_crypto.dart';
import 'package:miji/core/sync/local_snapshot/database_snapshot_models.dart';

class DatabaseSnapshotService {
  const DatabaseSnapshotService({
    required this.database,
    required this.resolver,
    required this.crypto,
  });

  static const _snapshotExtension = '.miji-snapshot';
  static const _restoreMarkerFileName = 'last_restore_at.txt';
  static const _maxLocalSnapshots = 3;

  final AppDatabase database;
  final DatabaseFileResolver resolver;
  final DatabaseSnapshotCrypto crypto;

  Future<LocalDatabaseSnapshotStatus> loadStatus() async {
    await _pruneLocalSnapshots();
    final databaseFile = await resolver.databaseFile();
    final snapshots = await _listLocalSnapshots();

    return LocalDatabaseSnapshotStatus(
      databasePath: databaseFile.path,
      snapshots: snapshots,
      lastRestoreAt: await _readLastRestoreAt(),
    );
  }

  Future<ExportDatabaseSnapshotResult> exportSnapshot(String password) async {
    final databaseFile = await resolver.databaseFile();
    if (!await databaseFile.exists()) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.databaseFileMissing,
      );
    }

    try {
      await database.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
      final createdAt = DateTime.now().toUtc();
      final databaseBytes = await databaseFile.readAsBytes();
      final envelope = await crypto.encrypt(
        databaseBytes: databaseBytes,
        password: password,
        schemaVersion: database.schemaVersion,
        createdAt: createdAt,
      );

      final snapshotDir = await resolver.snapshotDirectory();
      final file = File(_join(snapshotDir.path, _snapshotFileName(createdAt)));
      await file.writeAsString(jsonEncode(envelope), flush: true);

      final info = await _readSnapshotInfo(file);
      if (info == null) {
        throw const DatabaseSnapshotException(
          DatabaseSnapshotErrorCode.exportFailed,
        );
      }

      await _pruneLocalSnapshots();
      return ExportDatabaseSnapshotResult(snapshot: info);
    } on DatabaseSnapshotException {
      rethrow;
    } catch (error) {
      throw DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.exportFailed,
        error,
      );
    }
  }

  Future<RestoreDatabaseSnapshotResult> restoreSnapshot({
    required File snapshotFile,
    required String password,
    Future<void> Function()? beforeDatabaseClose,
  }) async {
    try {
      final envelope = await _readEnvelope(snapshotFile);
      _validateSchema(envelope);

      final databaseBytes = await crypto.decrypt(
        envelope: envelope,
        password: password,
      );
      _validateSqliteHeader(databaseBytes);

      final tempDir = await resolver.tempDirectory();
      final restoredAt = DateTime.now().toUtc();
      final tempFile = File(
        _join(tempDir.path, 'restore-${_timestamp(restoredAt)}.sqlite'),
      );
      await tempFile.writeAsBytes(databaseBytes, flush: true);

      final databaseFile = await resolver.databaseFile();
      final backupDir = await resolver.restoreBackupDirectory();
      final emergencyBackupFile = File(
        _join(
          backupDir.path,
          '$appDatabaseName-before-restore-${_timestamp(restoredAt)}.sqlite',
        ),
      );

      await beforeDatabaseClose?.call();
      await database.close();

      if (await databaseFile.exists()) {
        await databaseFile.copy(emergencyBackupFile.path);
      }

      await tempFile.copy(databaseFile.path);
      await tempFile.delete();
      await _deleteIfExists(await resolver.databaseWalFile());
      await _deleteIfExists(await resolver.databaseShmFile());
      await _writeLastRestoreAt(restoredAt);

      return RestoreDatabaseSnapshotResult(
        restoredAt: restoredAt,
        emergencyBackupFile: emergencyBackupFile,
      );
    } on DatabaseSnapshotException {
      rethrow;
    } catch (error) {
      throw DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.restoreFailed,
        error,
      );
    }
  }

  Future<List<LocalDatabaseSnapshotInfo>> _listLocalSnapshots() async {
    final snapshotDir = await resolver.snapshotDirectory();
    final snapshots = <LocalDatabaseSnapshotInfo>[];

    await for (final entity in snapshotDir.list()) {
      if (entity is! File || !entity.path.endsWith(_snapshotExtension)) {
        continue;
      }

      final info = await _readSnapshotInfo(entity);
      if (info != null) {
        snapshots.add(info);
      }
    }

    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return snapshots;
  }

  Future<void> _pruneLocalSnapshots() async {
    final snapshots = await _listLocalSnapshots();
    if (snapshots.length <= _maxLocalSnapshots) {
      return;
    }

    for (final snapshot in snapshots.skip(_maxLocalSnapshots)) {
      await _deleteIfExists(snapshot.file);
    }
  }

  Future<LocalDatabaseSnapshotInfo?> _readSnapshotInfo(File file) async {
    try {
      final envelope = await _readEnvelope(file);
      if (envelope['format'] != DatabaseSnapshotCrypto.format) {
        return null;
      }

      final createdAtText = envelope['createdAt'] as String?;
      final schemaVersion = envelope['schemaVersion'];
      if (createdAtText == null || schemaVersion is! int) {
        return null;
      }

      final stat = await file.stat();
      return LocalDatabaseSnapshotInfo(
        file: file,
        createdAt: DateTime.parse(createdAtText).toUtc(),
        schemaVersion: schemaVersion,
        sizeBytes: stat.size,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _readEnvelope(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.invalidSnapshotFormat,
      );
    }

    return decoded.map((key, value) {
      if (key is! String) {
        throw const DatabaseSnapshotException(
          DatabaseSnapshotErrorCode.invalidSnapshotFormat,
        );
      }
      return MapEntry(key, value as Object?);
    });
  }

  void _validateSchema(Map<String, Object?> envelope) {
    final schemaVersion = envelope['schemaVersion'];
    if (schemaVersion is! int || schemaVersion > database.schemaVersion) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.incompatibleSchema,
      );
    }
  }

  void _validateSqliteHeader(List<int> bytes) {
    const sqliteHeader = 'SQLite format 3\u0000';
    if (bytes.length < sqliteHeader.length) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.databaseValidationFailed,
      );
    }

    final header = ascii.decode(bytes.take(sqliteHeader.length).toList());
    if (header != sqliteHeader) {
      throw const DatabaseSnapshotException(
        DatabaseSnapshotErrorCode.databaseValidationFailed,
      );
    }
  }

  Future<DateTime?> _readLastRestoreAt() async {
    try {
      final snapshotDir = await resolver.snapshotDirectory();
      final marker = File(_join(snapshotDir.path, _restoreMarkerFileName));
      if (!await marker.exists()) {
        return null;
      }

      final value = (await marker.readAsString()).trim();
      if (value.isEmpty) {
        return null;
      }

      return DateTime.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeLastRestoreAt(DateTime restoredAt) async {
    final snapshotDir = await resolver.snapshotDirectory();
    final marker = File(_join(snapshotDir.path, _restoreMarkerFileName));
    await marker.writeAsString(restoredAt.toIso8601String(), flush: true);
  }

  Future<void> _deleteIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _snapshotFileName(DateTime createdAt) {
    return 'miji-${_timestamp(createdAt)}$_snapshotExtension';
  }

  String _timestamp(DateTime value) {
    return value
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('Z', 'z');
  }
}

String _join(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}
