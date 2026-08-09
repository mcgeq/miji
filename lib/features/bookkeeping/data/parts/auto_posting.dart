part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

mixin _AutoPosting on _DriftMoneyRepositoryBase {
  @override
  Stream<List<MoneyAutoPostingTemplateEntity>> watchAutoPostingTemplatesForUser(
    String userId, {
    String? ledgerId,
  }) {
    final query = database.select(database.moneyAutoPostingTemplates)
      ..where((row) {
        final base = row.userId.equals(userId) & row.isDeleted.equals(false);
        if (ledgerId == null) {
          return base;
        }
        return base & row.ledgerId.equals(ledgerId);
      })
      ..orderBy([
        (row) => OrderingTerm.desc(row.isActive),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);

    return query.watch().map(
      (rows) => rows.map(_mapAutoPostingTemplate).toList(growable: false),
    );
  }

  @override
  Stream<List<MoneyAutoPostingRunEntity>> watchAutoPostingRunsForTemplate(
    String userId,
    String templateId,
  ) {
    final query = database.select(database.moneyAutoPostingRuns)
      ..where(
        (row) => row.userId.equals(userId) & row.templateId.equals(templateId),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.scheduledFor)]);

    return query.watch().map(
      (rows) => rows.map(_mapAutoPostingRun).toList(growable: false),
    );
  }

  @override
  Future<MoneyAutoPostingTemplateEntity> createAutoPostingTemplate(
    String userId,
    MoneyAutoPostingTemplateDraft draft,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateAutoPostingTemplateDraft(draft);
      await _getWritableAccountForUser(userId, draft.accountId);
      await _assertCategoryForUser(
        userId,
        draft.categoryId,
        _categoryKindForTransactionType(draft.type),
      );
      if (draft.subCategoryId != null) {
        await _assertSubCategoryForUser(
          userId,
          draft.categoryId,
          draft.subCategoryId!,
          _categoryKindForTransactionType(draft.type),
        );
      }
      final ledgerId = draft.ledgerId == null
          ? null
          : await _resolveLedgerId(userId, draft.ledgerId);
      final now = _utcNow();
      final id = _uuid.v4();

      await database
          .into(database.moneyAutoPostingTemplates)
          .insert(
            MoneyAutoPostingTemplatesCompanion.insert(
              id: id,
              userId: userId,
              name: draft.name.trim(),
              type: draft.type.storageValue,
              amountMinor: draft.amountMinor,
              currencyCode: draft.currencyCode,
              description: draft.description.trim(),
              notes: Value<String?>(_blankToNull(draft.notes)),
              merchant: Value<String?>(_blankToNull(draft.merchant)),
              accountId: draft.accountId,
              categoryId: draft.categoryId,
              subCategoryId: Value<String?>(draft.subCategoryId),
              paymentMethod: draft.paymentMethod.storageValue,
              customPaymentMethodName: Value<String?>(
                _blankToNull(draft.customPaymentMethodName),
              ),
              actualPayerAccount: Value(draft.actualPayerAccount),
              ledgerId: Value<String?>(ledgerId),
              frequency: draft.frequency.storageValue,
              dayOfMonth: Value<int?>(draft.dayOfMonth),
              weekday: Value<int?>(draft.weekday),
              timeOfDayMinutes: Value(draft.timeOfDayMinutes),
              startsOn: _dateOnlyUtc(draft.startsOn),
              endsOn: Value<DateTime?>(_nullableDateOnlyUtc(draft.endsOn)),
              isActive: Value(draft.isActive),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await syncChangeLogger?.recordAutoPostingTemplateChange(
        userId: userId,
        recordId: id,
        operation: SyncChangeOperation.insert,
        changedFields: _autoPostingTemplateDraftSyncFields(
          draft,
          ledgerId: ledgerId,
        ),
        afterVersion: 1,
      );

      return _mapAutoPostingTemplate(
        await _getAutoPostingTemplateForUser(userId, id),
      );
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

  @override
  Future<MoneyAutoPostingTemplateEntity> updateAutoPostingTemplate(
    String userId,
    MoneyAutoPostingTemplateUpdate update,
  ) async {
    try {
      await ensureReadyForUser(userId);
      _validateAutoPostingTemplateUpdate(update);
      final existing = await _getAutoPostingTemplateForUser(userId, update.id);
      await _getWritableAccountForUser(userId, update.accountId);
      await _assertCategoryForUser(
        userId,
        update.categoryId,
        _categoryKindForTransactionType(update.type),
      );
      if (update.subCategoryId != null) {
        await _assertSubCategoryForUser(
          userId,
          update.categoryId,
          update.subCategoryId!,
          _categoryKindForTransactionType(update.type),
        );
      }
      final ledgerId = update.ledgerId == null
          ? null
          : await _resolveLedgerId(userId, update.ledgerId);
      final now = _utcNow();

      await (database.update(database.moneyAutoPostingTemplates)..where(
            (row) =>
                row.id.equals(update.id) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyAutoPostingTemplatesCompanion(
              name: Value(update.name.trim()),
              type: Value(update.type.storageValue),
              amountMinor: Value(update.amountMinor),
              currencyCode: Value(update.currencyCode),
              description: Value(update.description.trim()),
              notes: Value<String?>(_blankToNull(update.notes)),
              merchant: Value<String?>(_blankToNull(update.merchant)),
              accountId: Value(update.accountId),
              categoryId: Value(update.categoryId),
              subCategoryId: Value<String?>(update.subCategoryId),
              paymentMethod: Value(update.paymentMethod.storageValue),
              customPaymentMethodName: Value<String?>(
                _blankToNull(update.customPaymentMethodName),
              ),
              actualPayerAccount: Value(update.actualPayerAccount),
              ledgerId: Value<String?>(ledgerId),
              frequency: Value(update.frequency.storageValue),
              dayOfMonth: Value<int?>(update.dayOfMonth),
              weekday: Value<int?>(update.weekday),
              timeOfDayMinutes: Value(update.timeOfDayMinutes),
              startsOn: Value(_dateOnlyUtc(update.startsOn)),
              endsOn: Value<DateTime?>(_nullableDateOnlyUtc(update.endsOn)),
              isActive: Value(update.isActive),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );

      await syncChangeLogger?.recordAutoPostingTemplateChange(
        userId: userId,
        recordId: update.id,
        operation: SyncChangeOperation.update,
        changedFields: _autoPostingTemplateUpdateSyncFields(
          update,
          ledgerId: ledgerId,
        ),
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );

      return _mapAutoPostingTemplate(
        await _getAutoPostingTemplateForUser(userId, update.id),
      );
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

  @override
  Future<void> deleteAutoPostingTemplate(
    String userId,
    String templateId,
  ) async {
    try {
      final existing = await _getAutoPostingTemplateForUser(userId, templateId);
      final now = _utcNow();
      await (database.update(database.moneyAutoPostingTemplates)..where(
            (row) =>
                row.id.equals(templateId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyAutoPostingTemplatesCompanion(
              isActive: const Value(false),
              isDeleted: const Value(true),
              deletedAt: Value<DateTime?>(now),
              version: Value(existing.version + 1),
              updatedAt: Value(now),
            ),
          );
      await syncChangeLogger?.recordAutoPostingTemplateChange(
        userId: userId,
        recordId: templateId,
        operation: SyncChangeOperation.delete,
        changedFields: {'is_active': false, ..._deleteSyncFields(now)},
        beforeVersion: existing.version,
        afterVersion: existing.version + 1,
      );
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

  @override
  Future<MoneyAutoPostingExecutionSummary> executeDueAutoPostings(
    String userId, {
    DateTime? now,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final effectiveNow = (now ?? _utcNow()).toUtc();
      final rows =
          await (database.select(database.moneyAutoPostingTemplates)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isActive.equals(true) &
                    row.isDeleted.equals(false),
              ))
              .get();

      var summary = MoneyAutoPostingExecutionSummary.empty;
      final impactedTransactions = <MoneyTransactionEntity>[];
      final impactedAccounts = <String>{};
      final impactedLedgerIds = <String, List<String>>{};

      for (final row in rows) {
        summary = await _executeAutoPostingTemplateOccurrences(
          userId: userId,
          template: _mapAutoPostingTemplate(row),
          effectiveNow: effectiveNow,
          summary: summary,
          impactedTransactions: impactedTransactions,
          impactedAccounts: impactedAccounts,
          impactedLedgerIds: impactedLedgerIds,
        );
      }

      await _applyAutoPostingImpacts(
        userId,
        impactedTransactions,
        impactedAccounts,
        impactedLedgerIds,
      );

      return summary;
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

  @override
  Future<MoneyAutoPostingExecutionSummary> executeAutoPostingTemplateNow(
    String userId,
    String templateId, {
    DateTime? now,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final effectiveNow = (now ?? _utcNow()).toUtc();
      final row =
          await (database.select(database.moneyAutoPostingTemplates)..where(
                (queryRow) =>
                    queryRow.userId.equals(userId) &
                    queryRow.id.equals(templateId),
              ))
              .getSingleOrNull();
      if (row == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseReadFailed,
        );
      }
      final template = _mapAutoPostingTemplate(row);

      var summary = MoneyAutoPostingExecutionSummary.empty;
      final impactedTransactions = <MoneyTransactionEntity>[];
      final impactedAccounts = <String>{};
      final impactedLedgerIds = <String, List<String>>{};

      if (template.isActive) {
        summary = await _executeAutoPostingTemplateOccurrences(
          userId: userId,
          template: template,
          effectiveNow: effectiveNow,
          summary: summary,
          impactedTransactions: impactedTransactions,
          impactedAccounts: impactedAccounts,
          impactedLedgerIds: impactedLedgerIds,
        );
      }

      await _applyAutoPostingImpacts(
        userId,
        impactedTransactions,
        impactedAccounts,
        impactedLedgerIds,
      );

      return summary;
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

  Future<MoneyAutoPostingExecutionSummary>
  _executeAutoPostingTemplateOccurrences({
    required String userId,
    required MoneyAutoPostingTemplateEntity template,
    required DateTime effectiveNow,
    required MoneyAutoPostingExecutionSummary summary,
    required List<MoneyTransactionEntity> impactedTransactions,
    required Set<String> impactedAccounts,
    required Map<String, List<String>> impactedLedgerIds,
  }) async {
    for (final occurrence in _dueAutoPostingOccurrences(
      template,
      effectiveNow,
    )) {
      final outcome = await _executeAutoPostingOccurrence(
        userId: userId,
        template: template,
        occurrence: occurrence,
      );
      summary = summary.add(
        posted: outcome.posted ? 1 : 0,
        skipped: outcome.skipped ? 1 : 0,
        blocked: outcome.blocked ? 1 : 0,
        failed: outcome.failed ? 1 : 0,
      );
      final transaction = outcome.transaction;
      if (transaction != null) {
        impactedTransactions.add(transaction);
        impactedAccounts.add(transaction.accountId);
        impactedLedgerIds[transaction.id] = outcome.ledgerIds;
      }
    }
    return summary;
  }

  Future<void> _applyAutoPostingImpacts(
    String userId,
    List<MoneyTransactionEntity> impactedTransactions,
    Set<String> impactedAccounts,
    Map<String, List<String>> impactedLedgerIds,
  ) async {
    if (impactedTransactions.isEmpty) return;
    await _refreshBudgetSnapshotsForTransactionImpacts(userId, [
      for (final transaction in impactedTransactions)
        _BudgetTransactionImpact(
          type: transaction.type,
          accountId: transaction.accountId,
          categoryId: transaction.categoryId,
          subCategoryId: transaction.subCategoryId,
          ledgerIds: impactedLedgerIds[transaction.id] ?? const [],
        ),
    ]);
    await _syncCreditAccountRepaymentRemindersForAccounts(
      userId,
      impactedAccounts.toList(growable: false),
    );
    await _tryRebuildUsageStatsForUser(userId);
  }

  @override
  Future<int> getPendingAutoPostingAmountForBudget(
    String userId,
    String budgetId,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    await ensureReadyForUser(userId);
    final budget = await _getBudgetForUser(userId, budgetId);
    final scope = _readBudgetScope(budget);
    final periodStartUtc = periodStart.toUtc();
    final periodEndUtc = periodEnd.toUtc();

    final templateRows =
        await (database.select(database.moneyAutoPostingTemplates)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.isActive.equals(true) &
                  row.isDeleted.equals(false),
            ))
            .get();

    var pendingAmount = 0;

    for (final row in templateRows) {
      final template = _mapAutoPostingTemplate(row);

      if (!_autoPostingTemplateMatchesBudgetScope(template, scope)) {
        continue;
      }

      final occurrences = _occurrencesWithinPeriod(
        template,
        periodStartUtc,
        periodEndUtc,
      );

      for (final occurrence in occurrences) {
        final run = await _getAutoPostingRunForOccurrence(
          userId,
          template.id,
          occurrence.occurrenceKey,
        );
        if (run == null ||
            run.status != MoneyAutoPostingRunStatus.posted.storageValue) {
          pendingAmount += template.amountMinor;
        }
      }
    }

    return pendingAmount;
  }

  bool _autoPostingTemplateMatchesBudgetScope(
    MoneyAutoPostingTemplateEntity template,
    _BudgetScope scope,
  ) {
    if (scope.accountId != null && template.accountId != scope.accountId) {
      return false;
    }
    if (scope.categoryId != null && template.categoryId != scope.categoryId) {
      return false;
    }
    if (scope.subCategoryId != null &&
        template.subCategoryId != scope.subCategoryId) {
      return false;
    }
    return true;
  }

  Iterable<_AutoPostingOccurrence> _occurrencesWithinPeriod(
    MoneyAutoPostingTemplateEntity template,
    DateTime periodStartUtc,
    DateTime periodEndUtc,
  ) {
    final startDate = _dateOnlyUtc(template.startsOn);
    final templateEndDate = template.endsOn == null
        ? _dateOnlyUtc(periodEndUtc)
        : _dateOnlyUtc(template.endsOn!);
    final endDate = templateEndDate.isBefore(_dateOnlyUtc(periodEndUtc))
        ? templateEndDate
        : _dateOnlyUtc(periodEndUtc);
    if (endDate.isBefore(startDate)) {
      return const <_AutoPostingOccurrence>[];
    }

    switch (template.frequency) {
      case MoneyAutoPostingFrequency.daily:
        return _dailyOccurrencesWithinPeriod(
          template,
          startDate,
          endDate,
          periodStartUtc,
          periodEndUtc,
        );
      case MoneyAutoPostingFrequency.weekly:
        return _weeklyOccurrencesWithinPeriod(
          template,
          startDate,
          endDate,
          periodStartUtc,
          periodEndUtc,
        );
      case MoneyAutoPostingFrequency.monthly:
        return _monthlyOccurrencesWithinPeriod(
          template,
          startDate,
          endDate,
          periodStartUtc,
          periodEndUtc,
        );
    }
  }

  Iterable<_AutoPostingOccurrence> _dailyOccurrencesWithinPeriod(
    MoneyAutoPostingTemplateEntity template,
    DateTime startDate,
    DateTime endDate,
    DateTime periodStartUtc,
    DateTime periodEndUtc,
  ) {
    final occurrences = <_AutoPostingOccurrence>[];
    var date = startDate;
    while (!date.isAfter(endDate)) {
      final scheduledFor = _autoPostingScheduledFor(template, date);
      if (!scheduledFor.isBefore(periodStartUtc) &&
          scheduledFor.isBefore(periodEndUtc)) {
        occurrences.add(_autoPostingOccurrence(date, scheduledFor));
      }
      date = date.add(const Duration(days: 1));
    }
    return occurrences;
  }

  Iterable<_AutoPostingOccurrence> _weeklyOccurrencesWithinPeriod(
    MoneyAutoPostingTemplateEntity template,
    DateTime startDate,
    DateTime endDate,
    DateTime periodStartUtc,
    DateTime periodEndUtc,
  ) {
    final weekday = template.weekday ?? startDate.weekday;
    final occurrences = <_AutoPostingOccurrence>[];
    var date = startDate;
    while (date.weekday != weekday && !date.isAfter(endDate)) {
      date = date.add(const Duration(days: 1));
    }
    while (!date.isAfter(endDate)) {
      final scheduledFor = _autoPostingScheduledFor(template, date);
      if (!scheduledFor.isBefore(periodStartUtc) &&
          scheduledFor.isBefore(periodEndUtc)) {
        occurrences.add(_autoPostingOccurrence(date, scheduledFor));
      }
      date = date.add(const Duration(days: 7));
    }
    return occurrences;
  }

  Iterable<_AutoPostingOccurrence> _monthlyOccurrencesWithinPeriod(
    MoneyAutoPostingTemplateEntity template,
    DateTime startDate,
    DateTime endDate,
    DateTime periodStartUtc,
    DateTime periodEndUtc,
  ) {
    final dayOfMonth = template.dayOfMonth ?? startDate.day;
    final occurrences = <_AutoPostingOccurrence>[];
    var monthCursor = DateTime.utc(startDate.year, startDate.month);
    final endMonth = DateTime.utc(endDate.year, endDate.month);
    while (!monthCursor.isAfter(endMonth)) {
      final date = _monthlyAutoPostingDate(
        monthCursor.year,
        monthCursor.month,
        dayOfMonth,
      );
      if (!date.isBefore(startDate) && !date.isAfter(endDate)) {
        final scheduledFor = _autoPostingScheduledFor(template, date);
        if (!scheduledFor.isBefore(periodStartUtc) &&
            scheduledFor.isBefore(periodEndUtc)) {
          occurrences.add(_autoPostingOccurrence(date, scheduledFor));
        }
      }
      monthCursor = DateTime.utc(monthCursor.year, monthCursor.month + 1);
    }
    return occurrences;
  }

  Iterable<_AutoPostingOccurrence> _dueAutoPostingOccurrences(
    MoneyAutoPostingTemplateEntity template,
    DateTime now,
  ) sync* {
    final nowUtc = now.toUtc();
    final startDate = _dateOnlyUtc(template.startsOn);
    final nowDate = _dateOnlyUtc(nowUtc);
    final templateEndDate = template.endsOn == null
        ? nowDate
        : _dateOnlyUtc(template.endsOn!);
    final endDate = templateEndDate.isBefore(nowDate)
        ? templateEndDate
        : nowDate;
    if (endDate.isBefore(startDate)) {
      return;
    }

    switch (template.frequency) {
      case MoneyAutoPostingFrequency.daily:
        var date = startDate;
        while (!date.isAfter(endDate)) {
          final scheduledFor = _autoPostingScheduledFor(template, date);
          if (!scheduledFor.isAfter(nowUtc)) {
            yield _autoPostingOccurrence(date, scheduledFor);
          }
          date = date.add(const Duration(days: 1));
        }
      case MoneyAutoPostingFrequency.weekly:
        final weekday = template.weekday ?? startDate.weekday;
        var date = startDate;
        while (date.weekday != weekday && !date.isAfter(endDate)) {
          date = date.add(const Duration(days: 1));
        }
        while (!date.isAfter(endDate)) {
          final scheduledFor = _autoPostingScheduledFor(template, date);
          if (!scheduledFor.isAfter(nowUtc)) {
            yield _autoPostingOccurrence(date, scheduledFor);
          }
          date = date.add(const Duration(days: 7));
        }
      case MoneyAutoPostingFrequency.monthly:
        final dayOfMonth = template.dayOfMonth ?? startDate.day;
        var monthCursor = DateTime.utc(startDate.year, startDate.month);
        final endMonth = DateTime.utc(endDate.year, endDate.month);
        while (!monthCursor.isAfter(endMonth)) {
          final date = _monthlyAutoPostingDate(
            monthCursor.year,
            monthCursor.month,
            dayOfMonth,
          );
          if (!date.isBefore(startDate) && !date.isAfter(endDate)) {
            final scheduledFor = _autoPostingScheduledFor(template, date);
            if (!scheduledFor.isAfter(nowUtc)) {
              yield _autoPostingOccurrence(date, scheduledFor);
            }
          }
          monthCursor = DateTime.utc(monthCursor.year, monthCursor.month + 1);
        }
    }
  }

  Future<_AutoPostingExecutionOutcome> _executeAutoPostingOccurrence({
    required String userId,
    required MoneyAutoPostingTemplateEntity template,
    required _AutoPostingOccurrence occurrence,
  }) async {
    var runRow = await _getAutoPostingRunForOccurrence(
      userId,
      template.id,
      occurrence.occurrenceKey,
    );
    if (runRow != null) {
      final run = _mapAutoPostingRun(runRow);
      final existingTransaction = await _getAutoPostingTransactionForRun(
        userId,
        run.id,
      );
      if (existingTransaction != null) {
        if (run.status != MoneyAutoPostingRunStatus.posted) {
          await _writeAutoPostingRunState(
            existing: run,
            status: MoneyAutoPostingRunStatus.posted,
            transactionId: existingTransaction.id,
            postedAt: run.postedAt ?? existingTransaction.createdAt,
            errorCode: null,
            errorMessage: null,
          );
        }
        return const _AutoPostingExecutionOutcome(
          posted: false,
          skipped: true,
          blocked: false,
          failed: false,
        );
      }

      switch (run.status) {
        case MoneyAutoPostingRunStatus.userDeleted ||
            MoneyAutoPostingRunStatus.posted ||
            MoneyAutoPostingRunStatus.duplicateIgnored:
          return const _AutoPostingExecutionOutcome(
            posted: false,
            skipped: true,
            blocked: false,
            failed: false,
          );
        case MoneyAutoPostingRunStatus.blocked:
          return const _AutoPostingExecutionOutcome(
            posted: false,
            skipped: false,
            blocked: true,
            failed: false,
          );
        case MoneyAutoPostingRunStatus.pending ||
            MoneyAutoPostingRunStatus.retryableFailed:
          break;
      }
    }

    final run = runRow == null
        ? await _insertAutoPostingRun(
            userId: userId,
            template: template,
            occurrence: occurrence,
          )
        : _mapAutoPostingRun(runRow);
    if (run == null) {
      // 并发执行者已先插入同一 occurrence 的 run：由对方负责入账，
      // 本轮直接跳过，避免重复建账。
      return const _AutoPostingExecutionOutcome(
        posted: false,
        skipped: true,
        blocked: false,
        failed: false,
      );
    }

    try {
      final account = await _getWritableAccountForUser(
        userId,
        template.accountId,
      );
      await _assertCategoryForUser(
        userId,
        template.categoryId,
        _categoryKindForTransactionType(template.type),
      );
      if (template.subCategoryId != null) {
        await _assertSubCategoryForUser(
          userId,
          template.categoryId,
          template.subCategoryId!,
          _categoryKindForTransactionType(template.type),
        );
      }
      _assertTransactionAccountRules(template.type, account);

      final ledgerIds = await _resolveTransactionLedgerIds(
        userId,
        template.ledgerId,
      );
      final ledger = _MutableAccountLedger.fromAccount(account)
        ..applyTransactionCreate(template.type, template.amountMinor)
        ..validate();
      MoneyTransactionEntity? transaction;
      final postedAt = _utcNow();
      await database.transaction(() async {
        transaction = await _createTransactionRow(
          userId,
          MoneyTransactionDraft(
            type: template.type,
            transactionAt: occurrence.scheduledFor,
            amountMinor: template.amountMinor,
            currencyCode: template.currencyCode,
            description: template.description,
            notes: template.notes,
            merchant: template.merchant,
            accountId: template.accountId,
            categoryId: template.categoryId,
            subCategoryId: template.subCategoryId,
            paymentMethod: template.paymentMethod,
            customPaymentMethodName: template.customPaymentMethodName,
            actualPayerAccount: template.actualPayerAccount,
            ledgerId: template.ledgerId,
            sourceTemplateRunId: run.id,
          ),
          ledgerIds,
        );
        await _linkTransactionToLedgersUnchecked(
          ledgerIds: ledgerIds,
          transactionId: transaction!.id,
        );
        await _updateAccountLedger(userId, account.id, ledger, postedAt);
      });
      final postedTransaction = transaction!;
      await _writeAutoPostingRunState(
        existing: run,
        status: MoneyAutoPostingRunStatus.posted,
        transactionId: postedTransaction.id,
        postedAt: postedAt,
        errorCode: null,
        errorMessage: null,
        updatedAt: postedAt,
      );
      return _AutoPostingExecutionOutcome(
        posted: true,
        skipped: false,
        blocked: false,
        failed: false,
        transaction: postedTransaction,
        ledgerIds: ledgerIds,
      );
    } catch (error) {
      final status =
          error is MoneyRepositoryException && _isAutoPostingBlockedError(error)
          ? MoneyAutoPostingRunStatus.blocked
          : MoneyAutoPostingRunStatus.retryableFailed;
      await _writeAutoPostingRunState(
        existing: run,
        status: status,
        transactionId: run.transactionId,
        postedAt: run.postedAt,
        errorCode: error is MoneyRepositoryException
            ? error.code.name
            : 'auto_posting_failed',
        errorMessage: error.toString(),
      );
      return _AutoPostingExecutionOutcome(
        posted: false,
        skipped: false,
        blocked: status == MoneyAutoPostingRunStatus.blocked,
        failed: status == MoneyAutoPostingRunStatus.retryableFailed,
      );
    }
  }

  Future<MoneyAutoPostingTemplate> _getAutoPostingTemplateForUser(
    String userId,
    String templateId,
  ) async {
    final template =
        await (database.select(database.moneyAutoPostingTemplates)..where(
              (row) =>
                  row.id.equals(templateId) &
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false),
            ))
            .getSingleOrNull();
    if (template == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.autoPostingTemplateNotFound,
      );
    }
    return template;
  }

  Future<MoneyAutoPostingRun?> _getAutoPostingRunForOccurrence(
    String userId,
    String templateId,
    String occurrenceKey,
  ) {
    return (database.select(database.moneyAutoPostingRuns)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.templateId.equals(templateId) &
                row.occurrenceKey.equals(occurrenceKey),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<MoneyTransaction?> _getAutoPostingTransactionForRun(
    String userId,
    String runId,
  ) {
    return (database.select(database.moneyTransactions)
          ..where(
            (row) =>
                row.userId.equals(userId) &
                row.sourceTemplateRunId.equals(runId) &
                row.isDeleted.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  /// 插入自动记账执行记录；同一 (user_id, template_id, occurrence_key)
  /// 已存在时返回 null（并发执行者已占有该 occurrence，由它入账）。
  Future<MoneyAutoPostingRunEntity?> _insertAutoPostingRun({
    required String userId,
    required MoneyAutoPostingTemplateEntity template,
    required _AutoPostingOccurrence occurrence,
  }) async {
    final now = _utcNow();
    final runId = _uuid.v4();
    await database
        .into(database.moneyAutoPostingRuns)
        .insert(
          MoneyAutoPostingRunsCompanion.insert(
            id: runId,
            userId: userId,
            templateId: template.id,
            occurrenceKey: occurrence.occurrenceKey,
            status: MoneyAutoPostingRunStatus.pending.storageValue,
            scheduledFor: occurrence.scheduledFor,
            templateVersion: template.version,
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    // insertOrIgnore 被唯一索引忽略时不返回 0（last_insert_rowid 语义），
    // 因此以 runId 是否存在判断是否真正插入。
    final row = await _getAutoPostingRunById(userId, runId);
    if (row == null) {
      return null;
    }
    final entity = _mapAutoPostingRun(row);
    await _recordAutoPostingRunChange(
      userId: userId,
      recordId: runId,
      operation: SyncChangeOperation.insert,
      changedFields: _autoPostingRunSyncFields(entity),
    );
    return entity;
  }

  Map<String, Object?> _autoPostingTemplateDraftSyncFields(
    MoneyAutoPostingTemplateDraft draft, {
    required String? ledgerId,
  }) {
    return {
      'name': draft.name.trim(),
      'type': draft.type.storageValue,
      'amount_minor': draft.amountMinor,
      'currency_code': draft.currencyCode,
      'description': draft.description.trim(),
      'notes': _blankToNull(draft.notes),
      'merchant': _blankToNull(draft.merchant),
      'account_id': draft.accountId,
      'category_id': draft.categoryId,
      'sub_category_id': draft.subCategoryId,
      'payment_method': draft.paymentMethod.storageValue,
      'custom_payment_method_name': _blankToNull(draft.customPaymentMethodName),
      'actual_payer_account': draft.actualPayerAccount,
      'ledger_id': ledgerId,
      'frequency': draft.frequency.storageValue,
      'day_of_month': draft.dayOfMonth,
      'weekday': draft.weekday,
      'time_of_day_minutes': draft.timeOfDayMinutes,
      'starts_on': _dateOnlyUtc(draft.startsOn).toIso8601String(),
      'ends_on': _nullableDateOnlyUtc(draft.endsOn)?.toIso8601String(),
      'is_active': draft.isActive,
      'is_deleted': false,
      'deleted_at': null,
    };
  }

  Map<String, Object?> _autoPostingTemplateUpdateSyncFields(
    MoneyAutoPostingTemplateUpdate update, {
    required String? ledgerId,
  }) {
    return {
      'name': update.name.trim(),
      'type': update.type.storageValue,
      'amount_minor': update.amountMinor,
      'currency_code': update.currencyCode,
      'description': update.description.trim(),
      'notes': _blankToNull(update.notes),
      'merchant': _blankToNull(update.merchant),
      'account_id': update.accountId,
      'category_id': update.categoryId,
      'sub_category_id': update.subCategoryId,
      'payment_method': update.paymentMethod.storageValue,
      'custom_payment_method_name': _blankToNull(
        update.customPaymentMethodName,
      ),
      'actual_payer_account': update.actualPayerAccount,
      'ledger_id': ledgerId,
      'frequency': update.frequency.storageValue,
      'day_of_month': update.dayOfMonth,
      'weekday': update.weekday,
      'time_of_day_minutes': update.timeOfDayMinutes,
      'starts_on': _dateOnlyUtc(update.startsOn).toIso8601String(),
      'ends_on': _nullableDateOnlyUtc(update.endsOn)?.toIso8601String(),
      'is_active': update.isActive,
    };
  }

  Map<String, Object?> _autoPostingRunSyncFields(
    MoneyAutoPostingRunEntity run,
  ) {
    return {
      'template_id': run.templateId,
      'occurrence_key': run.occurrenceKey,
      'status': run.status.storageValue,
      'transaction_id': run.transactionId,
      'scheduled_for': run.scheduledFor.toUtc().toIso8601String(),
      'posted_at': run.postedAt?.toUtc().toIso8601String(),
      'template_version': run.templateVersion,
      'error_code': run.errorCode,
      'error_message': run.errorMessage,
      'created_at': run.createdAt.toUtc().toIso8601String(),
      'updated_at': run.updatedAt.toUtc().toIso8601String(),
    };
  }
}
