part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

/// 预算「已预留」额度的计算。
///
/// 判定只有一条规则：**来源的记账日是否落在预算自己的周期内**。周期直接复用
/// [_budgetPeriodForBudget]——它与 [_budgetUsedAmountMinor] 用的是同一个区间，
/// 绝不能再按自然月另算一套，否则账单周期 / 周 / 一次性预算会多算或漏算。
///
/// 匹配维度也比照 [_budgetMatchesTransactionImpact]：账本、收支方向、币种、
/// scope（账户 / 分类 / 子分类 / 标签）。少比一项就会出现「收入模板预占支出预算」
/// 这类错误。
///
/// 去重：同一笔还款既登记成分期期次、又登记成自动记账模板时，只算分期那一份，
/// 见 [_CommitmentSources.conflictingTemplateIds]。
/// 依赖 [_Budgets]（账本谓词）、[_AutoPosting]（occurrence 展开）与
/// [_AutoPostingConflicts]（重复判定）里的私有成员，它们都是兄弟 mixin——
/// 只有写进 `on` 子句、并在 `DriftMoneyRepository` 的 `with` 列表里排在前面，
/// 这里才能访问到。
mixin _BudgetCommitments
    on
        _DriftMoneyRepositoryBase,
        _Budgets,
        _AutoPosting,
        _AutoPostingConflicts {
  @override
  Future<MoneyBudgetCommitment> budgetCommitmentForBudget(
    String userId,
    String budgetId, {
    MoneyBudgetCommitmentOptions options = const MoneyBudgetCommitmentOptions(),
  }) async {
    await ensureReadyForUser(userId);
    final budget = await _getBudgetForUser(userId, budgetId);
    final sources = await _loadCommitmentSources(userId, options);
    return _commitmentForBudgetRow(
      userId: userId,
      budget: budget,
      options: options,
      sources: sources,
    );
  }

  @override
  Future<Map<String, MoneyBudgetCommitment>> budgetCommitmentsForUser(
    String userId, {
    String? ledgerId,
    MoneyBudgetCommitmentOptions options = const MoneyBudgetCommitmentOptions(),
  }) async {
    await ensureReadyForUser(userId);
    final resolvedLedgerId = await _resolveLedgerId(userId, ledgerId);
    final rows =
        await (database.select(database.moneyBudgets)..where(
              (budget) =>
                  budget.userId.equals(userId) &
                  budget.isDeleted.equals(false) &
                  _budgetLedgerPredicate(budget, resolvedLedgerId, userId),
            ))
            .get();

    // 数据源只加载一次：模板 / 分期 / 账单提醒对每个预算都是同一份，
    // 逐个预算各查一遍会退化成 N× 查询。
    final sources = await _loadCommitmentSources(userId, options);
    final result = <String, MoneyBudgetCommitment>{};
    for (final row in rows) {
      result[row.id] = await _commitmentForBudgetRow(
        userId: userId,
        budget: row,
        options: options,
        sources: sources,
      );
    }
    return result;
  }

  Future<MoneyBudgetCommitment> _commitmentForBudgetRow({
    required String userId,
    required MoneyBudget budget,
    required MoneyBudgetCommitmentOptions options,
    required _CommitmentSources sources,
  }) async {
    final periodType = MoneyBudgetPeriodType.fromStorageValue(
      budget.repeatPeriodType,
    );
    final period = await _budgetPeriodForBudget(budget, periodType);
    if (options.isEmpty) {
      return MoneyBudgetCommitment(
        budgetId: budget.id,
        periodStart: period.start,
        periodEnd: period.end,
      );
    }

    final scope = _readBudgetScope(budget);
    final trackingType = MoneyBudgetTrackingType.fromStorageValue(
      budget.trackingType,
    );
    final budgetLedgerId = budget.ledgerId ?? _defaultLedgerId(userId);
    final items = <MoneyBudgetCommitmentItem>[];

    if (options.includeAutoPosting) {
      items.addAll(
        _autoPostingCommitmentItems(
          userId: userId,
          budget: budget,
          scope: scope,
          trackingType: trackingType,
          budgetLedgerId: budgetLedgerId,
          period: period,
          sources: sources,
        ),
      );
    }

    if (options.includeInstallments) {
      items.addAll(
        _installmentCommitmentItems(
          userId: userId,
          budget: budget,
          scope: scope,
          trackingType: trackingType,
          budgetLedgerId: budgetLedgerId,
          period: period,
          sources: sources,
        ),
      );
    }

    if (options.includePendingTransactions) {
      items.addAll(
        await _pendingTransactionCommitmentItems(
          userId: userId,
          scope: scope,
          trackingType: trackingType,
          budgetLedgerId: budgetLedgerId,
          period: period,
        ),
      );
    }

    if (options.includeBillReminders) {
      items.addAll(
        _billReminderCommitmentItems(
          userId: userId,
          budget: budget,
          scope: scope,
          trackingType: trackingType,
          budgetLedgerId: budgetLedgerId,
          period: period,
          sources: sources,
        ),
      );
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    return MoneyBudgetCommitment(
      budgetId: budget.id,
      periodStart: period.start,
      periodEnd: period.end,
      items: items,
    );
  }

  /// 这里刻意不用 async：occurrence 展开与 run 状态判定全是纯内存计算，
  /// 加 async 只会让返回类型变成 Future，调用方还得再 await 一层。
  List<MoneyBudgetCommitmentItem> _autoPostingCommitmentItems({
    required String userId,
    required MoneyBudget budget,
    required _BudgetScope scope,
    required MoneyBudgetTrackingType trackingType,
    required String budgetLedgerId,
    required ({DateTime start, DateTime end}) period,
    required _CommitmentSources sources,
  }) {
    final items = <MoneyBudgetCommitmentItem>[];
    final periodStartUtc = period.start.toUtc();
    final periodEndUtc = period.end.toUtc();

    for (final template in sources.templates) {
      // 这一笔已经由分期期次计入了，模板这一份必须跳过，否则同一笔还款
      // 会把额度占掉两次。
      if (sources.conflictingTemplateIds.contains(template.id)) {
        continue;
      }
      // 转账只是资金搬家，不占任何收支预算。
      if (template.type == MoneyTransactionType.transfer) {
        continue;
      }
      if (!_commitmentMatchesTrackingType(trackingType, template.type)) {
        continue;
      }
      if (template.currencyCode != budget.currencyCode) {
        continue;
      }
      if ((template.ledgerId ?? _defaultLedgerId(userId)) != budgetLedgerId) {
        continue;
      }
      if (!_commitmentMatchesScope(
        scope,
        accountId: template.accountId,
        categoryId: template.categoryId,
        subCategoryId: template.subCategoryId,
      )) {
        continue;
      }

      for (final occurrence in _occurrencesWithinPeriod(
        template,
        periodStartUtc,
        periodEndUtc,
      )) {
        final runStatus = sources
            .runStatusByKey['${template.id}::${occurrence.occurrenceKey}'];
        if (!_isCommittedAutoPostingRunStatus(runStatus)) {
          continue;
        }
        items.add(
          MoneyBudgetCommitmentItem(
            source: MoneyBudgetCommitmentSource.autoPosting,
            sourceId: template.id,
            title: template.name.trim().isEmpty ? '自动记账' : template.name,
            date: occurrence.scheduledFor,
            amountMinor: template.amountMinor,
            detail: MoneyBudgetCommitmentSource.autoPosting.label,
          ),
        );
      }
    }
    return items;
  }

  List<MoneyBudgetCommitmentItem> _installmentCommitmentItems({
    required String userId,
    required MoneyBudget budget,
    required _BudgetScope scope,
    required MoneyBudgetTrackingType trackingType,
    required String budgetLedgerId,
    required ({DateTime start, DateTime end}) period,
    required _CommitmentSources sources,
  }) {
    // 分期只会产生支出。
    if (trackingType != MoneyBudgetTrackingType.expenseLimit) {
      return const <MoneyBudgetCommitmentItem>[];
    }

    final items = <MoneyBudgetCommitmentItem>[];
    for (final entry in sources.pendingInstallments) {
      final detail = entry.detail;
      final plan = entry.plan;
      if (plan.currencyCode != budget.currencyCode) {
        continue;
      }
      if (plan.ledgerId != budgetLedgerId) {
        continue;
      }
      if (!_commitmentMatchesScope(
        scope,
        accountId: detail.accountId,
        categoryId: plan.categoryId,
        subCategoryId: plan.subCategoryId,
      )) {
        continue;
      }
      if (_isBeforePeriod(detail.dueDate, period) ||
          !detail.dueDate.isBefore(period.end)) {
        continue;
      }
      items.add(
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.installment,
          sourceId: detail.id,
          title: plan.name,
          date: detail.dueDate,
          amountMinor: detail.amountMinor,
          detail: '第${detail.periodNumber}期',
        ),
      );
    }
    return items;
  }

  Future<List<MoneyBudgetCommitmentItem>> _pendingTransactionCommitmentItems({
    required String userId,
    required _BudgetScope scope,
    required MoneyBudgetTrackingType trackingType,
    required String budgetLedgerId,
    required ({DateTime start, DateTime end}) period,
  }) async {
    final transactionType = trackingType == MoneyBudgetTrackingType.incomeTarget
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    final tag = scope.tag;
    final page = await listTransactions(
      userId,
      MoneyTransactionQuery(
        page: 1,
        pageSize: 200,
        ledgerId: budgetLedgerId,
        status: MoneyTransactionStatus.pending,
        type: transactionType,
        accountId: scope.accountId,
        categoryId: scope.categoryId,
        subCategoryId: scope.subCategoryId,
        tags: tag == null ? const <String>[] : <String>[tag],
        dateStart: period.start,
        dateEnd: period.end.subtract(const Duration(milliseconds: 1)),
      ),
    );

    final items = <MoneyBudgetCommitmentItem>[];
    for (final transaction in page.items) {
      final amountMinor =
          transaction.amountMinor - transaction.refundAmountMinor;
      if (amountMinor <= 0) {
        continue;
      }
      items.add(
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.pendingTransaction,
          sourceId: transaction.id,
          title: _commitmentTransactionTitle(transaction),
          date: transaction.transactionAt,
          amountMinor: amountMinor,
          detail: '待确认',
        ),
      );
    }
    return items;
  }

  List<MoneyBudgetCommitmentItem> _billReminderCommitmentItems({
    required String userId,
    required MoneyBudget budget,
    required _BudgetScope scope,
    required MoneyBudgetTrackingType trackingType,
    required String budgetLedgerId,
    required ({DateTime start, DateTime end}) period,
    required _CommitmentSources sources,
  }) {
    // 账单提醒金额常常是估算值，且只用于「有支出目标」的场景。
    if (trackingType != MoneyBudgetTrackingType.expenseLimit) {
      return const <MoneyBudgetCommitmentItem>[];
    }

    final items = <MoneyBudgetCommitmentItem>[];
    for (final reminder in sources.pendingReminders) {
      if (reminder.amountMinor <= 0) {
        continue;
      }
      if (reminder.currencyCode != budget.currencyCode) {
        continue;
      }
      if ((reminder.ledgerId ?? _defaultLedgerId(userId)) != budgetLedgerId) {
        continue;
      }
      if (!_commitmentMatchesScope(
        scope,
        accountId: reminder.accountId,
        categoryId: reminder.categoryId,
        subCategoryId: null,
      )) {
        continue;
      }
      if (_isBeforePeriod(reminder.dueDate, period) ||
          !reminder.dueDate.isBefore(period.end)) {
        continue;
      }
      items.add(
        MoneyBudgetCommitmentItem(
          source: MoneyBudgetCommitmentSource.billReminder,
          sourceId: reminder.id,
          title: reminder.name,
          date: reminder.dueDate,
          amountMinor: reminder.amountMinor,
          detail: MoneyBudgetCommitmentSource.billReminder.label,
        ),
      );
    }
    return items;
  }

  Future<_CommitmentSources> _loadCommitmentSources(
    String userId,
    MoneyBudgetCommitmentOptions options,
  ) async {
    final templates = <MoneyAutoPostingTemplateEntity>[];
    final runStatusByKey = <String, String>{};
    if (options.includeAutoPosting) {
      // taken_over_by_plan_id 非空 = 已由分期接管。正常路径上这类模板 isActive
      // 已经是 false，会被上面的条件过滤掉；这里再显式排除一次，是为了防止
      //「标了接管却仍是启用态」的脏数据把同一笔钱算两遍。
      final templateRows =
          await (database.select(database.moneyAutoPostingTemplates)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isActive.equals(true) &
                    row.isDeleted.equals(false) &
                    row.takenOverByPlanId.isNull(),
              ))
              .get();
      for (final row in templateRows) {
        templates.add(_mapAutoPostingTemplate(row));
      }

      final runRows = await (database.select(
        database.moneyAutoPostingRuns,
      )..where((row) => row.userId.equals(userId))).get();
      for (final run in runRows) {
        runStatusByKey['${run.templateId}::${run.occurrenceKey}'] = run.status;
      }
    }

    final pendingInstallments = <_PendingInstallmentCommitment>[];
    if (options.includeInstallments) {
      final detailRows =
          await (database.select(database.moneyInstallmentDetails)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.status.equals(
                      MoneyInstallmentDetailStatus.pending.storageValue,
                    ),
              ))
              .get();
      final plans = <String, MoneyInstallmentPlanEntity>{};
      for (final row in detailRows) {
        var plan = plans[row.planId];
        if (plan == null) {
          final planRow = await _getInstallmentPlanForUser(userId, row.planId);
          plan = _mapInstallmentPlan(planRow);
          plans[row.planId] = plan;
        }
        // 已取消 / 已完成的分期不能再占额度。
        if (plan.status != MoneyInstallmentPlanStatus.active) {
          continue;
        }
        pendingInstallments.add(
          _PendingInstallmentCommitment(
            detail: _mapInstallmentDetail(row),
            plan: plan,
          ),
        );
      }
    }

    final pendingReminders = <MoneyBillReminderEntity>[];
    if (options.includeBillReminders) {
      final reminderRows =
          await (database.select(database.moneyBillReminders)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false) &
                    row.status.equals(
                      MoneyBillReminderStatus.pending.storageValue,
                    ),
              ))
              .get();
      for (final row in reminderRows) {
        final reminder = _mapBillReminder(row);
        // autoManaged 的提醒是从信用卡账单 / 分期派生出来的，算进来会与
        // 分期那一份重复计入。
        if (reminder.autoManaged) {
          continue;
        }
        pendingReminders.add(reminder);
      }
    }

    // 同一笔还款在模板和分期里各登记了一次时，只保留分期那一份。
    // 分期期次是唯一真相：它带着本金 / 利息 / 冻结额度，自动记账模板只是
    // 一个固定金额，本来就不该由它来代表分期还款。
    final conflictingTemplateIds =
        options.includeAutoPosting && options.includeInstallments
        ? conflictingAutoPostingTemplateIds(
            userId: userId,
            templates: templates,
            pendingInstallments: pendingInstallments,
          )
        : const <String>{};

    return _CommitmentSources(
      templates: templates,
      runStatusByKey: runStatusByKey,
      pendingInstallments: pendingInstallments,
      pendingReminders: pendingReminders,
      conflictingTemplateIds: conflictingTemplateIds,
    );
  }

  /// 只有「还没入账、且将来会入账」的 run 才占额度。
  ///
  /// - `posted` / `duplicateIgnored`：已经入过账了，再算一次就是重复计算；
  /// - `blocked`：账户不可用，永远不会入账；
  /// - `userDeleted`：用户手动删掉了这一笔。
  bool _isCommittedAutoPostingRunStatus(String? status) {
    if (status == null) {
      return true;
    }
    final parsed = MoneyAutoPostingRunStatus.fromStorageValue(status);
    return parsed == MoneyAutoPostingRunStatus.pending ||
        parsed == MoneyAutoPostingRunStatus.retryableFailed;
  }

  bool _commitmentMatchesTrackingType(
    MoneyBudgetTrackingType trackingType,
    MoneyTransactionType type,
  ) {
    return switch (trackingType) {
      MoneyBudgetTrackingType.expenseLimit =>
        type == MoneyTransactionType.expense,
      MoneyBudgetTrackingType.incomeTarget =>
        type == MoneyTransactionType.income,
    };
  }

  /// 未传 tags 的来源（自动记账 / 分期 / 账单提醒）在标签预算下必然不匹配，
  /// 这是刻意的：宁可不计入，也不要猜。
  bool _commitmentMatchesScope(
    _BudgetScope scope, {
    required String? accountId,
    required String? categoryId,
    String? subCategoryId,
    List<String> tags = const <String>[],
  }) {
    if (scope.accountId != null && scope.accountId != accountId) {
      return false;
    }
    if (scope.categoryId != null && scope.categoryId != categoryId) {
      return false;
    }
    if (scope.subCategoryId != null && scope.subCategoryId != subCategoryId) {
      return false;
    }
    final tag = scope.tag;
    if (tag != null && !tags.contains(tag)) {
      return false;
    }
    return true;
  }

  bool _isBeforePeriod(DateTime date, ({DateTime start, DateTime end}) period) {
    return date.isBefore(period.start);
  }

  String _commitmentTransactionTitle(MoneyTransactionEntity transaction) {
    final description = transaction.description.trim();
    if (description.isNotEmpty) {
      return description;
    }
    final merchant = transaction.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      return merchant;
    }
    return transaction.type.label;
  }
}

/// 一次加载、多个预算复用的数据源。
class _CommitmentSources {
  const _CommitmentSources({
    required this.templates,
    required this.runStatusByKey,
    required this.pendingInstallments,
    required this.pendingReminders,
    this.conflictingTemplateIds = const <String>{},
  });

  final List<MoneyAutoPostingTemplateEntity> templates;

  /// `${templateId}::${occurrenceKey}` → run 状态。
  final Map<String, String> runStatusByKey;
  final List<_PendingInstallmentCommitment> pendingInstallments;
  final List<MoneyBillReminderEntity> pendingReminders;

  /// 与分期期次重复登记、因而被跳过的自动记账模板 id。
  final Set<String> conflictingTemplateIds;
}

class _PendingInstallmentCommitment {
  const _PendingInstallmentCommitment({
    required this.detail,
    required this.plan,
  });

  final MoneyInstallmentDetailEntity detail;
  final MoneyInstallmentPlanEntity plan;
}
