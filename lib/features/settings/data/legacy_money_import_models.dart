enum LegacyMoneyImportWarningSeverity { info, warning, error }

class LegacyMoneyImportWarning {
  const LegacyMoneyImportWarning({
    required this.severity,
    required this.message,
    this.tableName,
    this.rowId,
  });

  final LegacyMoneyImportWarningSeverity severity;
  final String message;
  final String? tableName;
  final String? rowId;
}

class LegacyMoneyImportTableCount {
  const LegacyMoneyImportTableCount({
    required this.tableName,
    required this.totalRows,
    required this.importableRows,
  });

  final String tableName;
  final int totalRows;
  final int importableRows;
}

class LegacyMoneyImportPreview {
  const LegacyMoneyImportPreview({
    required this.sourcePath,
    required this.tableCounts,
    required this.warnings,
    required this.canImport,
  });

  final String sourcePath;
  final List<LegacyMoneyImportTableCount> tableCounts;
  final List<LegacyMoneyImportWarning> warnings;
  final bool canImport;

  int countFor(String tableName) {
    for (final count in tableCounts) {
      if (count.tableName == tableName) {
        return count.importableRows;
      }
    }
    return 0;
  }

  bool get hasErrors {
    return warnings.any(
      (warning) => warning.severity == LegacyMoneyImportWarningSeverity.error,
    );
  }
}

class LegacyMoneyImportOptions {
  const LegacyMoneyImportOptions({
    required this.sourcePath,
    required this.userId,
    required this.personalLedgerId,
    required this.defaultMemberId,
    this.selfMemberNames = const <String>[
      '我',
      '自己',
      '本人',
      'me',
      'self',
      'owner',
      'mcgeq',
    ],
    this.dryRun = false,
    this.clearCurrentMoneyData = true,
  });

  final String sourcePath;
  final String userId;
  final String personalLedgerId;
  final String defaultMemberId;
  final List<String> selfMemberNames;
  final bool dryRun;
  final bool clearCurrentMoneyData;
}

class LegacyMoneyImportResult {
  const LegacyMoneyImportResult({
    required this.importedCounts,
    required this.warnings,
  });

  final Map<String, int> importedCounts;
  final List<LegacyMoneyImportWarning> warnings;

  int countFor(String tableName) {
    return importedCounts[tableName] ?? 0;
  }
}
