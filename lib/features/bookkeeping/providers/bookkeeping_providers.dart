import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/database/seed/seed_providers.dart';
import 'package:miji/core/notifications/app_notification_service.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';
import 'package:miji/features/bookkeeping/application/money_bill_reminder_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_budget_alert_notification_service.dart';
import 'package:miji/features/bookkeeping/application/money_delta_conflict_apply_service.dart';
import 'package:miji/features/bookkeeping/application/transaction_entry_defaults_store.dart';
import 'package:miji/features/bookkeeping/data/drift_money_repository.dart';
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
import 'package:miji/features/bookkeeping/domain/money_ledger_scope.dart';
import 'package:miji/features/bookkeeping/domain/money_overview_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

final moneyRepositoryProvider = Provider<MoneyRepository>((ref) {
  return DriftMoneyRepository(
    database: ref.watch(appDatabaseProvider),
    seedRunner: ref.watch(databaseSeedRunnerProvider),
    syncChangeLogger: ref.watch(syncChangeLoggerProvider),
  );
});

final transactionEntryDefaultsStoreProvider =
    Provider<TransactionEntryDefaultsStore>((ref) {
      return const TransactionEntryDefaultsStore();
    });

final appNotificationServiceProvider = Provider<AppNotificationService>((ref) {
  return AppNotificationService();
});

final moneyBudgetAlertNotificationServiceProvider =
    Provider<MoneyBudgetAlertNotificationService>((ref) {
      return MoneyBudgetAlertNotificationService(
        notificationService: ref.watch(appNotificationServiceProvider),
      );
    });

final moneyBillReminderNotificationServiceProvider =
    Provider<MoneyBillReminderNotificationService>((ref) {
      return MoneyBillReminderNotificationService(
        notificationService: ref.watch(appNotificationServiceProvider),
      );
    });

final currentUserBudgetAlertNotificationActionsProvider =
    Provider<CurrentUserBudgetAlertNotificationActions>((ref) {
      return CurrentUserBudgetAlertNotificationActions(ref);
    });

final currentUserBillReminderNotificationActionsProvider =
    Provider<CurrentUserBillReminderNotificationActions>((ref) {
      return CurrentUserBillReminderNotificationActions(ref);
    });

final currentUserAutoPostingExecutionProvider =
    FutureProvider<MoneyAutoPostingExecutionSummary>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return MoneyAutoPostingExecutionSummary.empty;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      return repository.executeDueAutoPostings(userId);
    });

final moneyDeltaConflictApplyServiceProvider =
    Provider<MoneyDeltaConflictApplyService>((ref) {
      return MoneyDeltaConflictApplyService(
        repository: ref.watch(moneyRepositoryProvider),
        conflictStore: ref.watch(deltaConflictStoreProvider),
      );
    });

final currentUserVisibleAccountsProvider =
    StreamProvider.autoDispose<List<MoneyAccountEntity>>((ref) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyAccountEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchVisibleAccountsForUser(userId);
    });

final currentUserMoneyLedgerAccountsProvider = StreamProvider.autoDispose
    .family<List<MoneyAccountEntity>, String>((ref, ledgerId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyAccountEntity>[];
        return;
      }

      yield* ref
          .watch(moneyRepositoryProvider)
          .watchAccountsForLedger(session.userId!, ledgerId);
    });

final currentUserMoneyTransferAccountsProvider = StreamProvider.autoDispose
    .family<List<MoneyAccountEntity>, String>((ref, ledgerId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyAccountEntity>[];
        return;
      }

      yield* ref
          .watch(moneyRepositoryProvider)
          .watchTransferAccountsForLedger(session.userId!, ledgerId);
    });

final currentUserAccountMonthlySummariesProvider =
    FutureProvider<Map<String, MoneyAccountMonthlySummary>>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <String, MoneyAccountMonthlySummary>{};
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      return repository.getAccountMonthlySummariesForUser(userId);
    });

final currentUserCreditCardStatementProvider = FutureProvider.autoDispose
    .family<MoneyCreditCardStatement?, String>((ref, accountId) async {
      ref.watch(moneyDataRefreshVersionProvider);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }
      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      return repository.getCreditCardStatementForAccount(userId, accountId);
    });

final currentUserCreditCardBillViewProvider = FutureProvider.autoDispose
    .family<MoneyCreditCardBillView?, String>((ref, accountId) async {
      ref.watch(moneyDataRefreshVersionProvider);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }
      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      return repository.getCurrentCreditCardBillViewForAccount(
        userId,
        accountId,
      );
    });
final currentUserBookkeepingOverviewProvider =
    FutureProvider<MoneyOverviewEntity>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const MoneyOverviewEntity.empty();
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        return const MoneyOverviewEntity.empty();
      }

      final accountsFuture = repository
          .watchVisibleAccountsForUser(userId)
          .first;
      final accountSummariesFuture = repository
          .getAccountMonthlySummariesForUser(userId, ledgerId: ledger.id);
      final budgetsFuture = repository
          .watchBudgetsForUser(userId, ledgerId: ledger.id)
          .first;
      final recentTransactionsFuture = repository
          .watchRecentTransactionsForUser(userId, limit: 5, ledgerId: ledger.id)
          .first;

      return MoneyOverviewEntity.fromSources(
        accounts: await accountsFuture,
        accountSummaries: await accountSummariesFuture,
        budgets: await budgetsFuture,
        recentTransactions: await recentTransactionsFuture,
      );
    });

final currentMoneyLedgerIdProvider =
    NotifierProvider<CurrentMoneyLedgerIdController, String?>(
      CurrentMoneyLedgerIdController.new,
    );

class CurrentMoneyLedgerIdController extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return null;
  }

  void set(String ledgerId) {
    state = ledgerId;
  }

  void clear() {
    state = null;
  }
}

final currentUserMoneyLedgersProvider =
    StreamProvider.autoDispose<List<MoneyLedgerEntity>>((ref) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyLedgerEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchLedgersForUser(userId);
    });

final currentUserTransactionLedgersProvider = StreamProvider.autoDispose
    .family<List<MoneyLedgerEntity>, String>((ref, transactionId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyLedgerEntity>[];
        return;
      }

      yield* ref
          .watch(moneyRepositoryProvider)
          .watchLedgersForTransaction(session.userId!, transactionId);
    });

final currentUserCurrentLedgerValueProvider = Provider<MoneyLedgerEntity?>((
  ref,
) {
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }

  final selectedLedgerId = ref.watch(currentMoneyLedgerIdProvider);
  final ledgers = ref
      .watch(currentUserMoneyLedgersProvider)
      .maybeWhen(data: (items) => items, orElse: () => null);
  if (ledgers == null) {
    return null;
  }
  if (ledgers.isEmpty) {
    return null;
  }

  final selected = _findLedgerById(ledgers, selectedLedgerId);
  if (selected != null) {
    return selected;
  }

  for (final ledger in ledgers) {
    if (ledger.isPersonal) {
      return ledger;
    }
  }
  return ledgers.first;
});

