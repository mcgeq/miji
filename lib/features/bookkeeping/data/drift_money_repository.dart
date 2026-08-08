import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/seed/database_seed_runner.dart';
import 'package:miji/core/sync/delta_sync/delta_conflict_models.dart';
import 'package:miji/core/sync/delta_sync/delta_package_models.dart';
import 'package:miji/core/sync/delta_sync/sync_change_logger.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_auto_posting_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_history_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

part 'parts/ledgers.dart';
part 'parts/splits.dart';
part 'parts/accounts.dart';
part 'parts/statistics.dart';
part 'parts/transactions.dart';
part 'parts/categories.dart';
part 'parts/budgets.dart';
part 'parts/bill_reminders.dart';
part 'parts/installments.dart';
part 'parts/auto_posting.dart';
part 'parts/remote_apply.dart';
part 'parts/reports.dart';
part 'parts/asset_snapshots.dart';

class _TransferPair {
  const _TransferPair({required this.outgoing, required this.incoming});

  final MoneyTransaction outgoing;
  final MoneyTransaction incoming;
}

class _SplitAmount {
  const _SplitAmount({
    required this.memberId,
    required this.amountMinor,
    required this.percentageBasisPoints,
  });

  final String memberId;
  final int amountMinor;
  final int? percentageBasisPoints;
}

class _IncomeExpenseTotals {
  const _IncomeExpenseTotals({
    required this.incomeMinor,
    required this.expenseMinor,
  });

  final int incomeMinor;
  final int expenseMinor;
}

class _AutoPostingOccurrence {
  const _AutoPostingOccurrence({
    required this.occurrenceKey,
    required this.scheduledFor,
  });

  final String occurrenceKey;
  final DateTime scheduledFor;
}

class _AutoPostingExecutionOutcome {
  const _AutoPostingExecutionOutcome({
    required this.posted,
    required this.skipped,
    required this.blocked,
    required this.failed,
    this.transaction,
    this.ledgerIds = const <String>[],
  });

  final bool posted;
  final bool skipped;
  final bool blocked;
  final bool failed;
  final MoneyTransactionEntity? transaction;
  final List<String> ledgerIds;
}

class _UsageStat {
  _UsageStat({this.useCount = 0, this.totalAmountMinor = 0, this.lastUsedAt});

  int useCount;
  int totalAmountMinor;
  DateTime? lastUsedAt;

  void add({required int amountMinor, required DateTime usedAt}) {
    useCount++;
    totalAmountMinor += amountMinor;
    final current = lastUsedAt;
    if (current == null || usedAt.isAfter(current)) {
      lastUsedAt = usedAt;
    }
  }
}

int _effectiveTransactionAmountMinor(MoneyTransaction transaction) {
  return _effectiveAmountMinor(
    amountMinor: transaction.amountMinor,
    refundAmountMinor: transaction.refundAmountMinor,
  );
}

int _effectiveAmountMinor({
  required int amountMinor,
  required int refundAmountMinor,
}) {
  final amount = amountMinor;
  if (amount <= 0) {
    return 0;
  }

  final refund = refundAmountMinor;
  if (refund <= 0) {
    return amount;
  }
  if (refund >= amount) {
    return 0;
  }
  return amount - refund;
}

class _MutableStatisticsPaymentMethod {
  _MutableStatisticsPaymentMethod({
    required this.method,
    required this.label,
    required this.customPaymentMethodName,
  });

  final MoneyPaymentMethod method;
  final String label;
  final String? customPaymentMethodName;
  int incomeMinor = 0;
  int expenseMinor = 0;
  int transactionCount = 0;
}

class _MutableStatisticsAccountPaymentMethod {
  _MutableStatisticsAccountPaymentMethod({
    required this.accountId,
    required this.method,
    required this.label,
  });

  final String accountId;
  final MoneyPaymentMethod method;
  final String label;
  int incomeMinor = 0;
  int expenseMinor = 0;
  int transactionCount = 0;
}

class _MutableStatisticsRank {
  _MutableStatisticsRank({required this.id, required this.name});

  final String id;
  final String name;
  int amountMinor = 0;
  int transactionCount = 0;
}

class _MutableStatisticsMember {
  _MutableStatisticsMember({
    required this.memberId,
    required this.memberName,
    required this.role,
  });

  final String memberId;
  final String memberName;
  final String role;
  int paidAmountMinor = 0;
  int participatedAmountMinor = 0;
  int paidRecordCount = 0;
  int participationCount = 0;
}

class _MutableAccountTypeStatistics {
  _MutableAccountTypeStatistics({
    required this.type,
    required this.currencyCode,
  });

  final MoneyAccountType type;
  final String currencyCode;
  int assetMinor = 0;
  int liabilityMinor = 0;
  int accountCount = 0;

  int get totalMinor => assetMinor + liabilityMinor;
}

class _MutableAccountLedger {
  _MutableAccountLedger({
    required this.type,
    required this.isVirtual,
    required this.balanceMinor,
    required this.initialBalanceMinor,
    required this.creditLimitMinor,
    required this.postedDebtMinor,
    required this.frozenCreditMinor,
  });

  factory _MutableAccountLedger.fromAccount(MoneyAccount account) {
    final type = MoneyAccountType.fromStorageValue(account.type);
    final creditLimitMinor =
        account.creditLimitMinor ?? account.initialBalanceMinor;
    final postedDebtMinor = account.postedDebtMinor ?? 0;
    final frozenCreditMinor = account.frozenCreditMinor ?? 0;
    return _MutableAccountLedger(
      type: type,
      isVirtual: account.isVirtual,
      balanceMinor: type.isCreditLike
          ? creditLimitMinor - postedDebtMinor - frozenCreditMinor
          : account.balanceMinor,
      initialBalanceMinor: type.isCreditLike
          ? creditLimitMinor
          : account.initialBalanceMinor,
      creditLimitMinor: type.isCreditLike ? creditLimitMinor : null,
      postedDebtMinor: type.isCreditLike ? postedDebtMinor : null,
      frozenCreditMinor: type.isCreditLike ? frozenCreditMinor : null,
    );
  }

  factory _MutableAccountLedger.fromDraft(MoneyAccountDraft draft) {
    if (draft.type.isCreditLike) {
      return _MutableAccountLedger(
        type: draft.type,
        isVirtual: false,
        balanceMinor: draft.initialBalanceMinor,
        initialBalanceMinor: draft.initialBalanceMinor,
        creditLimitMinor: draft.initialBalanceMinor,
        postedDebtMinor: 0,
        frozenCreditMinor: 0,
      );
    }

    return _MutableAccountLedger(
      type: draft.type,
      isVirtual: false,
      balanceMinor: draft.initialBalanceMinor,
      initialBalanceMinor: draft.initialBalanceMinor,
      creditLimitMinor: null,
      postedDebtMinor: null,
      frozenCreditMinor: null,
    );
  }

  MoneyAccountType type;
  final bool isVirtual;
  int balanceMinor;
  int initialBalanceMinor;
  int? creditLimitMinor;
  int? postedDebtMinor;
  int? frozenCreditMinor;

  int get effectiveCreditLimitMinor => creditLimitMinor ?? initialBalanceMinor;

  int get effectivePostedDebtMinor => postedDebtMinor ?? 0;

  int get effectiveFrozenCreditMinor => frozenCreditMinor ?? 0;

  int get usedCreditMinor {
    return effectivePostedDebtMinor + effectiveFrozenCreditMinor;
  }

  int get availableCreditMinor {
    return effectiveCreditLimitMinor - usedCreditMinor;
  }

  void applyAccountUpdate(MoneyAccountUpdate update) {
    final wasCreditLike = type.isCreditLike;
    if (update.type.isCreditLike) {
      final nextPostedDebtMinor = type.isCreditLike
          ? effectivePostedDebtMinor
          : 0;
      final nextFrozenCreditMinor = type.isCreditLike
          ? effectiveFrozenCreditMinor
          : 0;
      type = update.type;
      initialBalanceMinor = update.initialBalanceMinor;
      creditLimitMinor = update.initialBalanceMinor;
      postedDebtMinor = nextPostedDebtMinor;
      frozenCreditMinor = nextFrozenCreditMinor;
      balanceMinor = availableCreditMinor;
      return;
    }

    final balanceDelta = update.initialBalanceMinor - initialBalanceMinor;
    type = update.type;
    initialBalanceMinor = update.initialBalanceMinor;
    balanceMinor = wasCreditLike
        ? update.initialBalanceMinor
        : balanceMinor + balanceDelta;
    creditLimitMinor = null;
    postedDebtMinor = null;
    frozenCreditMinor = null;
  }

  void applyTransactionCreate(
    MoneyTransactionType transactionType,
    int amountMinor,
  ) {
    if (type.isCreditLike) {
      switch (transactionType) {
        case MoneyTransactionType.income:
          postedDebtMinor = effectivePostedDebtMinor - amountMinor;
        case MoneyTransactionType.expense:
          postedDebtMinor = effectivePostedDebtMinor + amountMinor;
        case MoneyTransactionType.transfer:
          break;
      }
      balanceMinor = availableCreditMinor;
      return;
    }

    balanceMinor = switch (transactionType) {
      MoneyTransactionType.income => balanceMinor + amountMinor,
      MoneyTransactionType.expense => balanceMinor - amountMinor,
      MoneyTransactionType.transfer => balanceMinor,
    };
  }

  void applyTransactionRollback(
    MoneyTransactionType transactionType,
    int amountMinor,
  ) {
    if (type.isCreditLike) {
      switch (transactionType) {
        case MoneyTransactionType.income:
          postedDebtMinor = effectivePostedDebtMinor + amountMinor;
        case MoneyTransactionType.expense:
          postedDebtMinor = effectivePostedDebtMinor - amountMinor;
        case MoneyTransactionType.transfer:
          break;
      }
      balanceMinor = availableCreditMinor;
      return;
    }

    balanceMinor = switch (transactionType) {
      MoneyTransactionType.income => balanceMinor - amountMinor,
      MoneyTransactionType.expense => balanceMinor + amountMinor,
      MoneyTransactionType.transfer => balanceMinor,
    };
  }

  void applyTransferOutgoing(int amountMinor) {
    if (!type.isAssetLike && !type.isInternal) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
    balanceMinor -= amountMinor;
  }

  void applyTransferIncoming(int amountMinor) {
    if (!type.isAssetLike && !type.isCreditLike && !type.isInternal) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
    if (type.isCreditLike) {
      postedDebtMinor = effectivePostedDebtMinor - amountMinor;
      balanceMinor = availableCreditMinor;
      return;
    }
    balanceMinor += amountMinor;
  }

  void applyTransferOutgoingRollback(int amountMinor) {
    if (!type.isAssetLike && !type.isInternal) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
    balanceMinor += amountMinor;
  }

  void applyTransferIncomingRollback(int amountMinor) {
    if (!type.isAssetLike && !type.isCreditLike && !type.isInternal) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
    if (type.isCreditLike) {
      postedDebtMinor = effectivePostedDebtMinor + amountMinor;
      balanceMinor = availableCreditMinor;
      return;
    }
    balanceMinor -= amountMinor;
  }

  void freezeCredit(int principalMinor) {
    if (!type.isCreditLike) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidInstallmentAccount,
      );
    }
    frozenCreditMinor = effectiveFrozenCreditMinor + principalMinor;
    balanceMinor = availableCreditMinor;
  }

  void releaseFrozenCredit(int principalMinor) {
    if (!type.isCreditLike) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidInstallmentAccount,
      );
    }
    frozenCreditMinor = effectiveFrozenCreditMinor - principalMinor;
    balanceMinor = availableCreditMinor;
  }

  void postInstallmentExpense({
    required int principalMinor,
    required int amountMinor,
  }) {
    if (!type.isCreditLike) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidInstallmentAccount,
      );
    }
    frozenCreditMinor = effectiveFrozenCreditMinor - principalMinor;
    postedDebtMinor = effectivePostedDebtMinor + amountMinor;
    balanceMinor = availableCreditMinor;
  }

  void validate() {
    if (isVirtual) {
      return;
    }
    if (type.isCreditLike) {
      if (effectiveCreditLimitMinor < 0 ||
          effectivePostedDebtMinor < 0 ||
          effectiveFrozenCreditMinor < 0) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidAccountBalance,
        );
      }
      if (usedCreditMinor > effectiveCreditLimitMinor) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.creditCardLimitExceeded,
        );
      }
      return;
    }

    if (initialBalanceMinor < 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidAccountBalance,
      );
    }
    if (balanceMinor < 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.insufficientFunds,
      );
    }
  }

  MoneyAccountsCompanion toCompanion({required DateTime updatedAt}) {
    return MoneyAccountsCompanion(
      balanceMinor: Value(balanceMinor),
      initialBalanceMinor: Value(initialBalanceMinor),
      creditLimitMinor: Value<int?>(creditLimitMinor),
      postedDebtMinor: Value<int?>(postedDebtMinor),
      frozenCreditMinor: Value<int?>(frozenCreditMinor),
      updatedAt: Value(updatedAt),
    );
  }
}

class _BudgetScope {
  const _BudgetScope({this.categoryId, this.subCategoryId, this.accountId});

  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
}

class _BudgetTransactionImpact {
  const _BudgetTransactionImpact({
    required this.type,
    required this.accountId,
    required this.categoryId,
    required this.subCategoryId,
    required this.ledgerIds,
  });

  final MoneyTransactionType type;
  final String accountId;
  final String categoryId;
  final String? subCategoryId;
  final List<String> ledgerIds;
}

class _MutableAccountMonthlySummary {
  _MutableAccountMonthlySummary(this.accountId);

  final String accountId;
  int currentIncomeMinor = 0;
  int currentExpenseMinor = 0;
  int previousIncomeMinor = 0;
  int previousExpenseMinor = 0;

  MoneyAccountMonthlySummary toEntity() {
    return MoneyAccountMonthlySummary(
      accountId: accountId,
      currentIncomeMinor: currentIncomeMinor,
      currentExpenseMinor: currentExpenseMinor,
      previousIncomeMinor: previousIncomeMinor,
      previousExpenseMinor: previousExpenseMinor,
    );
  }
}

