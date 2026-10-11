import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:miji/core/database/app_database_path.dart';

class DatabaseFileResolver {
  const DatabaseFileResolver();

  Future<File> databaseFile() {
    return resolveAppDatabaseFile();
  }

  Future<File> databaseWalFile() async {
    final file = await databaseFile();
    return File('${file.path}-wal');
  }

  Future<File> databaseShmFile() async {
    final file = await databaseFile();
    return File('${file.path}-shm');
  }

  Future<Directory> snapshotDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final snapshots = Directory(_join(dir.path, 'snapshots'));
    if (!await snapshots.exists()) {
      await snapshots.create(recursive: true);
    }
    return snapshots;
  }

  Future<Directory> restoreBackupDirectory() async {
    final dir = await getApplicationSupportDirectory();
    final backups = Directory(_join(dir.path, 'restore_backups'));
    if (!await backups.exists()) {
      await backups.create(recursive: true);
    }
    return backups;
  }

  Future<Directory> tempDirectory() async {
    final dir = await getTemporaryDirectory();
    final temp = Directory(_join(dir.path, 'miji_snapshots'));
    if (!await temp.exists()) {
      await temp.create(recursive: true);
    }
    return temp;
  }
}

String _join(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}
