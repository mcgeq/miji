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

      // 清理历史遗留的 generation_started 残行（如生成过程中 App 被杀），
      // 避免无限期卡在"生成中"。
      await (database.delete(database.moneyAnalysisReports)..where(
            (r) =>
                r.userId.equals(userId) &
                (r.ledgerId.equals(resolvedLedgerId) | r.ledgerId.isNull()) &
                r.reportPeriod.equals(request.reportPeriod) &
                r.status.equals('generation_started'),
          ))
          .go();

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

      try {
        return await _generateReportBody(
          userId: userId,
          request: request,
          reportId: reportId,
          resolvedLedgerId: resolvedLedgerId,
          startedAt: now,
        );
      } catch (error) {
        final failedAt = _utcNow();
        await (database.update(
          database.moneyAnalysisReports,
        )..where((r) => r.id.equals(reportId))).write(
          MoneyAnalysisReportsCompanion(
            status: const Value('failed'),
            generationCompletedAt: Value(failedAt),
            errorMessage: Value(error.toString()),
            updatedAt: Value(failedAt),
          ),
        );
        throw MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseWriteFailed,
          error,
        );
      }
    } catch (error) {
      if (error is MoneyRepositoryException) {
        rethrow;
      }
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<MoneyAnalysisReportEntity> _generateReportBody({
    required String userId,
    required MoneyAnalysisReportRequest request,
    required String reportId,
    required String resolvedLedgerId,
    required DateTime startedAt,
  }) async {
    final statsQuery = MoneyStatisticsQuery(
      dateStart: request.periodStart,
      dateEndExclusive: request.periodEnd,
      groupBy: MoneyStatisticsGroupBy.month,
      ledgerId: resolvedLedgerId,
    );
    final summary = await getStatisticsForUser(userId, statsQuery);

    final insights = await getStatisticsInsightsForUser(userId, statsQuery);

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

    final jsonStr = jsonEncode(snapshot.toJson());
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
      generationStartedAt: startedAt,
      generationCompletedAt: completedAt,
      createdAt: startedAt,
      updatedAt: completedAt,
    );
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

      final rows =
          await (database.select(database.moneyAnalysisReports)
                ..where(
                  (r) =>
                      r.userId.equals(userId) &
                      (r.ledgerId.equals(resolvedLedgerId) |
                          r.ledgerId.isNull()) &
                      r.reportPeriod.equals(reportPeriod),
                )
                ..orderBy([
                  (r) => OrderingTerm.desc(r.periodEndDate),
                  (r) => OrderingTerm.desc(r.updatedAt),
                ]))
              .get();

      MoneyAnalysisReportEntity? latestFailed;
      for (final row in rows) {
        if (row.status == 'completed') {
          return _mapReport(row);
        }
        if (row.status == 'failed' && latestFailed == null) {
          latestFailed = _mapReport(row);
        }
      }
      return latestFailed;
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
}