final currentUserCurrentLedgerProvider = FutureProvider<MoneyLedgerEntity?>((
  ref,
) async {
  _watchMoneyDataRefresh(ref);
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return null;
  }

  final selectedLedgerId = ref.watch(currentMoneyLedgerIdProvider);
  final ledgers = await ref.watch(currentUserMoneyLedgersProvider.future);
  return _resolveCurrentLedgerFromList(ledgers, selectedLedgerId);
});

final currentUserMoneyLedgerScopeProvider = FutureProvider<MoneyLedgerScope?>((
  ref,
) async {
  final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
  if (ledger == null) {
    return null;
  }
  return MoneyLedgerScope.fromLedger(ledger);
});

final currentUserMoneyLedgerScopeValueProvider = Provider<MoneyLedgerScope?>((
  ref,
) {
  final ledger = ref.watch(currentUserCurrentLedgerValueProvider);
  if (ledger == null) {
    return null;
  }
  return MoneyLedgerScope.fromLedger(ledger);
});

final currentUserEffectiveTransactionLedgerValueProvider =
    Provider<MoneyLedgerEntity?>((ref) {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }

      final selectedLedgerId = ref.watch(currentMoneyLedgerIdProvider);
      final ledgers = ref
          .watch(currentUserMoneyLedgersProvider)
          .maybeWhen(data: (items) => items, orElse: () => null);
      if (ledgers == null || ledgers.isEmpty) {
        return null;
      }

      final selected = _findLedgerById(ledgers, selectedLedgerId);
      if (selected != null && selected.isFamily) {
        return selected;
      }

      for (final ledger in ledgers) {
        if (ledger.isPersonal) {
          return ledger;
        }
      }
      return ledgers.first;
    });

final currentUserEffectiveTransactionLedgerProvider =
    FutureProvider<MoneyLedgerEntity?>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }

      final selectedLedgerId = ref.watch(currentMoneyLedgerIdProvider);
      final ledgers = await ref.watch(currentUserMoneyLedgersProvider.future);
      if (ledgers.isEmpty) {
        return null;
      }

      final selected = _findLedgerById(ledgers, selectedLedgerId);
      if (selected != null && selected.isFamily) {
        return selected;
      }

      for (final ledger in ledgers) {
        if (ledger.isPersonal) {
          return ledger;
        }
      }
      return ledgers.first;
    });

final currentUserCurrentLedgerMembersProvider =
    StreamProvider.autoDispose<List<MoneyMemberEntity>>((ref) {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return Stream.value(const <MoneyMemberEntity>[]);
      }

      final ledger = ref.watch(currentUserCurrentLedgerValueProvider);
      if (ledger == null) {
        return Stream.value(const <MoneyMemberEntity>[]);
      }

      final controller = StreamController<List<MoneyMemberEntity>>();
      final subscription = ref
          .watch(moneyRepositoryProvider)
          .watchMembersForLedger(session.userId!, ledger.id)
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );
      ref.onDispose(() {
        subscription.cancel();
        controller.close();
      });
      return controller.stream;
    });

final moneyStatisticsFilterProvider =
    NotifierProvider<
      MoneyStatisticsFilterController,
      MoneyStatisticsFilterState
    >(MoneyStatisticsFilterController.new);

final moneyStatisticsContextProvider = FutureProvider<MoneyStatisticsContext>((
  ref,
) async {
  _watchMoneyDataRefresh(ref);
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    return const MoneyStatisticsContext.empty();
  }

  final userId = session.userId!;
  final repository = ref.watch(moneyRepositoryProvider);
  final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
  if (ledger == null) {
    return const MoneyStatisticsContext.empty();
  }
  final accounts = await repository.watchVisibleAccountsForUser(userId).first;

  return MoneyStatisticsContext(
    userId: userId,
    ledger: ledger,
    accounts: accounts,
  );
});

class MoneyStatisticsContext {
  const MoneyStatisticsContext({
    required this.userId,
    required this.ledger,
    required this.accounts,
  });

  const MoneyStatisticsContext.empty()
    : userId = null,
      ledger = null,
      accounts = const <MoneyAccountEntity>[];

  final String? userId;
  final MoneyLedgerEntity? ledger;
  final List<MoneyAccountEntity> accounts;

  bool get isReady => userId != null && ledger != null;
}

class MoneyStatisticsFilterState {
  const MoneyStatisticsFilterState({
    this.periodPreset = MoneyStatisticsPeriodPreset.thisMonth,
    this.accountId,
    this.accountType,
    this.paymentMethod,
    this.typeFocus = MoneyStatisticsTypeFocus.balance,
    this.anchorDate,
    this.customStart,
    this.customEnd,
  });

  final MoneyStatisticsPeriodPreset periodPreset;
  final String? accountId;
  final MoneyAccountType? accountType;
  final MoneyPaymentMethod? paymentMethod;
  final MoneyStatisticsTypeFocus typeFocus;
  final DateTime? anchorDate;
  final DateTime? customStart;
  final DateTime? customEnd;

  MoneyStatisticsFilterState copyWith({
    MoneyStatisticsPeriodPreset? periodPreset,
    String? accountId,
    bool clearAccountId = false,
    MoneyAccountType? accountType,
    bool clearAccountType = false,
    MoneyPaymentMethod? paymentMethod,
    bool clearPaymentMethod = false,
    MoneyStatisticsTypeFocus? typeFocus,
    DateTime? anchorDate,
    bool clearAnchorDate = false,
    DateTime? customStart,
    bool clearCustomStart = false,
    DateTime? customEnd,
    bool clearCustomEnd = false,
  }) {
    return MoneyStatisticsFilterState(
      periodPreset: periodPreset ?? this.periodPreset,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
      accountType: clearAccountType ? null : accountType ?? this.accountType,
      paymentMethod: clearPaymentMethod
          ? null
          : paymentMethod ?? this.paymentMethod,
      typeFocus: typeFocus ?? this.typeFocus,
      anchorDate: clearAnchorDate ? null : anchorDate ?? this.anchorDate,
      customStart: clearCustomStart ? null : customStart ?? this.customStart,
      customEnd: clearCustomEnd ? null : customEnd ?? this.customEnd,
    );
  }
}

