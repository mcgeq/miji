import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

class LegacyMoneyDatabaseReader {
  const LegacyMoneyDatabaseReader();

  T openReadOnly<T>(String path, T Function(Database database) action) {
    final file = File(path);
    if (!file.existsSync()) {
      throw const LegacyMoneyDatabaseReadException('旧数据库文件不存在');
    }

    final database = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      return action(database);
    } finally {
      database.close();
    }
  }

  bool tableExists(Database database, String tableName) {
    final result = database.select(
      'SELECT name FROM sqlite_master WHERE type = ? AND name = ? LIMIT 1',
      ['table', tableName],
    );
    return result.isNotEmpty;
  }

  List<Map<String, Object?>> readTable(Database database, String tableName) {
    if (!tableExists(database, tableName)) {
      return const [];
    }

    final rows = database.select(
      'SELECT * FROM ${_quoteIdentifier(tableName)}',
    );
    return rows
        .map((row) => Map<String, Object?>.from(row))
        .toList(growable: false);
  }

  int countRows(Database database, String tableName) {
    if (!tableExists(database, tableName)) {
      return 0;
    }

    final result = database.select(
      'SELECT COUNT(*) AS count FROM ${_quoteIdentifier(tableName)}',
    );
    if (result.isEmpty) {
      return 0;
    }
    return (result.first['count'] as int?) ?? 0;
  }

  String _quoteIdentifier(String value) {
    if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(value)) {
      throw LegacyMoneyDatabaseReadException('非法表名: $value');
    }
    return '"$value"';
  }
}

class LegacyMoneyDatabaseReadException implements Exception {
  const LegacyMoneyDatabaseReadException(this.message);

  final String message;

  @override
  String toString() => message;
}
