part of 'package:miji/features/bookkeeping/data/drift_money_repository.dart';

/// 自动记账模板与分期计划的重复登记：检测与处置。
///
/// 分期自己就会自动入账（到期把期次记成一笔支出），用户再为同一笔还款建个
/// 自动记账模板，到期当天两个引擎各建一笔流水。这里不合并两个引擎，而是让
/// 分期独占：模板被「接管」后 isActive 置 false，既不再入账也不再占预算。
///
/// 检测是**保守**的：只报不猜，绝不自动停用模板或自动跳过执行。误判的代价是
/// 「该记的账没记」，比多记一次严重得多。
///
/// 依赖 [_AutoPosting]（occurrence 展开）与 [_Installments]（分期读取）的私有
/// 成员，两者都是兄弟 mixin，必须写进 `on` 子句并在 with 列表里排在前面。
mixin _AutoPostingConflicts
    on _DriftMoneyRepositoryBase, _AutoPosting, _Installments {
  @override
  Future<MoneyAutoPostingTemplateEntity> takeOverAutoPostingTemplate(
    String userId,
    String templateId,
    String planId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final template = await _getAutoPostingTemplateForUser(userId, templateId);
      final plan = await _getInstallmentPlanForUser(userId, planId);
      if (MoneyInstallmentPlanStatus.fromStorageValue(plan.status) !=
          MoneyInstallmentPlanStatus.active) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.installmentPlanNotFound,
        );
      }
      // 币种不同就没法「同一笔还款」，账面会直接错乱。
      if (plan.currencyCode != template.currencyCode) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidInstallmentTakeOver,
        );
      }

      final now = _utcNow();
      await (database.update(database.moneyAutoPostingTemplates)..where(
            (row) =>
                row.id.equals(templateId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyAutoPostingTemplatesCompanion(
              takenOverByPlanId: Value<String?>(planId),
              isActive: const Value(false),
              version: Value(template.version + 1),
              updatedAt: Value(now),
            ),
          );

      final updated = await _getAutoPostingTemplateForUser(userId, templateId);
      await syncChangeLogger?.recordAutoPostingTemplateChange(
        userId: userId,
        recordId: templateId,
        operation: SyncChangeOperation.update,
        changedFields: <String, Object?>{
          'is_active': false,
          'taken_over_by_plan_id': planId,
        },
        beforeVersion: template.version,
        afterVersion: updated.version,
      );
      return _mapAutoPostingTemplate(updated);
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
  Future<MoneyAutoPostingTemplateEntity> releaseAutoPostingTakeOver(
    String userId,
    String templateId,
  ) async {
    try {
      await ensureReadyForUser(userId);
      final template = await _getAutoPostingTemplateForUser(userId, templateId);
      if (template.takenOverByPlanId == null) {
        return _mapAutoPostingTemplate(template);
      }

      final now = _utcNow();
      await (database.update(database.moneyAutoPostingTemplates)..where(
            (row) =>
                row.id.equals(templateId) &
                row.userId.equals(userId) &
                row.isDeleted.equals(false),
          ))
          .write(
            MoneyAutoPostingTemplatesCompanion(
              takenOverByPlanId: const Value<String?>(null),
              // 接管时是停用的，解除后必须重新启用，否则模板会变成一个
              // 用户看不出原因的「停用僵尸」。
              isActive: const Value(true),
              version: Value(template.version + 1),
              updatedAt: Value(now),
            ),
          );

      final updated = await _getAutoPostingTemplateForUser(userId, templateId);
      await syncChangeLogger?.recordAutoPostingTemplateChange(
        userId: userId,
        recordId: templateId,
        operation: SyncChangeOperation.update,
        changedFields: const <String, Object?>{
          'is_active': true,
          'taken_over_by_plan_id': null,
        },
        beforeVersion: template.version,
        afterVersion: updated.version,
      );
      return _mapAutoPostingTemplate(updated);
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
  Future<List<MoneyAutoPostingInstallmentConflict>>
  findAutoPostingInstallmentConflicts(String userId) async {
    try {
      await ensureReadyForUser(userId);

      // 只看「还在跑、还会记账」的模板：已停用的不参与入账，不构成冲突。
      // 被接管的模板 isActive 已经是 false，天然不会被这里检出——
      // 处置完成的冲突就该从列表里消失。
      final templateRows =
          await (database.select(database.moneyAutoPostingTemplates)..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.isActive.equals(true) &
                    row.isDeleted.equals(false),
              ))
              .get();
      final templates = templateRows
          .map(_mapAutoPostingTemplate)
          .where((template) => template.type == MoneyTransactionType.expense)
          .toList(growable: false);
      if (templates.isEmpty) {
        return const <MoneyAutoPostingInstallmentConflict>[];
      }

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
      final pendingByPlan = <String, List<MoneyInstallmentDetailEntity>>{};
      for (final row in detailRows) {
        var plan = plans[row.planId];
        if (plan == null) {
          // 计划被删了就跳过这一批期次：冲突检测是提示性的，
          // 不该因为一条脏数据让整个列表读不出来。
          final loaded = await _installmentPlanOrNull(userId, row.planId);
          if (loaded == null) {
            continue;
          }
          plan = loaded;
          plans[row.planId] = plan;
        }
        if (!plan.isActive) {
          continue;
        }
        pendingByPlan
            .putIfAbsent(row.planId, () => <MoneyInstallmentDetailEntity>[])
            .add(_mapInstallmentDetail(row));
      }
      if (pendingByPlan.isEmpty) {
        return const <MoneyAutoPostingInstallmentConflict>[];
      }

      final conflicts = <MoneyAutoPostingInstallmentConflict>[];
      for (final template in templates) {
        final templateLedgerId = template.ledgerId ?? _defaultLedgerId(userId);
        for (final entry in pendingByPlan.entries) {
          final plan = plans[entry.key]!;
          if (plan.currencyCode != template.currencyCode) {
            continue;
          }
          if (plan.ledgerId != templateLedgerId) {
            continue;
          }
          final match = _matchPendingDetail(
            template: template,
            plan: plan,
            details: entry.value,
          );
          if (match == null) {
            continue;
          }
          conflicts.add(
            MoneyAutoPostingInstallmentConflict(
              templateId: template.id,
              templateName: template.name,
              templateAmountMinor: template.amountMinor,
              currencyCode: template.currencyCode,
              planId: plan.id,
              planName: plan.name,
              periodNumber: match.detail.periodNumber,
              dueDate: match.detail.dueDate,
              detailAmountMinor: match.detail.amountMinor,
              kind: match.kind,
              isTakenOver: false,
              ledgerId: plan.ledgerId,
            ),
          );
        }
      }

      conflicts.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return conflicts;
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

  /// 在已加载的数据上判定哪些模板与分期期次重复，供预算「已预留」去重复用。
  ///
  /// 预算层与冲突检测页看的是同一件事，两边各判一次必然漂移；共用这一个
  /// 判定才能保证「列表里提示的冲突」和「预留里跳过的金额」永远一致。
  /// 传入的数据是调用方已经加载好的，这里不再查库。
  Set<String> conflictingAutoPostingTemplateIds({
    required String userId,
    required List<MoneyAutoPostingTemplateEntity> templates,
    required List<_PendingInstallmentCommitment> pendingInstallments,
  }) {
    if (templates.isEmpty || pendingInstallments.isEmpty) {
      return const <String>{};
    }

    final detailsByPlan = <String, List<MoneyInstallmentDetailEntity>>{};
    final plans = <String, MoneyInstallmentPlanEntity>{};
    for (final entry in pendingInstallments) {
      plans[entry.plan.id] = entry.plan;
      detailsByPlan
          .putIfAbsent(entry.plan.id, () => <MoneyInstallmentDetailEntity>[])
          .add(entry.detail);
    }

    final result = <String>{};
    for (final template in templates) {
      if (template.type != MoneyTransactionType.expense) {
        continue;
      }
      final templateLedgerId = template.ledgerId ?? _defaultLedgerId(userId);
      for (final entry in detailsByPlan.entries) {
        final plan = plans[entry.key]!;
        if (plan.currencyCode != template.currencyCode ||
            plan.ledgerId != templateLedgerId) {
          continue;
        }
        if (_matchPendingDetail(
              template: template,
              plan: plan,
              details: entry.value,
            ) !=
            null) {
          result.add(template.id);
          break;
        }
      }
    }
    return result;
  }

  /// 读分期计划；计划不存在（或已被删）时返回 null，让调用方跳过而不是抛错。
  Future<MoneyInstallmentPlanEntity?> _installmentPlanOrNull(
    String userId,
    String planId,
  ) async {
    try {
      return _mapInstallmentPlan(
        await _getInstallmentPlanForUser(userId, planId),
      );
    } on MoneyRepositoryException {
      return null;
    }
  }

  /// 模板的执行计划里，是否有一天正好落在某一期待还的到期日上。
  _ConflictMatch? _matchPendingDetail({
    required MoneyAutoPostingTemplateEntity template,
    required MoneyInstallmentPlanEntity plan,
    required List<MoneyInstallmentDetailEntity> details,
  }) {
    final sorted = [...details]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    // 一次展开覆盖全部待还期次，而不是对每个 detail 各展开一遍——
    // daily 模板按日循环，逐个展开会退化成 N× 循环。
    final first = sorted.first.dueDate;
    final last = sorted.last.dueDate;
    final occurrenceDays = <int>{};
    for (final occurrence in _occurrencesWithinPeriod(
      template,
      _dateOnlyUtc(first),
      _dateOnlyUtc(last).add(const Duration(days: 1)),
    )) {
      occurrenceDays.add(_dateKey(occurrence.scheduledFor));
    }
    if (occurrenceDays.isEmpty) {
      return null;
    }

    // 等额本息 / 等额本金每期金额递减，跟固定金额的模板本来就对不上；
    // 这时候「同一天 + 同一账户」已经足够可疑，值得提示用户看一眼。
    final allowSameDayOnly = plan.calcMethod != MoneyInstallmentCalcMethod.flat;

    for (final detail in sorted) {
      if (!occurrenceDays.contains(_dateKey(detail.dueDate))) {
        continue;
      }
      if (detail.accountId != template.accountId) {
        continue;
      }
      if (template.amountMinor == detail.amountMinor) {
        return _ConflictMatch(
          detail: detail,
          kind: MoneyAutoPostingConflictKind.exactAmount,
        );
      }
      if (allowSameDayOnly) {
        return _ConflictMatch(
          detail: detail,
          kind: MoneyAutoPostingConflictKind.sameDayOnly,
        );
      }
    }
    return null;
  }
}

class _ConflictMatch {
  const _ConflictMatch({required this.detail, required this.kind});

  final MoneyInstallmentDetailEntity detail;
  final MoneyAutoPostingConflictKind kind;
}
