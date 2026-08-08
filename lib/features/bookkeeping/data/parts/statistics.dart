part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Statistics on _DriftMoneyRepositoryBase {
  @override
  Future<MoneySpendingAnalysis> getSpendingAnalysisForUser(
    String userId,
    MoneySpendingAnalysisQuery query,
  ) async {
    try {
      final ledger = await _getLedgerForUser(userId, query.ledgerId);
      final transactionIds = await _transactionIdsForLedger(userId, ledger.id);
      final statisticsQuery = MoneyStatisticsQuery(
        dateStart: query.dateStart,
        dateEndExclusive: query.dateEndExclusive,
        groupBy: MoneyStatisticsGroupBy.month,
        ledgerId: ledger.id,
        accountId: query.accountId,
        accountType: query.accountType,
        paymentMethod: query.paymentMethod,
        typeFocus: MoneyStatisticsTypeFocus.expense,
      );
      final rows = await _statisticsTransactions(
        userId: userId,
        query: statisticsQuery,
        transactionIds: transactionIds,
      );
      final expenseRows = rows
          .where((row) => row.type == MoneyTransactionType.expense.storageValue)
          .toList();
      final currencyCode = _dominantCurrencyCode(expenseRows);
      final filteredRows = expenseRows
          .where((row) => row.currencyCode == currencyCode)
          .toList();

      final categoryIds = filteredRows.map((row) => row.categoryId).toSet();
      final subCategoryIds = filteredRows
          .map((row) => row.subCategoryId)
          .whereType<String>()
          .where((id) => id.trim().isNotEmpty)
          .toSet();
      final categories = categoryIds.isEmpty
          ? const <MoneyCategory>[]
          : await (database.select(database.moneyCategories)
                  ..where((category) => category.id.isIn(categoryIds.toList())))
                .get();
      final subCategories = subCategoryIds.isEmpty
          ? const <MoneySubCategory>[]
          : await (database.select(database.moneySubCategories)..where(
                  (subCategory) =>
                      subCategory.id.isIn(subCategoryIds.toList()) &
                      subCategory.isDeleted.equals(false),
                ))
                .get();
      final categoryNameById = {
        for (final category in categories) category.id: category.name,
      };
      final subCategoryNameById = {
        for (final subCategory in subCategories)
          subCategory.id: subCategory.name,
      };

      final samples = <MoneySpendingAnalysisSample>[];
      for (final row in filteredRows) {
        final month = row.transactionAt.toLocal();
        final categoryName = categoryNameById[row.categoryId] ?? '未命名分类';
        samples.add(
          MoneySpendingAnalysisSample(
            dimension: MoneySpendingAnalysisDimension.category.storageValue,
            id: row.categoryId,
            name: categoryName,
            month: month,
            amountMinor: _effectiveTransactionAmountMinor(row),
            transactionCount: 1,
          ),
        );

        final subCategoryId = row.subCategoryId;
        if (subCategoryId != null && subCategoryId.trim().isNotEmpty) {
          final subCategoryName =
              subCategoryNameById[subCategoryId] ?? subCategoryId;
          samples.add(
            MoneySpendingAnalysisSample(
              dimension:
                  MoneySpendingAnalysisDimension.subCategory.storageValue,
              id: subCategoryId,
              name: '$categoryName / $subCategoryName',
              month: month,
              amountMinor: _effectiveTransactionAmountMinor(row),
              transactionCount: 1,
            ),
          );
        }

        final merchant = _blankToNull(row.merchant);
        if (merchant != null) {
          samples.add(
            MoneySpendingAnalysisSample(
              dimension: MoneySpendingAnalysisDimension.merchant.storageValue,
              id: merchant.toLowerCase(),
              name: merchant,
              month: month,
              amountMinor: _effectiveTransactionAmountMinor(row),
              transactionCount: 1,
            ),
          );
        }
      }

      return MoneySpendingAnalysis.fromSamples(
        currencyCode: currencyCode,
        currentMonth: query.currentMonth,
        baselineMonthCount: query.baselineMonthCount,
        windowMonthCount: query.windowMonthCount,
        samples: samples,
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyStatisticsSummary> getStatisticsForUser(
    String userId,
    MoneyStatisticsQuery query,
  ) async {
    try {
      final ledger = await _getLedgerForUser(userId, query.ledgerId);
      final transactionIds = await _transactionIdsForLedger(userId, ledger.id);
      final rows = await _statisticsTransactions(
        userId: userId,
        query: query,
        transactionIds: transactionIds,
      );
      final currencyCode = _dominantCurrencyCode(rows);
      final filteredRows = rows
          .where((row) => row.currencyCode == currencyCode)
          .toList();
      final previousQuery = _shiftStatisticsQuery(
        query,
        start: _previousStatisticsStart(query),
        endExclusive: query.dateStart,
      );
      final previousRows = await _statisticsTransactions(
        userId: userId,
        query: previousQuery,
        transactionIds: transactionIds,
      );
      final previousFilteredRows = previousRows
          .where((row) => row.currencyCode == currencyCode)
          .toList();
      final sameYearQuery = _shiftStatisticsQuery(
        query,
        start: DateTime(
          query.dateStart.year - 1,
          query.dateStart.month,
          query.dateStart.day,
        ),
        endExclusive: DateTime(
          query.dateEndExclusive.year - 1,
          query.dateEndExclusive.month,
          query.dateEndExclusive.day,
        ),
      );
      final sameYearRows = await _statisticsTransactions(
        userId: userId,
        query: sameYearQuery,
        transactionIds: transactionIds,
      );
      final sameYearFilteredRows = sameYearRows
          .where((row) => row.currencyCode == currencyCode)
          .toList();

      return MoneyStatisticsSummary(
        currencyCode: currencyCode,
        totalIncomeMinor: _sumByType(filteredRows, MoneyTransactionType.income),
        totalExpenseMinor: _sumByType(
          filteredRows,
          MoneyTransactionType.expense,
        ),
        incomeTransactionCount: _countByType(
          filteredRows,
          MoneyTransactionType.income,
        ),
        expenseTransactionCount: _countByType(
          filteredRows,
          MoneyTransactionType.expense,
        ),
        trend: _buildStatisticsTrend(filteredRows, query),
        expenseCategories: await _buildCategorySlices(
          filteredRows,
          MoneyTransactionType.expense,
        ),
        incomeCategories: await _buildCategorySlices(
          filteredRows,
          MoneyTransactionType.income,
        ),
        accounts: await _buildAccountSlices(
          userId,
          accountId: query.accountId,
          accountType: query.accountType,
        ),
        accountTypes: await _buildAccountTypeSlices(
          userId,
          accountId: query.accountId,
          accountType: query.accountType,
        ),
        paymentMethods: _buildPaymentMethodSlices(filteredRows, query),
        accountPaymentMethods: await _buildAccountPaymentMethodSlices(
          filteredRows,
          query,
        ),
        merchants: _buildMerchantSlices(filteredRows),
        expenseSubCategories: await _buildSubCategorySlices(
          filteredRows,
          MoneyTransactionType.expense,
        ),
        incomeSubCategories: await _buildSubCategorySlices(
          filteredRows,
          MoneyTransactionType.income,
        ),
        hasMixedCurrencies: rows.any((row) => row.currencyCode != currencyCode),
        familyMembers: ledger.ledgerType == 'family'
            ? await _buildFamilyMemberSlices(userId, ledger.id)
            : const <MoneyStatisticsMemberSlice>[],
        previousPeriod: _buildComparisonSummary(previousFilteredRows),
        samePeriodLastYear: _buildComparisonSummary(sameYearFilteredRows),
      );
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<Map<MoneyPaymentMethod, int>> getPaymentMethodUsageRanksForUser(
    String userId,
  ) async {
    await ensureReadyForUser(userId);
    final rows = await (database.select(
      database.moneyPaymentMethodUsageStats,
    )..where((row) => row.userId.equals(userId))).get();
    return {
      for (final row in rows)
        MoneyPaymentMethod.fromStorageValue(row.paymentMethod): row.useCount,
    };
  }

  @override
  Future<void> refreshUsageStatsForUser(String userId) async {
    await ensureReadyForUser(userId);
    await _rebuildUsageStatsForUser(userId);
  }

  @override
  Future<void> refreshUsageStatsForAllUsers() async {
    final users = await (database.select(
      database.users,
    )..where((row) => row.isDeleted.equals(false))).get();
    for (final user in users) {
      await _tryRebuildUsageStatsForUser(user.id);
    }
  }

  Future<List<MoneyTransaction>> _statisticsTransactions({
    required String userId,
    required MoneyStatisticsQuery query,
    required List<String> transactionIds,
  }) async {
    if (transactionIds.isEmpty) {
      return Future.value(const <MoneyTransaction>[]);
    }
    final accountType = query.accountType;
    final accountIdsForType = accountType == null
        ? null
        : await _accountIdsForType(userId, accountType);
    if (accountIdsForType != null && accountIdsForType.isEmpty) {
      return const <MoneyTransaction>[];
    }

    return (database.select(database.moneyTransactions)..where((row) {
          var predicate =
              row.userId.equals(userId) &
              row.id.isIn(transactionIds) &
              row.isDeleted.equals(false) &
              row.status.equals(MoneyTransactionStatus.completed.storageValue) &
              row.actualPayerAccount.isNotIn([
                _DriftMoneyRepositoryBase._transferInMarker,
              ]) &
              row.categoryId.isNotIn(
                _DriftMoneyRepositoryBase._transferCategoryIds,
              ) &
              row.type.isIn([
                MoneyTransactionType.income.storageValue,
                MoneyTransactionType.expense.storageValue,
              ]) &
              row.transactionAt.isBiggerOrEqualValue(query.dateStart.toUtc()) &
              row.transactionAt.isSmallerThanValue(
                query.dateEndExclusive.toUtc(),
              );

          final accountId = query.accountId;
          if (accountId != null) {
            predicate = predicate & row.accountId.equals(accountId);
          }
          if (accountIdsForType != null) {
            predicate = predicate & row.accountId.isIn(accountIdsForType);
          }
          final paymentMethod = query.paymentMethod;
          if (paymentMethod != null) {
            predicate =
                predicate &
                row.paymentMethod.equals(paymentMethod.storageValue);
          }

          return predicate;
        }))
        .get();
  }

  List<MoneyStatisticsTrendPoint> _buildStatisticsTrend(
    List<MoneyTransaction> transactions,
    MoneyStatisticsQuery query,
  ) {
    final buckets = <DateTime, _IncomeExpenseTotals>{};
    var cursor = query.groupBy == MoneyStatisticsGroupBy.day
        ? DateTime(
            query.dateStart.year,
            query.dateStart.month,
            query.dateStart.day,
          )
        : DateTime(query.dateStart.year, query.dateStart.month);

    while (cursor.isBefore(query.dateEndExclusive)) {
      buckets[cursor] = const _IncomeExpenseTotals(
        incomeMinor: 0,
        expenseMinor: 0,
      );
      cursor = query.groupBy == MoneyStatisticsGroupBy.day
          ? cursor.add(const Duration(days: 1))
          : DateTime(cursor.year, cursor.month + 1);
    }

    for (final transaction in transactions) {
      final local = transaction.transactionAt.toLocal();
      final bucket = query.groupBy == MoneyStatisticsGroupBy.day
          ? DateTime(local.year, local.month, local.day)
          : DateTime(local.year, local.month);
      final current = buckets[bucket];
      if (current == null) {
        continue;
      }

      if (transaction.type == MoneyTransactionType.income.storageValue) {
        buckets[bucket] = _IncomeExpenseTotals(
          incomeMinor:
              current.incomeMinor +
              _effectiveTransactionAmountMinor(transaction),
          expenseMinor: current.expenseMinor,
        );
      } else if (transaction.type ==
          MoneyTransactionType.expense.storageValue) {
        buckets[bucket] = _IncomeExpenseTotals(
          incomeMinor: current.incomeMinor,
          expenseMinor:
              current.expenseMinor +
              _effectiveTransactionAmountMinor(transaction),
        );
      }
    }

    return [
      for (final entry in buckets.entries)
        MoneyStatisticsTrendPoint(
          bucketStart: entry.key,
          incomeMinor: entry.value.incomeMinor,
          expenseMinor: entry.value.expenseMinor,
        ),
    ];
  }

  Future<List<MoneyStatisticsCategorySlice>> _buildCategorySlices(
    List<MoneyTransaction> transactions,
    MoneyTransactionType type,
  ) async {
    final targetRows = transactions
        .where((row) => row.type == type.storageValue)
        .toList();
    final total = targetRows.fold<int>(
      0,
      (sum, row) => sum + _effectiveTransactionAmountMinor(row),
    );
    if (total <= 0) {
      return const <MoneyStatisticsCategorySlice>[];
    }

    final amountByCategory = <String, int>{};
    for (final transaction in targetRows) {
      amountByCategory[transaction.categoryId] =
          (amountByCategory[transaction.categoryId] ?? 0) +
          _effectiveTransactionAmountMinor(transaction);
    }

    final categories =
        await (database.select(database.moneyCategories)..where(
              (category) => category.id.isIn(amountByCategory.keys.toList()),
            ))
            .get();
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    final slices = [
      for (final entry in amountByCategory.entries)
        MoneyStatisticsCategorySlice(
          categoryId: entry.key,
          categoryName: categoryNameById[entry.key] ?? '未命名分类',
          amountMinor: entry.value,
          percentage: entry.value / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices;
  }

  List<MoneyStatisticsPaymentMethodSlice> _buildPaymentMethodSlices(
    List<MoneyTransaction> transactions,
    MoneyStatisticsQuery query,
  ) {
    final rows = transactions.where((row) {
      return switch (query.typeFocus) {
        MoneyStatisticsTypeFocus.income =>
          row.type == MoneyTransactionType.income.storageValue,
        MoneyStatisticsTypeFocus.expense =>
          row.type == MoneyTransactionType.expense.storageValue,
        MoneyStatisticsTypeFocus.balance => true,
      };
    }).toList();

    final buckets = <String, _MutableStatisticsPaymentMethod>{};
    for (final row in rows) {
      final method = MoneyPaymentMethod.fromStorageValue(row.paymentMethod);
      final customPaymentMethodName = _blankToNull(row.customPaymentMethodName);
      final label = _statisticsPaymentMethodLabel(row, method);
      final key = '${method.storageValue}|$label';
      final bucket = buckets.putIfAbsent(
        key,
        () => _MutableStatisticsPaymentMethod(
          method: method,
          label: label,
          customPaymentMethodName: customPaymentMethodName,
        ),
      );
      if (row.type == MoneyTransactionType.income.storageValue) {
        bucket.incomeMinor += _effectiveTransactionAmountMinor(row);
      } else if (row.type == MoneyTransactionType.expense.storageValue) {
        bucket.expenseMinor += _effectiveTransactionAmountMinor(row);
      }
      bucket.transactionCount += 1;
    }

    final total = buckets.values.fold<int>(
      0,
      (sum, bucket) => sum + _statisticsPaymentAmount(bucket, query.typeFocus),
    );
    if (total <= 0) {
      return const <MoneyStatisticsPaymentMethodSlice>[];
    }

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsPaymentMethodSlice(
          paymentMethod: bucket.method,
          label: bucket.label,
          customPaymentMethodName: bucket.customPaymentMethodName,
          amountMinor: _statisticsPaymentAmount(bucket, query.typeFocus),
          incomeMinor: bucket.incomeMinor,
          expenseMinor: bucket.expenseMinor,
          transactionCount: bucket.transactionCount,
          percentage: _statisticsPaymentAmount(bucket, query.typeFocus) / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices.take(10).toList();
  }

  List<MoneyStatisticsRankSlice> _buildMerchantSlices(
    List<MoneyTransaction> transactions,
  ) {
    final buckets = <String, _MutableStatisticsRank>{};
    for (final row in transactions) {
      if (row.type != MoneyTransactionType.expense.storageValue) {
        continue;
      }
      final merchant = _blankToNull(row.merchant);
      if (merchant == null) {
        continue;
      }
      final key = merchant.toLowerCase();
      final bucket = buckets.putIfAbsent(
        key,
        () => _MutableStatisticsRank(id: key, name: merchant),
      );
      bucket.amountMinor += _effectiveTransactionAmountMinor(row);
      bucket.transactionCount += 1;
    }

    final total = buckets.values.fold<int>(
      0,
      (sum, bucket) => sum + bucket.amountMinor,
    );
    if (total <= 0) {
      return const <MoneyStatisticsRankSlice>[];
    }

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsRankSlice(
          id: bucket.id,
          name: bucket.name,
          amountMinor: bucket.amountMinor,
          transactionCount: bucket.transactionCount,
          percentage: bucket.amountMinor / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices.take(10).toList();
  }

  Future<List<MoneyStatisticsRankSlice>> _buildSubCategorySlices(
    List<MoneyTransaction> transactions,
    MoneyTransactionType type,
  ) async {
    final buckets = <String, _MutableStatisticsRank>{};
    final categoryIds = <String>{};
    for (final row in transactions) {
      if (row.type != type.storageValue) {
        continue;
      }
      final subCategoryId = row.subCategoryId;
      if (subCategoryId == null || subCategoryId.trim().isEmpty) {
        continue;
      }
      categoryIds.add(row.categoryId);
      final bucket = buckets.putIfAbsent(
        subCategoryId,
        () => _MutableStatisticsRank(id: subCategoryId, name: subCategoryId),
      );
      bucket.amountMinor += _effectiveTransactionAmountMinor(row);
      bucket.transactionCount += 1;
    }
    if (buckets.isEmpty) {
      return const <MoneyStatisticsRankSlice>[];
    }

    final subCategories =
        await (database.select(database.moneySubCategories)..where(
              (subCategory) =>
                  subCategory.id.isIn(buckets.keys.toList()) &
                  subCategory.isDeleted.equals(false),
            ))
            .get();
    final categories = categoryIds.isEmpty
        ? const <MoneyCategory>[]
        : await (database.select(database.moneyCategories)..where(
                (category) =>
                    category.id.isIn(categoryIds.toList()) &
                    category.isDeleted.equals(false),
              ))
              .get();
    final categoryNameById = {
      for (final category in categories) category.id: category.name,
    };
    for (final subCategory in subCategories) {
      final categoryName = categoryNameById[subCategory.categoryId];
      buckets[subCategory.id] =
          _MutableStatisticsRank(
              id: subCategory.id,
              name: categoryName == null
                  ? subCategory.name
                  : '$categoryName / ${subCategory.name}',
            )
            ..amountMinor = buckets[subCategory.id]!.amountMinor
            ..transactionCount = buckets[subCategory.id]!.transactionCount;
    }

    final total = buckets.values.fold<int>(
      0,
      (sum, bucket) => sum + bucket.amountMinor,
    );
    if (total <= 0) {
      return const <MoneyStatisticsRankSlice>[];
    }

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsRankSlice(
          id: bucket.id,
          name: bucket.name,
          amountMinor: bucket.amountMinor,
          transactionCount: bucket.transactionCount,
          percentage: bucket.amountMinor / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices.take(10).toList();
  }

  Future<List<MoneyStatisticsMemberSlice>> _buildFamilyMemberSlices(
    String userId,
    String ledgerId,
  ) async {
    final ledger = await _getLedgerForUser(userId, ledgerId);
    if (ledger.ledgerType != 'family') {
      return const <MoneyStatisticsMemberSlice>[];
    }

    final members = await _membersForLedger(userId, ledgerId);
    if (members.isEmpty) {
      return const <MoneyStatisticsMemberSlice>[];
    }

    final recordRows =
        await (database.select(database.moneySplitRecords)..where((record) {
              return record.userId.equals(userId) &
                  record.ledgerId.equals(ledgerId) &
                  record.status.equals(
                    MoneySplitRecordStatus.active.storageValue,
                  ) &
                  record.isDeleted.equals(false);
            }))
            .get();
    if (recordRows.isEmpty) {
      return const <MoneyStatisticsMemberSlice>[];
    }

    final recordIds = recordRows.map((row) => row.id).toList();
    final detailRows =
        await (database.select(database.moneySplitRecordDetails)
              ..where((detail) {
                return detail.userId.equals(userId) &
                    detail.splitRecordId.isIn(recordIds) &
                    detail.isDeleted.equals(false);
              }))
            .get();

    final buckets = <String, _MutableStatisticsMember>{
      for (final member in members)
        member.id: _MutableStatisticsMember(
          memberId: member.id,
          memberName: member.name,
          role: member.role,
        ),
    };

    for (final record in recordRows) {
      final payer = buckets[record.payerMemberId];
      if (payer != null) {
        payer.paidAmountMinor += record.totalAmountMinor;
        payer.paidRecordCount += 1;
      }
    }

    for (final detail in detailRows) {
      final participant = buckets[detail.memberId];
      if (participant != null) {
        participant.participatedAmountMinor += detail.amountMinor;
        participant.participationCount += 1;
      }
    }

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsMemberSlice(
          memberId: bucket.memberId,
          memberName: bucket.memberName,
          role: bucket.role,
          paidAmountMinor: bucket.paidAmountMinor,
          participatedAmountMinor: bucket.participatedAmountMinor,
          paidRecordCount: bucket.paidRecordCount,
          participationCount: bucket.participationCount,
        ),
    ];
    slices.sort((a, b) {
      final delta = b.involvedAmountMinor.compareTo(a.involvedAmountMinor);
      if (delta != 0) {
        return delta;
      }
      return a.memberName.compareTo(b.memberName);
    });
    return slices;
  }

  Future<List<MoneyStatisticsAccountSlice>> _buildAccountSlices(
    String userId, {
    required String? accountId,
    required MoneyAccountType? accountType,
  }) async {
    final rows =
        await (database.select(database.moneyAccounts)..where((account) {
              var predicate =
                  account.userId.equals(userId) &
                  account.isActive.equals(true) &
                  account.isVirtual.equals(false) &
                  account.isDeleted.equals(false);
              if (accountId != null) {
                predicate = predicate & account.id.equals(accountId);
              }
              if (accountType != null) {
                predicate =
                    predicate & account.type.equals(accountType.storageValue);
              }
              return predicate;
            }))
            .get();

    final slices = <MoneyStatisticsAccountSlice>[];
    for (final row in rows) {
      final entity = _mapAccount(row);
      slices.add(
        MoneyStatisticsAccountSlice(
          accountId: entity.id,
          accountName: entity.name,
          currencyCode: entity.currencyCode,
          assetMinor: entity.type.isAssetLike
              ? entity.displayBalanceMinor.abs()
              : 0,
          liabilityMinor: entity.type.isCreditLike
              ? entity.usedCreditMinor.abs()
              : entity.type.isDebtLike
              ? entity.balanceMinor.abs()
              : 0,
        ),
      );
    }
    slices.sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return slices;
  }

  Future<List<MoneyStatisticsAccountTypeSlice>> _buildAccountTypeSlices(
    String userId, {
    required String? accountId,
    required MoneyAccountType? accountType,
  }) async {
    final rows =
        await (database.select(database.moneyAccounts)..where((account) {
              var predicate =
                  account.userId.equals(userId) &
                  account.isActive.equals(true) &
                  account.isVirtual.equals(false) &
                  account.isDeleted.equals(false);
              if (accountId != null) {
                predicate = predicate & account.id.equals(accountId);
              }
              if (accountType != null) {
                predicate =
                    predicate & account.type.equals(accountType.storageValue);
              }
              return predicate;
            }))
            .get();

    final buckets = <MoneyAccountType, _MutableAccountTypeStatistics>{};
    for (final row in rows) {
      final entity = _mapAccount(row);
      final bucket = buckets.putIfAbsent(
        entity.type,
        () => _MutableAccountTypeStatistics(
          type: entity.type,
          currencyCode: entity.currencyCode,
        ),
      );
      bucket.accountCount += 1;
      if (entity.type.isAssetLike) {
        bucket.assetMinor += entity.displayBalanceMinor.abs();
      } else if (entity.type.isCreditLike) {
        bucket.liabilityMinor += entity.usedCreditMinor.abs();
      } else if (entity.type.isDebtLike) {
        bucket.liabilityMinor += entity.balanceMinor.abs();
      }
    }

    final total = buckets.values.fold<int>(
      0,
      (sum, bucket) => sum + bucket.totalMinor,
    );
    if (total <= 0) {
      return const <MoneyStatisticsAccountTypeSlice>[];
    }

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsAccountTypeSlice(
          accountType: bucket.type,
          label: bucket.type.label,
          currencyCode: bucket.currencyCode,
          assetMinor: bucket.assetMinor,
          liabilityMinor: bucket.liabilityMinor,
          accountCount: bucket.accountCount,
          percentage: bucket.totalMinor / total,
        ),
    ]..sort((a, b) => b.totalMinor.compareTo(a.totalMinor));
    return slices;
  }

  @override
  Future<MoneyStatisticsInsights> getStatisticsInsightsForUser(
    String userId,
    MoneyStatisticsQuery query,
  ) async {
    try {
      final ledger = await _getLedgerForUser(userId, query.ledgerId);
      final transactionIds = await _transactionIdsForLedger(userId, ledger.id);
      final rows = await _statisticsTransactions(
        userId: userId,
        query: query,
        transactionIds: transactionIds,
      );
      final currencyCode = _dominantCurrencyCode(rows);
      final filteredRows = rows
          .where((row) => row.currencyCode == currencyCode)
          .toList();

      final expenseRows = filteredRows
          .where((row) => row.type == MoneyTransactionType.expense.storageValue)
          .toList();
      final expenseTotal = expenseRows.fold<int>(
        0,
        (sum, row) => sum + _effectiveTransactionAmountMinor(row),
      );

      return MoneyStatisticsInsights(
        currencyCode: currencyCode,
        timeSlices: _buildTimeSlices(expenseRows, expenseTotal),
        weekdaySlices: _buildWeekdaySlices(expenseRows, expenseTotal),
        refund: _buildRefundSummary(filteredRows),
        sourceSlices: _buildSourceSlices(expenseRows, expenseTotal),
        sourceTrend: await _buildSourceTrendWide(
          userId: userId,
          transactionIds: transactionIds,
          currencyCode: currencyCode,
          query: query,
        ),
        tagSlices: await _buildTagSlices(filteredRows),
        creditUtilization: await _buildCreditUtilizationSlices(userId),
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyUpcomingCashFlowSummary> getUpcomingCashFlowForUser(
    String userId, {
    required String ledgerId,
    int windowDays = 90,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);
      final today = _utcNow();
      final nowDateKey = _dateKey(today);
      final windowEndKey = _dateKey(today.add(Duration(days: windowDays)));
      final thirtyDayKey = _dateKey(today.add(const Duration(days: 30)));
      final items = <MoneyUpcomingCashFlowItem>[];
      int next30DaysMinor = 0;
      int next90DaysMinor = 0;

      // 1) Pending installment details
      final plans =
          await (database.select(database.moneyInstallmentPlans)..where(
                (plan) =>
                    plan.userId.equals(userId) &
                    (plan.ledgerId.equals(resolvedLedgerId) |
                        plan.ledgerId.isNull()) &
                    plan.status.equals(
                      MoneyInstallmentPlanStatus.active.storageValue,
                    ),
              ))
              .get();
      final planIds = plans.map((p) => p.id).toList();

      if (planIds.isNotEmpty) {
        final details =
            await (database.select(database.moneyInstallmentDetails)..where(
                  (detail) =>
                      detail.userId.equals(userId) &
                      detail.planId.isIn(planIds) &
                      detail.isDeleted.equals(false) &
                      detail.status.equals(
                        MoneyInstallmentDetailStatus.pending.storageValue,
                      ) &
                      detail.dueDate.isBetweenValues(nowDateKey, windowEndKey),
                ))
                .get();

        for (final detail in details) {
          final plan = plans.firstWhere((p) => p.id == detail.planId);
          final dueDate = _dateFromKey(detail.dueDate);
          items.add(
            MoneyUpcomingCashFlowItem(
              sourceType: 'installment',
              title: '${plan.name} · 第${detail.periodNumber}期',
              amountMinor: detail.amountMinor,
              currencyCode: plan.currencyCode,
              dueDate: dueDate,
            ),
          );
          if (detail.dueDate <= thirtyDayKey) {
            next30DaysMinor += detail.amountMinor;
          }
          next90DaysMinor += detail.amountMinor;
        }
      }

      // 2) Pending bill reminders
      final bills =
          await (database.select(database.moneyBillReminders)..where(
                (reminder) =>
                    reminder.userId.equals(userId) &
                    reminder.isDeleted.equals(false) &
                    (reminder.ledgerId.equals(resolvedLedgerId) |
                        reminder.ledgerId.isNull()) &
                    reminder.status.equals(
                      MoneyBillReminderStatus.pending.storageValue,
                    ) &
                    reminder.dueDate.isBetweenValues(nowDateKey, windowEndKey),
              ))
              .get();

      for (final bill in bills) {
        final dueDate = _dateFromKey(bill.dueDate);
        items.add(
          MoneyUpcomingCashFlowItem(
            sourceType: 'bill',
            title: bill.name,
            amountMinor: bill.amountMinor,
            currencyCode: bill.currencyCode,
            dueDate: dueDate,
          ),
        );
        if (bill.dueDate <= thirtyDayKey) {
          next30DaysMinor += bill.amountMinor;
        }
        next90DaysMinor += bill.amountMinor;
      }

      // 3) Auto-posting monthly recurring estimate
      final templates =
          await (database.select(database.moneyAutoPostingTemplates)..where(
                (template) =>
                    template.userId.equals(userId) &
                    template.isActive.equals(true) &
                    template.isDeleted.equals(false) &
                    (template.ledgerId.equals(resolvedLedgerId) |
                        template.ledgerId.isNull()),
              ))
              .get();
      int monthlyRecurringMinor = 0;
      for (final template in templates) {
        final freq = MoneyAutoPostingFrequency.fromStorageValue(
          template.frequency,
        );
        final monthlyFactor = switch (freq) {
          MoneyAutoPostingFrequency.daily => 30.0,
          MoneyAutoPostingFrequency.weekly => 4.33,
          MoneyAutoPostingFrequency.monthly => 1.0,
        };
        monthlyRecurringMinor += (template.amountMinor * monthlyFactor).round();
      }

      // Sort items by dueDate
      items.sort((a, b) => a.dueDate.compareTo(b.dueDate));

      return MoneyUpcomingCashFlowSummary(
        items: items,
        next30DaysMinor: next30DaysMinor,
        next90DaysMinor: next90DaysMinor,
        monthlyRecurringMinor: monthlyRecurringMinor,
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  List<MoneyStatisticsTimeSlice> _buildTimeSlices(
    List<MoneyTransaction> transactions,
    int total,
  ) {
    final buckets = <MoneyStatisticsTimeBucket, _IncomeExpenseTotals>{};
    final counts = <MoneyStatisticsTimeBucket, int>{};
    for (final row in transactions) {
      final bucket = MoneyStatisticsTimeBucket.forHour(
        row.transactionAt.toLocal().hour,
      );
      if (bucket == null) {
        continue;
      }
      final current =
          buckets[bucket] ??
          const _IncomeExpenseTotals(incomeMinor: 0, expenseMinor: 0);
      buckets[bucket] = _IncomeExpenseTotals(
        incomeMinor: current.incomeMinor,
        expenseMinor:
            current.expenseMinor + _effectiveTransactionAmountMinor(row),
      );
      counts[bucket] = (counts[bucket] ?? 0) + 1;
    }
    if (total <= 0) {
      return const <MoneyStatisticsTimeSlice>[];
    }
    return [
      for (final entry in buckets.entries)
        MoneyStatisticsTimeSlice(
          bucket: entry.key,
          amountMinor: entry.value.expenseMinor,
          transactionCount: counts[entry.key] ?? 0,
          percentage: entry.value.expenseMinor / total,
        ),
    ]..sort((a, b) => a.bucket.startHour.compareTo(b.bucket.startHour));
  }

  List<MoneyStatisticsWeekdaySlice> _buildWeekdaySlices(
    List<MoneyTransaction> transactions,
    int total,
  ) {
    final buckets = <int, int>{};
    final counts = <int, int>{};
    for (final row in transactions) {
      final weekday = row.transactionAt.toLocal().weekday;
      buckets[weekday] =
          (buckets[weekday] ?? 0) + _effectiveTransactionAmountMinor(row);
      counts[weekday] = (counts[weekday] ?? 0) + 1;
    }
    if (total <= 0) {
      return const <MoneyStatisticsWeekdaySlice>[];
    }
    return [
      for (var weekday = 1; weekday <= 7; weekday++)
        MoneyStatisticsWeekdaySlice(
          weekday: weekday,
          amountMinor: buckets[weekday] ?? 0,
          transactionCount: counts[weekday] ?? 0,
          percentage: (buckets[weekday] ?? 0) / total,
        ),
    ];
  }

  MoneyStatisticsRefundSummary _buildRefundSummary(
    List<MoneyTransaction> transactions,
  ) {
    var refundCount = 0;
    var refundAmountMinor = 0;
    var transactionCount = 0;
    var transactionAmountMinor = 0;
    for (final row in transactions) {
      final amount = _effectiveTransactionAmountMinor(row);
      transactionAmountMinor += amount;
      transactionCount += 1;
      if (row.refundAmountMinor > 0) {
        refundCount += 1;
        refundAmountMinor += row.refundAmountMinor;
      }
    }
    return MoneyStatisticsRefundSummary(
      refundCount: refundCount,
      refundAmountMinor: refundAmountMinor,
      transactionCount: transactionCount,
      transactionAmountMinor: transactionAmountMinor,
    );
  }

  List<MoneyStatisticsSourceSlice> _buildSourceSlices(
    List<MoneyTransaction> transactions,
    int total,
  ) {
    final buckets = <String, _MutableStatisticsRank>{};
    for (final row in transactions) {
      final isInstallment = _DriftMoneyRepositoryBase._isInstallmentPosting(
        row,
      );
      final isAutoPosting = _blankToNull(row.sourceTemplateRunId) != null;
      final sourceKey = isInstallment
          ? 'installment'
          : isAutoPosting
          ? 'auto_posting'
          : 'manual';
      final bucket = buckets.putIfAbsent(
        sourceKey,
        () => _MutableStatisticsRank(
          id: sourceKey,
          name: switch (sourceKey) {
            'installment' => '分期',
            'auto_posting' => '自动记账',
            _ => '手工',
          },
        ),
      );
      bucket.amountMinor += _effectiveTransactionAmountMinor(row);
      bucket.transactionCount += 1;
    }
    if (total <= 0) {
      return const <MoneyStatisticsSourceSlice>[];
    }
    return [
      for (final entry in buckets.entries)
        MoneyStatisticsSourceSlice(
          sourceType: entry.key,
          label: entry.value.name,
          amountMinor: entry.value.amountMinor,
          transactionCount: entry.value.transactionCount,
          percentage: entry.value.amountMinor / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
  }

  Future<List<MoneyStatisticsSourceTrendPoint>> _buildSourceTrendWide({
    required String userId,
    required List<String> transactionIds,
    required String currencyCode,
    required MoneyStatisticsQuery query,
  }) async {
    // Always show the last 12 months, regardless of the current filter range
    final end = DateTime.now();
    final start = DateTime(end.year, end.month - 11, 1);

    final wideQuery = MoneyStatisticsQuery(
      dateStart: start,
      dateEndExclusive: DateTime(end.year, end.month + 1, 1),
      groupBy: MoneyStatisticsGroupBy.month,
      ledgerId: query.ledgerId,
      accountId: query.accountId,
      accountType: query.accountType,
      paymentMethod: query.paymentMethod,
      typeFocus: query.typeFocus,
    );

    final wideRows = await _statisticsTransactions(
      userId: userId,
      query: wideQuery,
      transactionIds: transactionIds,
    );
    final filtered = wideRows
        .where((row) => row.currencyCode == currencyCode)
        .toList();

    return _buildSourceTrend(filtered, wideQuery);
  }

  List<MoneyStatisticsSourceTrendPoint> _buildSourceTrend(
    List<MoneyTransaction> transactions,
    MoneyStatisticsQuery query,
  ) {
    final buckets = <DateTime, _MutableSourceTrend>{};
    var cursor = query.groupBy == MoneyStatisticsGroupBy.day
        ? DateTime(
            query.dateStart.year,
            query.dateStart.month,
            query.dateStart.day,
          )
        : DateTime(query.dateStart.year, query.dateStart.month);

    while (cursor.isBefore(query.dateEndExclusive)) {
      buckets[cursor] = _MutableSourceTrend();
      cursor = query.groupBy == MoneyStatisticsGroupBy.day
          ? cursor.add(const Duration(days: 1))
          : DateTime(cursor.year, cursor.month + 1);
    }

    for (final row in transactions) {
      final local = row.transactionAt.toLocal();
      final bucket = query.groupBy == MoneyStatisticsGroupBy.day
          ? DateTime(local.year, local.month, local.day)
          : DateTime(local.year, local.month);
      final current = buckets[bucket];
      if (current == null) {
        continue;
      }
      if (row.type != MoneyTransactionType.expense.storageValue) {
        continue;
      }
      final amount = _effectiveTransactionAmountMinor(row);
      if (_DriftMoneyRepositoryBase._isInstallmentPosting(row)) {
        current.installmentMinor += amount;
      } else if (_blankToNull(row.sourceTemplateRunId) != null) {
        current.autoPostingMinor += amount;
      } else {
        current.otherMinor += amount;
      }
    }

    return [
      for (final entry in buckets.entries)
        MoneyStatisticsSourceTrendPoint(
          bucketStart: entry.key,
          installmentMinor: entry.value.installmentMinor,
          autoPostingMinor: entry.value.autoPostingMinor,
          otherMinor: entry.value.otherMinor,
        ),
    ];
  }

  Future<List<MoneyStatisticsTagSlice>> _buildTagSlices(
    List<MoneyTransaction> transactions,
  ) async {
    final transactionIds = [for (final row in transactions) row.id];
    if (transactionIds.isEmpty) {
      return const <MoneyStatisticsTagSlice>[];
    }
    final tagRows = await (database.select(
      database.moneyTransactionTags,
    )..where((tag) => tag.transactionId.isIn(transactionIds))).get();
    if (tagRows.isEmpty) {
      return const <MoneyStatisticsTagSlice>[];
    }
    final amountByTransactionId = <String, int>{
      for (final row in transactions)
        row.id: _effectiveTransactionAmountMinor(row),
    };
    final buckets = <String, _MutableStatisticsRank>{};
    for (final tagRow in tagRows) {
      final amount = amountByTransactionId[tagRow.transactionId] ?? 0;
      if (amount <= 0) {
        continue;
      }
      final bucket = buckets.putIfAbsent(
        tagRow.tag,
        () => _MutableStatisticsRank(id: tagRow.tag, name: tagRow.tag),
      );
      bucket.amountMinor += amount;
      bucket.transactionCount += 1;
    }
    if (buckets.isEmpty) {
      return const <MoneyStatisticsTagSlice>[];
    }
    final total = buckets.values.fold<int>(
      0,
      (sum, bucket) => sum + bucket.amountMinor,
    );
    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsTagSlice(
          tag: bucket.id,
          amountMinor: bucket.amountMinor,
          transactionCount: bucket.transactionCount,
          percentage: bucket.amountMinor / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices.take(10).toList();
  }

  Future<List<MoneyStatisticsCreditUtilizationSlice>>
  _buildCreditUtilizationSlices(String userId) async {
    final rows =
        await (database.select(database.moneyAccounts)..where(
              (account) =>
                  account.userId.equals(userId) &
                  account.isActive.equals(true) &
                  account.isVirtual.equals(false) &
                  account.isDeleted.equals(false),
            ))
            .get();
    final slices = <MoneyStatisticsCreditUtilizationSlice>[];
    for (final row in rows) {
      final entity = _mapAccount(row);
      if (!entity.type.isCreditLike) {
        continue;
      }
      slices.add(
        MoneyStatisticsCreditUtilizationSlice(
          accountId: entity.id,
          accountName: entity.name,
          currencyCode: entity.currencyCode,
          creditLimitMinor: entity.effectiveCreditLimitMinor,
          usedMinor: entity.usedCreditMinor,
          availableMinor: entity.availableCreditMinor,
        ),
      );
    }
    slices.sort((a, b) => b.usedMinor.compareTo(a.usedMinor));
    return slices;
  }
}

class _MutableSourceTrend {
  int installmentMinor = 0;
  int autoPostingMinor = 0;
  int otherMinor = 0;
}