class MoneyStatisticsFilterController
    extends Notifier<MoneyStatisticsFilterState> {
  @override
  MoneyStatisticsFilterState build() {
    ref.watch(
      authSessionControllerProvider.select((session) => session.userId),
    );
    return const MoneyStatisticsFilterState();
  }

  void setPeriod(MoneyStatisticsPeriodPreset value) {
    if (value != MoneyStatisticsPeriodPreset.custom) {
      state = state.copyWith(
        periodPreset: value,
        clearCustomStart: true,
        clearCustomEnd: true,
      );
    } else {
      final now = DateTime.now();
      state = state.copyWith(
        periodPreset: value,
        customStart: DateTime(now.year),
        customEnd: DateTime(now.year + 1),
      );
    }
  }

  void setCustomRange(DateTime start, DateTime end) {
    state = state.copyWith(
      periodPreset: MoneyStatisticsPeriodPreset.custom,
      customStart: start,
      customEnd: end,
    );
  }

  void setAccountId(String? value) {
    state = state.copyWith(accountId: value, clearAccountId: value == null);
  }

  void setTypeFocus(MoneyStatisticsTypeFocus value) {
    state = state.copyWith(typeFocus: value);
  }

  void setPaymentMethod(MoneyPaymentMethod? value) {
    state = state.copyWith(
      paymentMethod: value,
      clearPaymentMethod: value == null,
    );
  }

  void setAccountType(MoneyAccountType? value) {
    state = state.copyWith(accountType: value, clearAccountType: value == null);
  }
}

final moneySpendingAnalysisProvider = FutureProvider.autoDispose
    .family<MoneySpendingAnalysis, MoneySpendingAnalysisRequest>((
      ref,
      request,
    ) {
      _watchMoneyDataRefresh(ref);
      return ref
          .watch(moneyRepositoryProvider)
          .getSpendingAnalysisForUser(request.userId, request.query);
    });

class MoneySpendingAnalysisRequest {
  const MoneySpendingAnalysisRequest({
    required this.userId,
    required this.query,
  });

  final String userId;
  final MoneySpendingAnalysisQuery query;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoneySpendingAnalysisRequest &&
            userId == other.userId &&
            query.currentMonth == other.query.currentMonth &&
            query.ledgerId == other.query.ledgerId &&
            query.accountId == other.query.accountId &&
            query.accountType == other.query.accountType &&
            query.paymentMethod == other.query.paymentMethod &&
            query.baselineMonthCount == other.query.baselineMonthCount;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      query.currentMonth,
      query.ledgerId,
      query.accountId,
      query.accountType,
      query.paymentMethod,
      query.baselineMonthCount,
    );
  }
}

final moneyStatisticsProvider = FutureProvider.autoDispose
    .family<MoneyStatisticsSummary, MoneyStatisticsRequest>((ref, request) {
      _watchMoneyDataRefresh(ref);
      return ref
          .watch(moneyRepositoryProvider)
          .getStatisticsForUser(request.userId, request.query);
    });

class MoneyStatisticsRequest {
  const MoneyStatisticsRequest({required this.userId, required this.query});

  final String userId;
  final MoneyStatisticsQuery query;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MoneyStatisticsRequest &&
            userId == other.userId &&
            query.dateStart == other.query.dateStart &&
            query.dateEndExclusive == other.query.dateEndExclusive &&
            query.groupBy == other.query.groupBy &&
            query.ledgerId == other.query.ledgerId &&
            query.accountId == other.query.accountId &&
            query.accountType == other.query.accountType &&
            query.paymentMethod == other.query.paymentMethod &&
            query.typeFocus == other.query.typeFocus;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      query.dateStart,
      query.dateEndExclusive,
      query.groupBy,
      query.ledgerId,
      query.accountId,
      query.accountType,
      query.paymentMethod,
      query.typeFocus,
    );
  }
}

final moneyStatisticsInsightsProvider = FutureProvider.autoDispose
    .family<MoneyStatisticsInsights, MoneyStatisticsRequest>((ref, request) {
      _watchMoneyDataRefresh(ref);
      return ref
          .watch(moneyRepositoryProvider)
          .getStatisticsInsightsForUser(request.userId, request.query);
    });

final currentUserMoneyLedgerMembersProvider = StreamProvider.autoDispose
    .family<List<MoneyMemberEntity>, String>((ref, ledgerId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyMemberEntity>[];
        return;
      }

      yield* ref
          .watch(moneyRepositoryProvider)
          .watchMembersForLedger(session.userId!, ledgerId);
    });

MoneyLedgerEntity? _findLedgerById(
  List<MoneyLedgerEntity> ledgers,
  String? ledgerId,
) {
  if (ledgerId == null) {
    return null;
  }
  for (final ledger in ledgers) {
    if (ledger.id == ledgerId) {
      return ledger;
    }
  }
  return null;
}

MoneyLedgerEntity? _resolveCurrentLedgerFromList(
  List<MoneyLedgerEntity> ledgers,
  String? selectedLedgerId,
) {
  if (ledgers.isEmpty) {
    return null;
  }

  final selected = _findLedgerById(ledgers, selectedLedgerId);
  if (selected != null) {
    return selected;
  }

  for (final ledger in ledgers) {
    if (ledger.isPersonal) {
      return ledger;
    }
  }
  return ledgers.first;
}

final currentUserCategoryCatalogProvider = StreamProvider.autoDispose
    .family<MoneyCategoryCatalog, MoneyCategoryKind>((ref, kind) {
      // 使用 StreamController + ref.onDispose 避免 async* generator 在
      // provider dispose 后恢复时 ref.watch 抛 StateError。
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return Stream.value(const MoneyCategoryCatalog.empty());
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final controller = StreamController<MoneyCategoryCatalog>();

      final subscription = repository
          .watchCategoryCatalogForUser(session.userId!, kind)
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );

      ref.onDispose(() {
        subscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

final currentUserCategoryManagementCatalogProvider = StreamProvider.autoDispose
    .family<MoneyCategoryCatalog, MoneyCategoryKind>((ref, kind) {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return Stream.value(const MoneyCategoryCatalog.empty());
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final controller = StreamController<MoneyCategoryCatalog>();

      final subscription = repository
          .watchCategoryCatalogForUser(
            session.userId!,
            kind,
            includeDeleted: true,
          )
          .listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
          );

      ref.onDispose(() {
        subscription.cancel();
        controller.close();
      });

      return controller.stream;
    });

final currentUserPaymentMethodUsageRanksProvider =
    FutureProvider<Map<MoneyPaymentMethod, int>>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyPaymentMethod, int>{};
      }

      return ref
          .watch(moneyRepositoryProvider)
          .getPaymentMethodUsageRanksForUser(session.userId!);
    });

final currentUserBudgetsProvider = StreamProvider<List<MoneyBudgetEntity>>((
  ref,
) async* {
  _watchMoneyDataRefresh(ref);
  final session = ref.watch(authSessionControllerProvider);
  if (!session.isUnlocked || session.userId == null) {
    yield const <MoneyBudgetEntity>[];
    return;
  }

  final repository = ref.watch(moneyRepositoryProvider);
  final userId = session.userId!;
  final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
  if (ledger == null) {
    yield const <MoneyBudgetEntity>[];
    return;
  }

  await repository.refreshBudgetSnapshotsForUser(userId);
  yield* repository.watchBudgetsForUser(userId, ledgerId: ledger.id);
});

