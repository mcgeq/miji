import 'dart:io';

enum DatabaseSnapshotErrorCode {
  databaseFileMissing,
  invalidPassword,
  invalidSnapshotFormat,
  incompatibleSchema,
  databaseValidationFailed,
  exportFailed,
  restoreFailed,
}

class DatabaseSnapshotException implements Exception {
  const DatabaseSnapshotException(this.code, [this.cause]);

  final DatabaseSnapshotErrorCode code;
  final Object? cause;

  @override
  String toString() {
    return 'DatabaseSnapshotException($code, cause: $cause)';
  }
}

class LocalDatabaseSnapshotInfo {
  const LocalDatabaseSnapshotInfo({
    required this.file,
    required this.createdAt,
    required this.schemaVersion,
    required this.sizeBytes,
  });

  final File file;
  final DateTime createdAt;
  final int schemaVersion;
  final int sizeBytes;
}

class LocalDatabaseSnapshotStatus {
  const LocalDatabaseSnapshotStatus({
    required this.databasePath,
    required this.snapshots,
    this.lastRestoreAt,
  });

  final String databasePath;
  final List<LocalDatabaseSnapshotInfo> snapshots;
  final DateTime? lastRestoreAt;

  LocalDatabaseSnapshotInfo? get latestSnapshot {
    if (snapshots.isEmpty) {
      return null;
    }

    return snapshots.first;
  }
}

class ExportDatabaseSnapshotResult {
  const ExportDatabaseSnapshotResult({required this.snapshot});

  final LocalDatabaseSnapshotInfo snapshot;
}

class RestoreDatabaseSnapshotResult {
  const RestoreDatabaseSnapshotResult({
    required this.restoredAt,
    required this.emergencyBackupFile,
  });

  final DateTime restoredAt;
  final File emergencyBackupFile;
}
