part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _Reports on _DriftMoneyRepositoryBase {
  @override
  Future<MoneyAnalysisReportEntity> generateReportForUser(
    String userId,
    MoneyAnalysisReportRequest request,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, request.ledgerId);

      final reportId = _uuid.v4();
      final now = _utcNow();

      // Write "generation_started" row
      await database
          .into(database.moneyAnalysisReports)
          .insert(
            MoneyAnalysisReportsCompanion.insert(
              id: reportId,
              userId: userId,
              scopeType: 'ledger',
              reportPeriod: request.reportPeriod,
              periodStartDate: _dateKey(request.periodStart),
              periodEndDate: _dateKey(request.periodEnd),
              status: 'generation_started',
              reportDataJson: '{}',
              createdAt: now,
              updatedAt: now,
              generationStartedAt: Value(now),
              ledgerId: Value(resolvedLedgerId),
            ),
          );

      // Aggregate data using existing statistics methods

      final statsQuery = MoneyStatisticsQuery(
        dateStart: request.periodStart,
        dateEndExclusive: request.periodEnd,
        groupBy: MoneyStatisticsGroupBy.month,
        ledgerId: resolvedLedgerId,
      );
      final summary = await getStatisticsForUser(userId, statsQuery);

      final insightsQuery = MoneyStatisticsQuery(
        dateStart: request.periodStart,
        dateEndExclusive: request.periodEnd,
        groupBy: MoneyStatisticsGroupBy.month,
        ledgerId: resolvedLedgerId,
      );
      final insights = await getStatisticsInsightsForUser(
        userId,
        insightsQuery,
      );

      final trend = await getBudgetHistoryTrendForUser(
        userId,
        resolvedLedgerId,
        months: 1,
      );
      final budgetUsageRate = trend.isNotEmpty ? trend.last.usageRate : 0.0;
      final overspentBudgetCount = trend.isNotEmpty
          ? trend.last.overspentBudgetCount
          : 0;

      final snapshot = MoneyAnalysisReportSnapshot(
        incomeMinor: summary.totalIncomeMinor,
        expenseMinor: summary.totalExpenseMinor,
        netMinor: summary.totalIncomeMinor - summary.totalExpenseMinor,
        expenseByCategory: summary.expenseCategories
            .map(
              (s) => MoneyCategoryAmount(
                categoryName: s.categoryName,
                amountMinor: s.amountMinor,
              ),
            )
            .toList(),
        topMerchants: summary.merchants
            .take(5)
            .map(
              (s) => MoneyCategoryAmount(
                categoryName: s.name,
                amountMinor: s.amountMinor,
              ),
            )
            .toList(),
        installmentMinor: insights.sourceSlices
            .where((s) => s.sourceType == 'installment')
            .fold<int>(0, (sum, s) => sum + s.amountMinor),
        autoPostingMinor: insights.sourceSlices
            .where((s) => s.sourceType == 'auto_posting')
            .fold<int>(0, (sum, s) => sum + s.amountMinor),
        budgetUsageRate: budgetUsageRate,
        overspentBudgetCount: overspentBudgetCount,
        currencyCode: summary.currencyCode,
      );

      final jsonStr = _jsonEncode(snapshot.toJson());
      final completedAt = _utcNow();

      await (database.update(
        database.moneyAnalysisReports,
      )..where((r) => r.id.equals(reportId))).write(
        MoneyAnalysisReportsCompanion(
          status: const Value('completed'),
          reportDataJson: Value(jsonStr),
          generationCompletedAt: Value(completedAt),
          updatedAt: Value(completedAt),
        ),
      );

      return MoneyAnalysisReportEntity(
        id: reportId,
        userId: userId,
        scopeType: 'ledger',
        ledgerId: resolvedLedgerId,
        reportPeriod: request.reportPeriod,
        periodStart: request.periodStart,
        periodEnd: request.periodEnd,
        status: 'completed',
        reportDataJson: jsonStr,
        generationStartedAt: now,
        generationCompletedAt: completedAt,
        createdAt: now,
        updatedAt: completedAt,
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyAnalysisReportEntity?> getLatestReportForUser(
    String userId,
    String ledgerId,
    String reportPeriod,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);

      final row =
          await (database.select(database.moneyAnalysisReports)
                ..where(
                  (r) =>
                      r.userId.equals(userId) &
                      (r.ledgerId.equals(resolvedLedgerId) |
                          r.ledgerId.isNull()) &
                      r.reportPeriod.equals(reportPeriod) &
                      r.status.equals('completed'),
                )
                ..orderBy([(r) => OrderingTerm.desc(r.periodEndDate)])
                ..limit(1))
              .getSingleOrNull();

      if (row == null) return null;

      return _mapReport(row);
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<MoneyReportGenerationConfigEntity> getReportGenerationConfig(
    String userId,
    String ledgerId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);

      final row =
          await (database.select(database.moneyReportGenerationConfigs)..where(
                (c) =>
                    c.userId.equals(userId) &
                    c.ledgerId.equals(resolvedLedgerId),
              ))
              .getSingleOrNull();

      if (row != null) {
        return MoneyReportGenerationConfigEntity(
          userId: row.userId,
          ledgerId: row.ledgerId,
          autoGenerateWeekly: row.autoGenerateWeekly,
          autoGenerateMonthly: row.autoGenerateMonthly,
          autoGenerateQuarterly: row.autoGenerateQuarterly,
          autoGenerateYearly: row.autoGenerateYearly,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        );
      }

      return MoneyReportGenerationConfigEntity.defaults(
        userId: userId,
        ledgerId: resolvedLedgerId,
      );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
        error,
      );
    }
  }

  @override
  Future<void> updateReportGenerationConfig(
    String userId,
    MoneyReportGenerationConfigEntity config,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final resolvedLedgerId = await _resolveLedgerId(userId, config.ledgerId);
      final now = _utcNow();

      await database
          .into(database.moneyReportGenerationConfigs)
          .insertOnConflictUpdate(
            MoneyReportGenerationConfigsCompanion.insert(
              userId: userId,
              ledgerId: resolvedLedgerId,
              autoGenerateWeekly: Value(config.autoGenerateWeekly),
              autoGenerateMonthly: Value(config.autoGenerateMonthly),
              autoGenerateQuarterly: Value(config.autoGenerateQuarterly),
              autoGenerateYearly: Value(config.autoGenerateYearly),
              createdAt: config.createdAt,
              updatedAt: now,
            ),
          );
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  MoneyAnalysisReportEntity _mapReport(MoneyAnalysisReport row) {
    return MoneyAnalysisReportEntity(
      id: row.id,
      userId: row.userId,
      scopeType: row.scopeType,
      ledgerId: row.ledgerId,
      reportPeriod: row.reportPeriod,
      periodStart: _dateFromKey(row.periodStartDate),
      periodEnd: _dateFromKey(row.periodEndDate),
      status: row.status,
      reportDataJson: row.reportDataJson,
      generationStartedAt: row.generationStartedAt,
      generationCompletedAt: row.generationCompletedAt,
      errorMessage: row.errorMessage,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  String _jsonEncode(Map<String, dynamic> data) {
    final sb = StringBuffer();
    sb.write('{');
    var first = true;
    for (final entry in data.entries) {
      if (!first) sb.write(',');
      first = false;
      sb.write('"${entry.key}":');
      _writeJsonValue(sb, entry.value);
    }
    sb.write('}');
    return sb.toString();
  }

  void _writeJsonValue(StringBuffer sb, dynamic value) {
    if (value == null) {
      sb.write('null');
    } else if (value is String) {
      sb.write('"${value.replaceAll('"', '\\"')}"');
    } else if (value is bool) {
      sb.write(value.toString());
    } else if (value is num) {
      sb.write(value.toString());
    } else if (value is List) {
      sb.write('[');
      for (var i = 0; i < value.length; i++) {
        if (i > 0) sb.write(',');
        _writeJsonValue(sb, value[i]);
      }
      sb.write(']');
    } else if (value is Map) {
      sb.write('{');
      var first = true;
      for (final entry in value.entries) {
        if (!first) sb.write(',');
        first = false;
        sb.write('"${entry.key}":');
        _writeJsonValue(sb, entry.value);
      }
      sb.write('}');
    }
  }
}