final currentUserBudgetAllocationsProvider = StreamProvider.autoDispose
    .family<List<MoneyBudgetAllocationEntity>, String>((ref, budgetId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyBudgetAllocationEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchBudgetAllocationsForUser(userId, budgetId);
    });

final currentUserBudgetSnapshotsProvider = StreamProvider.autoDispose
    .family<List<MoneyBudgetHistorySnapshotEntity>, String>((
      ref,
      budgetId,
    ) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyBudgetHistorySnapshotEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      await repository.ensureBudgetSnapshotForBudget(userId, budgetId);
      yield* repository.watchBudgetSnapshotsForUser(userId, budgetId: budgetId);
    });

final currentUserBudgetAllocationSnapshotsProvider = StreamProvider.autoDispose
    .family<List<MoneyBudgetAllocationHistorySnapshotEntity>, String>((
      ref,
      budgetId,
    ) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyBudgetAllocationHistorySnapshotEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      await repository.ensureBudgetSnapshotForBudget(userId, budgetId);
      yield* repository.watchBudgetAllocationSnapshotsForUser(userId, budgetId);
    });

final currentUserBillRemindersProvider =
    StreamProvider.autoDispose<List<MoneyBillReminderEntity>>((ref) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyBillReminderEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        yield const <MoneyBillReminderEntity>[];
        return;
      }

      yield* repository.watchBillRemindersForUser(userId, ledgerId: ledger.id);
    });

final currentUserAutoPostingTemplatesProvider =
    StreamProvider.autoDispose<List<MoneyAutoPostingTemplateEntity>>((
      ref,
    ) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyAutoPostingTemplateEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        yield const <MoneyAutoPostingTemplateEntity>[];
        return;
      }

      yield* repository.watchAutoPostingTemplatesForUser(
        userId,
        ledgerId: ledger.id,
      );
    });

final moneyBudgetHistoryTrendProvider = FutureProvider.autoDispose
    .family<List<MoneyBudgetHistoryTrendPoint>, String>((ref, ledgerId) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyBudgetHistoryTrendPoint>[];
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      return repository.getBudgetHistoryTrendForUser(userId, ledgerId);
    });

final moneyUpcomingCashFlowProvider = FutureProvider.autoDispose
    .family<MoneyUpcomingCashFlowSummary, String>((ref, ledgerId) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const MoneyUpcomingCashFlowSummary.empty();
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      return repository.getUpcomingCashFlowForUser(userId, ledgerId: ledgerId);
    });

final currentUserLatestReportProvider = FutureProvider.autoDispose
    .family<MoneyAnalysisReportEntity?, (String, String)>((ref, params) async {
      final (ledgerId, reportPeriod) = params;
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return null;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      return repository.getLatestReportForUser(userId, ledgerId, reportPeriod);
    });

final currentUserNetWorthTrendProvider = FutureProvider.autoDispose
    .family<List<MoneyNetWorthTrendPoint>, (String, int)>((ref, params) async {
      final (ledgerId, days) = params;
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyNetWorthTrendPoint>[];
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.captureAssetSnapshotsForUser(userId);
      return repository.getNetWorthTrendForUser(userId, days: days);
    });

final currentUserPendingReminderCenterItemsProvider =
    FutureProvider<List<MoneyReminderCenterItem>>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyReminderCenterItem>[];
      }

      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        return const <MoneyReminderCenterItem>[];
      }

      return ref
          .watch(moneyRepositoryProvider)
          .getPendingReminderCenterItems(session.userId!, ledgerId: ledger.id);
    });

final currentUserReminderCenterHistoryProvider =
    FutureProvider<List<MoneyReminderCenterItem>>((ref) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        return const <MoneyReminderCenterItem>[];
      }

      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        return const <MoneyReminderCenterItem>[];
      }

      return ref
          .watch(moneyRepositoryProvider)
          .getReminderCenterHistory(session.userId!, ledgerId: ledger.id);
    });
final currentUserInstallmentPlansProvider =
    StreamProvider.autoDispose<List<MoneyInstallmentPlanEntity>>((ref) async* {
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyInstallmentPlanEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      final ledger = await ref.watch(currentUserCurrentLedgerProvider.future);
      if (ledger == null) {
        yield const <MoneyInstallmentPlanEntity>[];
        return;
      }
      await repository.repairInstallmentPlanStatuses(
        userId,
        ledgerId: ledger.id,
      );
      yield* repository.watchInstallmentPlansForUser(
        userId,
        ledgerId: ledger.id,
      );
    });

final currentUserInstallmentDetailsProvider = StreamProvider.autoDispose
    .family<List<MoneyInstallmentDetailEntity>, String>((ref, planId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyInstallmentDetailEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchInstallmentDetailsForPlan(userId, planId);
    });

final currentUserTransactionProvider = FutureProvider.autoDispose
    .family<MoneyTransactionEntity, String>((ref, transactionId) async {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        throw const MoneyRepositoryException(
          MoneyRepositoryErrorCode.databaseReadFailed,
        );
      }

      final repository = ref.watch(moneyRepositoryProvider);
      await repository.ensureReadyForUser(session.userId!);
      return repository.getTransactionForUser(session.userId!, transactionId);
    });

final currentUserSplitRulesProvider = StreamProvider.autoDispose
    .family<List<MoneySplitRuleEntity>, String>((ref, ledgerId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneySplitRuleEntity>[];
        return;
      }

      yield* ref
          .watch(moneyRepositoryProvider)
          .watchSplitRulesForLedger(session.userId!, ledgerId);
    });

final currentUserMoneyMembersProvider =
    StreamProvider.autoDispose<List<MoneyMemberEntity>>((ref) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneyMemberEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchMembersForUser(userId);
    });

final currentUserSplitRecordsForTransactionProvider = StreamProvider.autoDispose
    .family<List<MoneySplitRecordEntity>, String>((ref, transactionId) async* {
      _watchMoneyDataRefresh(ref);
      final session = ref.watch(authSessionControllerProvider);
      if (!session.isUnlocked || session.userId == null) {
        yield const <MoneySplitRecordEntity>[];
        return;
      }

      final repository = ref.watch(moneyRepositoryProvider);
      final userId = session.userId!;
      await repository.ensureReadyForUser(userId);
      yield* repository.watchSplitRecordsForTransaction(userId, transactionId);
    });

final currentUserMoneyAccountActionsProvider =
    Provider<CurrentUserMoneyAccountActions>((ref) {
      return CurrentUserMoneyAccountActions(ref);
    });

