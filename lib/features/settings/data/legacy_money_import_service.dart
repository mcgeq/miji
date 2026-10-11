import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/settings/data/legacy_money_database_reader.dart';
import 'package:miji/features/settings/data/legacy_money_import_mapper.dart';
import 'package:miji/features/settings/data/legacy_money_import_models.dart';

class LegacyMoneyImportService {
  LegacyMoneyImportService({
    required this.database,
    this.reader = const LegacyMoneyDatabaseReader(),
  });

  final AppDatabase database;
  final LegacyMoneyDatabaseReader reader;

  static const importTables = <String>[
    'currency',
    'categories',
    'sub_categories',
    'account',
    'family_member',
    'family_ledger',
    'family_ledger_account',
    'family_ledger_transaction',
    'family_ledger_member',
    'transactions',
    'split_rules',
    'split_records',
    'split_record_details',
    'installment_plans',
    'installment_details',
    'budget',
    'budget_allocations',
  ];

  static const skippedTables = <String>['debt_relations', 'settlement_records'];

  Future<LegacyMoneyImportPreview> preview(String sourcePath) async {
    if (_isJsonSnapshotPath(sourcePath)) {
      final legacy = _readJsonLegacyRows(sourcePath);
      final counts = <LegacyMoneyImportTableCount>[
        for (final table in importTables)
          LegacyMoneyImportTableCount(
            tableName: table,
            totalRows: legacy.rows(table).length,
            importableRows: legacy.rows(table).length,
          ),
      ];
      final warnings = _skippedTableWarnings(legacy);
      final hasAccounts = legacy.rows('account').isNotEmpty;
      final hasTransactions = legacy.rows('transactions').isNotEmpty;
      if (!hasAccounts && !hasTransactions) {
        warnings.add(
          const LegacyMoneyImportWarning(
            severity: LegacyMoneyImportWarningSeverity.error,
            message: '未找到可导入的账户或流水数据。',
          ),
        );
      }

      return LegacyMoneyImportPreview(
        sourcePath: sourcePath,
        tableCounts: counts,
        warnings: warnings,
        canImport: hasAccounts || hasTransactions,
      );
    }

    return reader.openReadOnly(sourcePath, (legacyDb) {
      final counts = <LegacyMoneyImportTableCount>[];
      final warnings = <LegacyMoneyImportWarning>[];

      for (final table in importTables) {
        final totalRows = reader.countRows(legacyDb, table);
        counts.add(
          LegacyMoneyImportTableCount(
            tableName: table,
            totalRows: totalRows,
            importableRows: totalRows,
          ),
        );
      }

      warnings.addAll(_skippedDatabaseTableWarnings(legacyDb));

      final hasAccounts = counts.any(
        (item) => item.tableName == 'account' && item.totalRows > 0,
      );
      final hasTransactions = counts.any(
        (item) => item.tableName == 'transactions' && item.totalRows > 0,
      );

      if (!hasAccounts && !hasTransactions) {
        warnings.add(
          const LegacyMoneyImportWarning(
            severity: LegacyMoneyImportWarningSeverity.error,
            message: '未找到可导入的账户或流水数据。',
          ),
        );
      }

      return LegacyMoneyImportPreview(
        sourcePath: sourcePath,
        tableCounts: counts,
        warnings: warnings,
        canImport: hasAccounts || hasTransactions,
      );
    });
  }