abstract class _DriftMoneyRepositoryBase implements MoneyRepository {
  _DriftMoneyRepositoryBase({
    required this.database,
    required this.seedRunner,
    this.syncChangeLogger,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? _defaultNow;

  final AppDatabase database;
  final DatabaseSeedRunner seedRunner;
  final SyncChangeLogger? syncChangeLogger;
  final DateTime Function() _now;
  final Uuid _uuid;
  static const _transferCategoryId = 'system_transfer';
  static const _legacyIncomeTransferCategoryId = 'income_transfer';
  static const _transferCategoryIds = <String>[
    _transferCategoryId,
    _legacyIncomeTransferCategoryId,
  ];
  static const _transferOutMarker = 'transfer_out';
  static const _transferInMarker = 'transfer_in';
  static const _budgetTypeStandard = 'standard';
  static const _budgetTypeLegacySnapshot = 'legacy_snapshot';
  static const _defaultLedgerName = '个人账本';
  static const _defaultMemberColor = '#F59E0B';
  final Set<String> _readyUserIds = <String>{};
  final Map<String, Future<void>> _readyUserFutures = <String, Future<void>>{};
  Future<void>? _globalDefaultsFuture;

  static bool _isInstallmentPosting(MoneyTransaction transaction) {
    return MoneyTransactionEntity.isInstallmentPostingRecord(
      actualPayerAccount: transaction.actualPayerAccount,
      installmentPlanId: transaction.installmentPlanId,
    );
  }

  static DateTime _defaultNow() => DateTime.now();

  DateTime _utcNow() => _now().toUtc();

  @override
  Future<void> ensureReadyForUser(String userId) async {
    if (_readyUserIds.contains(userId)) {
      return;
    }

    final existingFuture = _readyUserFutures[userId];
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _ensureReadyForUserUncached(userId);
    _readyUserFutures[userId] = future;
    try {
      await future;
      _readyUserIds.add(userId);
    } finally {
      _readyUserFutures.remove(userId);
    }
  }

  Future<void> _ensureReadyForUserUncached(String userId) async {
    try {
      await _ensureGlobalDefaults();

      final now = DateTime.now().toUtc();
      await database.transaction(() async {
        await database
            .into(database.moneyAccounts)
            .insert(
              MoneyAccountsCompanion.insert(
                id: _internalAccountId(userId),
                userId: userId,
                name: '内部账户',
                description: const Value<String?>('系统内部账户'),
                type: MoneyAccountType.internal.storageValue,
                balanceMinor: 0,
                initialBalanceMinor: 0,
                currencyCode: 'CNY',
                isShared: const Value(false),
                isVirtual: const Value(true),
                color: const Value<String?>('#94A3B8'),
                icon: const Value<String?>('account_balance_wallet'),
                isActive: const Value(true),
                createdAt: now,
                updatedAt: now,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await _ensureDefaultSplitContext(userId, now);
      });
    } catch (error) {
      throw MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
        error,
      );
    }
  }

  Future<void> _ensureGlobalDefaults() async {
    final existingFuture = _globalDefaultsFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = seedRunner.seedGlobalDefaults();
    _globalDefaultsFuture = future;
    try {
      await future;
    } catch (_) {
      if (identical(_globalDefaultsFuture, future)) {
        _globalDefaultsFuture = null;
      }
      rethrow;
    }
  }

  @override
  Future<MoneyCreditCardBillView?> getCurrentCreditCardBillViewForAccount(
    String userId,
    String accountId, {
    DateTime? asOf,
  }) async {
    try {
      await ensureReadyForUser(userId);
      final account = await _getAccountForUser(userId, accountId);
      final accountType = MoneyAccountType.fromStorageValue(account.type);
      final statementDay = account.statementDay;
      final cycleStartDay = account.budgetCycleStartDay ?? statementDay;
      final repaymentDay = account.repaymentDay;
      if (!accountType.isCreditLike ||
          statementDay == null ||
          cycleStartDay == null ||
          repaymentDay == null) {
        return null;
      }

      final effectiveAsOf = asOf ?? _now();
      final today = _dateOnly(effectiveAsOf);
      final currentPeriod = _billingCyclePeriodFor(account, effectiveAsOf);

      final latestIssuedPeriod = _latestIssuedBillingCyclePeriod(
        currentPeriod,
        today,
        cycleStartDay,
      );
      if (latestIssuedPeriod != null) {
        final bill = await _buildCreditCardBillViewForPeriod(
          userId: userId,
          account: account,
          source: MoneyCreditCardBillViewSource.issuedStatement,
          period: latestIssuedPeriod,
          repaymentDay: repaymentDay,
          today: today,
          asOf: effectiveAsOf,
        );
        if (bill.amountDueMinor > 0) {
          return bill;
        }
      }

      final unbilledBill = await _buildCreditCardBillViewForPeriod(
        userId: userId,
        account: account,
        source: MoneyCreditCardBillViewSource.unbilled,
        period: currentPeriod,
        repaymentDay: repaymentDay,
        today: today,
        asOf: effectiveAsOf,
      );
      if (unbilledBill.purchaseAmountMinor > 0 ||
          unbilledBill.amountDueMinor > 0) {
        return unbilledBill;
      }

      final postedDebtMinor = account.postedDebtMinor ?? 0;
      if (postedDebtMinor > 0 && latestIssuedPeriod != null) {
        return _buildCreditCardAccountDebtBillView(
          userId: userId,
          account: account,
          period: latestIssuedPeriod,
          repaymentDay: repaymentDay,
          today: today,
        );
      }

      return unbilledBill;
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

  Future<MoneyCreditCardBillView> _buildCreditCardBillViewForPeriod({
    required String userId,
    required MoneyAccount account,
    required MoneyCreditCardBillViewSource source,
    required ({DateTime start, DateTime end}) period,
    required int repaymentDay,
    required DateTime today,
    required DateTime asOf,
  }) async {
    final repaymentDate = _repaymentDateForStatementPeriod(
      periodEndExclusive: period.end,
      repaymentDay: repaymentDay,
    );
    final purchaseRows =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.accountId.equals(account.id) &
                    row.isDeleted.equals(false) &
                    row.status.equals(
                      MoneyTransactionStatus.completed.storageValue,
                    ) &
                    row.type.equals(MoneyTransactionType.expense.storageValue) &
                    row.categoryId.isNotIn(_transferCategoryIds) &
                    row.actualPayerAccount.isNotIn([_transferInMarker]) &
                    row.transactionAt.isBiggerOrEqualValue(
                      period.start.toUtc(),
                    ) &
                    row.transactionAt.isSmallerThanValue(period.end.toUtc()),
              )
              ..orderBy([
                (row) => OrderingTerm.desc(row.transactionAt),
                (row) => OrderingTerm.desc(row.updatedAt),
              ]))
            .get();
    final repaymentRows =
        await (database.select(database.moneyTransactions)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.accountId.equals(account.id) &
                  row.isDeleted.equals(false) &
                  row.status.equals(
                    MoneyTransactionStatus.completed.storageValue,
                  ) &
                  row.type.equals(MoneyTransactionType.transfer.storageValue) &
                  row.actualPayerAccount.equals(_transferInMarker) &
                  row.transactionAt.isBiggerOrEqualValue(period.start.toUtc()) &
                  row.transactionAt.isSmallerThanValue(asOf.toUtc()),
            ))
            .get();

    final purchaseAmountMinor = purchaseRows.fold<int>(
      0,
      (total, row) => total + _effectiveTransactionAmountMinor(row),
    );
    final rawRepaymentAmountMinor = repaymentRows.fold<int>(
      0,
      (total, row) => total + _effectiveTransactionAmountMinor(row),
    );
    final postedDebtMinor = account.postedDebtMinor ?? 0;
    final repaymentAmountMinor =
        source == MoneyCreditCardBillViewSource.unbilled
        ? 0
        : rawRepaymentAmountMinor;
    final amountDueMinor = source == MoneyCreditCardBillViewSource.unbilled
        ? _unbilledAmountDueMinor(
            postedDebtMinor: postedDebtMinor,
            purchaseAmountMinor: purchaseAmountMinor,
          )
        : _statementAmountDueMinor(
            postedDebtMinor: postedDebtMinor,
            purchaseAmountMinor: purchaseAmountMinor,
            repaymentAmountMinor: repaymentAmountMinor,
          );
    final availableCreditMinor =
        (account.creditLimitMinor ?? account.initialBalanceMinor) -
        postedDebtMinor -
        (account.frozenCreditMinor ?? 0);

    return MoneyCreditCardBillView(
      accountId: account.id,
      source: source,
      currencyCode: account.currencyCode,
      periodStart: period.start,
      periodEndExclusive: period.end,
      repaymentDate: repaymentDate,
      purchaseAmountMinor: purchaseAmountMinor,
      repaymentAmountMinor: repaymentAmountMinor,
      amountDueMinor: amountDueMinor,
      availableCreditMinor: availableCreditMinor,
      postedDebtMinor: postedDebtMinor,
      state: _creditCardStatementState(
        amountDueMinor: amountDueMinor,
        periodEndExclusive: period.end,
        repaymentDate: repaymentDate,
        today: today,
      ),
      transactions: [
        for (final row in purchaseRows) _mapTransaction(row, tags: const []),
      ],
    );
  }

  Future<MoneyCreditCardBillView> _buildCreditCardAccountDebtBillView({
    required String userId,
    required MoneyAccount account,
    required ({DateTime start, DateTime end}) period,
    required int repaymentDay,
    required DateTime today,
  }) async {
    final postedDebtMinor = account.postedDebtMinor ?? 0;
    final repaymentDate =
        await _creditRepaymentReminderDueDate(userId, account.id) ??
        _repaymentDateForStatementPeriod(
          periodEndExclusive: period.end,
          repaymentDay: repaymentDay,
        );
    final availableCreditMinor =
        (account.creditLimitMinor ?? account.initialBalanceMinor) -
        postedDebtMinor -
        (account.frozenCreditMinor ?? 0);

    return MoneyCreditCardBillView(
      accountId: account.id,
      source: MoneyCreditCardBillViewSource.accountDebt,
      currencyCode: account.currencyCode,
      periodStart: period.start,
      periodEndExclusive: period.end,
      repaymentDate: repaymentDate,
      purchaseAmountMinor: postedDebtMinor,
      repaymentAmountMinor: 0,
      amountDueMinor: postedDebtMinor,
      availableCreditMinor: availableCreditMinor,
      postedDebtMinor: postedDebtMinor,
      state: _creditCardStatementState(
        amountDueMinor: postedDebtMinor,
        periodEndExclusive: period.end,
        repaymentDate: repaymentDate,
        today: today,
      ),
    );
  }

  Future<DateTime?> _creditRepaymentReminderDueDate(
    String userId,
    String accountId,
  ) async {
    final sourceKey = _creditRepaymentReminderSourceKey(accountId);
    final reminder =
        await (database.select(database.moneyBillReminders)
              ..where(
                (row) =>
                    row.userId.equals(userId) &
                    row.sourceKey.equals(sourceKey) &
                    row.isDeleted.equals(false) &
                    row.status.equals(
                      MoneyBillReminderStatus.pending.storageValue,
                    ),
              )
              ..limit(1))
            .getSingleOrNull();
    if (reminder == null) {
      return null;
    }
    return _dateFromKey(reminder.dueDate);
  }

  void _validateAutoPostingTemplateDraft(MoneyAutoPostingTemplateDraft draft) {
    _validateAutoPostingTemplateShape(
      name: draft.name,
      type: draft.type,
      amountMinor: draft.amountMinor,
      currencyCode: draft.currencyCode,
      description: draft.description,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
      frequency: draft.frequency,
      dayOfMonth: draft.dayOfMonth,
      weekday: draft.weekday,
      timeOfDayMinutes: draft.timeOfDayMinutes,
      startsOn: draft.startsOn,
      endsOn: draft.endsOn,
    );
  }

  void _validateAutoPostingTemplateUpdate(
    MoneyAutoPostingTemplateUpdate update,
  ) {
    _validateAutoPostingTemplateShape(
      name: update.name,
      type: update.type,
      amountMinor: update.amountMinor,
      currencyCode: update.currencyCode,
      description: update.description,
      accountId: update.accountId,
      categoryId: update.categoryId,
      frequency: update.frequency,
      dayOfMonth: update.dayOfMonth,
      weekday: update.weekday,
      timeOfDayMinutes: update.timeOfDayMinutes,
      startsOn: update.startsOn,
      endsOn: update.endsOn,
    );
  }

  void _validateAutoPostingTemplateShape({
    required String name,
    required MoneyTransactionType type,
    required int amountMinor,
    required String currencyCode,
    required String description,
    required String accountId,
    required String categoryId,
    required MoneyAutoPostingFrequency frequency,
    required int? dayOfMonth,
    required int? weekday,
    required int timeOfDayMinutes,
    required DateTime startsOn,
    required DateTime? endsOn,
  }) {
    if (name.trim().isEmpty ||
        description.trim().isEmpty ||
        currencyCode.trim().isEmpty ||
        accountId.trim().isEmpty ||
        categoryId.trim().isEmpty ||
        amountMinor <= 0 ||
        timeOfDayMinutes < 0 ||
        timeOfDayMinutes >= 24 * 60) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
    if (type == MoneyTransactionType.transfer) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
    if (frequency == MoneyAutoPostingFrequency.weekly &&
        weekday != null &&
        (weekday < DateTime.monday || weekday > DateTime.sunday)) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
    if (frequency == MoneyAutoPostingFrequency.monthly &&
        dayOfMonth != null &&
        (dayOfMonth < 1 || dayOfMonth > 31)) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
    final endDate = endsOn;
    if (endDate != null &&
        _dateOnlyUtc(endDate).isBefore(_dateOnlyUtc(startsOn))) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
  }

  MoneyCategoryKind _categoryKindForTransactionType(MoneyTransactionType type) {
    return switch (type) {
      MoneyTransactionType.income => MoneyCategoryKind.income,
      MoneyTransactionType.expense => MoneyCategoryKind.expense,
      MoneyTransactionType.transfer => throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      ),
    };
  }

  DateTime _dateOnlyUtc(DateTime date) {
    final local = date.toLocal();
    return DateTime.utc(local.year, local.month, local.day);
  }

  DateTime? _nullableDateOnlyUtc(DateTime? date) {
    return date == null ? null : _dateOnlyUtc(date);
  }

  _AutoPostingOccurrence _autoPostingOccurrence(
    DateTime occurrenceDate,
    DateTime scheduledFor,
  ) {
    final date = _dateOnlyUtc(occurrenceDate);
    return _AutoPostingOccurrence(
      occurrenceKey: _dateKey(date).toString(),
      scheduledFor: scheduledFor.toUtc(),
    );
  }

  DateTime _autoPostingScheduledFor(
    MoneyAutoPostingTemplateEntity template,
    DateTime occurrenceDate,
  ) {
    return _dateOnlyUtc(
      occurrenceDate,
    ).add(Duration(minutes: template.timeOfDayMinutes));
  }

  DateTime _monthlyAutoPostingDate(int year, int month, int dayOfMonth) {
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = dayOfMonth > lastDay ? lastDay : dayOfMonth;
    return DateTime.utc(year, month, day);
  }

  bool _isAutoPostingBlockedError(MoneyRepositoryException error) {
    return switch (error.code) {
      MoneyRepositoryErrorCode.accountNotFound ||
      MoneyRepositoryErrorCode.categoryNotFound ||
      MoneyRepositoryErrorCode.ledgerNotFound ||
      MoneyRepositoryErrorCode.invalidTransactionAmount ||
      MoneyRepositoryErrorCode.invalidTransferAccounts ||
      MoneyRepositoryErrorCode.invalidAccountBalance ||
      MoneyRepositoryErrorCode.insufficientFunds ||
      MoneyRepositoryErrorCode.creditCardLimitExceeded => true,
      _ => false,
    };
  }

  Future<MoneyAutoPostingRun?> _getAutoPostingRunById(
    String userId,
    String runId,
  ) {
    return (database.select(database.moneyAutoPostingRuns)
          ..where((row) => row.id.equals(runId) & row.userId.equals(userId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<MoneyAutoPostingRunEntity> _writeAutoPostingRunState({
    required MoneyAutoPostingRunEntity existing,
    required MoneyAutoPostingRunStatus status,
    required String? transactionId,
    required DateTime? postedAt,
    required String? errorCode,
    required String? errorMessage,
    DateTime? updatedAt,
  }) async {
    final effectiveUpdatedAt = (updatedAt ?? _utcNow()).toUtc();
    await (database.update(database.moneyAutoPostingRuns)..where(
          (row) =>
              row.id.equals(existing.id) & row.userId.equals(existing.userId),
        ))
        .write(
          MoneyAutoPostingRunsCompanion(
            status: Value(status.storageValue),
            transactionId: Value<String?>(transactionId),
            postedAt: Value<DateTime?>(postedAt?.toUtc()),
            errorCode: Value<String?>(errorCode),
            errorMessage: Value<String?>(errorMessage),
            updatedAt: Value(effectiveUpdatedAt),
          ),
        );
    final updatedRow = await _getAutoPostingRunById(
      existing.userId,
      existing.id,
    );
    final updated = _mapAutoPostingRun(updatedRow!);
    final changedFields = _autoPostingRunUpdateSyncFields(existing, updated);
    if (changedFields.isNotEmpty) {
      await _recordAutoPostingRunChange(
        userId: existing.userId,
        recordId: existing.id,
        operation: SyncChangeOperation.update,
        changedFields: changedFields,
      );
    }
    return updated;
  }

  MoneyAutoPostingTemplateEntity _mapAutoPostingTemplate(
    MoneyAutoPostingTemplate template,
  ) {
    return MoneyAutoPostingTemplateEntity(
      id: template.id,
      userId: template.userId,
      name: template.name,
      type: MoneyTransactionType.fromStorageValue(template.type),
      amountMinor: template.amountMinor,
      currencyCode: template.currencyCode,
      description: template.description,
      notes: template.notes,
      merchant: template.merchant,
      accountId: template.accountId,
      categoryId: template.categoryId,
      subCategoryId: template.subCategoryId,
      paymentMethod: MoneyPaymentMethod.fromStorageValue(
        template.paymentMethod,
      ),
      customPaymentMethodName: template.customPaymentMethodName,
      actualPayerAccount: template.actualPayerAccount,
      ledgerId: template.ledgerId,
      frequency: MoneyAutoPostingFrequency.fromStorageValue(template.frequency),
      dayOfMonth: template.dayOfMonth,
      weekday: template.weekday,
      timeOfDayMinutes: template.timeOfDayMinutes,
      startsOn: _dateOnlyUtc(template.startsOn),
      endsOn: _nullableDateOnlyUtc(template.endsOn),
      isActive: template.isActive,
      version: template.version,
      isDeleted: template.isDeleted,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    );
  }

  MoneyAutoPostingRunEntity _mapAutoPostingRun(MoneyAutoPostingRun run) {
    return MoneyAutoPostingRunEntity(
      id: run.id,
      userId: run.userId,
      templateId: run.templateId,
      occurrenceKey: run.occurrenceKey,
      status: MoneyAutoPostingRunStatus.fromStorageValue(run.status),
      transactionId: run.transactionId,
      scheduledFor: run.scheduledFor,
      postedAt: run.postedAt,
      templateVersion: run.templateVersion,
      errorCode: run.errorCode,
      errorMessage: run.errorMessage,
      createdAt: run.createdAt,
      updatedAt: run.updatedAt,
    );
  }

  Future<void> _recordAutoPostingRunChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }
    await logger.recordAutoPostingRunChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
    );
  }

  Future<void> _syncCreditAccountRepaymentReminder(
    String userId,
    MoneyAccount account,
  ) async {
    final sourceKey = _creditRepaymentReminderSourceKey(account.id);
    final existing =
        await (database.select(database.moneyBillReminders)
              ..where(
                (row) =>
                    row.userId.equals(userId) & row.sourceKey.equals(sourceKey),
              )
              ..limit(1))
            .getSingleOrNull();
    final accountType = MoneyAccountType.fromStorageValue(account.type);
    final repaymentDay = account.repaymentDay;
    final shouldEnable =
        accountType.isCreditLike &&
        account.autoRepaymentReminderEnabled &&
        account.isActive &&
        !account.isDeleted &&
        repaymentDay != null;

    if (!shouldEnable) {
      if (existing != null && !existing.isDeleted) {
        await _deleteAutoManagedBillReminder(userId, existing);
      }
      return;
    }

    final bill = await getCurrentCreditCardBillViewForAccount(
      userId,
      account.id,
    );
    if (bill == null ||
        bill.source != MoneyCreditCardBillViewSource.issuedStatement ||
        bill.amountDueMinor <= 0) {
      if (existing != null && !existing.isDeleted) {
        await _deleteAutoManagedBillReminder(userId, existing);
      }
      return;
    }

    final now = _utcNow();
    final amountMinor = bill.amountDueMinor;
    final currencyCode = bill.currencyCode;
    final fields = <String, Object?>{
      'name': '${account.name} 还款提醒',
      'amount_minor': amountMinor,
      'currency_code': currencyCode,
      'due_date': _dateKey(bill.repaymentDate),
      'remind_before_days': 1,
      'repeat_period_type':
          MoneyBillReminderRepeatPeriodType.monthly.storageValue,
      'repeat_interval': 1,
      'account_id': account.id,
      'ledger_id': null,
      'category_id': null,
      'related_transaction_id': null,
      'status': MoneyBillReminderStatus.pending.storageValue,
      'source_type': MoneyBillReminderSourceType.creditRepayment.storageValue,
      'source_key': sourceKey,
      'amount_source':
          MoneyBillReminderAmountSource.creditAccountDebt.storageValue,
      'auto_managed': true,
      'notes': null,
      'is_deleted': false,
      'deleted_at': null,
    };

    if (existing == null) {
      final reminderId = _uuid.v4();
      await database
          .into(database.moneyBillReminders)
          .insert(
            MoneyBillRemindersCompanion.insert(
              id: reminderId,
              userId: userId,
              name: fields['name']! as String,
              amountMinor: amountMinor,
              currencyCode: currencyCode,
              dueDate: fields['due_date']! as int,
              remindBeforeDays: fields['remind_before_days']! as int,
              repeatPeriodType: Value<String?>(
                fields['repeat_period_type'] as String?,
              ),
              repeatInterval: Value<int?>(fields['repeat_interval'] as int?),
              accountId: Value<String?>(account.id),
              ledgerId: const Value<String?>(null),
              categoryId: const Value<String?>(null),
              relatedTransactionId: const Value<String?>(null),
              status: MoneyBillReminderStatus.pending.storageValue,
              sourceType: Value(fields['source_type']! as String),
              sourceKey: Value<String?>(sourceKey),
              amountSource: Value(fields['amount_source']! as String),
              autoManaged: const Value(true),
              notes: const Value<String?>(null),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _recordBillReminderChange(
        userId: userId,
        recordId: reminderId,
        operation: SyncChangeOperation.insert,
        changedFields: fields,
        afterVersion: 1,
      );
      return;
    }

    final changedFields = <String, Object?>{};
    _putIfChanged(changedFields, 'name', existing.name, fields['name']);
    _putIfChanged(
      changedFields,
      'amount_minor',
      existing.amountMinor,
      amountMinor,
    );
    _putIfChanged(
      changedFields,
      'currency_code',
      existing.currencyCode,
      currencyCode,
    );
    _putIfChanged(
      changedFields,
      'due_date',
      existing.dueDate,
      fields['due_date'],
    );
    _putIfChanged(
      changedFields,
      'repeat_period_type',
      existing.repeatPeriodType,
      fields['repeat_period_type'],
    );
    _putIfChanged(
      changedFields,
      'repeat_interval',
      existing.repeatInterval,
      fields['repeat_interval'],
    );
    _putIfChanged(changedFields, 'account_id', existing.accountId, account.id);
    _putIfChanged(changedFields, 'ledger_id', existing.ledgerId, null);
    _putIfChanged(
      changedFields,
      'status',
      existing.status,
      MoneyBillReminderStatus.pending.storageValue,
    );
    _putIfChanged(
      changedFields,
      'source_type',
      existing.sourceType,
      fields['source_type'],
    );
    _putIfChanged(
      changedFields,
      'amount_source',
      existing.amountSource,
      fields['amount_source'],
    );
    _putIfChanged(changedFields, 'auto_managed', existing.autoManaged, true);
    if (existing.isDeleted) {
      changedFields.addAll(_restoreSyncFields());
    }

    if (changedFields.isEmpty) {
      return;
    }

    await (database.update(database.moneyBillReminders)..where(
          (row) => row.id.equals(existing.id) & row.userId.equals(userId),
        ))
        .write(
          MoneyBillRemindersCompanion(
            name: Value(fields['name']! as String),
            amountMinor: Value(amountMinor),
            currencyCode: Value(currencyCode),
            dueDate: Value(fields['due_date']! as int),
            remindBeforeDays: Value(fields['remind_before_days']! as int),
            repeatPeriodType: Value<String?>(
              fields['repeat_period_type'] as String?,
            ),
            repeatInterval: Value<int?>(fields['repeat_interval'] as int?),
            accountId: Value<String?>(account.id),
            ledgerId: const Value<String?>(null),
            categoryId: const Value<String?>(null),
            relatedTransactionId: const Value<String?>(null),
            status: Value(MoneyBillReminderStatus.pending.storageValue),
            sourceType: Value(fields['source_type']! as String),
            sourceKey: Value<String?>(sourceKey),
            amountSource: Value(fields['amount_source']! as String),
            autoManaged: const Value(true),
            notes: const Value<String?>(null),
            isDeleted: const Value(false),
            deletedAt: const Value<DateTime?>(null),
            version: Value(existing.version + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordBillReminderChange(
      userId: userId,
      recordId: existing.id,
      operation: SyncChangeOperation.update,
      changedFields: changedFields,
      beforeVersion: existing.version,
      afterVersion: existing.version + 1,
    );
  }

  Future<void> _syncCreditAccountRepaymentRemindersForAccounts(
    String userId,
    Iterable<String> accountIds,
  ) async {
    final uniqueAccountIds = accountIds.toSet();
    for (final accountId in uniqueAccountIds) {
      final account = await _getAccountForUser(userId, accountId);
      await _syncCreditAccountRepaymentReminder(userId, account);
    }
  }

  Future<void> _deleteAutoManagedBillReminder(
    String userId,
    MoneyBillReminder reminder,
  ) async {
    final now = _utcNow();
    await (database.update(database.moneyBillReminders)..where(
          (row) => row.id.equals(reminder.id) & row.userId.equals(userId),
        ))
        .write(
          MoneyBillRemindersCompanion(
            status: Value(MoneyBillReminderStatus.cancelled.storageValue),
            isDeleted: const Value(true),
            deletedAt: Value<DateTime?>(now),
            version: Value(reminder.version + 1),
            updatedAt: Value(now),
          ),
        );
    await _recordBillReminderChange(
      userId: userId,
      recordId: reminder.id,
      operation: SyncChangeOperation.delete,
      changedFields: {
        'status': MoneyBillReminderStatus.cancelled.storageValue,
        ..._deleteSyncFields(now),
      },
      beforeVersion: reminder.version,
      afterVersion: reminder.version + 1,
    );
  }

  Future<void> _refreshBudgetSnapshotsForTransactionImpacts(
    String userId,
    List<_BudgetTransactionImpact> impacts,
  ) async {
    if (impacts.isEmpty) {
      return;
    }

    final ledgerIds = impacts
        .expand((impact) => impact.ledgerIds)
        .toSet()
        .toList(growable: false);
    if (ledgerIds.isEmpty) {
      return;
    }

    final defaultLedgerId = _defaultLedgerId(userId);
    final budgets =
        await (database.select(database.moneyBudgets)..where((budget) {
              var predicate =
                  budget.userId.equals(userId) & budget.isDeleted.equals(false);
              Expression<bool>? ledgerPredicate;
              for (final ledgerId in ledgerIds) {
                final current = budget.ledgerId.equals(ledgerId);
                ledgerPredicate = ledgerPredicate == null
                    ? current
                    : ledgerPredicate | current;
                if (ledgerId == defaultLedgerId) {
                  ledgerPredicate = ledgerPredicate | budget.ledgerId.isNull();
                }
              }
              if (ledgerPredicate != null) {
                predicate = predicate & ledgerPredicate;
              }
              return predicate;
            }))
            .get();
    final matchedBudgetIds = <String>{};
    for (final budget in budgets) {
      if (_budgetMatchesAnyTransactionImpact(budget, impacts)) {
        matchedBudgetIds.add(budget.id);
      }
    }

    for (final budget in budgets) {
      if (matchedBudgetIds.contains(budget.id)) {
        await _refreshBudgetSnapshotForBudget(budget);
      }
    }
  }

  bool _budgetMatchesAnyTransactionImpact(
    MoneyBudget budget,
    List<_BudgetTransactionImpact> impacts,
  ) {
    for (final impact in impacts) {
      if (_budgetMatchesTransactionImpact(budget, impact)) {
        return true;
      }
    }
    return false;
  }

  bool _budgetMatchesTransactionImpact(
    MoneyBudget budget,
    _BudgetTransactionImpact impact,
  ) {
    if (impact.type == MoneyTransactionType.transfer) {
      return false;
    }

    final budgetType = MoneyBudgetTrackingType.fromStorageValue(
      budget.trackingType,
    );
    if (budgetType == MoneyBudgetTrackingType.expenseLimit &&
        impact.type != MoneyTransactionType.expense) {
      return false;
    }
    if (budgetType == MoneyBudgetTrackingType.incomeTarget &&
        impact.type != MoneyTransactionType.income) {
      return false;
    }

    final budgetLedgerId = budget.ledgerId ?? _defaultLedgerId(budget.userId);
    if (!impact.ledgerIds.contains(budgetLedgerId)) {
      return false;
    }

    final scope = _readBudgetScope(budget);
    if (scope.accountId != null && scope.accountId != impact.accountId) {
      return false;
    }
    if (scope.categoryId != null && scope.categoryId != impact.categoryId) {
      return false;
    }
    if (scope.subCategoryId != null &&
        scope.subCategoryId != impact.subCategoryId) {
      return false;
    }
    return true;
  }

  Future<MoneyBudgetSnapshot> _refreshBudgetSnapshotForBudget(
    MoneyBudget budget,
  ) async {
    final periodType = MoneyBudgetPeriodType.fromStorageValue(
      budget.repeatPeriodType,
    );
    final period = await _budgetPeriodForBudget(budget, periodType);
    final usedAmountMinor = await _budgetUsedAmountMinor(budget);
    final remainingAmountMinor = budget.amountMinor - usedAmountMinor;
    final now = _utcNow();
    final periodStartDate = _dateKey(period.start);
    final periodEndDate = _dateKey(period.end);
    final currentSnapshot =
        await (database.select(database.moneyBudgetSnapshots)
              ..where(
                (snapshot) =>
                    snapshot.budgetId.equals(budget.id) &
                    snapshot.periodStartDate.equals(periodStartDate) &
                    snapshot.periodEndDate.equals(periodEndDate) &
                    snapshot.sourceBudgetVersion.equals(budget.version),
              )
              ..limit(1))
            .getSingleOrNull();

    await _closeOpenBudgetSnapshotsForBudget(
      budget.userId,
      budget.id,
      keepSnapshotId: currentSnapshot?.id,
      activePeriodStartDate: periodStartDate,
      activePeriodEndDate: periodEndDate,
    );

    if (currentSnapshot == null) {
      final snapshotId = _budgetSnapshotId(
        budgetId: budget.id,
        periodStartDate: periodStartDate,
        periodEndDate: periodEndDate,
        sourceBudgetVersion: budget.version,
      );
      await database
          .into(database.moneyBudgetSnapshots)
          .insert(
            MoneyBudgetSnapshotsCompanion.insert(
              id: snapshotId,
              userId: budget.userId,
              budgetId: budget.id,
              ledgerId: Value<String?>(budget.ledgerId),
              trackingType: budget.trackingType,
              periodType: budget.repeatPeriodType,
              repeatInterval: budget.repeatInterval,
              periodStartDate: periodStartDate,
              periodEndDate: periodEndDate,
              budgetAmountMinor: budget.amountMinor,
              usedAmountMinor: usedAmountMinor,
              remainingAmountMinor: remainingAmountMinor,
              currencyCode: budget.currencyCode,
              status: MoneyBudgetHistoryStatus.open.storageValue,
              capturedAt: now,
              sourceBudgetVersion: budget.version,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final snapshot = await (database.select(
        database.moneyBudgetSnapshots,
      )..where((row) => row.id.equals(snapshotId))).getSingle();
      await _recordBudgetSnapshotChange(
        userId: budget.userId,
        recordId: snapshotId,
        operation: SyncChangeOperation.insert,
        changedFields: _budgetSnapshotSyncFields(snapshot),
        afterVersion: budget.version,
      );
      await _refreshBudgetAllocationSnapshotsForBudgetSnapshot(
        budget,
        snapshot,
      );
      return snapshot;
    }

    final shouldUpdate =
        currentSnapshot.userId != budget.userId ||
        currentSnapshot.budgetId != budget.id ||
        currentSnapshot.ledgerId != budget.ledgerId ||
        currentSnapshot.trackingType != budget.trackingType ||
        currentSnapshot.periodType != budget.repeatPeriodType ||
        currentSnapshot.repeatInterval != budget.repeatInterval ||
        currentSnapshot.periodStartDate != periodStartDate ||
        currentSnapshot.periodEndDate != periodEndDate ||
        currentSnapshot.budgetAmountMinor != budget.amountMinor ||
        currentSnapshot.usedAmountMinor != usedAmountMinor ||
        currentSnapshot.remainingAmountMinor != remainingAmountMinor ||
        currentSnapshot.currencyCode != budget.currencyCode ||
        currentSnapshot.status != MoneyBudgetHistoryStatus.open.storageValue ||
        currentSnapshot.sourceBudgetVersion != budget.version;
    if (!shouldUpdate) {
      await _refreshBudgetAllocationSnapshotsForBudgetSnapshot(
        budget,
        currentSnapshot,
      );
      return currentSnapshot;
    }

    await (database.update(
      database.moneyBudgetSnapshots,
    )..where((snapshot) => snapshot.id.equals(currentSnapshot.id))).write(
      MoneyBudgetSnapshotsCompanion(
        userId: Value(budget.userId),
        budgetId: Value(budget.id),
        ledgerId: Value<String?>(budget.ledgerId),
        trackingType: Value(budget.trackingType),
        periodType: Value(budget.repeatPeriodType),
        repeatInterval: Value(budget.repeatInterval),
        periodStartDate: Value(periodStartDate),
        periodEndDate: Value(periodEndDate),
        budgetAmountMinor: Value(budget.amountMinor),
        usedAmountMinor: Value(usedAmountMinor),
        remainingAmountMinor: Value(remainingAmountMinor),
        currencyCode: Value(budget.currencyCode),
        status: Value(MoneyBudgetHistoryStatus.open.storageValue),
        capturedAt: Value(now),
        sourceBudgetVersion: Value(budget.version),
        updatedAt: Value(now),
      ),
    );
    final snapshot = await (database.select(
      database.moneyBudgetSnapshots,
    )..where((row) => row.id.equals(currentSnapshot.id))).getSingle();
    await _recordBudgetSnapshotChange(
      userId: budget.userId,
      recordId: currentSnapshot.id,
      operation: SyncChangeOperation.update,
      changedFields: _budgetSnapshotSyncFields(snapshot),
      beforeVersion: currentSnapshot.sourceBudgetVersion,
      afterVersion: budget.version,
    );
    await _refreshBudgetAllocationSnapshotsForBudgetSnapshot(budget, snapshot);
    return snapshot;
  }

  Future<void> _refreshBudgetAllocationSnapshotsForBudgetSnapshot(
    MoneyBudget budget,
    MoneyBudgetSnapshot budgetSnapshot,
  ) async {
    final allocations = await _budgetAllocationsForUserWithUsage(
      budget.userId,
      budget.id,
    );

    for (final allocation in allocations) {
      await _upsertBudgetAllocationSnapshot(
        budget: budget,
        budgetSnapshot: budgetSnapshot,
        allocation: allocation,
        status: allocation.status,
        sourceAllocationVersion: allocation.version,
      );
    }
  }

  Future<void> _upsertBudgetAllocationSnapshot({
    required MoneyBudget budget,
    required MoneyBudgetSnapshot budgetSnapshot,
    required MoneyBudgetAllocationEntity allocation,
    required MoneyBudgetAllocationStatus status,
    required int sourceAllocationVersion,
  }) async {
    final now = _utcNow();
    final snapshotId = _budgetAllocationSnapshotId(
      budgetSnapshotId: budgetSnapshot.id,
      allocationId: allocation.id,
      sourceAllocationVersion: sourceAllocationVersion,
    );
    final existing =
        await (database.select(database.moneyBudgetAllocationSnapshots)
              ..where((row) => row.id.equals(snapshotId))
              ..limit(1))
            .getSingleOrNull();

    if (existing == null) {
      await database
          .into(database.moneyBudgetAllocationSnapshots)
          .insert(
            MoneyBudgetAllocationSnapshotsCompanion.insert(
              id: snapshotId,
              userId: allocation.userId,
              budgetSnapshotId: budgetSnapshot.id,
              budgetId: allocation.budgetId,
              allocationId: allocation.id,
              categoryId: Value<String?>(allocation.categoryId),
              memberId: Value<String?>(allocation.memberId),
              allocatedAmountMinor: allocation.allocatedAmountMinor,
              usedAmountMinor: allocation.usedAmountMinor,
              remainingAmountMinor: allocation.remainingAmountMinor,
              currencyCode: budget.currencyCode,
              status: status.storageValue,
              capturedAt: budgetSnapshot.capturedAt,
              sourceAllocationVersion: sourceAllocationVersion,
              createdAt: now,
              updatedAt: now,
            ),
          );
      final snapshot = await (database.select(
        database.moneyBudgetAllocationSnapshots,
      )..where((row) => row.id.equals(snapshotId))).getSingle();
      await _recordBudgetAllocationSnapshotChange(
        userId: allocation.userId,
        recordId: snapshotId,
        operation: SyncChangeOperation.insert,
        changedFields: _budgetAllocationSnapshotSyncFields(snapshot),
        afterVersion: sourceAllocationVersion,
      );
      return;
    }

    final shouldUpdate =
        existing.categoryId != allocation.categoryId ||
        existing.memberId != allocation.memberId ||
        existing.allocatedAmountMinor != allocation.allocatedAmountMinor ||
        existing.usedAmountMinor != allocation.usedAmountMinor ||
        existing.remainingAmountMinor != allocation.remainingAmountMinor ||
        existing.currencyCode != budget.currencyCode ||
        existing.status != status.storageValue ||
        existing.capturedAt != budgetSnapshot.capturedAt;
    if (!shouldUpdate) {
      return;
    }

    await (database.update(
      database.moneyBudgetAllocationSnapshots,
    )..where((row) => row.id.equals(snapshotId))).write(
      MoneyBudgetAllocationSnapshotsCompanion(
        categoryId: Value<String?>(allocation.categoryId),
        memberId: Value<String?>(allocation.memberId),
        allocatedAmountMinor: Value(allocation.allocatedAmountMinor),
        usedAmountMinor: Value(allocation.usedAmountMinor),
        remainingAmountMinor: Value(allocation.remainingAmountMinor),
        currencyCode: Value(budget.currencyCode),
        status: Value(status.storageValue),
        capturedAt: Value(budgetSnapshot.capturedAt),
        updatedAt: Value(now),
      ),
    );
    final snapshot = await (database.select(
      database.moneyBudgetAllocationSnapshots,
    )..where((row) => row.id.equals(snapshotId))).getSingle();
    await _recordBudgetAllocationSnapshotChange(
      userId: allocation.userId,
      recordId: snapshotId,
      operation: SyncChangeOperation.update,
      changedFields: _budgetAllocationSnapshotSyncFields(snapshot),
      beforeVersion: existing.sourceAllocationVersion,
      afterVersion: sourceAllocationVersion,
    );
  }

  Future<void> _closeOpenBudgetSnapshotsForBudget(
    String userId,
    String budgetId, {
    String? keepSnapshotId,
    int? activePeriodStartDate,
    int? activePeriodEndDate,
  }) async {
    final now = _utcNow();
    final openSnapshots =
        await (database.select(database.moneyBudgetSnapshots)..where(
              (snapshot) =>
                  snapshot.userId.equals(userId) &
                  snapshot.budgetId.equals(budgetId) &
                  snapshot.status.equals(
                    MoneyBudgetHistoryStatus.open.storageValue,
                  ),
            ))
            .get();

    for (final snapshot in openSnapshots) {
      if (keepSnapshotId != null && snapshot.id == keepSnapshotId) {
        continue;
      }

      final isCurrentPeriod =
          activePeriodStartDate != null &&
          activePeriodEndDate != null &&
          snapshot.periodStartDate == activePeriodStartDate &&
          snapshot.periodEndDate == activePeriodEndDate;
      final status =
          activePeriodStartDate == null || activePeriodEndDate == null
          ? MoneyBudgetHistoryStatus.closed
          : isCurrentPeriod
          ? MoneyBudgetHistoryStatus.closed
          : MoneyBudgetHistoryStatus.rolledOver;

      await (database.update(
        database.moneyBudgetSnapshots,
      )..where((row) => row.id.equals(snapshot.id))).write(
        MoneyBudgetSnapshotsCompanion(
          status: Value(status.storageValue),
          updatedAt: Value(now),
        ),
      );
      await _recordBudgetSnapshotChange(
        userId: userId,
        recordId: snapshot.id,
        operation: SyncChangeOperation.update,
        changedFields: _budgetSnapshotStatusSyncFields(
          status: status,
          updatedAt: now,
        ),
        beforeVersion: snapshot.sourceBudgetVersion,
        afterVersion: snapshot.sourceBudgetVersion,
      );
    }
  }

  void _validateBillReminderDraft(MoneyBillReminderDraft draft) {
    if (draft.name.trim().isEmpty ||
        draft.amountMinor <= 0 ||
        draft.remindBeforeDays < 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
  }

  void _validateBillReminderUpdate(MoneyBillReminderUpdate update) {
    if (update.name.trim().isEmpty ||
        update.amountMinor <= 0 ||
        update.remindBeforeDays < 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }
  }

  void _validateInstallmentDraft(MoneyInstallmentPlanDraft draft) {
    if (draft.name.trim().isEmpty ||
        draft.categoryId.trim().isEmpty ||
        draft.totalPrincipalMinor <= 0 ||
        draft.totalInterestMinor < 0 ||
        draft.totalPeriods <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidInstallmentAmount,
      );
    }
  }

  String _budgetScopeJson({
    required String? categoryId,
    required String? subCategoryId,
  }) {
    if (categoryId == null) {
      return jsonEncode(<String, String?>{});
    }
    return jsonEncode(<String, String?>{
      'categoryId': categoryId,
      'subCategoryId': subCategoryId,
    });
  }

  _BudgetScope _readBudgetScope(MoneyBudget budget) {
    final rawJson = budget.categoryScopeJson;
    String? categoryId;
    String? subCategoryId;
    if (rawJson != null && rawJson.trim().isNotEmpty) {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseReadFailed,
        );
      }
      final rawCategoryId = decoded['categoryId'];
      final rawSubCategoryId = decoded['subCategoryId'];
      categoryId = rawCategoryId is String && rawCategoryId.trim().isNotEmpty
          ? rawCategoryId
          : null;
      subCategoryId =
          rawSubCategoryId is String && rawSubCategoryId.trim().isNotEmpty
          ? rawSubCategoryId
          : null;
    }

    return _BudgetScope(
      categoryId: categoryId,
      subCategoryId: categoryId == null ? null : subCategoryId,
      accountId: budget.accountId,
    );
  }

  String _budgetScopeType({
    required MoneyBudgetScopeType? scopeType,
    required String? categoryId,
    required String? accountId,
  }) {
    final effectiveScopeType =
        scopeType ??
        _inferBudgetScopeType(categoryId: categoryId, accountId: accountId);
    return effectiveScopeType.storageValue;
  }

  MoneyBudgetScopeType _inferBudgetScopeType({
    required String? categoryId,
    required String? accountId,
  }) {
    if (categoryId != null && accountId != null) {
      return MoneyBudgetScopeType.categoryAccount;
    }
    if (accountId != null) {
      return MoneyBudgetScopeType.account;
    }
    if (categoryId != null) {
      return MoneyBudgetScopeType.category;
    }
    return MoneyBudgetScopeType.all;
  }

  Expression<bool> _installmentLedgerPredicate(
    $MoneyInstallmentPlansTable table,
    String ledgerId,
    String userId,
  ) {
    final currentLedgerPredicate = table.ledgerId.equals(ledgerId);
    if (ledgerId == _defaultLedgerId(userId)) {
      return currentLedgerPredicate | table.ledgerId.isNull();
    }
    return currentLedgerPredicate;
  }

  DateTime _currentMonthStart() {
    final now = _now();
    return DateTime(now.year, now.month);
  }

  DateTime _nextMonthStart(DateTime monthStart) {
    return DateTime(monthStart.year, monthStart.month + 1);
  }

  DateTime _previousMonthStart(DateTime monthStart) {
    return DateTime(monthStart.year, monthStart.month - 1);
  }

  ({DateTime start, DateTime end}) _currentBudgetPeriod(
    MoneyBudgetPeriodType periodType,
  ) {
    final now = _now();
    return switch (periodType) {
      MoneyBudgetPeriodType.daily => () {
        final start = DateTime(now.year, now.month, now.day);
        return (start: start, end: start.add(const Duration(days: 1)));
      }(),
      MoneyBudgetPeriodType.weekly => () {
        final today = DateTime(now.year, now.month, now.day);
        final start = today.subtract(Duration(days: today.weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      }(),
      MoneyBudgetPeriodType.monthly => () {
        final start = DateTime(now.year, now.month);
        return (start: start, end: DateTime(start.year, start.month + 1));
      }(),
      MoneyBudgetPeriodType.billingCycle => () {
        final start = DateTime(now.year, now.month);
        return (start: start, end: DateTime(start.year, start.month + 1));
      }(),
      MoneyBudgetPeriodType.yearly => () {
        final start = DateTime(now.year);
        return (start: start, end: DateTime(start.year + 1));
      }(),
    };
  }

  Future<({DateTime start, DateTime end})> _budgetPeriodForAccount({
    required String userId,
    required MoneyBudgetPeriodType periodType,
    required String? accountId,
  }) async {
    if (periodType != MoneyBudgetPeriodType.billingCycle) {
      return _currentBudgetPeriod(periodType);
    }
    if (accountId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
      );
    }
    final account = await _getAccountForUser(userId, accountId);
    return _currentBillingCyclePeriod(account);
  }

  Future<({DateTime start, DateTime end})> _budgetPeriodForBudget(
    MoneyBudget budget,
    MoneyBudgetPeriodType periodType,
  ) async {
    if (periodType != MoneyBudgetPeriodType.billingCycle) {
      return _currentBudgetPeriod(periodType);
    }
    final accountId = _readBudgetScope(budget).accountId;
    if (accountId == null) {
      return _currentBudgetPeriod(MoneyBudgetPeriodType.monthly);
    }
    final account = await _getAccountForUser(budget.userId, accountId);
    return _currentBillingCyclePeriod(account);
  }

  ({DateTime start, DateTime end}) _currentBillingCyclePeriod(
    MoneyAccount account,
  ) {
    final type = MoneyAccountType.fromStorageValue(account.type);
    final statementDay = account.statementDay;
    final cycleStartDay = account.budgetCycleStartDay ?? statementDay;
    if (!type.isCreditLike || statementDay == null || cycleStartDay == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
      );
    }

    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    var start = _dayInMonth(now.year, now.month, cycleStartDay);
    if (today.isBefore(start)) {
      start = _dayInMonth(now.year, now.month - 1, cycleStartDay);
    }
    final end = _dayInMonth(start.year, start.month + 1, cycleStartDay);
    return (start: start, end: end);
  }

  ({DateTime start, DateTime end}) _billingCyclePeriodFor(
    MoneyAccount account,
    DateTime asOf,
  ) {
    final type = MoneyAccountType.fromStorageValue(account.type);
    final statementDay = account.statementDay;
    final cycleStartDay = account.budgetCycleStartDay ?? statementDay;
    if (!type.isCreditLike || statementDay == null || cycleStartDay == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.unsupportedBudgetPeriod,
      );
    }

    final today = DateTime(asOf.year, asOf.month, asOf.day);
    var start = _dayInMonth(today.year, today.month, cycleStartDay);
    if (today.isBefore(start)) {
      start = _dayInMonth(today.year, today.month - 1, cycleStartDay);
    }
    final end = _dayInMonth(start.year, start.month + 1, cycleStartDay);
    return (start: start, end: end);
  }

  ({DateTime start, DateTime end})? _latestIssuedBillingCyclePeriod(
    ({DateTime start, DateTime end}) currentPeriod,
    DateTime today,
    int cycleStartDay,
  ) {
    for (final period in _recentIssuedBillingCyclePeriods(
      currentPeriod,
      today,
      cycleStartDay,
    )) {
      return period;
    }
    return null;
  }

  Iterable<({DateTime start, DateTime end})> _recentIssuedBillingCyclePeriods(
    ({DateTime start, DateTime end}) currentPeriod,
    DateTime today,
    int cycleStartDay,
  ) sync* {
    var end = currentPeriod.start;
    for (var index = 0; index < 6; index += 1) {
      if (end.isAfter(today)) {
        break;
      }
      final start = _dayInMonth(end.year, end.month - 1, cycleStartDay);
      yield (start: start, end: end);
      end = start;
    }
  }

  int _unbilledAmountDueMinor({
    required int postedDebtMinor,
    required int purchaseAmountMinor,
  }) {
    if (postedDebtMinor <= 0 || purchaseAmountMinor <= 0) {
      return 0;
    }
    return postedDebtMinor < purchaseAmountMinor
        ? postedDebtMinor
        : purchaseAmountMinor;
  }

  int _statementAmountDueMinor({
    required int postedDebtMinor,
    required int purchaseAmountMinor,
    required int repaymentAmountMinor,
  }) {
    final dueAfterRepayments = purchaseAmountMinor - repaymentAmountMinor;
    if (postedDebtMinor <= 0 || dueAfterRepayments <= 0) {
      return 0;
    }
    return postedDebtMinor < dueAfterRepayments
        ? postedDebtMinor
        : dueAfterRepayments;
  }

  DateTime _repaymentDateForStatementPeriod({
    required DateTime periodEndExclusive,
    required int repaymentDay,
  }) {
    var dueDate = _dayInMonth(
      periodEndExclusive.year,
      periodEndExclusive.month,
      repaymentDay,
    );
    if (dueDate.isBefore(periodEndExclusive)) {
      dueDate = _dayInMonth(
        periodEndExclusive.year,
        periodEndExclusive.month + 1,
        repaymentDay,
      );
    }
    return dueDate;
  }

  MoneyCreditCardStatementState _creditCardStatementState({
    required int amountDueMinor,
    required DateTime periodEndExclusive,
    required DateTime repaymentDate,
    required DateTime today,
  }) {
    if (amountDueMinor <= 0) {
      return MoneyCreditCardStatementState.settled;
    }
    if (periodEndExclusive.isAfter(today)) {
      return MoneyCreditCardStatementState.open;
    }
    if (repaymentDate.isBefore(today)) {
      return MoneyCreditCardStatementState.overdue;
    }
    if (!repaymentDate.isAfter(today.add(const Duration(days: 3)))) {
      return MoneyCreditCardStatementState.dueSoon;
    }
    return MoneyCreditCardStatementState.pending;
  }

  DateTime _dayInMonth(int year, int month, int day) {
    final monthStart = DateTime(year, month);
    final lastDay = DateTime(monthStart.year, monthStart.month + 1, 0).day;
    return DateTime(
      monthStart.year,
      monthStart.month,
      day > lastDay ? lastDay : day,
    );
  }

  int _dateKey(DateTime date) {
    return date.year * 10000 + date.month * 100 + date.day;
  }

  String _budgetSnapshotId({
    required String budgetId,
    required int periodStartDate,
    required int periodEndDate,
    required int sourceBudgetVersion,
  }) {
    return '$budgetId::$periodStartDate::$periodEndDate::$sourceBudgetVersion';
  }

  String _budgetAllocationSnapshotId({
    required String budgetSnapshotId,
    required String allocationId,
    required int sourceAllocationVersion,
  }) {
    return '$budgetSnapshotId::$allocationId::$sourceAllocationVersion';
  }

  DateTime _dateFromKey(int key) {
    final year = key ~/ 10000;
    final month = (key ~/ 100) % 100;
    final day = key % 100;
    return DateTime(year, month, day);
  }

  DateTime _dateOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _dominantCurrencyCode(List<MoneyTransaction> transactions) {
    if (transactions.isEmpty) {
      return 'CNY';
    }

    final amountByCurrency = <String, int>{};
    for (final transaction in transactions) {
      amountByCurrency[transaction.currencyCode] =
          (amountByCurrency[transaction.currencyCode] ?? 0) +
          _effectiveTransactionAmountMinor(transaction);
    }

    var selected = transactions.first.currencyCode;
    var selectedAmount = amountByCurrency[selected] ?? 0;
    for (final entry in amountByCurrency.entries) {
      if (entry.value > selectedAmount) {
        selected = entry.key;
        selectedAmount = entry.value;
      }
    }
    return selected;
  }

  int _sumByType(
    List<MoneyTransaction> transactions,
    MoneyTransactionType type,
  ) {
    var total = 0;
    for (final transaction in transactions) {
      if (transaction.type == type.storageValue) {
        total += _effectiveTransactionAmountMinor(transaction);
      }
    }
    return total;
  }

  int _countByType(
    List<MoneyTransaction> transactions,
    MoneyTransactionType type,
  ) {
    var total = 0;
    for (final transaction in transactions) {
      if (transaction.type == type.storageValue) {
        total += 1;
      }
    }
    return total;
  }

  MoneyStatisticsComparisonSummary _buildComparisonSummary(
    List<MoneyTransaction> transactions,
  ) {
    return MoneyStatisticsComparisonSummary(
      incomeMinor: _sumByType(transactions, MoneyTransactionType.income),
      expenseMinor: _sumByType(transactions, MoneyTransactionType.expense),
      incomeTransactionCount: _countByType(
        transactions,
        MoneyTransactionType.income,
      ),
      expenseTransactionCount: _countByType(
        transactions,
        MoneyTransactionType.expense,
      ),
    );
  }

  MoneyStatisticsQuery _shiftStatisticsQuery(
    MoneyStatisticsQuery query, {
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return MoneyStatisticsQuery(
      dateStart: start,
      dateEndExclusive: endExclusive,
      groupBy: query.groupBy,
      ledgerId: query.ledgerId,
      accountId: query.accountId,
      accountType: query.accountType,
      paymentMethod: query.paymentMethod,
      typeFocus: query.typeFocus,
    );
  }

  DateTime _previousStatisticsStart(MoneyStatisticsQuery query) {
    final monthSpan =
        (query.dateEndExclusive.year - query.dateStart.year) * 12 +
        (query.dateEndExclusive.month - query.dateStart.month);
    if (monthSpan > 0) {
      return DateTime(
        query.dateStart.year,
        query.dateStart.month - monthSpan,
        query.dateStart.day,
      );
    }
    final duration = query.dateEndExclusive.difference(query.dateStart);
    return query.dateStart.subtract(duration);
  }

  Future<List<MoneyStatisticsAccountPaymentMethodSlice>>
  _buildAccountPaymentMethodSlices(
    List<MoneyTransaction> transactions,
    MoneyStatisticsQuery query,
  ) async {
    final rows = transactions.where((row) {
      return switch (query.typeFocus) {
        MoneyStatisticsTypeFocus.income =>
          row.type == MoneyTransactionType.income.storageValue,
        MoneyStatisticsTypeFocus.expense =>
          row.type == MoneyTransactionType.expense.storageValue,
        MoneyStatisticsTypeFocus.balance => true,
      };
    }).toList();
    if (rows.isEmpty) {
      return const <MoneyStatisticsAccountPaymentMethodSlice>[];
    }

    final buckets = <String, _MutableStatisticsAccountPaymentMethod>{};
    for (final row in rows) {
      final method = MoneyPaymentMethod.fromStorageValue(row.paymentMethod);
      final label = _statisticsPaymentMethodLabel(row, method);
      final key = '${row.accountId}|${method.storageValue}|$label';
      final bucket = buckets.putIfAbsent(
        key,
        () => _MutableStatisticsAccountPaymentMethod(
          accountId: row.accountId,
          method: method,
          label: label,
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
      (sum, bucket) =>
          sum + _statisticsAccountPaymentAmount(bucket, query.typeFocus),
    );
    if (total <= 0) {
      return const <MoneyStatisticsAccountPaymentMethodSlice>[];
    }

    final accountIds = buckets.values.map((bucket) => bucket.accountId).toSet();
    final accounts = await (database.select(
      database.moneyAccounts,
    )..where((account) => account.id.isIn(accountIds.toList()))).get();
    final accountNameById = {
      for (final account in accounts) account.id: account.name,
    };

    final slices = [
      for (final bucket in buckets.values)
        MoneyStatisticsAccountPaymentMethodSlice(
          accountId: bucket.accountId,
          accountName: accountNameById[bucket.accountId] ?? '账户已不可用',
          paymentMethod: bucket.method,
          paymentMethodLabel: bucket.label,
          amountMinor: _statisticsAccountPaymentAmount(bucket, query.typeFocus),
          incomeMinor: bucket.incomeMinor,
          expenseMinor: bucket.expenseMinor,
          transactionCount: bucket.transactionCount,
          percentage:
              _statisticsAccountPaymentAmount(bucket, query.typeFocus) / total,
        ),
    ]..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));
    return slices.take(10).toList();
  }

  String _statisticsPaymentMethodLabel(
    MoneyTransaction row,
    MoneyPaymentMethod method,
  ) {
    final customName = _blankToNull(row.customPaymentMethodName);
    if (customName == null) {
      return method.label;
    }
    return customName;
  }

  int _statisticsPaymentAmount(
    _MutableStatisticsPaymentMethod bucket,
    MoneyStatisticsTypeFocus focus,
  ) {
    return switch (focus) {
      MoneyStatisticsTypeFocus.income => bucket.incomeMinor,
      MoneyStatisticsTypeFocus.expense => bucket.expenseMinor,
      MoneyStatisticsTypeFocus.balance =>
        bucket.incomeMinor + bucket.expenseMinor,
    };
  }

  int _statisticsAccountPaymentAmount(
    _MutableStatisticsAccountPaymentMethod bucket,
    MoneyStatisticsTypeFocus focus,
  ) {
    return switch (focus) {
      MoneyStatisticsTypeFocus.income => bucket.incomeMinor,
      MoneyStatisticsTypeFocus.expense => bucket.expenseMinor,
      MoneyStatisticsTypeFocus.balance =>
        bucket.incomeMinor + bucket.expenseMinor,
    };
  }

  DateTime _addMonths(DateTime date, int months) {
    final targetMonthIndex = date.month + months - 1;
    final year = date.year + targetMonthIndex ~/ 12;
    final month = targetMonthIndex % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  Future<int> _budgetUsedAmountMinor(MoneyBudget budget) async {
    if (budget.budgetType == _budgetTypeLegacySnapshot) {
      return budget.currentPeriodUsedMinor != 0
          ? budget.currentPeriodUsedMinor
          : budget.usedAmountMinor;
    }

    final scope = _readBudgetScope(budget);
    final trackingType = MoneyBudgetTrackingType.fromStorageValue(
      budget.trackingType,
    );
    final periodType = MoneyBudgetPeriodType.fromStorageValue(
      budget.repeatPeriodType,
    );
    final period = await _budgetPeriodForBudget(budget, periodType);
    final transactionType = trackingType == MoneyBudgetTrackingType.incomeTarget
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    final ledgerId = budget.ledgerId ?? _defaultLedgerId(budget.userId);
    final transactionIds = await _transactionIdsForLedger(
      budget.userId,
      ledgerId,
    );
    var predicate =
        database.moneyTransactions.userId.equals(budget.userId) &
        database.moneyTransactions.isDeleted.equals(false) &
        database.moneyTransactions.status.equals(
          MoneyTransactionStatus.completed.storageValue,
        ) &
        database.moneyTransactions.actualPayerAccount.isNotIn([
          _transferInMarker,
        ]) &
        (transactionIds.isEmpty
            ? database.moneyTransactions.id.equals('__no_budget_ledger_tx__')
            : database.moneyTransactions.id.isIn(transactionIds)) &
        database.moneyTransactions.type.equals(transactionType.storageValue) &
        database.moneyTransactions.categoryId.isNotIn(_transferCategoryIds) &
        database.moneyTransactions.transactionAt.isBiggerOrEqualValue(
          period.start.toUtc(),
        ) &
        database.moneyTransactions.transactionAt.isSmallerOrEqualValue(
          period.end.toUtc().subtract(const Duration(milliseconds: 1)),
        );

    final accountId = scope.accountId;
    if (accountId != null) {
      predicate =
          predicate & database.moneyTransactions.accountId.equals(accountId);
    }

    final categoryId = scope.categoryId;
    if (categoryId != null) {
      predicate =
          predicate & database.moneyTransactions.categoryId.equals(categoryId);
    }

    final subCategoryId = scope.subCategoryId;
    if (subCategoryId != null) {
      predicate =
          predicate &
          database.moneyTransactions.subCategoryId.equals(subCategoryId);
    }

    final rows = await (database.select(
      database.moneyTransactions,
    )..where((_) => predicate)).get();
    return rows.fold<int>(
      0,
      (total, transaction) =>
          total + _effectiveTransactionAmountMinor(transaction),
    );
  }

  Future<List<MoneyBudgetAllocationEntity>> _budgetAllocationsForUserWithUsage(
    String userId,
    String budgetId,
  ) async {
    final budget = await _getBudgetForUser(userId, budgetId);
    final rows =
        await (database.select(database.moneyBudgetAllocations)
              ..where(
                (allocation) =>
                    allocation.userId.equals(userId) &
                    allocation.budgetId.equals(budgetId) &
                    allocation.isDeleted.equals(false),
              )
              ..orderBy([
                (allocation) => OrderingTerm.asc(allocation.priority),
                (allocation) => OrderingTerm.desc(allocation.updatedAt),
              ]))
            .get();
    final allocations = <MoneyBudgetAllocationEntity>[];
    for (final row in rows) {
      allocations.add(await _mapBudgetAllocationWithUsage(budget, row));
    }
    return allocations;
  }

  Future<int> _budgetAllocationUsedAmountMinor(
    MoneyBudget budget,
    MoneyBudgetAllocation allocation,
  ) async {
    if (budget.budgetType == _budgetTypeLegacySnapshot) {
      return allocation.usedAmountMinor;
    }

    final transactions = await _budgetAllocationTransactions(
      budget,
      categoryId: allocation.categoryId,
    );
    if (transactions.isEmpty) {
      return 0;
    }

    final memberId = allocation.memberId;
    if (memberId != null) {
      return _budgetAllocationMemberSplitAmountMinor(
        userId: budget.userId,
        transactionIds: transactions
            .map((transaction) => transaction.id)
            .toList(),
        memberId: memberId,
      );
    }

    return transactions.fold<int>(
      0,
      (total, transaction) =>
          total + _effectiveTransactionAmountMinor(transaction),
    );
  }

  Future<int> _budgetAllocationMemberSplitAmountMinor({
    required String userId,
    required List<String> transactionIds,
    required String memberId,
  }) async {
    final splitRecords =
        await (database.select(database.moneySplitRecords)..where(
              (record) =>
                  record.userId.equals(userId) &
                  record.transactionId.isIn(transactionIds) &
                  record.status.equals(
                    MoneySplitRecordStatus.active.storageValue,
                  ) &
                  record.isDeleted.equals(false),
            ))
            .get();
    final splitRecordIds = splitRecords.map((record) => record.id).toList();
    if (splitRecordIds.isEmpty) {
      return 0;
    }

    final amount = database.moneySplitRecordDetails.amountMinor.sum();
    final query = database.selectOnly(database.moneySplitRecordDetails)
      ..addColumns([amount])
      ..where(
        database.moneySplitRecordDetails.userId.equals(userId) &
            database.moneySplitRecordDetails.splitRecordId.isIn(
              splitRecordIds,
            ) &
            database.moneySplitRecordDetails.memberId.equals(memberId) &
            database.moneySplitRecordDetails.isDeleted.equals(false),
      );
    return (await query.getSingle()).read(amount) ?? 0;
  }

  Future<List<MoneyTransaction>> _budgetAllocationTransactions(
    MoneyBudget budget, {
    required String? categoryId,
  }) async {
    final scope = _readBudgetScope(budget);
    final trackingType = MoneyBudgetTrackingType.fromStorageValue(
      budget.trackingType,
    );
    final periodType = MoneyBudgetPeriodType.fromStorageValue(
      budget.repeatPeriodType,
    );
    final period = await _budgetPeriodForBudget(budget, periodType);
    final transactionType = trackingType == MoneyBudgetTrackingType.incomeTarget
        ? MoneyTransactionType.income
        : MoneyTransactionType.expense;
    final ledgerId = budget.ledgerId ?? _defaultLedgerId(budget.userId);
    final transactionIds = await _transactionIdsForLedger(
      budget.userId,
      ledgerId,
    );
    if (transactionIds.isEmpty) {
      return const <MoneyTransaction>[];
    }

    var predicate =
        database.moneyTransactions.userId.equals(budget.userId) &
        database.moneyTransactions.isDeleted.equals(false) &
        database.moneyTransactions.status.equals(
          MoneyTransactionStatus.completed.storageValue,
        ) &
        database.moneyTransactions.actualPayerAccount.isNotIn([
          _transferInMarker,
        ]) &
        database.moneyTransactions.id.isIn(transactionIds) &
        database.moneyTransactions.type.equals(transactionType.storageValue) &
        database.moneyTransactions.categoryId.isNotIn(_transferCategoryIds) &
        database.moneyTransactions.transactionAt.isBiggerOrEqualValue(
          period.start.toUtc(),
        ) &
        database.moneyTransactions.transactionAt.isSmallerThanValue(
          period.end.toUtc(),
        );

    final accountId = scope.accountId;
    if (accountId != null) {
      predicate =
          predicate & database.moneyTransactions.accountId.equals(accountId);
    }

    final scopedCategoryId = scope.categoryId;
    if (scopedCategoryId != null) {
      predicate =
          predicate &
          database.moneyTransactions.categoryId.equals(scopedCategoryId);
    }

    final allocationCategoryId = categoryId;
    if (allocationCategoryId != null) {
      predicate =
          predicate &
          database.moneyTransactions.categoryId.equals(allocationCategoryId);
    }

    final subCategoryId = scope.subCategoryId;
    if (subCategoryId != null) {
      predicate =
          predicate &
          database.moneyTransactions.subCategoryId.equals(subCategoryId);
    }

    return (database.select(
      database.moneyTransactions,
    )..where((_) => predicate)).get();
  }

  String _internalAccountId(String userId) {
    return 'internal_account_$userId';
  }

  String _defaultMemberId(String userId) {
    return 'default_member_$userId';
  }

  String _defaultLedgerId(String userId) {
    return 'default_ledger_$userId';
  }

  String _ledgerAccountRecordId(String ledgerId, String accountId) {
    return '$ledgerId::$accountId';
  }

  Future<List<String>> _resolveTransactionLedgerIds(
    String userId,
    String? ledgerId,
  ) async {
    final personalLedgerId = (await _getDefaultLedgerForUser(userId)).id;
    final selectedLedgerId = await _resolveLedgerId(userId, ledgerId);
    if (selectedLedgerId == personalLedgerId) {
      return <String>[personalLedgerId];
    }
    return <String>[personalLedgerId, selectedLedgerId];
  }

  Future<List<String>> _transactionIdsForLedger(
    String userId,
    String ledgerId,
  ) async {
    await _getLedgerForUser(userId, ledgerId);
    final rows = await (database.select(
      database.moneyLedgerTransactions,
    )..where((link) => link.ledgerId.equals(ledgerId))).get();
    return rows.map((row) => row.transactionId).toList();
  }

  String _memberRoleOrDefault(String role) {
    final normalized = role.trim().toLowerCase();
    return switch (normalized) {
      'owner' => 'owner',
      'admin' || 'manager' => 'manager',
      'member' || 'viewer' || 'participant' => 'participant',
      _ => 'participant',
    };
  }

  Future<List<MoneyMember>> _membersForLedger(
    String userId,
    String ledgerId,
  ) async {
    final memberRows =
        await (database.select(database.moneyMembers).join([
                innerJoin(
                  database.moneyLedgerMembers,
                  database.moneyLedgerMembers.memberId.equalsExp(
                    database.moneyMembers.id,
                  ),
                ),
              ])
              ..where(
                database.moneyMembers.userId.equals(userId) &
                    database.moneyLedgerMembers.ledgerId.equals(ledgerId) &
                    database.moneyMembers.status.equals('active') &
                    database.moneyMembers.isDeleted.equals(false),
              )
              ..orderBy([
                OrderingTerm.asc(database.moneyMembers.createdAt),
                OrderingTerm.asc(database.moneyMembers.name),
              ]))
            .get();
    return memberRows
        .map((row) => row.readTable(database.moneyMembers))
        .toList();
  }

  List<_SplitAmount> _calculateSplitAmounts({
    required int totalAmountMinor,
    required MoneySplitType splitType,
    required List<MoneySplitParticipantDraft> participants,
  }) {
    final participantById = <String, MoneySplitParticipantDraft>{};
    for (final participant in participants) {
      if (participant.memberId.trim().isEmpty) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }
      participantById[participant.memberId] = participant;
    }
    final uniqueParticipants = participantById.values.toList();
    if (uniqueParticipants.length < 2 || totalAmountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidSplitAmount,
      );
    }

    return switch (splitType) {
      MoneySplitType.equal => _calculateEqualSplitAmounts(
        totalAmountMinor,
        uniqueParticipants,
      ),
      MoneySplitType.fixedAmount => _calculateFixedSplitAmounts(
        totalAmountMinor,
        uniqueParticipants,
      ),
      MoneySplitType.percentage => _calculatePercentageSplitAmounts(
        totalAmountMinor,
        uniqueParticipants,
      ),
    };
  }

  List<_SplitAmount> _calculateEqualSplitAmounts(
    int totalAmountMinor,
    List<MoneySplitParticipantDraft> participants,
  ) {
    final amounts = _splitMinorAmount(totalAmountMinor, participants.length);
    return List<_SplitAmount>.generate(
      participants.length,
      (index) => _SplitAmount(
        memberId: participants[index].memberId,
        amountMinor: amounts[index],
        percentageBasisPoints: null,
      ),
    );
  }

  List<_SplitAmount> _calculateFixedSplitAmounts(
    int totalAmountMinor,
    List<MoneySplitParticipantDraft> participants,
  ) {
    final amounts = <_SplitAmount>[];
    var sum = 0;
    for (final participant in participants) {
      final amountMinor = participant.amountMinor;
      if (amountMinor == null || amountMinor < 0) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitAmount,
        );
      }
      sum += amountMinor;
      amounts.add(
        _SplitAmount(
          memberId: participant.memberId,
          amountMinor: amountMinor,
          percentageBasisPoints: null,
        ),
      );
    }
    if (sum != totalAmountMinor) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidSplitAmount,
      );
    }
    return amounts;
  }

  List<_SplitAmount> _calculatePercentageSplitAmounts(
    int totalAmountMinor,
    List<MoneySplitParticipantDraft> participants,
  ) {
    var basisPointSum = 0;
    final basisPoints = <int>[];
    for (final participant in participants) {
      final basisPoint = participant.percentageBasisPoints;
      if (basisPoint == null || basisPoint < 0) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidSplitAmount,
        );
      }
      basisPointSum += basisPoint;
      basisPoints.add(basisPoint);
    }
    if (basisPointSum != 10000) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidSplitAmount,
      );
    }

    final rawAmounts = <int>[];
    var amountSum = 0;
    for (final basisPoint in basisPoints) {
      final amount = (totalAmountMinor * basisPoint) ~/ 10000;
      rawAmounts.add(amount);
      amountSum += amount;
    }
    var remainder = totalAmountMinor - amountSum;
    var index = 0;
    while (remainder > 0) {
      rawAmounts[index] += 1;
      remainder -= 1;
      index = (index + 1) % rawAmounts.length;
    }

    return List<_SplitAmount>.generate(
      participants.length,
      (index) => _SplitAmount(
        memberId: participants[index].memberId,
        amountMinor: rawAmounts[index],
        percentageBasisPoints: basisPoints[index],
      ),
    );
  }

  void _validateTransactionDraft(MoneyTransactionDraft draft) {
    if (draft.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransactionAmount,
      );
    }
    if (draft.type == MoneyTransactionType.transfer) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
  }

  void _validateTransactionUpdate(MoneyTransactionUpdate update) {
    if (update.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransactionAmount,
      );
    }
    if (update.type == MoneyTransactionType.transfer) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
  }

  void _validateTransferDraft(MoneyTransferDraft draft) {
    if (draft.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransactionAmount,
      );
    }
    if (draft.fromAccountId == draft.toAccountId) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
  }

  void _validateTransferUpdate(MoneyTransferUpdate update) {
    if (update.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransactionAmount,
      );
    }
    if (update.fromAccountId == update.toAccountId) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidTransferAccounts,
      );
    }
  }

  void _assertTransactionAccountRules(
    MoneyTransactionType transactionType,
    MoneyAccount account,
  ) {
    final accountType = MoneyAccountType.fromStorageValue(account.type);
    final isSelectableForIncome =
        accountType.isAssetLike && !accountType.isDebtLike;
    final isSelectableForExpense =
        accountType.isAssetLike ||
        accountType.isCreditLike ||
        accountType.isInternal;

    switch (transactionType) {
      case MoneyTransactionType.income:
        if (!isSelectableForIncome) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidTransferAccounts,
          );
        }
      case MoneyTransactionType.expense:
        if (!isSelectableForExpense) {
          throw const MoneyRepositoryException(
            MoneyRepositoryErrorCode.invalidTransferAccounts,
          );
        }
      case MoneyTransactionType.transfer:
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.invalidTransferAccounts,
        );
    }
  }

  Future<void> _recordTransactionChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordTransactionChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordAccountChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordAccountChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordBudgetSnapshotChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordBudgetSnapshotChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordBudgetAllocationSnapshotChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordBudgetAllocationSnapshotChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<void> _recordBillReminderChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordBillReminderChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Map<String, Object?> _restoreSyncFields() {
    return {'is_deleted': false, 'deleted_at': null};
  }

  Map<String, Object?> _deleteSyncFields(DateTime deletedAt) {
    return {
      'is_deleted': true,
      'deleted_at': deletedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _budgetSnapshotSyncFields(MoneyBudgetSnapshot snapshot) {
    return {
      'user_id': snapshot.userId,
      'budget_id': snapshot.budgetId,
      'ledger_id': snapshot.ledgerId,
      'tracking_type': snapshot.trackingType,
      'period_type': snapshot.periodType,
      'repeat_interval': snapshot.repeatInterval,
      'period_start_date': snapshot.periodStartDate,
      'period_end_date': snapshot.periodEndDate,
      'budget_amount_minor': snapshot.budgetAmountMinor,
      'used_amount_minor': snapshot.usedAmountMinor,
      'remaining_amount_minor': snapshot.remainingAmountMinor,
      'currency_code': snapshot.currencyCode,
      'status': snapshot.status,
      'captured_at': snapshot.capturedAt.toUtc().toIso8601String(),
      'source_budget_version': snapshot.sourceBudgetVersion,
      'created_at': snapshot.createdAt.toUtc().toIso8601String(),
      'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _budgetSnapshotStatusSyncFields({
    required MoneyBudgetHistoryStatus status,
    required DateTime updatedAt,
  }) {
    return {
      'status': status.storageValue,
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> _budgetAllocationSnapshotSyncFields(
    MoneyBudgetAllocationSnapshot snapshot,
  ) {
    return {
      'user_id': snapshot.userId,
      'budget_snapshot_id': snapshot.budgetSnapshotId,
      'budget_id': snapshot.budgetId,
      'allocation_id': snapshot.allocationId,
      'category_id': snapshot.categoryId,
      'member_id': snapshot.memberId,
      'allocated_amount_minor': snapshot.allocatedAmountMinor,
      'used_amount_minor': snapshot.usedAmountMinor,
      'remaining_amount_minor': snapshot.remainingAmountMinor,
      'currency_code': snapshot.currencyCode,
      'status': snapshot.status,
      'captured_at': snapshot.capturedAt.toUtc().toIso8601String(),
      'source_allocation_version': snapshot.sourceAllocationVersion,
      'created_at': snapshot.createdAt.toUtc().toIso8601String(),
      'updated_at': snapshot.updatedAt.toUtc().toIso8601String(),
    };
  }

  Future<Map<String, Object?>> _splitRecordSyncFields(
    MoneySplitRecord record,
  ) async {
    final details =
        await (database.select(database.moneySplitRecordDetails)
              ..where((row) => row.splitRecordId.equals(record.id))
              ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
            .get();
    return {
      'ledger_id': record.ledgerId,
      'transaction_id': record.transactionId,
      'split_rule_id': record.splitRuleId,
      'status': record.status,
      'split_type': record.splitType,
      'total_amount_minor': record.totalAmountMinor,
      'currency_code': record.currencyCode,
      'payer_member_id': record.payerMemberId,
      'notes': record.notes,
      'details': details
          .map(
            (detail) => {
              'id': detail.id,
              'member_id': detail.memberId,
              'amount_minor': detail.amountMinor,
              'percentage_basis_points': detail.percentageBasisPoints,
              'notes': detail.notes,
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, Object?> _autoPostingRunUpdateSyncFields(
    MoneyAutoPostingRunEntity existing,
    MoneyAutoPostingRunEntity updated,
  ) {
    final fields = <String, Object?>{};
    _putIfChanged(
      fields,
      'template_id',
      existing.templateId,
      updated.templateId,
    );
    _putIfChanged(
      fields,
      'occurrence_key',
      existing.occurrenceKey,
      updated.occurrenceKey,
    );
    _putIfChanged(
      fields,
      'status',
      existing.status.storageValue,
      updated.status.storageValue,
    );
    _putIfChanged(
      fields,
      'transaction_id',
      existing.transactionId,
      updated.transactionId,
    );
    _putIfChanged(
      fields,
      'scheduled_for',
      existing.scheduledFor.toUtc().toIso8601String(),
      updated.scheduledFor.toUtc().toIso8601String(),
    );
    _putIfChanged(
      fields,
      'posted_at',
      existing.postedAt?.toUtc().toIso8601String(),
      updated.postedAt?.toUtc().toIso8601String(),
    );
    _putIfChanged(
      fields,
      'template_version',
      existing.templateVersion,
      updated.templateVersion,
    );
    _putIfChanged(fields, 'error_code', existing.errorCode, updated.errorCode);
    _putIfChanged(
      fields,
      'error_message',
      existing.errorMessage,
      updated.errorMessage,
    );
    _putIfChanged(
      fields,
      'created_at',
      existing.createdAt.toUtc().toIso8601String(),
      updated.createdAt.toUtc().toIso8601String(),
    );
    _putIfChanged(
      fields,
      'updated_at',
      existing.updatedAt.toUtc().toIso8601String(),
      updated.updatedAt.toUtc().toIso8601String(),
    );
    return fields;
  }

  void _putIfChanged(
    Map<String, Object?> fields,
    String key,
    Object? before,
    Object? after,
  ) {
    if (before != after) {
      fields[key] = after;
    }
  }

  Map<String, Object?> _transactionDraftSyncFields(
    MoneyTransactionDraft draft,
    List<String> ledgerIds,
  ) {
    return {
      'type': draft.type.storageValue,
      'status': MoneyTransactionStatus.completed.storageValue,
      'transaction_at': draft.transactionAt.toUtc().toIso8601String(),
      'amount_minor': draft.amountMinor,
      'refund_amount_minor': 0,
      'currency_code': draft.currencyCode,
      'description': draft.description.trim(),
      'notes': _blankToNull(draft.notes),
      'merchant': _blankToNull(draft.merchant),
      'location': _blankToNull(draft.location),
      'account_id': draft.accountId,
      'category_id': draft.categoryId,
      'sub_category_id': draft.subCategoryId,
      'payment_method': draft.paymentMethod.storageValue,
      'custom_payment_method_name': _blankToNull(draft.customPaymentMethodName),
      'actual_payer_account': draft.actualPayerAccount,
      'source_template_run_id': draft.sourceTemplateRunId,
      'tags': draft.tags,
      'ledger_ids': ledgerIds,
    };
  }

  Future<MoneyTransactionEntity> _createTransactionRow(
    String userId,
    MoneyTransactionDraft draft,
    List<String> ledgerIds,
  ) async {
    final account = await _getWritableAccountForUser(userId, draft.accountId);
    final expectedCategoryKind = draft.type == MoneyTransactionType.income
        ? MoneyCategoryKind.income
        : MoneyCategoryKind.expense;
    await _assertCategoryForUser(
      userId,
      draft.categoryId,
      expectedCategoryKind,
    );
    if (draft.subCategoryId != null) {
      await _assertSubCategoryForUser(
        userId,
        draft.categoryId,
        draft.subCategoryId!,
        expectedCategoryKind,
      );
    }
    _assertTransactionAccountRules(draft.type, account);

    final ledger = _MutableAccountLedger.fromAccount(account)
      ..applyTransactionCreate(draft.type, draft.amountMinor)
      ..validate();

    final now = DateTime.now().toUtc();
    final transactionId = _uuid.v4();
    await database
        .into(database.moneyTransactions)
        .insert(
          MoneyTransactionsCompanion.insert(
            id: transactionId,
            userId: userId,
            type: draft.type.storageValue,
            status: MoneyTransactionStatus.completed.storageValue,
            transactionAt: draft.transactionAt.toUtc(),
            amountMinor: draft.amountMinor,
            currencyCode: draft.currencyCode,
            description: draft.description.trim(),
            notes: Value<String?>(_blankToNull(draft.notes)),
            merchant: Value<String?>(_blankToNull(draft.merchant)),
            location: Value<String?>(_blankToNull(draft.location)),
            accountId: draft.accountId,
            categoryId: draft.categoryId,
            subCategoryId: Value<String?>(draft.subCategoryId),
            paymentMethod: draft.paymentMethod.storageValue,
            customPaymentMethodName: Value<String?>(
              _blankToNull(draft.customPaymentMethodName),
            ),
            actualPayerAccount: draft.actualPayerAccount,
            sourceTemplateRunId: Value<String?>(draft.sourceTemplateRunId),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await _replaceTransactionTags(transactionId, draft.tags);
    await _recordTransactionChange(
      userId: userId,
      recordId: transactionId,
      operation: SyncChangeOperation.insert,
      changedFields: _transactionDraftSyncFields(draft, ledgerIds),
      afterVersion: 1,
    );
    await _updateAccountLedger(userId, account.id, ledger, now);

    return _mapTransaction(
      await _getTransactionForUser(userId, transactionId),
      tags: await _getTagsForTransaction(transactionId),
    );
  }

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  int? _draftStatementDay(MoneyAccountDraft draft) {
    return _billingDayFor(draft.type, draft.statementDay);
  }

  int? _draftBudgetCycleStartDay(MoneyAccountDraft draft) {
    return _billingDayFor(draft.type, draft.budgetCycleStartDay);
  }

  int? _draftRepaymentDay(MoneyAccountDraft draft) {
    return _billingDayFor(draft.type, draft.repaymentDay);
  }

  int? _updateStatementDay(MoneyAccountUpdate update) {
    return _billingDayFor(update.type, update.statementDay);
  }

  int? _updateBudgetCycleStartDay(MoneyAccountUpdate update) {
    return _billingDayFor(update.type, update.budgetCycleStartDay);
  }

  int? _updateRepaymentDay(MoneyAccountUpdate update) {
    return _billingDayFor(update.type, update.repaymentDay);
  }

  int? _billingDayFor(MoneyAccountType type, int? day) {
    if (!type.isCreditLike || day == null || day < 1 || day > 31) {
      return null;
    }
    return day;
  }

  String _creditRepaymentReminderSourceKey(String accountId) {
    return 'credit_repayment:$accountId';
  }

  Future<MoneyAccount> _getAccountForUser(
    String userId,
    String accountId,
  ) async {
    final account =
        await (database.select(database.moneyAccounts)
              ..where(
                (account) =>
                    account.id.equals(accountId) &
                    account.userId.equals(userId) &
                    account.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (account == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.accountNotFound,
      );
    }

    return account;
  }

  Future<MoneyAccount> _getWritableAccountForUser(
    String userId,
    String accountId,
  ) async {
    final account = await _getAccountForUser(userId, accountId);
    if (!account.isActive) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.accountNotFound,
      );
    }
    return account;
  }

  Future<MoneyInstallmentPlan> _getInstallmentPlanForUser(
    String userId,
    String planId,
  ) async {
    final plan =
        await (database.select(database.moneyInstallmentPlans)
              ..where(
                (row) =>
                    row.id.equals(planId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (plan == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.installmentPlanNotFound,
      );
    }

    return plan;
  }

  Future<MoneyTransaction> _getTransactionForUser(
    String userId,
    String transactionId,
  ) async {
    final transaction =
        await (database.select(database.moneyTransactions)
              ..where(
                (row) =>
                    row.id.equals(transactionId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (transaction == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseReadFailed,
      );
    }

    return transaction;
  }

  Future<MoneyBudget> _getBudgetForUser(String userId, String budgetId) async {
    final budget =
        await (database.select(database.moneyBudgets)
              ..where(
                (budget) =>
                    budget.id.equals(budgetId) &
                    budget.userId.equals(userId) &
                    budget.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();

    if (budget == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.budgetNotFound,
      );
    }

    return budget;
  }

  Future<void> _assertCategoryForUser(
    String userId,
    String categoryId,
    MoneyCategoryKind expectedKind,
  ) async {
    final category =
        await (database.select(database.moneyCategories)
              ..where(
                (category) =>
                    category.id.equals(categoryId) &
                    category.kind.equals(expectedKind.storageValue) &
                    category.isDeleted.equals(false) &
                    (category.userId.isNull() | category.userId.equals(userId)),
              )
              ..limit(1))
            .getSingleOrNull();

    if (category == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.categoryNotFound,
      );
    }
  }

  Future<void> _assertSubCategoryForUser(
    String userId,
    String categoryId,
    String subCategoryId,
    MoneyCategoryKind expectedKind,
  ) async {
    final subCategory =
        await (database.select(database.moneySubCategories)
              ..where(
                (subCategory) =>
                    subCategory.id.equals(subCategoryId) &
                    subCategory.categoryId.equals(categoryId) &
                    subCategory.kind.equals(expectedKind.storageValue) &
                    subCategory.isDeleted.equals(false) &
                    (subCategory.userId.isNull() |
                        subCategory.userId.equals(userId)),
              )
              ..limit(1))
            .getSingleOrNull();

    if (subCategory == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.categoryNotFound,
      );
    }
  }

  Future<void> _replaceTransactionTags(
    String transactionId,
    List<String> tags,
  ) async {
    await (database.delete(
      database.moneyTransactionTags,
    )..where((row) => row.transactionId.equals(transactionId))).go();

    final normalizedTags = tags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    for (final tag in normalizedTags) {
      await database
          .into(database.moneyTransactionTags)
          .insert(
            MoneyTransactionTagsCompanion.insert(
              transactionId: transactionId,
              tag: tag,
            ),
          );
    }
  }

  Future<List<String>> _getTagsForTransaction(String transactionId) async {
    final rows =
        await (database.select(database.moneyTransactionTags)
              ..where((row) => row.transactionId.equals(transactionId))
              ..orderBy([(row) => OrderingTerm.asc(row.tag)]))
            .get();
    return rows.map((row) => row.tag).toList();
  }

  Future<void> _updateAccountLedger(
    String userId,
    String accountId,
    _MutableAccountLedger ledger,
    DateTime now,
  ) async {
    await (database.update(database.moneyAccounts)..where(
          (account) =>
              account.id.equals(accountId) &
              account.userId.equals(userId) &
              account.isDeleted.equals(false),
        ))
        .write(ledger.toCompanion(updatedAt: now));
  }

  Future<MoneyBudgetEntity> _mapBudget(MoneyBudget budget) async {
    final scope = _readBudgetScope(budget);
    final scopeType = _budgetScopeTypeFromBudget(budget, scope);
    final trackingType = MoneyBudgetTrackingType.fromStorageValue(
      budget.trackingType,
    );
    final periodType = MoneyBudgetPeriodType.fromStorageValue(
      budget.repeatPeriodType,
    );
    final period = await _budgetDisplayPeriod(budget, periodType);
    return MoneyBudgetEntity(
      id: budget.id,
      userId: budget.userId,
      ledgerId: budget.ledgerId ?? _defaultLedgerId(budget.userId),
      scopeType: scopeType,
      name: budget.name,
      description: budget.description,
      trackingType: trackingType,
      periodType: periodType,
      repeatInterval: budget.repeatInterval,
      amountMinor: budget.amountMinor,
      currencyCode: budget.currencyCode,
      periodStart: period.start,
      periodEnd: period.end.subtract(const Duration(milliseconds: 1)),
      categoryId: scope.categoryId,
      subCategoryId: scope.subCategoryId,
      accountId: scope.accountId,
      usedAmountMinor: await _budgetUsedAmountMinor(budget),
      isActive: budget.isActive,
      alertEnabled: budget.alertEnabled,
      alertThresholdPercent: budget.alertThresholdPercent,
      color: budget.color,
      createdAt: budget.createdAt,
      updatedAt: budget.updatedAt,
    );
  }

  MoneyBudgetScopeType _budgetScopeTypeFromBudget(
    MoneyBudget budget,
    _BudgetScope scope,
  ) {
    final rawScopeType = budget.scopeType;
    if (rawScopeType.trim().isNotEmpty) {
      return MoneyBudgetScopeType.fromStorageValue(rawScopeType);
    }
    return _inferBudgetScopeType(
      categoryId: scope.categoryId,
      accountId: scope.accountId,
    );
  }

  MoneyBudgetHistorySnapshotEntity _mapBudgetSnapshot(
    MoneyBudgetSnapshot snapshot,
  ) {
    return MoneyBudgetHistorySnapshotEntity(
      id: snapshot.id,
      userId: snapshot.userId,
      budgetId: snapshot.budgetId,
      ledgerId: snapshot.ledgerId,
      trackingType: MoneyBudgetTrackingType.fromStorageValue(
        snapshot.trackingType,
      ),
      periodType: MoneyBudgetPeriodType.fromStorageValue(snapshot.periodType),
      repeatInterval: snapshot.repeatInterval,
      periodStart: _dateFromKey(snapshot.periodStartDate),
      periodEnd: _dateFromKey(
        snapshot.periodEndDate,
      ).subtract(const Duration(milliseconds: 1)),
      budgetAmountMinor: snapshot.budgetAmountMinor,
      usedAmountMinor: snapshot.usedAmountMinor,
      remainingAmountMinor: snapshot.remainingAmountMinor,
      currencyCode: snapshot.currencyCode,
      status: MoneyBudgetHistoryStatus.fromStorageValue(snapshot.status),
      capturedAt: snapshot.capturedAt,
      sourceBudgetVersion: snapshot.sourceBudgetVersion,
      createdAt: snapshot.createdAt,
      updatedAt: snapshot.updatedAt,
    );
  }

  MoneyBudgetAllocationHistorySnapshotEntity _mapBudgetAllocationSnapshot(
    MoneyBudgetAllocationSnapshot snapshot,
  ) {
    return MoneyBudgetAllocationHistorySnapshotEntity(
      id: snapshot.id,
      userId: snapshot.userId,
      budgetSnapshotId: snapshot.budgetSnapshotId,
      budgetId: snapshot.budgetId,
      allocationId: snapshot.allocationId,
      categoryId: snapshot.categoryId,
      memberId: snapshot.memberId,
      allocatedAmountMinor: snapshot.allocatedAmountMinor,
      usedAmountMinor: snapshot.usedAmountMinor,
      remainingAmountMinor: snapshot.remainingAmountMinor,
      currencyCode: snapshot.currencyCode,
      status: MoneyBudgetAllocationStatus.fromStorageValue(snapshot.status),
      capturedAt: snapshot.capturedAt,
      sourceAllocationVersion: snapshot.sourceAllocationVersion,
      createdAt: snapshot.createdAt,
      updatedAt: snapshot.updatedAt,
    );
  }

  Future<Map<String, MoneyReminderCenterProcessingData>>
  _reminderProcessingByItemKey(String userId, Iterable<String> itemKeys) async {
    final keys = itemKeys.toSet().toList(growable: false);
    if (keys.isEmpty) {
      return const <String, MoneyReminderCenterProcessingData>{};
    }
    final records =
        await (database.select(database.moneyReminderCenterProcessing)..where(
              (record) =>
                  record.userId.equals(userId) &
                  record.itemKey.isIn(keys) &
                  record.isDeleted.equals(false),
            ))
            .get();
    return {for (final record in records) record.itemKey: record};
  }

  MoneyReminderCenterItem _applyReminderProcessing(
    MoneyReminderCenterItem item,
    MoneyReminderCenterProcessingData processing,
  ) {
    return item.copyWith(
      state: MoneyReminderCenterState.fromStorageValue(processing.state),
      snoozedUntil: processing.snoozedUntil == null
          ? null
          : _dateFromKey(processing.snoozedUntil!),
      processedAt: processing.processedAt,
    );
  }

  MoneyReminderCenterItem _billReminderCenterItem(MoneyBillReminder reminder) {
    final sourceType =
        reminder.sourceType ==
            MoneyBillReminderSourceType.creditRepayment.storageValue
        ? MoneyReminderCenterSourceType.creditCardBill
        : MoneyReminderCenterSourceType.billReminder;
    final actionType =
        reminder.sourceType ==
            MoneyBillReminderSourceType.creditRepayment.storageValue
        ? MoneyReminderCenterActionType.repay
        : MoneyReminderCenterActionType.recordTransaction;
    return MoneyReminderCenterItem(
      sourceType: sourceType,
      sourceId: reminder.id,
      title: reminder.name,
      dueDate: _dateFromKey(reminder.dueDate),
      amountMinor: reminder.amountMinor,
      currencyCode: reminder.currencyCode,
      ledgerId: reminder.ledgerId,
      accountId: reminder.accountId,
      remindBeforeDays: reminder.remindBeforeDays,
      actionType: actionType,
    );
  }

  MoneyReminderCenterItem _mapReminderProcessingItem(
    MoneyReminderCenterProcessingData record,
  ) {
    return MoneyReminderCenterItem(
      sourceType: MoneyReminderCenterSourceType.fromStorageValue(
        record.sourceType,
      ),
      sourceId: record.sourceId,
      title: record.title,
      dueDate: _dateFromKey(record.dueDate),
      amountMinor: record.amountMinor,
      currencyCode: record.currencyCode,
      ledgerId: record.ledgerId,
      accountId: record.accountId,
      isBudgetExceeded: record.isBudgetExceeded,
      actionType: MoneyReminderCenterActionType.fromStorageValue(
        record.actionType,
      ),
      state: MoneyReminderCenterState.fromStorageValue(record.state),
      snoozedUntil: record.snoozedUntil == null
          ? null
          : _dateFromKey(record.snoozedUntil!),
      processedAt: record.processedAt,
    );
  }

  MoneyBillReminderEntity _mapBillReminder(MoneyBillReminder reminder) {
    return MoneyBillReminderEntity(
      id: reminder.id,
      userId: reminder.userId,
      name: reminder.name,
      amountMinor: reminder.amountMinor,
      currencyCode: reminder.currencyCode,
      dueDate: _dateFromKey(reminder.dueDate),
      remindBeforeDays: reminder.remindBeforeDays,
      repeatPeriodType: reminder.repeatPeriodType == null
          ? null
          : MoneyBillReminderRepeatPeriodType.fromStorageValue(
              reminder.repeatPeriodType!,
            ),
      repeatInterval: reminder.repeatInterval,
      accountId: reminder.accountId,
      ledgerId: reminder.ledgerId,
      categoryId: reminder.categoryId,
      relatedTransactionId: reminder.relatedTransactionId,
      status: MoneyBillReminderStatus.fromStorageValue(reminder.status),
      sourceType: MoneyBillReminderSourceType.fromStorageValue(
        reminder.sourceType,
      ),
      sourceKey: reminder.sourceKey,
      amountSource: MoneyBillReminderAmountSource.fromStorageValue(
        reminder.amountSource,
      ),
      autoManaged: reminder.autoManaged,
      notes: reminder.notes,
      deviceId: reminder.deviceId,
      version: reminder.version,
      isDeleted: reminder.isDeleted,
      deletedAt: reminder.deletedAt,
      createdAt: reminder.createdAt,
      updatedAt: reminder.updatedAt,
    );
  }

  Future<MoneyBudgetAllocationEntity> _mapBudgetAllocationWithUsage(
    MoneyBudget budget,
    MoneyBudgetAllocation allocation,
  ) async {
    final usedAmountMinor = await _budgetAllocationUsedAmountMinor(
      budget,
      allocation,
    );
    return _mapBudgetAllocation(
      allocation,
      usedAmountMinor: usedAmountMinor,
      remainingAmountMinor: allocation.allocatedAmountMinor - usedAmountMinor,
    );
  }

  MoneyBudgetAllocationEntity _mapBudgetAllocation(
    MoneyBudgetAllocation allocation, {
    int? usedAmountMinor,
    int? remainingAmountMinor,
  }) {
    return MoneyBudgetAllocationEntity(
      id: allocation.id,
      userId: allocation.userId,
      budgetId: allocation.budgetId,
      categoryId: allocation.categoryId,
      memberId: allocation.memberId,
      allocatedAmountMinor: allocation.allocatedAmountMinor,
      usedAmountMinor: usedAmountMinor ?? allocation.usedAmountMinor,
      remainingAmountMinor:
          remainingAmountMinor ?? allocation.remainingAmountMinor,
      percentageBasisPoints: allocation.percentageBasisPoints,
      allocationType: allocation.allocationType,
      ruleConfigJson: allocation.ruleConfigJson,
      allowOverspend: allocation.allowOverspend,
      overspendLimitType: allocation.overspendLimitType,
      overspendLimitMinor: allocation.overspendLimitMinor,
      alertEnabled: allocation.alertEnabled,
      alertThresholdPercent: allocation.alertThresholdPercent,
      alertConfigJson: allocation.alertConfigJson,
      priority: allocation.priority,
      isMandatory: allocation.isMandatory,
      status: MoneyBudgetAllocationStatus.fromStorageValue(allocation.status),
      notes: allocation.notes,
      version: allocation.version,
      createdAt: allocation.createdAt,
      updatedAt: allocation.updatedAt,
    );
  }

  Future<({DateTime start, DateTime end})> _budgetDisplayPeriod(
    MoneyBudget budget,
    MoneyBudgetPeriodType periodType,
  ) async {
    if (budget.budgetType == _budgetTypeLegacySnapshot) {
      final start = _dateFromKey(budget.startDate);
      final endExclusive = _dateFromKey(
        budget.endDate,
      ).add(const Duration(days: 1));
      return (start: start, end: endExclusive);
    }

    return _budgetPeriodForBudget(budget, periodType);
  }

  MoneyInstallmentPlanEntity _mapInstallmentPlan(MoneyInstallmentPlan plan) {
    return MoneyInstallmentPlanEntity(
      id: plan.id,
      userId: plan.userId,
      ledgerId: plan.ledgerId ?? _defaultLedgerId(plan.userId),
      accountId: plan.accountId,
      name: plan.name,
      description: plan.description,
      totalPrincipalMinor: plan.totalAmountMinor,
      totalInterestMinor: plan.totalInterestMinor ?? 0,
      totalPeriods: plan.totalPeriods,
      remainingPeriods: plan.remainingPeriods,
      periodAmountMinor: plan.periodAmountMinor,
      currencyCode: plan.currencyCode,
      categoryId: plan.categoryId,
      subCategoryId: plan.subCategoryId,
      startDate: _dateFromKey(plan.startDate),
      endDate: _dateFromKey(plan.endDate),
      firstDueDate: _dateFromKey(plan.firstDueDate),
      status: MoneyInstallmentPlanStatus.fromStorageValue(plan.status),
      notes: plan.notes,
      createdAt: plan.createdAt,
      updatedAt: plan.updatedAt,
    );
  }

  Future<({bool allPosted, int pendingCount})> _installmentPlanProgress(
    String userId,
    String planId,
  ) async {
    final details =
        await (database.select(database.moneyInstallmentDetails)..where(
              (detail) =>
                  detail.userId.equals(userId) &
                  detail.planId.equals(planId) &
                  detail.isDeleted.equals(false),
            ))
            .get();
    if (details.isEmpty) {
      return (allPosted: false, pendingCount: 0);
    }

    var pendingCount = 0;
    var allPosted = true;
    for (final detail in details) {
      final status = MoneyInstallmentDetailStatus.fromStorageValue(
        detail.status,
      );
      if (status == MoneyInstallmentDetailStatus.pending) {
        pendingCount += 1;
      }
      if (status != MoneyInstallmentDetailStatus.posted) {
        allPosted = false;
      }
    }

    return (allPosted: allPosted, pendingCount: pendingCount);
  }

  MoneyInstallmentDetailEntity _mapInstallmentDetail(
    MoneyInstallmentDetail detail,
  ) {
    return MoneyInstallmentDetailEntity(
      id: detail.id,
      userId: detail.userId,
      planId: detail.planId,
      accountId: detail.accountId,
      periodNumber: detail.periodNumber,
      amountMinor: detail.amountMinor,
      principalMinor: detail.principalMinor,
      interestMinor: detail.interestMinor,
      dueDate: _dateFromKey(detail.dueDate),
      paidDate: detail.paidDate == null ? null : _dateFromKey(detail.paidDate!),
      status: MoneyInstallmentDetailStatus.fromStorageValue(detail.status),
      transactionId: detail.transactionId,
      notes: detail.notes,
      createdAt: detail.createdAt,
      updatedAt: detail.updatedAt,
    );
  }

  MoneyPaymentMethod _paymentMethodForAccountType(MoneyAccountType type) {
    return switch (type) {
      MoneyAccountType.creditCard ||
      MoneyAccountType.meituanCredit ||
      MoneyAccountType.otherCredit => MoneyPaymentMethod.creditCard,
      MoneyAccountType.huabei => MoneyPaymentMethod.huabei,
      MoneyAccountType.baitiao => MoneyPaymentMethod.baitiao,
      MoneyAccountType.alipay => MoneyPaymentMethod.alipay,
      MoneyAccountType.wechat => MoneyPaymentMethod.wechatPay,
      MoneyAccountType.bank => MoneyPaymentMethod.bankCard,
      MoneyAccountType.cash => MoneyPaymentMethod.cash,
      _ => MoneyPaymentMethod.other,
    };
  }

  Future<void> _tryRebuildUsageStatsForUser(String userId) async {
    try {
      await _rebuildUsageStatsForUser(userId);
    } catch (_) {
      // Usage stats are a derived cache. A rebuild failure must not block
      // transaction writes or remote sync application.
    }
  }

  Future<void> _rebuildUsageStatsForUser(String userId) async {
    final rows =
        await (database.select(database.moneyTransactions)..where(
              (row) =>
                  row.userId.equals(userId) &
                  row.isDeleted.equals(false) &
                  row.status.equals(
                    MoneyTransactionStatus.completed.storageValue,
                  ) &
                  row.type.isIn([
                    MoneyTransactionType.income.storageValue,
                    MoneyTransactionType.expense.storageValue,
                  ]) &
                  row.actualPayerAccount.isNotIn([
                    _transferOutMarker,
                    _transferInMarker,
                    'installment',
                  ]) &
                  row.installmentPlanId.isNull(),
            ))
            .get();

    final categoryStats = <String, _UsageStat>{};
    final subCategoryStats = <String, _UsageStat>{};
    final accountStats = <String, _UsageStat>{};
    final paymentMethodStats = <String, _UsageStat>{};
    final accountPaymentMethodStats = <String, _UsageStat>{};

    for (final row in rows) {
      final amountMinor = _effectiveTransactionAmountMinor(row);
      if (amountMinor <= 0) {
        continue;
      }
      _addUsageStat(
        categoryStats,
        row.categoryId,
        amountMinor: amountMinor,
        usedAt: row.transactionAt,
      );
      final subCategoryId = row.subCategoryId;
      if (subCategoryId != null && subCategoryId.trim().isNotEmpty) {
        _addUsageStat(
          subCategoryStats,
          subCategoryId,
          amountMinor: amountMinor,
          usedAt: row.transactionAt,
        );
      }
      _addUsageStat(
        accountStats,
        row.accountId,
        amountMinor: amountMinor,
        usedAt: row.transactionAt,
      );
      _addUsageStat(
        paymentMethodStats,
        row.paymentMethod,
        amountMinor: amountMinor,
        usedAt: row.transactionAt,
      );
      _addUsageStat(
        accountPaymentMethodStats,
        '${row.accountId}\n${row.paymentMethod}',
        amountMinor: amountMinor,
        usedAt: row.transactionAt,
      );
    }

    final now = _utcNow();
    await database.transaction(() async {
      await (database.delete(
        database.moneyCategoryUsageStats,
      )..where((row) => row.userId.equals(userId))).go();
      await (database.delete(
        database.moneySubCategoryUsageStats,
      )..where((row) => row.userId.equals(userId))).go();
      await (database.delete(
        database.moneyAccountUsageStats,
      )..where((row) => row.userId.equals(userId))).go();
      await (database.delete(
        database.moneyPaymentMethodUsageStats,
      )..where((row) => row.userId.equals(userId))).go();
      await (database.delete(
        database.moneyAccountPaymentMethodUsageStats,
      )..where((row) => row.userId.equals(userId))).go();

      for (final entry in categoryStats.entries) {
        await database
            .into(database.moneyCategoryUsageStats)
            .insert(
              MoneyCategoryUsageStatsCompanion.insert(
                userId: userId,
                categoryId: entry.key,
                useCount: Value(entry.value.useCount),
                totalAmountMinor: Value(entry.value.totalAmountMinor),
                lastUsedAt: Value<DateTime?>(entry.value.lastUsedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      for (final entry in subCategoryStats.entries) {
        await database
            .into(database.moneySubCategoryUsageStats)
            .insert(
              MoneySubCategoryUsageStatsCompanion.insert(
                userId: userId,
                subCategoryId: entry.key,
                useCount: Value(entry.value.useCount),
                totalAmountMinor: Value(entry.value.totalAmountMinor),
                lastUsedAt: Value<DateTime?>(entry.value.lastUsedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      for (final entry in accountStats.entries) {
        await database
            .into(database.moneyAccountUsageStats)
            .insert(
              MoneyAccountUsageStatsCompanion.insert(
                userId: userId,
                accountId: entry.key,
                useCount: Value(entry.value.useCount),
                totalAmountMinor: Value(entry.value.totalAmountMinor),
                lastUsedAt: Value<DateTime?>(entry.value.lastUsedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      for (final entry in paymentMethodStats.entries) {
        await database
            .into(database.moneyPaymentMethodUsageStats)
            .insert(
              MoneyPaymentMethodUsageStatsCompanion.insert(
                userId: userId,
                paymentMethod: entry.key,
                useCount: Value(entry.value.useCount),
                totalAmountMinor: Value(entry.value.totalAmountMinor),
                lastUsedAt: Value<DateTime?>(entry.value.lastUsedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      for (final entry in accountPaymentMethodStats.entries) {
        final parts = entry.key.split('\n');
        if (parts.length != 2) {
          continue;
        }
        await database
            .into(database.moneyAccountPaymentMethodUsageStats)
            .insert(
              MoneyAccountPaymentMethodUsageStatsCompanion.insert(
                userId: userId,
                accountId: parts.first,
                paymentMethod: parts.last,
                useCount: Value(entry.value.useCount),
                totalAmountMinor: Value(entry.value.totalAmountMinor),
                lastUsedAt: Value<DateTime?>(entry.value.lastUsedAt),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    });
  }

  void _addUsageStat(
    Map<String, _UsageStat> stats,
    String key, {
    required int amountMinor,
    required DateTime usedAt,
  }) {
    stats
        .putIfAbsent(key, () => _UsageStat())
        .add(amountMinor: amountMinor, usedAt: usedAt);
  }

  void _sortAccountsByUsage(
    List<MoneyAccountEntity> accounts,
    Map<String, _UsageStat> usageRanks,
  ) {
    accounts.sort((left, right) {
      final usageCompare = _compareUsage(
        usageRanks[left.id],
        usageRanks[right.id],
      );
      if (usageCompare != 0) {
        return usageCompare;
      }
      final updatedCompare = right.updatedAt.compareTo(left.updatedAt);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return left.name.compareTo(right.name);
    });
  }

  void _sortCategoriesByUsage(
    List<MoneyCategoryEntity> categories,
    Map<String, _UsageStat> usageRanks,
  ) {
    categories.sort((left, right) {
      final usageCompare = _compareUsage(
        usageRanks[left.id],
        usageRanks[right.id],
      );
      if (usageCompare != 0) {
        return usageCompare;
      }
      if (left.isSystem != right.isSystem) {
        return left.isSystem ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });
  }

  void _sortSubCategoriesByUsage(
    List<MoneySubCategoryEntity> subCategories,
    Map<String, _UsageStat> usageRanks,
  ) {
    subCategories.sort((left, right) {
      final categoryCompare = left.categoryId.compareTo(right.categoryId);
      if (categoryCompare != 0) {
        return categoryCompare;
      }
      final usageCompare = _compareUsage(
        usageRanks[left.id],
        usageRanks[right.id],
      );
      if (usageCompare != 0) {
        return usageCompare;
      }
      if (left.isSystem != right.isSystem) {
        return left.isSystem ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });
  }

  int _compareUsage(_UsageStat? left, _UsageStat? right) {
    final countCompare = (right?.useCount ?? 0).compareTo(left?.useCount ?? 0);
    if (countCompare != 0) {
      return countCompare;
    }
    final amountCompare = (right?.totalAmountMinor ?? 0).compareTo(
      left?.totalAmountMinor ?? 0,
    );
    if (amountCompare != 0) {
      return amountCompare;
    }
    final leftLastUsedAt = left?.lastUsedAt;
    final rightLastUsedAt = right?.lastUsedAt;
    if (leftLastUsedAt != null && rightLastUsedAt != null) {
      return rightLastUsedAt.compareTo(leftLastUsedAt);
    }
    if (leftLastUsedAt != null) {
      return -1;
    }
    if (rightLastUsedAt != null) {
      return 1;
    }
    return 0;
  }

  MoneyAccountEntity _mapAccount(MoneyAccount account) {
    return MoneyAccountEntity(
      id: account.id,
      userId: account.userId,
      name: account.name,
      description: account.description,
      type: MoneyAccountType.fromStorageValue(account.type),
      balanceMinor: account.balanceMinor,
      initialBalanceMinor: account.initialBalanceMinor,
      creditLimitMinor: account.creditLimitMinor,
      postedDebtMinor: account.postedDebtMinor,
      frozenCreditMinor: account.frozenCreditMinor,
      statementDay: account.statementDay,
      budgetCycleStartDay: account.budgetCycleStartDay,
      repaymentDay: account.repaymentDay,
      autoRepaymentReminderEnabled: account.autoRepaymentReminderEnabled,
      currencyCode: account.currencyCode,
      isShared: account.isShared,
      isVirtual: account.isVirtual,
      color: account.color,
      icon: account.icon,
      isActive: account.isActive,
      isDeleted: account.isDeleted,
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    );
  }

  MoneyTransactionEntity _mapTransaction(
    MoneyTransaction transaction, {
    required List<String> tags,
  }) {
    return MoneyTransactionEntity(
      id: transaction.id,
      userId: transaction.userId,
      type: MoneyTransactionType.fromStorageValue(transaction.type),
      status: MoneyTransactionStatus.fromStorageValue(transaction.status),
      transactionAt: transaction.transactionAt,
      amountMinor: transaction.amountMinor,
      refundAmountMinor: transaction.refundAmountMinor,
      currencyCode: transaction.currencyCode,
      description: transaction.description,
      notes: transaction.notes,
      merchant: transaction.merchant,
      location: transaction.location,
      accountId: transaction.accountId,
      toAccountId: transaction.toAccountId,
      categoryId: transaction.categoryId,
      subCategoryId: transaction.subCategoryId,
      paymentMethod: MoneyPaymentMethod.fromStorageValue(
        transaction.paymentMethod,
      ),
      customPaymentMethodName: transaction.customPaymentMethodName,
      actualPayerAccount: transaction.actualPayerAccount,
      relatedTransactionId: transaction.relatedTransactionId,
      installmentPlanId: transaction.installmentPlanId,
      sourceTemplateRunId: transaction.sourceTemplateRunId,
      interestRateBasisPoints: transaction.interestRateBasisPoints,
      totalInterestMinor: transaction.totalInterestMinor,
      calcMethod: transaction.calcMethod,
      tags: List.unmodifiable(tags),
      isDeleted: transaction.isDeleted,
      createdAt: transaction.createdAt,
      updatedAt: transaction.updatedAt,
    );
  }

  MoneyCategoryEntity _mapCategory(MoneyCategory category) {
    return MoneyCategoryEntity(
      id: category.id,
      userId: category.userId,
      name: category.name,
      kind: MoneyCategoryKind.fromStorageValue(category.kind),
      color: category.color,
      icon: category.icon,
      isSystem: category.isSystem,
    );
  }

  MoneySubCategoryEntity _mapSubCategory(MoneySubCategory subCategory) {
    return MoneySubCategoryEntity(
      id: subCategory.id,
      categoryId: subCategory.categoryId,
      userId: subCategory.userId,
      name: subCategory.name,
      kind: MoneyCategoryKind.fromStorageValue(subCategory.kind),
      color: subCategory.color,
      icon: subCategory.icon,
      isSystem: subCategory.isSystem,
    );
  }

  Future<void> _ensureDefaultSplitContext(String userId, DateTime now) async {
    final memberId = _defaultMemberId(userId);
    final ledgerId = _defaultLedgerId(userId);
    final user =
        await (database.select(database.users)
              ..where(
                (row) => row.id.equals(userId) & row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    final memberName =
        _blankToNull(user?.displayName) ?? _blankToNull(user?.username) ?? '我';

    await database
        .into(database.moneyMembers)
        .insert(
          MoneyMembersCompanion.insert(
            id: memberId,
            userId: userId,
            name: memberName,
            role: 'owner',
            status: 'active',
            color: const Value<String?>(_defaultMemberColor),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    await database
        .into(database.moneyLedgers)
        .insert(
          MoneyLedgersCompanion.insert(
            id: ledgerId,
            userId: userId,
            name: _defaultLedgerName,
            description: const Value<String?>('默认个人账本'),
            createdByMemberId: memberId,
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
    await (database.update(database.moneyLedgers)..where(
          (row) =>
              row.id.equals(ledgerId) &
              row.userId.equals(userId) &
              row.name.equals('默认账本') &
              row.isDeleted.equals(false),
        ))
        .write(
          MoneyLedgersCompanion(
            name: const Value(_defaultLedgerName),
            description: const Value<String?>('默认个人账本'),
            ledgerType: const Value('personal'),
            updatedAt: Value(now),
          ),
        );
    await database
        .into(database.moneyLedgerMembers)
        .insert(
          MoneyLedgerMembersCompanion.insert(
            ledgerId: ledgerId,
            memberId: memberId,
            createdAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<MoneyLedger> _getDefaultLedgerForUser(String userId) async {
    final ledger =
        await (database.select(database.moneyLedgers)
              ..where(
                (row) =>
                    row.id.equals(_defaultLedgerId(userId)) &
                    row.userId.equals(userId) &
                    row.status.equals('active') &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger;
  }

  Future<MoneyLedger> _getLedgerForUser(String userId, String ledgerId) async {
    final ledger =
        await (database.select(database.moneyLedgers)
              ..where(
                (row) =>
                    row.id.equals(ledgerId) &
                    row.userId.equals(userId) &
                    row.status.equals('active') &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger;
  }

  Future<List<String>> _accountIdsForType(
    String userId,
    MoneyAccountType accountType,
  ) async {
    final rows =
        await (database.select(database.moneyAccounts)..where(
              (account) =>
                  account.userId.equals(userId) &
                  account.type.equals(accountType.storageValue) &
                  account.isActive.equals(true) &
                  account.isVirtual.equals(false) &
                  account.isDeleted.equals(false),
            ))
            .get();
    return [for (final row in rows) row.id];
  }

  Future<String> _resolveLedgerId(String userId, String? ledgerId) async {
    final normalized = ledgerId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return (await _getDefaultLedgerForUser(userId)).id;
    }
    return (await _getLedgerForUser(userId, normalized)).id;
  }

  Future<void> _linkTransactionToLedgerUnchecked({
    required String ledgerId,
    required String transactionId,
  }) {
    return database
        .into(database.moneyLedgerTransactions)
        .insert(
          MoneyLedgerTransactionsCompanion.insert(
            ledgerId: ledgerId,
            transactionId: transactionId,
            createdAt: DateTime.now().toUtc(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<void> _linkTransactionToLedgersUnchecked({
    required List<String> ledgerIds,
    required String transactionId,
  }) async {
    for (final ledgerId in ledgerIds) {
      await _linkTransactionToLedgerUnchecked(
        ledgerId: ledgerId,
        transactionId: transactionId,
      );
    }
  }

  Future<MoneyMember> _getMemberForUser(String userId, String memberId) async {
    final member =
        await (database.select(database.moneyMembers)
              ..where(
                (row) =>
                    row.id.equals(memberId) &
                    row.userId.equals(userId) &
                    row.status.equals('active') &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (member == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.memberNotFound,
      );
    }
    return member;
  }

  MoneyMemberEntity _mapMember(MoneyMember member) {
    return MoneyMemberEntity(
      id: member.id,
      userId: member.userId,
      name: member.name,
      role: member.role,
      status: member.status,
      color: member.color,
      createdAt: member.createdAt,
      updatedAt: member.updatedAt,
    );
  }

  MoneyLedgerEntity _mapLedger(MoneyLedger ledger) {
    return MoneyLedgerEntity(
      id: ledger.id,
      userId: ledger.userId,
      name: ledger.name,
      ledgerType: ledger.ledgerType,
      status: ledger.status,
      baseCurrencyCode: ledger.baseCurrencyCode,
      createdAt: ledger.createdAt,
      updatedAt: ledger.updatedAt,
    );
  }

  List<int> _splitMinorAmount(int totalMinor, int periods) {
    final base = totalMinor ~/ periods;
    final remainder = totalMinor % periods;
    return List<int>.generate(
      periods,
      (index) => base + (index < remainder ? 1 : 0),
    );
  }

  Future<MoneySplitRecord> _getSplitRecordForUser(
    String userId,
    String splitRecordId,
  ) async {
    final record =
        await (database.select(database.moneySplitRecords)
              ..where(
                (row) =>
                    row.id.equals(splitRecordId) &
                    row.userId.equals(userId) &
                    row.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (record == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.splitRecordNotFound,
      );
    }
    return record;
  }

  Future<void> _recordSplitRecordChange({
    required String userId,
    required String recordId,
    required SyncChangeOperation operation,
    required Map<String, Object?> changedFields,
    int? beforeVersion,
    int? afterVersion,
  }) async {
    final logger = syncChangeLogger;
    if (logger == null) {
      return;
    }

    await logger.recordSplitRecordChange(
      userId: userId,
      recordId: recordId,
      operation: operation,
      changedFields: changedFields,
      beforeVersion: beforeVersion,
      afterVersion: afterVersion,
    );
  }

  Future<MoneySplitRecordEntity> _createSplitForExistingTransaction(
    String userId,
    MoneySplitDraft draft,
  ) async {
    final transaction = await _getTransactionForUser(
      userId,
      draft.transactionId,
    );
    if (MoneyTransactionType.fromStorageValue(transaction.type) !=
            MoneyTransactionType.expense ||
        MoneyTransactionStatus.fromStorageValue(transaction.status) !=
            MoneyTransactionStatus.completed ||
        transaction.amountMinor <= 0) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.invalidSplitTransaction,
      );
    }

    final existingSplit =
        await (database.select(database.moneySplitRecords)
              ..where(
                (record) =>
                    record.userId.equals(userId) &
                    record.transactionId.equals(transaction.id) &
                    record.status.equals(
                      MoneySplitRecordStatus.active.storageValue,
                    ) &
                    record.isDeleted.equals(false),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existingSplit != null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.activeSplitAlreadyExists,
      );
    }

    final ledger = await _getLedgerForUser(userId, draft.ledgerId);
    if (ledger.ledgerType != 'family') {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    final members = await _membersForLedger(userId, ledger.id);
    final memberById = <String, MoneyMember>{
      for (final member in members) member.id: member,
    };
    final splitAmounts = _calculateSplitAmounts(
      totalAmountMinor: transaction.amountMinor,
      splitType: draft.splitType,
      participants: draft.participants,
    );
    if (!splitAmounts.any((entry) => entry.memberId == draft.payerMemberId)) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.memberNotFound,
      );
    }
    for (final entry in splitAmounts) {
      if (!memberById.containsKey(entry.memberId)) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.memberNotFound,
        );
      }
    }

    final now = DateTime.now().toUtc();
    final splitRecordId = _uuid.v4();
    await _linkTransactionToLedgerUnchecked(
      ledgerId: ledger.id,
      transactionId: transaction.id,
    );
    await database
        .into(database.moneySplitRecords)
        .insert(
          MoneySplitRecordsCompanion.insert(
            id: splitRecordId,
            userId: userId,
            ledgerId: ledger.id,
            transactionId: Value<String?>(transaction.id),
            status: MoneySplitRecordStatus.active.storageValue,
            splitType: draft.splitType.storageValue,
            totalAmountMinor: transaction.amountMinor,
            currencyCode: transaction.currencyCode,
            payerMemberId: draft.payerMemberId,
            notes: Value<String?>(_blankToNull(draft.notes)),
            createdAt: now,
            updatedAt: now,
          ),
        );

    for (final entry in splitAmounts) {
      await database
          .into(database.moneySplitRecordDetails)
          .insert(
            MoneySplitRecordDetailsCompanion.insert(
              id: _uuid.v4(),
              userId: userId,
              splitRecordId: splitRecordId,
              memberId: entry.memberId,
              amountMinor: entry.amountMinor,
              percentageBasisPoints: Value<int?>(entry.percentageBasisPoints),
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    final splitRecord = await _getSplitRecordForUser(userId, splitRecordId);
    await _recordSplitRecordChange(
      userId: userId,
      recordId: splitRecordId,
      operation: SyncChangeOperation.insert,
      changedFields: await _splitRecordSyncFields(splitRecord),
      afterVersion: 1,
    );

    return _mapSplitRecord(splitRecord);
  }

  MoneySplitRuleEntity _mapSplitRule(MoneySplitRule rule) {
    return MoneySplitRuleEntity(
      id: rule.id,
      userId: rule.userId,
      ledgerId: rule.ledgerId,
      name: rule.name,
      ruleType: MoneySplitRuleType.fromStorageValue(rule.ruleType),
      ruleConfigJson: rule.ruleConfigJson,
      isActive: rule.isActive,
      priority: rule.priority,
      version: rule.version,
      isDeleted: rule.isDeleted,
      deletedAt: rule.deletedAt,
      createdAt: rule.createdAt,
      updatedAt: rule.updatedAt,
    );
  }

  Future<MoneySplitRecordEntity> _mapSplitRecord(
    MoneySplitRecord record,
  ) async {
    final memberRows = await _membersForLedger(record.userId, record.ledgerId);
    final memberById = <String, MoneyMember>{
      for (final member in memberRows) member.id: member,
    };
    final details =
        await (database.select(database.moneySplitRecordDetails)
              ..where(
                (detail) =>
                    detail.userId.equals(record.userId) &
                    detail.splitRecordId.equals(record.id) &
                    detail.isDeleted.equals(false),
              )
              ..orderBy([(detail) => OrderingTerm.asc(detail.createdAt)]))
            .get();
    final payerMember = memberById[record.payerMemberId];

    return MoneySplitRecordEntity(
      id: record.id,
      userId: record.userId,
      ledgerId: record.ledgerId,
      transactionId: record.transactionId,
      status: MoneySplitRecordStatus.fromStorageValue(record.status),
      splitType: MoneySplitType.fromStorageValue(record.splitType),
      totalAmountMinor: record.totalAmountMinor,
      currencyCode: record.currencyCode,
      payerMemberId: record.payerMemberId,
      payerMemberName: payerMember?.name ?? '成员已不可用',
      notes: record.notes,
      details: details.map((detail) {
        final member = memberById[detail.memberId];
        return MoneySplitRecordDetailEntity(
          id: detail.id,
          userId: detail.userId,
          splitRecordId: detail.splitRecordId,
          memberId: detail.memberId,
          memberName: member?.name ?? '成员已不可用',
          amountMinor: detail.amountMinor,
          percentageBasisPoints: detail.percentageBasisPoints,
          notes: detail.notes,
          createdAt: detail.createdAt,
          updatedAt: detail.updatedAt,
        );
      }).toList(),
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
  }
}

class DriftMoneyRepository extends _DriftMoneyRepositoryBase
    with
        _Ledgers,
        _Splits,
        _Accounts,
        _Statistics,
        _Transactions,
        _Categories,
        _Budgets,
        _BillReminders,
        _Installments,
        _AutoPosting,
        _RemoteApply,
        _Reports,
        _AssetSnapshots {
  DriftMoneyRepository({
    required super.database,
    required super.seedRunner,
    super.syncChangeLogger,
    super.now,
    super.uuid,
  });
}