final currentUserMoneyTransactionActionsProvider =
    Provider<CurrentUserMoneyTransactionActions>((ref) {
      return CurrentUserMoneyTransactionActions(ref);
    });

final moneyDataRefreshVersionProvider =
    NotifierProvider<MoneyDataRefreshVersionController, int>(
      MoneyDataRefreshVersionController.new,
    );

class MoneyDataRefreshVersionController extends Notifier<int> {
  @override
  int build() {
    return 0;
  }

  void bump() {
    state++;
  }
}

void _watchMoneyDataRefresh(Ref ref) {
  // StreamProvider.autoDispose 的 async* generator 在 dispose 后恢复时会抛异常。
  // Ref 失效时 ref.watch 会抛 Error，用 catch 安全降级。
  try {
    ref.watch(moneyDataRefreshVersionProvider);
  } catch (_) {
    // Provider 已 dispose，忽略。
  }
}

class CurrentUserBudgetAlertNotificationActions {
  CurrentUserBudgetAlertNotificationActions(this._ref);

  final Ref _ref;
  bool _running = false;
  bool _pending = false;

  Future<void> scanNow() async {
    if (_running) {
      // 扫描期间数据可能又变了（如刚记账），标记待重扫，结束后补一次，
      // 避免用旧预算数据扫描而漏掉通知。
      _pending = true;
      return;
    }
    _running = true;
    try {
      do {
        _pending = false;
        await _scanOnce();
      } while (_pending);
    } finally {
      _running = false;
    }
  }

  Future<void> _scanOnce() async {
    try {
      final session = _ref.read(authSessionControllerProvider);
      final userId = session.userId;
      if (!session.isUnlocked || userId == null || userId.isEmpty) {
        return;
      }

      final budgets = await _ref.read(currentUserBudgetsProvider.future);
      await _ref
          .read(moneyBudgetAlertNotificationServiceProvider)
          .scanAndNotify(userId: userId, budgets: budgets);
    } catch (error, stackTrace) {
      debugPrint('[budget-alert] 扫描失败: $error\n$stackTrace');
    }
  }
}

class CurrentUserBillReminderNotificationActions {
  CurrentUserBillReminderNotificationActions(this._ref);

  final Ref _ref;

  Future<void> scanNow() async {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      return;
    }

    try {
      final reminders = await _ref.read(
        currentUserBillRemindersProvider.future,
      );
      final accounts = await _ref.read(
        currentUserVisibleAccountsProvider.future,
      );
      final accountsById = {
        for (final account in accounts) account.id: account,
      };
      await _ref
          .read(moneyBillReminderNotificationServiceProvider)
          .scanAndNotify(
            userId: userId,
            reminders: reminders,
            accountsById: accountsById,
          );
    } catch (_) {
      // Notification scan must not break foreground data flows.
    }
  }
}

final moneyDataRefreshCoordinatorProvider =
    Provider<MoneyDataRefreshCoordinator>((ref) {
      return MoneyDataRefreshCoordinator(ref);
    });

class MoneyDataRefreshCoordinator {
  const MoneyDataRefreshCoordinator(this._ref);

  final Ref _ref;

  void refreshAfterLedgerChanged({String? ledgerId}) {
    _bumpTransactions();
  }

  void refreshAfterAccountChanged({String? ledgerId}) {
    _bumpTransactions();
  }

  void refreshAfterBudgetChanged({String? budgetId}) {
    _bumpTransactions();
    _scheduleBudgetAlertScan();
  }

  void refreshAfterReminderChanged() {
    _bumpTransactions();
    _scheduleBillReminderScan();
  }

  void refreshAfterInstallmentChanged() {
    _bumpTransactions();
  }

  void refreshAfterAutoPostingChanged() {
    _bumpTransactions();
  }

  void refreshAfterSplitChanged({String? transactionId, String? ledgerId}) {
    _bumpTransactions();
  }

  void refreshAfterSplitRuleChanged({String? ledgerId}) {
    _bumpTransactions();
  }

  void refreshAfterTransactionChanged({String? transactionId}) {
    _bumpTransactions();
    _scheduleBudgetAlertScan();
  }

  void refreshAllMoneyData({bool clearLedgerSelection = false}) {
    if (clearLedgerSelection) {
      _ref.read(currentMoneyLedgerIdProvider.notifier).clear();
    }
    _bumpTransactions();
    _scheduleBudgetAlertScan();
    _scheduleBillReminderScan();
  }

  void refreshHome() {
    _bumpTransactions();
  }

  void _bumpTransactions() {
    _ref.read(moneyDataRefreshVersionProvider.notifier).bump();
  }

  void _scheduleBudgetAlertScan() {
    unawaited(
      Future<void>.microtask(
        () => _ref
            .read(currentUserBudgetAlertNotificationActionsProvider)
            .scanNow(),
      ),
    );
  }

  void _scheduleBillReminderScan() {
    unawaited(
      Future<void>.microtask(
        () => _ref
            .read(currentUserBillReminderNotificationActionsProvider)
            .scanNow(),
      ),
    );
  }
}

final currentUserMoneyBudgetActionsProvider =
    Provider<CurrentUserMoneyBudgetActions>((ref) {
      return CurrentUserMoneyBudgetActions(ref);
    });

final currentUserMoneyBillReminderActionsProvider =
    Provider<CurrentUserMoneyBillReminderActions>((ref) {
      return CurrentUserMoneyBillReminderActions(ref);
    });

final currentUserMoneyAutoPostingActionsProvider =
    Provider<CurrentUserMoneyAutoPostingActions>((ref) {
      return CurrentUserMoneyAutoPostingActions(ref);
    });

final currentUserReminderCenterActionsProvider =
    Provider<CurrentUserReminderCenterActions>((ref) {
      return CurrentUserReminderCenterActions(ref);
    });
final currentUserMoneyInstallmentActionsProvider =
    Provider<CurrentUserMoneyInstallmentActions>((ref) {
      return CurrentUserMoneyInstallmentActions(ref);
    });

final currentUserMoneySplitActionsProvider =
    Provider<CurrentUserMoneySplitActions>((ref) {
      return CurrentUserMoneySplitActions(ref);
    });

final currentUserMoneyLedgerActionsProvider =
    Provider<CurrentUserMoneyLedgerActions>((ref) {
      return CurrentUserMoneyLedgerActions(ref);
    });

class CurrentUserMoneyLedgerActions {
  const CurrentUserMoneyLedgerActions(this._ref);

  final Ref _ref;

  Future<MoneyLedgerEntity> createLedger(MoneyLedgerDraft draft) async {
    final userId = _requireUnlockedUserId();
    final ledger = await _ref
        .read(moneyRepositoryProvider)
        .createLedger(userId, draft);
    _refresh();
    return ledger;
  }

