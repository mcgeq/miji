import 'dart:io';

import 'package:path_provider/path_provider.dart';

const appDatabaseName = 'miji';
const appDatabaseFileName = '$appDatabaseName.sqlite';

Future<File> resolveAppDatabaseFile() async {
  final targetDir = await getApplicationSupportDirectory();
  if (!await targetDir.exists()) {
    await targetDir.create(recursive: true);
  }

  return File(_join(targetDir.path, appDatabaseFileName));
}

String _join(String directory, String child) {
  if (directory.endsWith(Platform.pathSeparator)) {
    return '$directory$child';
  }
  return '$directory${Platform.pathSeparator}$child';
}