  Future<LegacyMoneyImportResult> importNow(
    LegacyMoneyImportOptions options,
  ) async {
    final legacy = _readLegacyRows(options.sourcePath);
    final warnings = <LegacyMoneyImportWarning>[];
    final counts = <String, int>{};
    final context = _LegacyMoneyImportContext(options: options);

    for (final table in skippedTables) {
      final totalRows = legacy.rows(table).length;
      if (totalRows == 0) {
        continue;
      }
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.info,
          tableName: table,
          message: '$table 有 $totalRows 条数据，当前版本不导入结算/债务关系。',
        ),
      );
    }

    if (options.dryRun) {
      return LegacyMoneyImportResult(
        importedCounts: {
          for (final table in importTables) table: legacy.rows(table).length,
        },
        warnings: warnings,
      );
    }

    await database.transaction(() async {
      if (options.clearCurrentMoneyData) {
        await _clearCurrentMoneyData();
      }

      await _importCurrencies(legacy, counts);
      await _ensureDefaultImportContext(options);
      await _importMembers(legacy, options, context, counts);
      await _importLedgers(legacy, options, context, counts);
      await _importAccounts(legacy, options, context, warnings, counts);
      await _importCategories(legacy, options, context, counts);
      await _importLedgerMembers(legacy, options, context, warnings, counts);
      await _importLedgerAccounts(legacy, context, warnings, counts);
      await _importTransactions(legacy, options, context, warnings, counts);
      await _importLedgerTransactions(
        legacy,
        options,
        context,
        warnings,
        counts,
      );
      await _importInstallmentPlans(legacy, options, context, warnings, counts);
      await _importInstallmentDetails(
        legacy,
        options,
        context,
        warnings,
        counts,
      );
      await _importSplitRules(legacy, options, context, warnings, counts);
      await _importSplitRecords(legacy, options, context, warnings, counts);
      await _importSplitRecordDetails(
        legacy,
        options,
        context,
        warnings,
        counts,
      );
      await _importBudgets(legacy, options, context, warnings, counts);
      await _importBudgetAllocations(
        legacy,
        options,
        context,
        warnings,
        counts,
      );
    });

    return LegacyMoneyImportResult(importedCounts: counts, warnings: warnings);
  }

  _LegacyMoneyRows _readLegacyRows(String sourcePath) {
    if (_isJsonSnapshotPath(sourcePath)) {
      return _readJsonLegacyRows(sourcePath);
    }

    return reader.openReadOnly(sourcePath, (legacyDb) {
      return _LegacyMoneyRows({
        for (final table in [...importTables, ...skippedTables])
          table: reader.readTable(legacyDb, table),
      });
    });
  }

  _LegacyMoneyRows _readJsonLegacyRows(String sourcePath) {
    final file = File(sourcePath);
    if (!file.existsSync()) {
      throw const LegacyMoneyImportException('旧版 JSON 快照文件不存在');
    }

    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      throw const LegacyMoneyImportException('旧版 JSON 快照格式不正确');
    }
    final domains = decoded['domains'];
    if (domains is! Map<String, Object?>) {
      throw const LegacyMoneyImportException('旧版 JSON 快照缺少 domains 数据');
    }

    return _LegacyMoneyRows({
      for (final table in [...importTables, ...skippedTables])
        table: _jsonDomainRows(domains, _jsonDomainNameForTable(table)),
    });
  }

  List<Map<String, Object?>> _jsonDomainRows(
    Map<String, Object?> domains,
    String domainName,
  ) {
    final rows = domains[domainName];
    if (rows == null) {
      return const [];
    }
    if (rows is! List) {
      throw LegacyMoneyImportException('旧版 JSON 快照域 $domainName 不是数组');
    }

    return rows
        .map((row) {
          if (row is! Map) {
            throw LegacyMoneyImportException('旧版 JSON 快照域 $domainName 包含非法行');
          }
          return <String, Object?>{
            for (final entry in row.entries)
              entry.key.toString(): _normalizeJsonValue(entry.value),
          };
        })
        .toList(growable: false);
  }

  Object? _normalizeJsonValue(Object? value) {
    return switch (value) {
      null => null,
      String value => value,
      num value => value,
      bool value => value,
      List value => jsonEncode(value),
      Map value => jsonEncode(value),
      _ => value.toString(),
    };
  }

  List<LegacyMoneyImportWarning> _skippedDatabaseTableWarnings(
    dynamic legacyDb,
  ) {
    final rows = _LegacyMoneyRows({
      for (final table in skippedTables)
        table: List<Map<String, Object?>>.filled(
          reader.countRows(legacyDb, table),
          const <String, Object?>{},
        ),
    });
    return _skippedTableWarnings(rows);
  }

  List<LegacyMoneyImportWarning> _skippedTableWarnings(
    _LegacyMoneyRows legacy,
  ) {
    final warnings = <LegacyMoneyImportWarning>[];
    for (final table in skippedTables) {
      final totalRows = legacy.rows(table).length;
      if (totalRows == 0) {
        continue;
      }
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.info,
          tableName: table,
          message: '$table 有 $totalRows 条数据，当前版本不导入结算/债务关系。',
        ),
      );
    }
    return warnings;
  }

  bool _isJsonSnapshotPath(String sourcePath) {
    return sourcePath.trim().toLowerCase().endsWith('.json');
  }

  String _jsonDomainNameForTable(String tableName) {
    return switch (tableName) {
      'currency' => 'currencies',
      'account' => 'accounts',
      'family_member' => 'family_members',
      'family_ledger' => 'family_ledgers',
      'family_ledger_account' => 'family_ledger_accounts',
      'family_ledger_transaction' => 'family_ledger_transactions',
      'family_ledger_member' => 'family_ledger_members',
      'budget' => 'budgets',
      _ => tableName,
    };
  }

  Future<void> _clearCurrentMoneyData() async {
    const tables = <String>[
      'money_account_payment_method_usage_stats',
      'money_payment_method_usage_stats',
      'money_account_usage_stats',
      'money_sub_category_usage_stats',
      'money_category_usage_stats',
      'money_report_generation_configs',
      'money_analysis_reports',
      'money_bill_reminders',
      'money_transaction_tags',
      'money_split_record_details',
      'money_split_records',
      'money_split_rules',
      'money_installment_details',
      'money_installment_plans',
      'money_budget_allocations',
      'money_budgets',
      'money_ledger_transactions',
      'money_ledger_accounts',
      'money_ledger_members',
      'money_transactions',
      'money_accounts',
      'money_ledgers',
      'money_members',
    ];

    for (final table in tables) {
      await database.customStatement('DELETE FROM $table');
    }
    await database.customStatement(
      'DELETE FROM money_sub_categories WHERE user_id IS NOT NULL',
    );
    await database.customStatement(
      'DELETE FROM money_categories WHERE user_id IS NOT NULL',
    );
  }

  Future<void> _importCurrencies(
    _LegacyMoneyRows legacy,
    Map<String, int> counts,
  ) async {
    final now = DateTime.now();
    final rows = legacy.rows('currency');
    var imported = 0;

    if (rows.isEmpty) {
      await database
          .into(database.moneyCurrencies)
          .insert(
            MoneyCurrenciesCompanion.insert(
              code: 'CNY',
              locale: 'zh_CN',
              symbol: '¥',
              isDefault: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrReplace,
          );
      counts['currency'] = 1;
      return;
    }

    for (final row in rows) {
      final code = row.text('code') ?? 'CNY';
      await database
          .into(database.moneyCurrencies)
          .insert(
            MoneyCurrenciesCompanion.insert(
              code: code,
              locale: row.text('locale') ?? _defaultLocaleForCurrency(code),
              symbol: row.text('symbol') ?? _defaultSymbolForCurrency(code),
              isDefault: Value(row.boolValue('is_default')),
              isActive: Value(row.boolValue('is_active', defaultValue: true)),
              createdAt: row.dateTime('created_at') ?? now,
              updatedAt: row.dateTime('updated_at') ?? now,
            ),
            mode: InsertMode.insertOrReplace,
          );
      imported++;
    }

    if (rows.every((row) => row.text('code') != 'CNY')) {
      await database
          .into(database.moneyCurrencies)
          .insert(
            MoneyCurrenciesCompanion.insert(
              code: 'CNY',
              locale: 'zh_CN',
              symbol: '¥',
              isDefault: const Value(true),
              createdAt: now,
              updatedAt: now,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    counts['currency'] = imported;
  }

  Future<void> _ensureDefaultImportContext(
    LegacyMoneyImportOptions options,
  ) async {
    final now = DateTime.now();
    await database
        .into(database.moneyMembers)
        .insert(
          MoneyMembersCompanion.insert(
            id: options.defaultMemberId,
            userId: options.userId,
            name: '我',
            role: 'owner',
            status: 'active',
            color: const Value<String?>('#F59E0B'),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: options.personalLedgerId,
            userId: options.userId,
            name: '个人账本',
            description: const Value<String?>('旧版数据导入默认个人账本'),
            createdByMemberId: options.defaultMemberId,
            ledgerType: 'personal',
            status: 'active',
            baseCurrencyCode: 'CNY',
            settlementCycle: 'manual',
            settlementDay: 1,
            color: const Value<String?>('#F59E0B'),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: options.personalLedgerId,
            memberId: options.defaultMemberId,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _importMembers(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    for (final row in legacy.rows('family_member')) {
      final id = row.requiredText('serial_num');
      if (id == options.defaultMemberId ||
          _isLegacySelfMember(row.text('name'), options)) {
        context.registerMemberAlias(id, options.defaultMemberId);
        continue;
      }
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await database
          .into(database.moneyMembers)
          .insert(
            MoneyMembersCompanion.insert(
              id: id,
              userId: options.userId,
              name: row.text('name') ?? '成员',
              role: _memberRole(row.text('role')),
              status: _activeStatus(row.text('status')),
              avatarUri: Value(row.text('avatar_url')),
              color: Value(row.text('color')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
      context.memberIds.add(id);
    }
    counts['family_member'] = imported;
  }

  Future<void> _importLedgers(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    for (final row in legacy.rows('family_ledger')) {
      final id = row.requiredText('serial_num');
      if (id == options.personalLedgerId) {
        continue;
      }
      final ledgerType = _ledgerType(row.text('ledger_type'));
      if (ledgerType == 'personal') {
        context.legacyPersonalLedgerIds.add(id);
        continue;
      }
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await _ensureCurrency(row.text('base_currency') ?? 'CNY');
      await database
          .into(database.moneyLedgers)
          .insert(
            MoneyLedgersCompanion.insert(
              id: id,
              userId: options.userId,
              name: row.text('name') ?? '家庭账本',
              description: Value(row.text('description')),
              createdByMemberId: options.defaultMemberId,
              ledgerType: ledgerType,
              status: _activeStatus(row.text('status')),
              baseCurrencyCode: row.text('base_currency') ?? 'CNY',
              settlementCycle: row.text('settlement_cycle') ?? 'manual',
              settlementDay: row.intValue('settlement_day') ?? 1,
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
      context.ledgerIds.add(id);
    }
    counts['family_ledger'] = imported;
  }

  Future<void> _importAccounts(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    for (final row in legacy.rows('account')) {
      final id = row.requiredText('serial_num');
      final type = LegacyMoneyImportMapper.accountType(row.text('type'));
      final balanceMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('balance'),
      );
      final initialBalanceMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('initial_balance'),
      );
      final creditLimitMinor = type.isCreditLike
          ? initialBalanceMinor.abs()
          : null;
      final postedDebtMinor = type.isCreditLike
          ? (creditLimitMinor! - balanceMinor)
                .clamp(0, creditLimitMinor)
                .toInt()
          : null;
      final ownerId = row.text('owner_id');
      final ownerMemberId = context.memberIdOrDefault(ownerId);
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      final currencyCode = row.text('currency') ?? 'CNY';
      await _ensureCurrency(currencyCode);

      await database
          .into(database.moneyAccounts)
          .insert(
            MoneyAccountsCompanion.insert(
              id: id,
              userId: options.userId,
              name: row.text('name') ?? '未命名账户',
              description: Value(row.text('description')),
              type: type.storageValue,
              balanceMinor: balanceMinor,
              initialBalanceMinor: initialBalanceMinor,
              creditLimitMinor: Value(creditLimitMinor),
              postedDebtMinor: Value(postedDebtMinor),
              frozenCreditMinor: Value(type.isCreditLike ? 0 : null),
              statementDay: const Value<int?>(null),
              budgetCycleStartDay: const Value<int?>(null),
              repaymentDay: const Value<int?>(null),
              currencyCode: currencyCode,
              isShared: Value(row.boolValue('is_shared')),
              isVirtual: Value(row.boolValue('is_virtual')),
              ownerMemberId: Value(ownerMemberId),
              color: Value(row.text('color')),
              icon: Value(row.text('icon')),
              isActive: Value(row.boolValue('is_active', defaultValue: true)),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      await database
          .into(database.moneyLedgerAccounts)
          .insert(
            MoneyLedgerAccountsCompanion.insert(
              ledgerId: options.personalLedgerId,
              accountId: id,
              createdAt: createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.accountIds.add(id);
      imported++;
    }

    if (imported == 0 && legacy.rows('transactions').isNotEmpty) {
      warnings.add(
        const LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.error,
          tableName: 'account',
          message: '旧库存在流水但没有账户，流水导入会被跳过。',
        ),
      );
    }
    counts['account'] = imported;
  }

  Future<void> _importCategories(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    Map<String, int> counts,
  ) async {
    final legacyCategories = {
      for (final row in legacy.rows('categories'))
        if (row.text('name') != null) row.text('name')!: row,
    };
    final legacySubCategories = {
      for (final row in legacy.rows('sub_categories'))
        if (row.text('category_name') != null && row.text('name') != null)
          '${row.text('category_name')}///${row.text('name')}': row,
    };
    var categoryCount = 0;
    var subCategoryCount = 0;

    for (final row in legacy.rows('transactions')) {
      final rawKind = LegacyMoneyImportMapper.transactionTypeStorage(
        row.text('transaction_type'),
      );
      final categoryName =
          row.text('category') ?? _defaultCategoryName(rawKind);
      final subCategoryName = row.text('sub_category');
      final kind =
          _isLegacyTransferTransaction(
            rawKind: rawKind,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
          )
          ? MoneyTransactionType.expense.storageValue
          : rawKind;
      final legacyTarget = _legacyCategoryTarget(
        kind: kind,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
      );
      if (legacyTarget != null) {
        _registerLegacyCategoryTarget(
          context: context,
          kind: kind,
          categoryName: categoryName,
          subCategoryName: subCategoryName,
          target: legacyTarget,
        );
        continue;
      }

      final categoryKey = _categoryKey(kind, categoryName);
      if (!context.categoryIds.containsKey(categoryKey)) {
        final legacyCategory = legacyCategories[categoryName];
        final categoryId = 'legacy_category_${_stableKey(categoryKey)}';
        final createdAt =
            legacyCategory?.dateTime('created_at') ??
            row.dateTime('created_at') ??
            DateTime.now();
        await database
            .into(database.moneyCategories)
            .insert(
              MoneyCategoriesCompanion.insert(
                id: categoryId,
                userId: Value(options.userId),
                name: categoryName,
                kind: kind,
                color: Value(legacyCategory?.text('color')),
                icon: Value(legacyCategory?.text('icon')),
                isSystem: const Value(false),
                createdAt: createdAt,
                updatedAt: legacyCategory?.dateTime('updated_at') ?? createdAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        context.categoryIds[categoryKey] = categoryId;
        categoryCount++;
      }

      if (subCategoryName == null) {
        continue;
      }
      final subCategoryKey = _subCategoryKey(
        kind,
        categoryName,
        subCategoryName,
      );
      if (context.subCategoryIds.containsKey(subCategoryKey)) {
        continue;
      }

      final legacySubCategory =
          legacySubCategories['$categoryName///$subCategoryName'];
      final subCategoryId = 'legacy_sub_category_${_stableKey(subCategoryKey)}';
      final createdAt =
          legacySubCategory?.dateTime('created_at') ??
          row.dateTime('created_at') ??
          DateTime.now();
      await database
          .into(database.moneySubCategories)
          .insert(
            MoneySubCategoriesCompanion.insert(
              id: subCategoryId,
              categoryId: context.categoryIds[categoryKey]!,
              userId: Value(options.userId),
              name: subCategoryName,
              kind: kind,
              icon: Value(legacySubCategory?.text('icon')),
              isSystem: const Value(false),
              createdAt: createdAt,
              updatedAt: legacySubCategory?.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.subCategoryIds[subCategoryKey] = subCategoryId;
      subCategoryCount++;
    }

    counts['categories'] = categoryCount;
    counts['sub_categories'] = subCategoryCount;
  }

  Future<void> _importLedgerMembers(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;
    for (final row in legacy.rows('family_ledger_member')) {
      final ledgerId = row.text('family_ledger_serial_num');
      final memberId = row.text('family_member_serial_num');
      if (ledgerId == null || memberId == null) {
        continue;
      }
      if (context.legacyPersonalLedgerIds.contains(ledgerId)) {
        continue;
      }
      final resolvedMemberId = context.resolveMemberId(memberId);
      if (!context.ledgerIds.contains(ledgerId) || resolvedMemberId == null) {
        skipped++;
        continue;
      }
      await database
          .into(database.moneyLedgerMembers)
          .insert(
            MoneyLedgerMembersCompanion.insert(
              ledgerId: ledgerId,
              memberId: resolvedMemberId,
              createdAt: row.dateTime('created_at') ?? DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }

    for (final ledger in legacy.rows('family_ledger')) {
      final ledgerId = ledger.text('serial_num');
      if (ledgerId == null) {
        continue;
      }
      if (context.legacyPersonalLedgerIds.contains(ledgerId) ||
          !context.ledgerIds.contains(ledgerId)) {
        continue;
      }
      await database
          .into(database.moneyLedgerMembers)
          .insert(
            MoneyLedgerMembersCompanion.insert(
              ledgerId: ledgerId,
              memberId: options.defaultMemberId,
              createdAt: DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    }

    counts['family_ledger_member'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'family_ledger_member',
          message: '共有 $skipped 条账本成员关系因成员或账本不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importLedgerAccounts(
    _LegacyMoneyRows legacy,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;
    for (final row in legacy.rows('family_ledger_account')) {
      final ledgerId = row.text('family_ledger_serial_num');
      final accountId = row.text('account_serial_num');
      if (ledgerId == null || accountId == null) {
        continue;
      }
      if (context.legacyPersonalLedgerIds.contains(ledgerId)) {
        continue;
      }
      if (!context.ledgerIds.contains(ledgerId) ||
          !context.accountIds.contains(accountId)) {
        skipped++;
        continue;
      }
      await database
          .into(database.moneyLedgerAccounts)
          .insert(
            MoneyLedgerAccountsCompanion.insert(
              ledgerId: ledgerId,
              accountId: accountId,
              createdAt: row.dateTime('created_at') ?? DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }
    counts['family_ledger_account'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'family_ledger_account',
          message: '共有 $skipped 条账本账户关系因账户或账本不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importTransactions(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;
    final installmentPlanIdByTransactionId = <String, String>{
      for (final row in legacy.rows('installment_plans'))
        if (row.text('transaction_serial_num') != null)
          row.text('transaction_serial_num')!: row.requiredText('serial_num'),
    };

    for (final row in legacy.rows('transactions')) {
      final id = row.requiredText('serial_num');
      final accountId = row.text('account_serial_num');
      if (accountId == null || !context.accountIds.contains(accountId)) {
        skipped++;
        warnings.add(
          LegacyMoneyImportWarning(
            severity: LegacyMoneyImportWarningSeverity.warning,
            tableName: 'transactions',
            rowId: id,
            message: '流水 $id 关联账户不存在，已跳过。',
          ),
        );
        continue;
      }

      final rawType = LegacyMoneyImportMapper.transactionTypeStorage(
        row.text('transaction_type'),
      );
      final categoryName =
          row.text('category') ?? _defaultCategoryName(rawType);
      final subCategoryName = row.text('sub_category');
      final isTransfer = _isLegacyTransferTransaction(
        rawKind: rawType,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
      );
      final type = isTransfer
          ? MoneyTransactionType.transfer.storageValue
          : rawType;
      final categorySelection = await _ensureLegacyCategorySelection(
        options: options,
        context: context,
        kind: isTransfer ? MoneyTransactionType.expense.storageValue : rawType,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
        createdAt: row.dateTime('created_at') ?? DateTime.now(),
      );
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      final directInstallmentPlanId = row.text('installment_plan_serial_num');
      final relatedTransactionId = row.text('related_transaction_serial_num');
      final effectiveInstallmentPlanId =
          directInstallmentPlanId ??
          installmentPlanIdByTransactionId[relatedTransactionId];
      final actualPayerAccount = isTransfer
          ? _legacyTransferDirectionMarker(rawType)
          : directInstallmentPlanId == null &&
                effectiveInstallmentPlanId != null
          ? 'installment'
          : row.text('actual_payer_account') ?? accountId;
      final currencyCode = row.text('currency') ?? 'CNY';
      final toAccountId = row.text('to_account_serial_num');
      await _ensureCurrency(currencyCode);

      await database
          .into(database.moneyTransactions)
          .insert(
            MoneyTransactionsCompanion.insert(
              id: id,
              userId: options.userId,
              type: type,
              status: LegacyMoneyImportMapper.transactionStatusStorage(
                row.text('transaction_status'),
              ),
              transactionAt: row.dateTime('date') ?? createdAt,
              amountMinor: LegacyMoneyImportMapper.decimalToMinor(
                row.value('amount'),
              ),
              refundAmountMinor: Value(
                LegacyMoneyImportMapper.decimalToMinor(
                  row.value('refund_amount'),
                ),
              ),
              currencyCode: currencyCode,
              description: row.text('description') ?? '',
              notes: Value(row.text('notes')),
              merchant: Value(row.text('merchant')),
              location: Value(row.text('location')),
              accountId: accountId,
              toAccountId: Value(
                context.accountIds.contains(toAccountId) ? toAccountId : null,
              ),
              categoryId: categorySelection.categoryId,
              subCategoryId: Value(categorySelection.subCategoryId),
              paymentMethod: LegacyMoneyImportMapper.paymentMethodStorage(
                row.text('payment_method'),
              ),
              customPaymentMethodName: Value(
                row.text('custom_payment_method_name'),
              ),
              actualPayerAccount: actualPayerAccount,
              relatedTransactionId: Value(relatedTransactionId),
              installmentPlanId: Value(effectiveInstallmentPlanId),
              interestRateBasisPoints: Value(
                LegacyMoneyImportMapper.interestRateToBasisPoints(
                  row.value('interest_rate'),
                ),
              ),
              totalInterestMinor: Value(
                LegacyMoneyImportMapper.decimalToMinor(
                  row.value('total_interest'),
                ),
              ),
              calcMethod: Value(row.text('calc_method')),
              isDeleted: Value(row.boolValue('is_deleted')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );

      for (final tag in _parseTags(row.value('tags'))) {
        await database
            .into(database.moneyTransactionTags)
            .insert(
              MoneyTransactionTagsCompanion.insert(transactionId: id, tag: tag),
              mode: InsertMode.insertOrIgnore,
            );
      }

      await database
          .into(database.moneyLedgerTransactions)
          .insert(
            MoneyLedgerTransactionsCompanion.insert(
              ledgerId: options.personalLedgerId,
              transactionId: id,
              createdAt: createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
      context.transactionIds.add(id);
    }

    counts['transactions'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'transactions',
          message: '共有 $skipped 条流水因缺少必要关联被跳过。',
        ),
      );
    }
  }

  Future<void> _importLedgerTransactions(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;
    for (final row in legacy.rows('family_ledger_transaction')) {
      final ledgerId = row.text('family_ledger_serial_num');
      final transactionId = row.text('transaction_serial_num');
      if (ledgerId == null || transactionId == null) {
        continue;
      }
      if (ledgerId == options.personalLedgerId ||
          context.legacyPersonalLedgerIds.contains(ledgerId)) {
        continue;
      }
      if (!context.ledgerIds.contains(ledgerId) ||
          !context.transactionIds.contains(transactionId)) {
        skipped++;
        continue;
      }
      await database
          .into(database.moneyLedgerTransactions)
          .insert(
            MoneyLedgerTransactionsCompanion.insert(
              ledgerId: ledgerId,
              transactionId: transactionId,
              createdAt: row.dateTime('created_at') ?? DateTime.now(),
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }
    counts['family_ledger_transaction'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'family_ledger_transaction',
          message: '共有 $skipped 条账本流水关系因账本或流水不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importInstallmentPlans(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('installment_plans')) {
      final id = row.requiredText('serial_num');
      final accountId = row.text('account_serial_num');
      if (accountId == null || !context.accountIds.contains(accountId)) {
        skipped++;
        continue;
      }

      final transactionId = row.text('transaction_serial_num');
      final transaction = transactionId == null
          ? null
          : legacy.rowById('transactions', transactionId);
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      final categoryName = transaction?.text('category') ?? '分期';
      final subCategoryName = transaction?.text('sub_category');
      final categorySelection = await _ensureLegacyCategorySelection(
        options: options,
        context: context,
        kind: 'expense',
        categoryName: categoryName,
        subCategoryName: subCategoryName,
        createdAt: createdAt,
      );
      final totalPeriods = row.intValue('total_periods') ?? 1;
      final totalAmountMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('total_amount'),
      );
      final totalInterestMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('total_interest'),
      );
      final firstDueDate =
          row.dateTime('first_due_date') ??
          transaction?.dateTime('date') ??
          createdAt;
      final status = _installmentPlanStatus(row.text('status'));
      final remainingPeriods =
          row.intValue('remaining_periods') ??
          (status == MoneyInstallmentPlanStatus.completed.storageValue
              ? 0
              : totalPeriods);
      final currencyCode = transaction?.text('currency') ?? 'CNY';
      await _ensureCurrency(currencyCode);

      await database
          .into(database.moneyInstallmentPlans)
          .insert(
            MoneyInstallmentPlansCompanion.insert(
              id: id,
              userId: options.userId,
              accountId: accountId,
              transactionId: Value(
                context.transactionIds.contains(transactionId)
                    ? transactionId
                    : null,
              ),
              name: transaction?.text('description') ?? '分期',
              description: Value(transaction?.text('notes')),
              categoryId: categorySelection.categoryId,
              subCategoryId: Value(categorySelection.subCategoryId),
              totalAmountMinor: totalAmountMinor,
              totalPeriods: totalPeriods,
              remainingPeriods: remainingPeriods.clamp(0, totalPeriods).toInt(),
              periodAmountMinor:
                  LegacyMoneyImportMapper.decimalToMinor(
                    row.value('installment_amount'),
                  ).takeIfPositive() ??
                  ((totalAmountMinor + totalInterestMinor + totalPeriods - 1) ~/
                      totalPeriods),
              currencyCode: currencyCode,
              startDate: _dateKey(transaction?.dateTime('date') ?? createdAt),
              endDate: _dateKey(_addMonths(firstDueDate, totalPeriods - 1)),
              firstDueDate: _dateKey(firstDueDate),
              status: status,
              interestRateBasisPoints: Value(
                LegacyMoneyImportMapper.interestRateToBasisPoints(
                  row.value('interest_rate'),
                ),
              ),
              totalInterestMinor: Value(totalInterestMinor),
              calcMethod: Value(row.text('calc_method') ?? 'flat'),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.installmentPlanIds.add(id);
      imported++;
    }

    counts['installment_plans'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'installment_plans',
          message: '共有 $skipped 条分期计划因账户不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importInstallmentDetails(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('installment_details')) {
      final id = row.requiredText('serial_num');
      final planId = row.text('plan_serial_num');
      final accountId = row.text('account_serial_num');
      if (planId == null ||
          accountId == null ||
          !context.installmentPlanIds.contains(planId) ||
          !context.accountIds.contains(accountId)) {
        skipped++;
        continue;
      }

      final amountMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('amount'),
      );
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await database
          .into(database.moneyInstallmentDetails)
          .insert(
            MoneyInstallmentDetailsCompanion.insert(
              id: id,
              userId: options.userId,
              planId: planId,
              accountId: accountId,
              periodNumber: row.intValue('period_number') ?? 1,
              amountMinor: amountMinor,
              principalMinor: amountMinor,
              interestMinor: 0,
              dueDate: _dateKey(row.dateTime('due_date') ?? createdAt),
              paidDate: Value(_nullableDateKey(row.dateTime('paid_date'))),
              status: _installmentDetailStatus(row.text('status')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }

    counts['installment_details'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'installment_details',
          message: '共有 $skipped 条分期明细因计划或账户不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importSplitRules(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('split_rules')) {
      final id = row.requiredText('serial_num');
      final ledgerId = row.text('family_ledger_serial_num');
      if (ledgerId == null || !context.ledgerIds.contains(ledgerId)) {
        skipped++;
        continue;
      }
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await database
          .into(database.moneySplitRules)
          .insert(
            MoneySplitRulesCompanion.insert(
              id: id,
              userId: options.userId,
              ledgerId: ledgerId,
              name: row.text('name') ?? '分摊规则',
              ruleType: _splitType(row.text('rule_type')),
              ruleConfigJson: row.text('rule_config') ?? '{}',
              isActive: Value(row.boolValue('is_active', defaultValue: true)),
              priority: Value(row.intValue('priority') ?? 0),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.splitRuleIds.add(id);
      imported++;
    }

    counts['split_rules'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'split_rules',
          message: '共有 $skipped 条分摊规则因账本不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importSplitRecords(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('split_records')) {
      final id = row.requiredText('serial_num');
      final ledgerId = row.text('family_ledger_serial_num');
      if (ledgerId == null || !context.ledgerIds.contains(ledgerId)) {
        skipped++;
        continue;
      }
      final transactionId = row.text('transaction_serial_num');
      final splitRuleId = row.text('split_rule_serial_num');
      final payerMemberId = context.memberIdOrDefault(
        row.text('payer_member_serial_num'),
      );
      final currencyCode = row.text('currency') ?? 'CNY';
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await _ensureCurrency(currencyCode);

      await database
          .into(database.moneySplitRecords)
          .insert(
            MoneySplitRecordsCompanion.insert(
              id: id,
              userId: options.userId,
              ledgerId: ledgerId,
              transactionId: Value(
                context.transactionIds.contains(transactionId)
                    ? transactionId
                    : null,
              ),
              splitRuleId: Value(
                context.splitRuleIds.contains(splitRuleId) ? splitRuleId : null,
              ),
              status: _splitRecordStatus(row.text('status')),
              splitType: _splitType(row.text('split_type')),
              totalAmountMinor: LegacyMoneyImportMapper.decimalToMinor(
                row.value('total_amount'),
              ),
              currencyCode: currencyCode,
              payerMemberId: payerMemberId,
              notes: Value(row.text('notes') ?? row.text('description')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.splitRecordIds.add(id);
      imported++;

      if (!legacy.hasRowsWhere(
        'split_record_details',
        'split_record_serial_num',
        id,
      )) {
        await _insertFallbackSplitDetail(row, options, context, createdAt);
      }
    }

    counts['split_records'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'split_records',
          message: '共有 $skipped 条分摊记录因账本不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importSplitRecordDetails(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('split_record_details')) {
      final id = row.requiredText('serial_num');
      final splitRecordId = row.text('split_record_serial_num');
      final memberId = context.resolveMemberId(row.text('member_serial_num'));
      if (splitRecordId == null ||
          memberId == null ||
          !context.splitRecordIds.contains(splitRecordId)) {
        skipped++;
        continue;
      }
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await database
          .into(database.moneySplitRecordDetails)
          .insert(
            MoneySplitRecordDetailsCompanion.insert(
              id: id,
              userId: options.userId,
              splitRecordId: splitRecordId,
              memberId: memberId,
              amountMinor: LegacyMoneyImportMapper.decimalToMinor(
                row.value('amount'),
              ),
              percentageBasisPoints: Value(
                _percentageToBasisPoints(row.value('percentage')),
              ),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }

    counts['split_record_details'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'split_record_details',
          message: '共有 $skipped 条分摊明细因分摊记录或成员不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _importBudgets(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('budget')) {
      final id = row.requiredText('serial_num');
      final accountId = row.text('account_serial_num');
      final safeAccountId = context.accountIds.contains(accountId)
          ? accountId
          : null;
      final ledgerId = row.text('family_ledger_serial_num');
      final safeLedgerId = context.ledgerIds.contains(ledgerId)
          ? ledgerId
          : options.personalLedgerId;
      final createdBy = context.memberIdOrDefault(row.text('created_by'));
      final trackingType = _budgetTrackingType(row);
      final categoryName =
          _categoryNameFromBudgetScope(row.value('category_scope')) ??
          (safeAccountId == null
              ? _defaultCategoryName(
                  trackingType ==
                          MoneyBudgetTrackingType.incomeTarget.storageValue
                      ? 'income'
                      : 'expense',
                )
              : null);
      final categoryKind =
          trackingType == MoneyBudgetTrackingType.incomeTarget.storageValue
          ? 'income'
          : 'expense';
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      final categoryId = categoryName == null
          ? null
          : (await _ensureLegacyCategorySelection(
              options: options,
              context: context,
              kind: categoryKind,
              categoryName: categoryName,
              subCategoryName: null,
              createdAt: createdAt,
            )).categoryId;
      if (safeAccountId == null && categoryId == null) {
        skipped++;
        continue;
      }
      final currencyCode = row.text('currency') ?? 'CNY';
      await _ensureCurrency(currencyCode);

      await database
          .into(database.moneyBudgets)
          .insert(
            MoneyBudgetsCompanion.insert(
              id: id,
              userId: options.userId,
              accountId: Value(safeAccountId),
              ledgerId: Value(safeLedgerId),
              createdByMemberId: Value(createdBy),
              name: row.text('name') ?? '预算',
              description: Value(row.text('description')),
              amountMinor: LegacyMoneyImportMapper.decimalToMinor(
                row.value('amount'),
              ),
              currencyCode: currencyCode,
              repeatPeriodType: _budgetPeriodType(
                row.text('repeat_period_type'),
              ),
              repeatInterval: row.intValue('repeat_period') ?? 1,
              startDate: _dateKey(row.dateTime('start_date') ?? createdAt),
              endDate: _dateKey(row.dateTime('end_date') ?? createdAt),
              usedAmountMinor: Value(
                LegacyMoneyImportMapper.decimalToMinor(
                  row.value('used_amount'),
                ),
              ),
              isActive: Value(row.boolValue('is_active', defaultValue: true)),
              alertEnabled: Value(row.boolValue('alert_enabled')),
              alertThresholdPercent: Value(row.intValue('alert_threshold')),
              color: Value(row.text('color')),
              currentPeriodUsedMinor: Value(
                LegacyMoneyImportMapper.decimalToMinor(
                  row.value('current_period_used'),
                ),
              ),
              currentPeriodStartDate: _dateKey(
                row.dateTime('current_period_start') ??
                    row.dateTime('start_date') ??
                    createdAt,
              ),
              lastResetAt: row.dateTime('last_reset_at') ?? createdAt,
              budgetType: 'legacy_snapshot',
              trackingType: Value(trackingType),
              progressMinor: Value(
                LegacyMoneyImportMapper.decimalToMinor(row.value('progress')),
              ),
              linkedGoal: Value(row.text('linked_goal')),
              priority: Value(row.intValue('priority') ?? 0),
              autoRollover: Value(row.boolValue('auto_rollover')),
              scopeType: _budgetScopeType(
                categoryId: categoryId,
                accountId: safeAccountId,
              ),
              accountScopeJson: Value(row.text('account_scope')),
              categoryScopeJson: Value(
                _budgetScopeJson(categoryId: categoryId),
              ),
              advancedRulesJson: Value(row.text('advanced_rules')),
              tagsJson: Value(row.text('tags')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      context.budgetIds.add(id);
      imported++;
    }

    counts['budget'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'budget',
          message: '共有 $skipped 条预算因缺少账户或分类范围被跳过。',
        ),
      );
    }
  }

  Future<void> _importBudgetAllocations(
    _LegacyMoneyRows legacy,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    List<LegacyMoneyImportWarning> warnings,
    Map<String, int> counts,
  ) async {
    var imported = 0;
    var skipped = 0;

    for (final row in legacy.rows('budget_allocations')) {
      final id = row.requiredText('serial_num');
      final budgetId = row.text('budget_serial_num');
      if (budgetId == null || !context.budgetIds.contains(budgetId)) {
        skipped++;
        continue;
      }
      final memberId = row.text('member_serial_num');
      final safeMemberId = context.resolveMemberId(memberId);
      final categoryId = _resolveLegacyCategoryReference(
        context,
        row.text('category_serial_num'),
      );
      final allocatedAmountMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('allocated_amount'),
      );
      final usedAmountMinor = LegacyMoneyImportMapper.decimalToMinor(
        row.value('used_amount'),
      );
      final createdAt = row.dateTime('created_at') ?? DateTime.now();
      await database
          .into(database.moneyBudgetAllocations)
          .insert(
            MoneyBudgetAllocationsCompanion.insert(
              id: id,
              userId: options.userId,
              budgetId: budgetId,
              categoryId: Value(categoryId),
              memberId: Value(safeMemberId),
              allocatedAmountMinor: allocatedAmountMinor,
              usedAmountMinor: Value(usedAmountMinor),
              remainingAmountMinor: row.value('remaining_amount') == null
                  ? allocatedAmountMinor - usedAmountMinor
                  : LegacyMoneyImportMapper.decimalToMinor(
                      row.value('remaining_amount'),
                    ),
              percentageBasisPoints: Value(
                _percentageToBasisPoints(row.value('percentage')),
              ),
              allocationType: row.text('allocation_type') ?? 'fixed_amount',
              ruleConfigJson: Value(row.text('rule_config')),
              allowOverspend: Value(row.boolValue('allow_overspend')),
              overspendLimitType: Value(row.text('overspend_limit_type')),
              overspendLimitMinor: Value(
                LegacyMoneyImportMapper.nullableDecimalToMinor(
                  row.value('overspend_limit_value'),
                ),
              ),
              alertEnabled: Value(row.boolValue('alert_enabled')),
              alertThresholdPercent: row.intValue('alert_threshold') ?? 80,
              alertConfigJson: Value(row.text('alert_config')),
              priority: Value(row.intValue('priority') ?? 0),
              isMandatory: Value(row.boolValue('is_mandatory')),
              status: _activeStatus(row.text('status')),
              notes: Value(row.text('notes')),
              createdAt: createdAt,
              updatedAt: row.dateTime('updated_at') ?? createdAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
      imported++;
    }

    counts['budget_allocations'] = imported;
    if (skipped > 0) {
      warnings.add(
        LegacyMoneyImportWarning(
          severity: LegacyMoneyImportWarningSeverity.warning,
          tableName: 'budget_allocations',
          message: '共有 $skipped 条预算分配因预算不存在被跳过。',
        ),
      );
    }
  }

  Future<void> _insertFallbackSplitDetail(
    Map<String, Object?> row,
    LegacyMoneyImportOptions options,
    _LegacyMoneyImportContext context,
    DateTime createdAt,
  ) async {
    final splitRecordId = row.text('serial_num');
    final legacyMemberId = row.text('owe_member_serial_num');
    final memberId = context.resolveMemberId(legacyMemberId);
    if (splitRecordId == null || memberId == null) {
      return;
    }
    await database
        .into(database.moneySplitRecordDetails)
        .insert(
          MoneySplitRecordDetailsCompanion.insert(
            id: 'legacy_split_detail_${_stableKey('$splitRecordId::$legacyMemberId')}',
            userId: options.userId,
            splitRecordId: splitRecordId,
            memberId: memberId,
            amountMinor: LegacyMoneyImportMapper.decimalToMinor(
              row.value('split_amount'),
            ),
            percentageBasisPoints: Value(
              _percentageToBasisPoints(row.value('split_percentage')),
            ),
            createdAt: createdAt,
            updatedAt: row.dateTime('updated_at') ?? createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _ensureCurrency(String code) async {
    await database
        .into(database.moneyCurrencies)
        .insert(
          MoneyCurrenciesCompanion.insert(
            code: code,
            locale: _defaultLocaleForCurrency(code),
            symbol: _defaultSymbolForCurrency(code),
            isDefault: Value(code == 'CNY'),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<_ResolvedLegacyCategory> _ensureLegacyCategorySelection({
    required LegacyMoneyImportOptions options,
    required _LegacyMoneyImportContext context,
    required String kind,
    required String categoryName,
    required String? subCategoryName,
    required DateTime createdAt,
  }) async {
    final target = _legacyCategoryTarget(
      kind: kind,
      categoryName: categoryName,
      subCategoryName: subCategoryName,
    );
    if (target != null) {
      _registerLegacyCategoryTarget(
        context: context,
        kind: kind,
        categoryName: categoryName,
        subCategoryName: subCategoryName,
        target: target,
      );
      return _ResolvedLegacyCategory(
        categoryId: target.categoryId,
        subCategoryId: target.subCategoryId,
      );
    }

    final categoryId = await _ensureCategory(
      options: options,
      context: context,
      kind: kind,
      name: categoryName,
      createdAt: createdAt,
    );
    final subCategoryId = subCategoryName == null
        ? null
        : await _ensureSubCategory(
            options: options,
            context: context,
            kind: kind,
            categoryName: categoryName,
            subCategoryName: subCategoryName,
            createdAt: createdAt,
          );
    return _ResolvedLegacyCategory(
      categoryId: categoryId,
      subCategoryId: subCategoryId,
    );
  }

  static const Map<String, _LegacyCategoryTarget>
  _legacyCategoryTargets = <String, _LegacyCategoryTarget>{
    'expense::food': _LegacyCategoryTarget(categoryId: 'expense_food'),
    'expense::food::restaurant': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_restaurant',
    ),
    'expense::food::groceries': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_groceries',
    ),
    'expense::food::cookingingredients': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_ingredients',
    ),
    'expense::food::takeout': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_takeout',
    ),
    'expense::food::snacks': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_snacks',
    ),
    'expense::food::coffeetea': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_coffee_tea',
    ),
    'expense::food::alcohol': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_drinks',
    ),
    'expense::food::diningvouchers': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_restaurant',
    ),
    'expense::food::fooddeliveryfee': _LegacyCategoryTarget(
      categoryId: 'expense_food',
      subCategoryId: 'expense_food_takeout',
    ),
    'expense::transport': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
    ),
    'expense::transport::bus': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_public',
    ),
    'expense::transport::taxi': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_taxi',
    ),
    'expense::transport::rideshare': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_taxi',
    ),
    'expense::transport::train': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_train',
    ),
    'expense::transport::flight': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_flight',
    ),
    'expense::transport::fuel': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_fuel',
    ),
    'expense::transport::parking': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_parking',
    ),
    'expense::transport::tollbridge': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_toll',
    ),
    'expense::transport::bikerental': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_bike',
    ),
    'expense::transport::parkingfine': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_parking_fine',
    ),
    'expense::transport::ferry': _LegacyCategoryTarget(
      categoryId: 'expense_transport',
      subCategoryId: 'expense_transport_ferry',
    ),
    'expense::shopping': _LegacyCategoryTarget(categoryId: 'expense_shopping'),
    'expense::shopping::supermarket': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_supermarket',
    ),
    'expense::shopping::onlineshopping': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_online',
    ),
    'expense::shopping::conveniencestore': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_convenience',
    ),
    'expense::shopping::streetvendor': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_street_vendor',
    ),
    'expense::shopping::farmersmarket': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_farmers_market',
    ),
    'expense::shopping::clothing': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_clothing',
    ),
    'expense::shopping::footwear': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_footwear',
    ),
    'expense::shopping::householdgoods': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_daily',
    ),
    'expense::shopping::electronics': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_digital',
    ),
    'expense::shopping::cosmetics': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_beauty',
    ),
    'expense::shopping::pharmacy': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_medicine',
    ),
    'expense::shopping::expressdelivery': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_express',
    ),
    'expense::shopping::secondhandtrading': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_secondhand',
    ),
    'expense::shopping::accessories': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_accessories',
    ),
    'expense::shopping::jewelry': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_jewelry',
    ),
    'expense::shopping::toys': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_toys',
    ),
    'expense::shopping::booksmagazines': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_books',
    ),
    'expense::shopping::babyproducts': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_baby',
    ),
    'expense::shopping::shoppingmall': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_mall',
    ),
    'expense::shopping::specialtystore': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_specialty_store',
    ),
    'expense::shopping::gasstationstore': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_gas_station_store',
    ),
    'expense::shopping::dutyfreeshop': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_duty_free',
    ),
    'expense::shopping::fleamarket': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_flea_market',
    ),
    'expense::utilities': _LegacyCategoryTarget(categoryId: 'expense_housing'),
    'expense::utilities::propertyrental': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_rent',
    ),
    'expense::utilities::propertymanagement': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_property',
    ),
    'expense::utilities::electricity': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_electricity',
    ),
    'expense::utilities::water': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_water',
    ),
    'expense::utilities::gas': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_gas',
    ),
    'expense::utilities::internet': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_internet',
    ),
    'expense::utilities::phonebill': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_phone',
    ),
    'expense::utilities::heating': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_heating',
    ),
    'expense::utilities::cable': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_internet',
    ),
    'expense::utilities::garbagedisposal': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_garbage',
    ),
    'expense::utilities::solarpanel': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_solar',
    ),
    'expense::entertainment': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
    ),
    'expense::entertainment::movies': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_movies',
    ),
    'expense::entertainment::concerts': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_concerts',
    ),
    'expense::entertainment::karaoke': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_karaoke',
    ),
    'expense::entertainment::gaming': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_games',
    ),
    'expense::entertainment::theater': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_theater',
    ),
    'expense::entertainment::exhibition': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_exhibition',
    ),
    'expense::entertainment::streaming': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_streaming',
    ),
    'expense::entertainment::e-sports': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_esports',
    ),
    'expense::entertainment::amusementpark': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_amusement',
    ),
    'expense::entertainment::hobbysupplies': _LegacyCategoryTarget(
      categoryId: 'expense_entertainment',
      subCategoryId: 'expense_entertainment_hobby',
    ),
    'expense::subscription': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
    ),
    'expense::subscription::software': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_software',
    ),
    'expense::subscription::netflix': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_streaming',
    ),
    'expense::subscription::spotify': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_streaming',
    ),
    'expense::subscription::cloudstorage': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_cloud',
    ),
    'expense::subscription::streamingsub': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_streaming',
    ),
    'expense::subscription::knowledgepaid': _LegacyCategoryTarget(
      categoryId: 'expense_subscription',
      subCategoryId: 'expense_subscription_knowledge',
    ),
    'expense::healthcare': _LegacyCategoryTarget(categoryId: 'expense_health'),
    'expense::healthcare::doctorvisit': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_hospital',
    ),
    'expense::healthcare::medications': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_medicine',
    ),
    'expense::healthcare::hospitalization': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_hospitalization',
    ),
    'expense::healthcare::dental': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_dental',
    ),
    'expense::healthcare::physicalexamination': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_checkup',
    ),
    'expense::healthcare::vaccination': _LegacyCategoryTarget(
      categoryId: 'expense_health',
      subCategoryId: 'expense_health_vaccination',
    ),
    'expense::insurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
    ),
    'expense::insurance::healthinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_health',
    ),
    'expense::insurance::carinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_car',
    ),
    'expense::insurance::lifeinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_life',
    ),
    'expense::insurance::propertyinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_property',
    ),
    'expense::insurance::travelinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_travel',
    ),
    'expense::insurance::petinsurance': _LegacyCategoryTarget(
      categoryId: 'expense_insurance',
      subCategoryId: 'expense_insurance_pet',
    ),
    'expense::gift': _LegacyCategoryTarget(categoryId: 'expense_gift'),
    'expense::gift::redpacketexpense': _LegacyCategoryTarget(
      categoryId: 'expense_gift',
      subCategoryId: 'expense_gift_red_packet',
    ),
    'expense::gift::giftsent': _LegacyCategoryTarget(
      categoryId: 'expense_gift',
      subCategoryId: 'expense_gift_sent',
    ),
    'expense::gift::charitydonation': _LegacyCategoryTarget(
      categoryId: 'expense_gift',
      subCategoryId: 'expense_gift_charity',
    ),
    'expense::gift::corporategift': _LegacyCategoryTarget(
      categoryId: 'expense_gift',
      subCategoryId: 'expense_gift_business',
    ),
    'expense::loan': _LegacyCategoryTarget(categoryId: 'expense_loan'),
    'expense::loan::mortgage': _LegacyCategoryTarget(
      categoryId: 'expense_loan',
      subCategoryId: 'expense_loan_mortgage',
    ),
    'expense::loan::carloan': _LegacyCategoryTarget(
      categoryId: 'expense_loan',
      subCategoryId: 'expense_loan_car',
    ),
    'expense::loan::personalloan': _LegacyCategoryTarget(
      categoryId: 'expense_loan',
      subCategoryId: 'expense_loan_personal',
    ),
    'expense::loan::creditcardpayment': _LegacyCategoryTarget(
      categoryId: 'expense_loan',
      subCategoryId: 'expense_loan_credit_card',
    ),
    'expense::loan::overduepenalty': _LegacyCategoryTarget(
      categoryId: 'expense_other',
      subCategoryId: 'expense_other_fees',
    ),
    'expense::transfer': _LegacyCategoryTarget(categoryId: 'system_transfer'),
    'expense::transfer::accounttransfer': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'expense::transfer::friendfamilytransfer': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_family',
    ),
    'expense::transfer::creditcardrepayment': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_credit_card',
    ),
    'expense::transfer::loanrepayment': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_credit_card',
    ),
    'expense::transfer::investmentwithdrawal': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'expense::transfer::platformwithdrawal': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'expense::education': _LegacyCategoryTarget(
      categoryId: 'expense_education',
    ),
    'expense::education::tuition': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_tuition',
    ),
    'expense::education::textbooks': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_books',
    ),
    'expense::education::courses': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_courses',
    ),
    'expense::education::studyabroad': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_study_abroad',
    ),
    'expense::education::tutoring': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_tutoring',
    ),
    'expense::education::examfees': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_exams',
    ),
    'expense::education::educationaltools': _LegacyCategoryTarget(
      categoryId: 'expense_education',
      subCategoryId: 'expense_education_tools',
    ),
    'expense::travel': _LegacyCategoryTarget(categoryId: 'expense_travel'),
    'expense::travel::hotel': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_hotel',
    ),
    'expense::travel::tourpackage': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_package',
    ),
    'expense::travel::airticket': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_air_ticket',
    ),
    'expense::travel::visafee': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_visa',
    ),
    'expense::travel::touristguide': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_guide',
    ),
    'expense::travel::travelsouvenirs': _LegacyCategoryTarget(
      categoryId: 'expense_travel',
      subCategoryId: 'expense_travel_souvenir',
    ),
    'expense::home': _LegacyCategoryTarget(categoryId: 'expense_housing'),
    'expense::home::furniture': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_supplies',
    ),
    'expense::home::householdappliances': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_appliances',
    ),
    'expense::home::decoritems': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_decor',
    ),
    'expense::home::cleaningtools': _LegacyCategoryTarget(
      categoryId: 'expense_shopping',
      subCategoryId: 'expense_shopping_daily',
    ),
    'expense::home::gardening': _LegacyCategoryTarget(
      categoryId: 'expense_housing',
      subCategoryId: 'expense_housing_gardening',
    ),
    'expense::pet': _LegacyCategoryTarget(categoryId: 'expense_pet'),
    'expense::pet::petfood': _LegacyCategoryTarget(
      categoryId: 'expense_pet',
      subCategoryId: 'expense_pet_food',
    ),
    'expense::pet::petvet': _LegacyCategoryTarget(
      categoryId: 'expense_pet',
      subCategoryId: 'expense_pet_vet',
    ),
    'expense::pet::pettoys': _LegacyCategoryTarget(
      categoryId: 'expense_pet',
      subCategoryId: 'expense_pet_toys',
    ),
    'expense::pet::petgrooming': _LegacyCategoryTarget(
      categoryId: 'expense_pet',
      subCategoryId: 'expense_pet_grooming',
    ),
    'expense::pet::petboarding': _LegacyCategoryTarget(
      categoryId: 'expense_pet',
      subCategoryId: 'expense_pet_boarding',
    ),
    'expense::business': _LegacyCategoryTarget(categoryId: 'expense_business'),
    'expense::business::officesupplies': _LegacyCategoryTarget(
      categoryId: 'expense_business',
      subCategoryId: 'expense_business_office_supplies',
    ),
    'expense::business::equipmentpurchase': _LegacyCategoryTarget(
      categoryId: 'expense_business',
      subCategoryId: 'expense_business_equipment',
    ),
    'expense::business::travelexpenses': _LegacyCategoryTarget(
      categoryId: 'expense_business',
      subCategoryId: 'expense_business_travel',
    ),
    'expense::business::marketing': _LegacyCategoryTarget(
      categoryId: 'expense_business',
      subCategoryId: 'expense_business_marketing',
    ),
    'expense::business::consultingfees': _LegacyCategoryTarget(
      categoryId: 'expense_business',
      subCategoryId: 'expense_business_consulting',
    ),
    'expense::charity': _LegacyCategoryTarget(categoryId: 'expense_charity'),
    'expense::charity::donation': _LegacyCategoryTarget(
      categoryId: 'expense_charity',
      subCategoryId: 'expense_charity_donation',
    ),
    'expense::charity::materialdonation': _LegacyCategoryTarget(
      categoryId: 'expense_charity',
      subCategoryId: 'expense_charity_material',
    ),
    'expense::charity::projectsupport': _LegacyCategoryTarget(
      categoryId: 'expense_charity',
      subCategoryId: 'expense_charity_project',
    ),
    'expense::others': _LegacyCategoryTarget(categoryId: 'expense_other'),
    'expense::other': _LegacyCategoryTarget(categoryId: 'expense_other'),
    'expense::others::other': _LegacyCategoryTarget(
      categoryId: 'expense_other',
      subCategoryId: 'expense_other_misc',
    ),
    'expense::other::other': _LegacyCategoryTarget(
      categoryId: 'expense_other',
      subCategoryId: 'expense_other_misc',
    ),
    'expense::分期': _LegacyCategoryTarget(categoryId: 'expense_loan'),
    'income::salary': _LegacyCategoryTarget(categoryId: 'income_salary'),
    'income::salary::monthlysalary': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_base',
    ),
    'income::salary::overtime': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_overtime',
    ),
    'income::salary::allowance': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_allowance',
    ),
    'income::salary::commission': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_commission',
    ),
    'income::salary::retirementpension': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_pension',
    ),
    'income::salary::parttimejob': _LegacyCategoryTarget(
      categoryId: 'income_salary',
      subCategoryId: 'income_salary_part_time',
    ),
    'income::salary::bonus': _LegacyCategoryTarget(
      categoryId: 'income_bonus',
      subCategoryId: 'income_bonus_performance',
    ),
    'income::gift': _LegacyCategoryTarget(categoryId: 'income_gift'),
    'income::gift::redpacketincome': _LegacyCategoryTarget(
      categoryId: 'income_gift',
      subCategoryId: 'income_gift_red_packet',
    ),
    'income::gift::giftreceived': _LegacyCategoryTarget(
      categoryId: 'income_gift',
      subCategoryId: 'income_gift_received',
    ),
    'expense::转账': _LegacyCategoryTarget(categoryId: 'system_transfer'),
    'income::转账': _LegacyCategoryTarget(categoryId: 'system_transfer'),
    'income::transfer': _LegacyCategoryTarget(categoryId: 'system_transfer'),
    'income::transfer::accounttransfer': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'income::transfer::friendfamilytransfer': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_family',
    ),
    'income::transfer::creditcardrepayment': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_credit_card',
    ),
    'income::transfer::loanrepayment': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_credit_card',
    ),
    'income::transfer::investmentwithdrawal': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'income::transfer::platformwithdrawal': _LegacyCategoryTarget(
      categoryId: 'system_transfer',
      subCategoryId: 'expense_transfer_account',
    ),
    'income::savings': _LegacyCategoryTarget(categoryId: 'income_savings'),
    'income::savings::bankinterest': _LegacyCategoryTarget(
      categoryId: 'income_savings',
      subCategoryId: 'income_savings_bank_interest',
    ),
    'income::savings::fixeddeposit': _LegacyCategoryTarget(
      categoryId: 'income_savings',
      subCategoryId: 'income_savings_fixed_deposit',
    ),
    'income::savings::moneymarketfund': _LegacyCategoryTarget(
      categoryId: 'income_savings',
      subCategoryId: 'income_savings_money_market',
    ),
    'income::savings::shorttermbond': _LegacyCategoryTarget(
      categoryId: 'income_savings',
      subCategoryId: 'income_savings_short_bond',
    ),
    'income::investment': _LegacyCategoryTarget(
      categoryId: 'income_investment',
    ),
    'income::investment::stockdividend': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_stock',
    ),
    'income::investment::bondinterest': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_interest',
    ),
    'income::investment::funddistribution': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_fund',
    ),
    'income::investment::rentalincome': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_rent',
    ),
    'income::investment::cryptoincome': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_crypto',
    ),
    'income::investment::royalties': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_royalties',
    ),
    'income::investment::dividendreinvestment': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_reinvestment',
    ),
    'income::investment::capitalgain': _LegacyCategoryTarget(
      categoryId: 'income_investment',
      subCategoryId: 'income_investment_capital_gain',
    ),
    'income::reimbursement': _LegacyCategoryTarget(
      categoryId: 'income_reimbursement',
    ),
    'income::reimbursement::medicalreimbursement': _LegacyCategoryTarget(
      categoryId: 'income_reimbursement',
      subCategoryId: 'income_reimbursement_medical',
    ),
    'income::reimbursement::businessreimbursement': _LegacyCategoryTarget(
      categoryId: 'income_reimbursement',
      subCategoryId: 'income_reimbursement_business',
    ),
    'income::reimbursement::travelreimbursement': _LegacyCategoryTarget(
      categoryId: 'income_reimbursement',
      subCategoryId: 'income_reimbursement_travel',
    ),
    'income::reimbursement::otherreimbursement': _LegacyCategoryTarget(
      categoryId: 'income_reimbursement',
      subCategoryId: 'income_reimbursement_other',
    ),
    'income::business': _LegacyCategoryTarget(categoryId: 'income_business'),
    'income::business::serviceincome': _LegacyCategoryTarget(
      categoryId: 'income_business',
      subCategoryId: 'income_business_service',
    ),
    'income::business::projectpayment': _LegacyCategoryTarget(
      categoryId: 'income_business',
      subCategoryId: 'income_business_project',
    ),
    'income::business::salesincome': _LegacyCategoryTarget(
      categoryId: 'income_business',
      subCategoryId: 'income_business_sales',
    ),
    'income::business::contractincome': _LegacyCategoryTarget(
      categoryId: 'income_business',
      subCategoryId: 'income_business_contract',
    ),
    'income::loan': _LegacyCategoryTarget(categoryId: 'income_loan'),
    'income::loan::personalborrowing': _LegacyCategoryTarget(
      categoryId: 'income_loan',
      subCategoryId: 'income_loan_personal',
    ),
    'income::loan::bankloandisbursement': _LegacyCategoryTarget(
      categoryId: 'income_loan',
      subCategoryId: 'income_loan_bank',
    ),
    'income::loan::creditlinedrawdown': _LegacyCategoryTarget(
      categoryId: 'income_loan',
      subCategoryId: 'income_loan_credit_line',
    ),
    'income::others': _LegacyCategoryTarget(categoryId: 'income_other'),
    'income::other': _LegacyCategoryTarget(categoryId: 'income_other'),
    'income::others::other': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_misc',
    ),
    'income::other::other': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_misc',
    ),
    'income::others::taxrefund': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_tax_refund',
    ),
    'income::others::subsidy': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_subsidy',
    ),
    'income::others::refundincome': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_refund',
    ),
    'income::others::windfall': _LegacyCategoryTarget(
      categoryId: 'income_other',
      subCategoryId: 'income_other_windfall',
    ),
  };

  static _LegacyCategoryTarget? _legacyCategoryTarget({
    required String kind,
    required String categoryName,
    required String? subCategoryName,
  }) {
    if (subCategoryName != null) {
      final subTarget =
          _legacyCategoryTargets[_legacyCategoryLookupKey(
            kind,
            categoryName,
            subCategoryName,
          )];
      if (subTarget != null) {
        return subTarget;
      }
    }
    return _legacyCategoryTargets[_legacyCategoryLookupKey(kind, categoryName)];
  }

  static bool _isLegacyTransferTransaction({
    required String rawKind,
    required String categoryName,
    required String? subCategoryName,
  }) {
    if (rawKind == MoneyTransactionType.transfer.storageValue) {
      return true;
    }
    final target = _legacyCategoryTarget(
      kind: rawKind,
      categoryName: categoryName,
      subCategoryName: subCategoryName,
    );
    return target?.categoryId == 'system_transfer';
  }

  static String _legacyTransferDirectionMarker(String rawKind) {
    return rawKind == MoneyTransactionType.income.storageValue
        ? 'transfer_in'
        : 'transfer_out';
  }

  static void _registerLegacyCategoryTarget({
    required _LegacyMoneyImportContext context,
    required String kind,
    required String categoryName,
    required String? subCategoryName,
    required _LegacyCategoryTarget target,
  }) {
    final categoryOnlyTarget = _legacyCategoryTarget(
      kind: kind,
      categoryName: categoryName,
      subCategoryName: null,
    );
    context.categoryIds[_categoryKey(kind, categoryName)] =
        categoryOnlyTarget?.categoryId ?? target.categoryId;
    final subCategoryId = target.subCategoryId;
    if (subCategoryName != null && subCategoryId != null) {
      context.subCategoryIds[_subCategoryKey(
            kind,
            categoryName,
            subCategoryName,
          )] =
          subCategoryId;
    }
  }

  static String _legacyCategoryLookupKey(
    String kind,
    String categoryName, [
    String? subCategoryName,
  ]) {
    final categoryKey = '${kind.toLowerCase()}::${categoryName.toLowerCase()}';
    if (subCategoryName == null) {
      return categoryKey;
    }
    return '$categoryKey::${subCategoryName.toLowerCase()}';
  }

  Future<String> _ensureCategory({
    required LegacyMoneyImportOptions options,
    required _LegacyMoneyImportContext context,
    required String kind,
    required String name,
    required DateTime createdAt,
    String? color,
    String? icon,
  }) async {
    final categoryKey = _categoryKey(kind, name);
    final existing = context.categoryIds[categoryKey];
    if (existing != null) {
      return existing;
    }

    final categoryId = 'legacy_category_${_stableKey(categoryKey)}';
    await database
        .into(database.moneyCategories)
        .insert(
          MoneyCategoriesCompanion.insert(
            id: categoryId,
            userId: Value(options.userId),
            name: name,
            kind: kind,
            color: Value(color),
            icon: Value(icon),
            isSystem: const Value(false),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    context.categoryIds[categoryKey] = categoryId;
    return categoryId;
  }

  Future<String> _ensureSubCategory({
    required LegacyMoneyImportOptions options,
    required _LegacyMoneyImportContext context,
    required String kind,
    required String categoryName,
    required String subCategoryName,
    required DateTime createdAt,
    String? icon,
  }) async {
    final subCategoryKey = _subCategoryKey(kind, categoryName, subCategoryName);
    final existing = context.subCategoryIds[subCategoryKey];
    if (existing != null) {
      return existing;
    }

    final categoryId = await _ensureCategory(
      options: options,
      context: context,
      kind: kind,
      name: categoryName,
      createdAt: createdAt,
    );
    final subCategoryId = 'legacy_sub_category_${_stableKey(subCategoryKey)}';
    await database
        .into(database.moneySubCategories)
        .insert(
          MoneySubCategoriesCompanion.insert(
            id: subCategoryId,
            categoryId: categoryId,
            userId: Value(options.userId),
            name: subCategoryName,
            kind: kind,
            icon: Value(icon),
            isSystem: const Value(false),
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    context.subCategoryIds[subCategoryKey] = subCategoryId;
    return subCategoryId;
  }

  static int _dateKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  static int? _nullableDateKey(DateTime? date) {
    return date == null ? null : _dateKey(date);
  }

  static DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final day = date.day.clamp(1, _daysInMonth(year, month)).toInt();
    return DateTime(year, month, day);
  }

  static int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static int? _percentageToBasisPoints(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return null;
    }
    return (parsed * 100).round();
  }

  static String _installmentPlanStatus(String? value) {
    return switch (value) {
      'completed' ||
      'Completed' ||
      'PAID' ||
      'Paid' ||
      'paid' => MoneyInstallmentPlanStatus.completed.storageValue,
      'cancelled' ||
      'Cancelled' ||
      'CANCELLED' => MoneyInstallmentPlanStatus.cancelled.storageValue,
      _ => MoneyInstallmentPlanStatus.active.storageValue,
    };
  }

  static String _installmentDetailStatus(String? value) {
    return switch (value) {
      'posted' ||
      'Posted' ||
      'PAID' ||
      'Paid' ||
      'paid' => MoneyInstallmentDetailStatus.posted.storageValue,
      'skipped' ||
      'Skipped' ||
      'SKIPPED' => MoneyInstallmentDetailStatus.skipped.storageValue,
      _ => MoneyInstallmentDetailStatus.pending.storageValue,
    };
  }

  static String _splitType(String? value) {
    return MoneySplitType.fromStorageValue(value ?? '').storageValue;
  }

  static String _splitRecordStatus(String? value) {
    return switch (value) {
      'cancelled' ||
      'Cancelled' ||
      'CANCELLED' => MoneySplitRecordStatus.cancelled.storageValue,
      _ => MoneySplitRecordStatus.active.storageValue,
    };
  }

  static String _budgetTrackingType(Map<String, Object?> row) {
    final trackingType = row.text('tracking_type');
    if (trackingType != null &&
        (trackingType == MoneyBudgetTrackingType.incomeTarget.storageValue ||
            trackingType ==
                MoneyBudgetTrackingType.expenseLimit.storageValue)) {
      return trackingType;
    }

    final budgetType = row.text('budget_type')?.toLowerCase() ?? '';
    if (budgetType.contains('income') ||
        budgetType.contains('target') ||
        budgetType.contains('goal')) {
      return MoneyBudgetTrackingType.incomeTarget.storageValue;
    }
    return MoneyBudgetTrackingType.expenseLimit.storageValue;
  }

  static String _budgetPeriodType(String? value) {
    return switch (value) {
      'daily' || 'Daily' || 'DAY' || 'Day' => 'daily',
      'weekly' || 'Weekly' || 'WEEK' || 'Week' => 'weekly',
      'yearly' || 'Yearly' || 'YEAR' || 'Year' => 'yearly',
      _ => 'monthly',
    };
  }

  static String _budgetScopeType({
    required String? categoryId,
    required String? accountId,
  }) {
    if (categoryId != null && accountId != null) {
      return 'category_account';
    }
    if (accountId != null) {
      return 'account';
    }
    return 'category';
  }

  static String? _budgetScopeJson({required String? categoryId}) {
    if (categoryId == null) {
      return null;
    }
    return jsonEncode(<String, String?>{'categoryId': categoryId});
  }

  static String? _categoryNameFromBudgetScope(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List && decoded.isNotEmpty) {
        return decoded.first?.toString();
      }
      if (decoded is Map) {
        final included = decoded['included'];
        if (included is List && included.isNotEmpty) {
          return included.first?.toString();
        }
        final categoryId = decoded['categoryId'] ?? decoded['category'];
        return categoryId?.toString();
      }
    } catch (_) {
      // Fall through to raw text support.
    }
    return text;
  }

  static String? _resolveLegacyCategoryReference(
    _LegacyMoneyImportContext context,
    String? value,
  ) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (context.categoryIds.containsValue(value)) {
      return value;
    }
    final expenseTarget = _legacyCategoryTarget(
      kind: 'expense',
      categoryName: value,
      subCategoryName: null,
    );
    if (expenseTarget != null) {
      return expenseTarget.categoryId;
    }
    final incomeTarget = _legacyCategoryTarget(
      kind: 'income',
      categoryName: value,
      subCategoryName: null,
    );
    if (incomeTarget != null) {
      return incomeTarget.categoryId;
    }
    return context.categoryIds[_categoryKey('expense', value)] ??
        context.categoryIds[_categoryKey('income', value)];
  }

  static String _categoryKey(String kind, String name) => '$kind::$name';

  static String _subCategoryKey(
    String kind,
    String categoryName,
    String subCategoryName,
  ) {
    return '$kind::$categoryName::$subCategoryName';
  }

  static String _stableKey(String value) {
    final bytes = utf8.encode(value);
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  static String _defaultCategoryName(String kind) {
    return switch (kind) {
      'income' => '未分类收入',
      'transfer' => '转账',
      _ => '未分类支出',
    };
  }

  static String _defaultLocaleForCurrency(String code) {
    return switch (code) {
      'CNY' => 'zh_CN',
      'USD' => 'en_US',
      'EUR' => 'de_DE',
      'JPY' => 'ja_JP',
      _ => 'zh_CN',
    };
  }

  static String _defaultSymbolForCurrency(String code) {
    return switch (code) {
      'CNY' => '¥',
      'USD' => r'$',
      'EUR' => '€',
      'JPY' => '¥',
      _ => code,
    };
  }

  static String _memberRole(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'owner' => 'owner',
      'admin' || 'manager' => 'manager',
      _ => 'participant',
    };
  }

  static bool _isLegacySelfMember(
    String? legacyMemberName,
    LegacyMoneyImportOptions options,
  ) {
    final normalized = _normalizeMemberName(legacyMemberName);
    if (normalized.isEmpty) {
      return false;
    }
    return options.selfMemberNames.any(
      (name) => _normalizeMemberName(name) == normalized,
    );
  }

  static String _normalizeMemberName(String? value) {
    return value?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '') ?? '';
  }

  static String _ledgerType(String? value) {
    final normalized = value?.trim().toLowerCase();
    return normalized == 'personal' ? 'personal' : 'family';
  }

  static String _activeStatus(String? value) {
    return switch (value) {
      'inactive' || 'Inactive' || 'disabled' || 'Disabled' => 'inactive',
      _ => 'active',
    };
  }

  static List<String> _parseTags(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return const [];
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      // Fall through to comma-separated parsing for older free-form values.
    }
    return text
        .split(RegExp(r'[,，#\s]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

class _LegacyMoneyRows {
  const _LegacyMoneyRows(this._rowsByTable);

  final Map<String, List<Map<String, Object?>>> _rowsByTable;

  List<Map<String, Object?>> rows(String tableName) {
    return _rowsByTable[tableName] ?? const [];
  }

  Map<String, Object?>? rowById(String tableName, String id) {
    for (final row in rows(tableName)) {
      if (row.text('serial_num') == id) {
        return row;
      }
    }
    return null;
  }

  bool hasRowsWhere(String tableName, String columnName, String value) {
    return rows(tableName).any((row) => row.text(columnName) == value);
  }
}

class _LegacyMoneyImportContext {
  _LegacyMoneyImportContext({required this.options}) {
    memberIds.add(options.defaultMemberId);
    ledgerIds.add(options.personalLedgerId);
  }

  final LegacyMoneyImportOptions options;
  final Set<String> accountIds = <String>{};
  final Set<String> memberIds = <String>{};
  final Set<String> ledgerIds = <String>{};
  final Set<String> legacyPersonalLedgerIds = <String>{};
  final Set<String> transactionIds = <String>{};
  final Set<String> installmentPlanIds = <String>{};
  final Set<String> splitRuleIds = <String>{};
  final Set<String> splitRecordIds = <String>{};
  final Set<String> budgetIds = <String>{};
  final Map<String, String> categoryIds = <String, String>{};
  final Map<String, String> subCategoryIds = <String, String>{};
  final Map<String, String> memberIdAliases = <String, String>{};

  void registerMemberAlias(String legacyMemberId, String memberId) {
    if (legacyMemberId.isEmpty || memberId.isEmpty) {
      return;
    }
    memberIdAliases[legacyMemberId] = memberId;
  }

  String? resolveMemberId(String? memberId) {
    if (memberId == null || memberId.isEmpty) {
      return null;
    }
    final aliasedMemberId = memberIdAliases[memberId];
    if (aliasedMemberId != null) {
      return aliasedMemberId;
    }
    return memberIds.contains(memberId) ? memberId : null;
  }

  String memberIdOrDefault(String? memberId) {
    return resolveMemberId(memberId) ?? options.defaultMemberId;
  }
}

class _ResolvedLegacyCategory {
  const _ResolvedLegacyCategory({
    required this.categoryId,
    required this.subCategoryId,
  });

  final String categoryId;
  final String? subCategoryId;
}

class _LegacyCategoryTarget {
  const _LegacyCategoryTarget({required this.categoryId, this.subCategoryId});

  final String categoryId;
  final String? subCategoryId;
}

extension _LegacyMoneyRowRead on Map<String, Object?> {
  Object? value(String key) => this[key];

  String requiredText(String key) {
    final text = this[key]?.toString().trim();
    if (text == null || text.isEmpty) {
      throw LegacyMoneyImportException('旧数据缺少必要字段: $key');
    }
    return text;
  }

  String? text(String key) {
    final text = this[key]?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  int? intValue(String key) {
    final value = this[key];
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool boolValue(String key, {bool defaultValue = false}) {
    final value = this[key];
    return switch (value) {
      bool value => value,
      int value => value != 0,
      String value => value == 'true' || value == '1' || value == 'TRUE',
      _ => defaultValue,
    };
  }

  DateTime? dateTime(String key) {
    return LegacyMoneyImportMapper.nullableDateTime(this[key]);
  }
}

class LegacyMoneyImportException implements Exception {
  const LegacyMoneyImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

extension _PositiveIntRead on int {
  int? takeIfPositive() {
    return this > 0 ? this : null;
  }
}