  Future<void> addAccountToLedger({
    required String ledgerId,
    required String accountId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .addAccountToLedger(userId, ledgerId, accountId);
    _refresh(ledgerId: ledgerId);
  }

  Future<void> removeAccountFromLedger({
    required String ledgerId,
    required String accountId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .removeAccountFromLedger(userId, ledgerId, accountId);
    _refresh(ledgerId: ledgerId);
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh({String? ledgerId}) {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterLedgerChanged(ledgerId: ledgerId);
  }
}

class CurrentUserMoneyAccountActions {
  const CurrentUserMoneyAccountActions(this._ref);

  final Ref _ref;

  Future<void> createAccount(MoneyAccountDraft draft) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).createAccount(userId, draft);
    _refresh();
  }

  Future<void> updateAccount(MoneyAccountUpdate update) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).updateAccount(userId, update);
    _refresh();
  }

  Future<void> setAccountActive(String accountId, bool isActive) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .setAccountActive(userId, accountId, isActive);
    _refresh();
  }

  Future<void> deleteAccount(String accountId) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).deleteAccount(userId, accountId);
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh() {
    _ref.read(moneyDataRefreshCoordinatorProvider).refreshAfterAccountChanged();
  }
}

class CurrentUserMoneyBudgetActions {
  const CurrentUserMoneyBudgetActions(this._ref);

  final Ref _ref;

  Future<void> createBudget(MoneyBudgetDraft draft) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = draft.ledgerId ?? await _requireCurrentLedgerId();
    await _ref
        .read(moneyRepositoryProvider)
        .createBudget(userId, _draftWithLedger(draft, ledgerId));
    _refresh();
  }

  Future<void> updateBudget(MoneyBudgetUpdate update) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).updateBudget(userId, update);
    _refresh();
  }

  Future<void> createBudgetAllocation(MoneyBudgetAllocationDraft draft) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .createBudgetAllocation(userId, draft);
    _refresh(budgetId: draft.budgetId);
  }

  Future<void> updateBudgetAllocation(
    MoneyBudgetAllocationUpdate update,
  ) async {
    final userId = _requireUnlockedUserId();
    final allocation = await _ref
        .read(moneyRepositoryProvider)
        .updateBudgetAllocation(userId, update);
    _refresh(budgetId: allocation.budgetId);
  }

  Future<void> deleteBudgetAllocation(
    String allocationId,
    String budgetId,
  ) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .deleteBudgetAllocation(userId, allocationId);
    _refresh(budgetId: budgetId);
  }

  Future<void> deleteBudget(String budgetId) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).deleteBudget(userId, budgetId);
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh({String? budgetId}) {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterBudgetChanged(budgetId: budgetId);
  }

  Future<String> _requireCurrentLedgerId() async {
    final ledger = await _ref.read(currentUserCurrentLedgerProvider.future);
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  MoneyBudgetDraft _draftWithLedger(MoneyBudgetDraft draft, String ledgerId) {
    return MoneyBudgetDraft(
      name: draft.name,
      amountMinor: draft.amountMinor,
      ledgerId: ledgerId,
      scopeType: draft.scopeType,
      trackingType: draft.trackingType,
      periodType: draft.periodType,
      repeatInterval: draft.repeatInterval,
      categoryId: draft.categoryId,
      subCategoryId: draft.subCategoryId,
      accountId: draft.accountId,
      description: draft.description,
      currencyCode: draft.currencyCode,
      alertEnabled: draft.alertEnabled,
      alertThresholdPercent: draft.alertThresholdPercent,
      color: draft.color,
    );
  }
}

class CurrentUserReminderCenterActions {
  CurrentUserReminderCenterActions(this._ref);

  final Ref _ref;

  Future<void> complete(MoneyReminderCenterItem item) {
    return _setState(item, MoneyReminderCenterState.completed);
  }

  Future<void> ignore(MoneyReminderCenterItem item) {
    return _setState(item, MoneyReminderCenterState.ignored);
  }

  Future<void> snoozeOneDay(MoneyReminderCenterItem item) {
    final tomorrow = DateTime.now().toLocal().add(const Duration(days: 1));
    return _setState(
      item,
      MoneyReminderCenterState.snoozed,
      snoozedUntil: DateTime(tomorrow.year, tomorrow.month, tomorrow.day),
    );
  }

  Future<void> _setState(
    MoneyReminderCenterItem item,
    MoneyReminderCenterState state, {
    DateTime? snoozedUntil,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .setReminderCenterState(
          userId,
          item,
          state,
          snoozedUntil: snoozedUntil,
        );
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh() {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterReminderChanged();
  }
}

class CurrentUserMoneyBillReminderActions {
  CurrentUserMoneyBillReminderActions(this._ref);

  final Ref _ref;

  Future<void> createReminder(MoneyBillReminderDraft draft) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = await _requireCurrentLedgerId();
    await _ref
        .read(moneyRepositoryProvider)
        .createBillReminder(userId, _draftWithLedger(draft, ledgerId));
    _refresh();
  }

  Future<void> updateReminder(MoneyBillReminderUpdate update) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).updateBillReminder(userId, update);
    _refresh();
  }

  Future<void> setReminderStatus(
    String reminderId,
    MoneyBillReminderStatus status,
  ) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .setBillReminderStatus(userId, reminderId, status);
    _refresh();
  }

  Future<void> deleteReminder(String reminderId) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .deleteBillReminder(userId, reminderId);
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh() {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterReminderChanged();
  }

  Future<String> _requireCurrentLedgerId() async {
    final ledger = await _ref.read(currentUserCurrentLedgerProvider.future);
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  MoneyBillReminderDraft _draftWithLedger(
    MoneyBillReminderDraft draft,
    String ledgerId,
  ) {
    return MoneyBillReminderDraft(
      name: draft.name,
      amountMinor: draft.amountMinor,
      dueDate: draft.dueDate,
      remindBeforeDays: draft.remindBeforeDays,
      repeatPeriodType: draft.repeatPeriodType,
      repeatInterval: draft.repeatInterval,
      accountId: draft.accountId,
      ledgerId: ledgerId,
      categoryId: draft.categoryId,
      relatedTransactionId: draft.relatedTransactionId,
      sourceType: draft.sourceType,
      sourceKey: draft.sourceKey,
      amountSource: draft.amountSource,
      autoManaged: draft.autoManaged,
      currencyCode: draft.currencyCode,
      notes: draft.notes,
    );
  }
}

class CurrentUserMoneyAutoPostingActions {
  const CurrentUserMoneyAutoPostingActions(this._ref);

  final Ref _ref;

  Future<MoneyAutoPostingTemplateEntity> createTemplate(
    MoneyAutoPostingTemplateDraft draft,
  ) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = await _requireCurrentLedgerId();
    final template = await _ref
        .read(moneyRepositoryProvider)
        .createAutoPostingTemplate(userId, _draftWithLedger(draft, ledgerId));
    _refresh();
    return template;
  }

  Future<MoneyAutoPostingTemplateEntity> updateTemplate(
    MoneyAutoPostingTemplateUpdate update,
  ) async {
    final userId = _requireUnlockedUserId();
    final template = await _ref
        .read(moneyRepositoryProvider)
        .updateAutoPostingTemplate(userId, update);
    _refresh();
    return template;
  }

  Future<void> deleteTemplate(String templateId) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .deleteAutoPostingTemplate(userId, templateId);
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh() {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterAutoPostingChanged();
  }

  Future<String> _requireCurrentLedgerId() async {
    final ledger = await _ref.read(currentUserCurrentLedgerProvider.future);
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  MoneyAutoPostingTemplateDraft _draftWithLedger(
    MoneyAutoPostingTemplateDraft draft,
    String ledgerId,
  ) {
    return MoneyAutoPostingTemplateDraft(
      name: draft.name,
      type: draft.type,
      amountMinor: draft.amountMinor,
      currencyCode: draft.currencyCode,
      description: draft.description,
      notes: draft.notes,
      merchant: draft.merchant,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
      subCategoryId: draft.subCategoryId,
      paymentMethod: draft.paymentMethod,
      customPaymentMethodName: draft.customPaymentMethodName,
      actualPayerAccount: draft.actualPayerAccount,
      ledgerId: ledgerId,
      frequency: draft.frequency,
      dayOfMonth: draft.dayOfMonth,
      weekday: draft.weekday,
      timeOfDayMinutes: draft.timeOfDayMinutes,
      startsOn: draft.startsOn,
      endsOn: draft.endsOn,
      isActive: draft.isActive,
    );
  }
}

class CurrentUserMoneyInstallmentActions {
  const CurrentUserMoneyInstallmentActions(this._ref);

  final Ref _ref;

  Future<void> createInstallmentPlan(MoneyInstallmentPlanDraft draft) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = await _requireCurrentLedgerId();
    await _ref
        .read(moneyRepositoryProvider)
        .createInstallmentPlan(userId, _draftWithLedger(draft, ledgerId));
    _refresh();
  }

  Future<void> cancelInstallmentPlan(String planId) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .cancelInstallmentPlan(userId, planId);
    _refresh();
  }

  Future<void> postInstallmentDetail(String detailId) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .postInstallmentDetail(userId, detailId);
    _refresh();
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  Future<String> _requireCurrentLedgerId() async {
    final ledger = await _ref.read(currentUserCurrentLedgerProvider.future);
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  MoneyInstallmentPlanDraft _draftWithLedger(
    MoneyInstallmentPlanDraft draft,
    String ledgerId,
  ) {
    return MoneyInstallmentPlanDraft(
      ledgerId: ledgerId,
      accountId: draft.accountId,
      name: draft.name,
      categoryId: draft.categoryId,
      totalPrincipalMinor: draft.totalPrincipalMinor,
      totalInterestMinor: draft.totalInterestMinor,
      totalPeriods: draft.totalPeriods,
      firstDueDate: draft.firstDueDate,
      description: draft.description,
      subCategoryId: draft.subCategoryId,
      currencyCode: draft.currencyCode,
      notes: draft.notes,
    );
  }

  void _refresh() {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterInstallmentChanged();
  }
}

class CurrentUserMoneySplitActions {
  const CurrentUserMoneySplitActions(this._ref);

  final Ref _ref;

  Future<MoneySplitRuleEntity> createSplitRule(
    MoneySplitRuleDraft draft,
  ) async {
    final userId = _requireUnlockedUserId();
    final rule = await _ref
        .read(moneyRepositoryProvider)
        .createSplitRule(userId, draft);
    _refreshRule(ledgerId: draft.ledgerId);
    return rule;
  }

  Future<MoneySplitRuleEntity> updateSplitRule(
    MoneySplitRuleUpdate update, {
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    final rule = await _ref
        .read(moneyRepositoryProvider)
        .updateSplitRule(userId, update);
    _refreshRule(ledgerId: ledgerId);
    return rule;
  }

  Future<void> deleteSplitRule({
    required String ruleId,
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).deleteSplitRule(userId, ruleId);
    _refreshRule(ledgerId: ledgerId);
  }

  Future<MoneyMemberEntity> createMember(
    MoneyMemberDraft draft, {
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    final member = await _ref
        .read(moneyRepositoryProvider)
        .createMember(userId, draft, ledgerId: ledgerId);
    _refresh(ledgerId: ledgerId);
    return member;
  }

  Future<MoneyMemberEntity> updateMember(
    MoneyMemberUpdate update, {
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    final member = await _ref
        .read(moneyRepositoryProvider)
        .updateMember(userId, update, ledgerId: ledgerId);
    _refresh(ledgerId: ledgerId);
    return member;
  }

  Future<void> deleteMember({
    required String memberId,
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .deleteMember(userId, memberId, ledgerId: ledgerId);
    _refresh(ledgerId: ledgerId);
  }

  Future<MoneySplitRecordEntity> createSplitForTransaction(
    MoneySplitDraft draft,
  ) async {
    final userId = _requireUnlockedUserId();
    final split = await _ref
        .read(moneyRepositoryProvider)
        .createSplitForTransaction(userId, draft);
    _refresh(transactionId: draft.transactionId);
    return split;
  }

  Future<void> linkTransactionToLedger({
    required String transactionId,
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .linkTransactionToLedger(userId, transactionId, ledgerId);
    _refresh(transactionId: transactionId, ledgerId: ledgerId);
  }

  Future<void> unlinkTransactionFromLedger({
    required String transactionId,
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .unlinkTransactionFromLedger(userId, transactionId, ledgerId);
    _refresh(transactionId: transactionId, ledgerId: ledgerId);
  }

  Future<MoneySplitRecordEntity> replaceSplitForTransaction(
    MoneySplitDraft draft,
  ) async {
    final userId = _requireUnlockedUserId();
    final split = await _ref
        .read(moneyRepositoryProvider)
        .replaceSplitForTransaction(userId, draft);
    _refresh(transactionId: draft.transactionId, ledgerId: draft.ledgerId);
    return split;
  }

  Future<void> cancelSplitRecord({
    required String splitRecordId,
    required String transactionId,
    required String ledgerId,
  }) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .cancelSplitRecord(userId, splitRecordId);
    _refresh(transactionId: transactionId, ledgerId: ledgerId);
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  void _refresh({String? transactionId, String? ledgerId}) {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterSplitChanged(
          transactionId: transactionId,
          ledgerId: ledgerId,
        );
  }

  void _refreshRule({String? ledgerId}) {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterSplitRuleChanged(ledgerId: ledgerId);
  }
}

class CurrentUserMoneyTransactionActions {
  const CurrentUserMoneyTransactionActions(this._ref);

  final Ref _ref;

  Future<MoneyTransactionEntity> createTransaction(
    MoneyTransactionDraft draft, {
    bool rememberDefaults = true,
  }) async {
    final userId = _requireUnlockedUserId();
    final transaction = await _ref
        .read(moneyRepositoryProvider)
        .createTransaction(userId, draft);
    if (rememberDefaults) {
      await _rememberTransactionDefaults(userId, draft);
    }
    _refresh();
    return transaction;
  }

  Future<MoneyTransactionEntity> createTransactionWithSplit(
    MoneyTransactionDraft draft,
    MoneySplitConfigDraft splitConfig,
  ) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = splitConfig.ledgerId;
    final effectiveDraft = _draftWithLedger(draft, ledgerId);
    final effectiveSplitConfig = _splitConfigWithLedger(splitConfig, ledgerId);
    final transaction = await _ref
        .read(moneyRepositoryProvider)
        .createTransactionWithSplit(
          userId,
          effectiveDraft,
          effectiveSplitConfig,
        );
    await _rememberTransactionDefaults(userId, effectiveDraft);
    _refresh(transactionId: transaction.id);
    return transaction;
  }

  Future<void> createTransfer(MoneyTransferDraft draft) async {
    final userId = _requireUnlockedUserId();
    final ledgerId =
        draft.ledgerId ?? await _requireEffectiveTransactionLedgerId();
    await _ref
        .read(moneyRepositoryProvider)
        .createTransfer(userId, _transferDraftWithLedger(draft, ledgerId));
    _refresh();
  }

  Future<void> updateTransaction(MoneyTransactionUpdate update) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).updateTransaction(userId, update);
    _refresh();
  }

  Future<void> updateTransfer(MoneyTransferUpdate update) async {
    final userId = _requireUnlockedUserId();
    await _ref.read(moneyRepositoryProvider).updateTransfer(userId, update);
    _refresh();
  }

  Future<void> deleteTransaction(String transactionId) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .deleteTransaction(userId, transactionId);
    _refresh();
  }

  Future<void> recordTransactionRefund(
    String transactionId,
    int refundAmountMinor,
  ) async {
    final userId = _requireUnlockedUserId();
    await _ref
        .read(moneyRepositoryProvider)
        .recordTransactionRefund(userId, transactionId, refundAmountMinor);
    _refresh();
  }

  Future<MoneyTransactionPage> listTransactions(
    MoneyTransactionQuery query,
  ) async {
    final userId = _requireUnlockedUserId();
    final ledgerId = query.ledgerId ?? await _requireCurrentLedgerId();
    return _ref
        .read(moneyRepositoryProvider)
        .listTransactions(userId, _queryWithLedger(query, ledgerId));
  }

  String _requireUnlockedUserId() {
    final session = _ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (!session.isUnlocked || userId == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.databaseWriteFailed,
      );
    }

    return userId;
  }

  Future<String> _requireCurrentLedgerId() async {
    final ledger = await _ref.read(currentUserCurrentLedgerProvider.future);
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  Future<String> _requireEffectiveTransactionLedgerId() async {
    final ledger = await _ref.read(
      currentUserEffectiveTransactionLedgerProvider.future,
    );
    if (ledger == null) {
      throw const MoneyRepositoryException(
        MoneyRepositoryErrorCode.ledgerNotFound,
      );
    }
    return ledger.id;
  }

  Future<void> _rememberTransactionDefaults(
    String userId,
    MoneyTransactionDraft draft,
  ) async {
    if (draft.type != MoneyTransactionType.expense &&
        draft.type != MoneyTransactionType.income) {
      return;
    }
    await _ref
        .read(transactionEntryDefaultsStoreProvider)
        .saveDefaults(
          userId: userId,
          ledgerId: draft.ledgerId,
          type: draft.type,
          defaults: TransactionEntryDefaults(
            accountId: draft.accountId,
            categoryId: draft.categoryId,
            subCategoryId: draft.subCategoryId,
            paymentMethod: draft.paymentMethod,
          ),
        );
  }

  MoneyTransactionDraft _draftWithLedger(
    MoneyTransactionDraft draft,
    String ledgerId,
  ) {
    return MoneyTransactionDraft(
      type: draft.type,
      transactionAt: draft.transactionAt,
      amountMinor: draft.amountMinor,
      currencyCode: draft.currencyCode,
      description: draft.description,
      notes: draft.notes,
      merchant: draft.merchant,
      location: draft.location,
      accountId: draft.accountId,
      categoryId: draft.categoryId,
      subCategoryId: draft.subCategoryId,
      paymentMethod: draft.paymentMethod,
      customPaymentMethodName: draft.customPaymentMethodName,
      actualPayerAccount: draft.actualPayerAccount,
      ledgerId: ledgerId,
      tags: draft.tags,
    );
  }

  MoneySplitConfigDraft _splitConfigWithLedger(
    MoneySplitConfigDraft splitConfig,
    String ledgerId,
  ) {
    return MoneySplitConfigDraft(
      ledgerId: ledgerId,
      splitType: splitConfig.splitType,
      payerMemberId: splitConfig.payerMemberId,
      participants: splitConfig.participants,
      notes: splitConfig.notes,
    );
  }

  MoneyTransferDraft _transferDraftWithLedger(
    MoneyTransferDraft draft,
    String ledgerId,
  ) {
    return MoneyTransferDraft(
      transactionAt: draft.transactionAt,
      amountMinor: draft.amountMinor,
      currencyCode: draft.currencyCode,
      description: draft.description,
      notes: draft.notes,
      fromAccountId: draft.fromAccountId,
      toAccountId: draft.toAccountId,
      subCategoryId: draft.subCategoryId,
      paymentMethod: draft.paymentMethod,
      customPaymentMethodName: draft.customPaymentMethodName,
      ledgerId: ledgerId,
    );
  }

  MoneyTransactionQuery _queryWithLedger(
    MoneyTransactionQuery query,
    String ledgerId,
  ) {
    return MoneyTransactionQuery(
      page: query.page,
      pageSize: query.pageSize,
      type: query.type,
      accountId: query.accountId,
      categoryId: query.categoryId,
      subCategoryId: query.subCategoryId,
      paymentMethod: query.paymentMethod,
      merchant: query.merchant,
      dateStart: query.dateStart,
      dateEnd: query.dateEnd,
      keyword: query.keyword,
      ledgerId: ledgerId,
      budgetId: query.budgetId,
    );
  }

  void _refresh({String? transactionId}) {
    _ref
        .read(moneyDataRefreshCoordinatorProvider)
        .refreshAfterTransactionChanged(transactionId: transactionId);
  }
}
