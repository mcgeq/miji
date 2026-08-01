import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_section_entrance.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/user/providers/user_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transaction_actions.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/presentation/home_category_structure_panel.dart';
import 'package:miji/features/home/presentation/home_dashboard_greeting.dart';
import 'package:miji/features/home/presentation/home_month_budget_card.dart';
import 'package:miji/features/home/presentation/home_recent_transactions_panel.dart';
import 'package:miji/features/home/presentation/home_today_spending_card.dart';
import 'package:miji/features/home/presentation/home_urgent_reminders_panel.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (_) => const Stack(
        children: [
          AppPageFrame(child: _HomeDashboard()),
          _HomeMoneyDataPreloader(),
        ],
      ),
      loading: () =>
          const AppPageFrame(child: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => AppPageFrame(
        child: AppErrorState(
          title: '读取当前用户失败',
          onRetry: () => ref.invalidate(currentUserProvider),
        ),
      ),
    );
  }
}

class _HomeMoneyDataPreloader extends ConsumerStatefulWidget {
  const _HomeMoneyDataPreloader();

  @override
  ConsumerState<_HomeMoneyDataPreloader> createState() =>
      _HomeMoneyDataPreloaderState();
}

class _HomeMoneyDataPreloaderState
    extends ConsumerState<_HomeMoneyDataPreloader> {
  @override
  void initState() {
    super.initState();
    unawaited(_preload());
  }

  Future<void> _preload() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }

    await _ignoreErrors(
      Future.wait([
        ref.read(currentUserMoneyLedgersProvider.future),
        ref.read(currentUserCurrentLedgerProvider.future),
        ref.read(currentUserVisibleAccountsProvider.future),
        ref.read(
          currentUserCategoryCatalogProvider(MoneyCategoryKind.expense).future,
        ),
        ref.read(
          currentUserCategoryCatalogProvider(MoneyCategoryKind.income).future,
        ),
      ]),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }

    await _ignoreErrors(
      Future.wait([
        ref.read(currentUserBudgetsProvider.future),
        ref.read(homeMonthTransactionsProvider.future),
        ref.read(homeTodaySpendingSummaryProvider.future),
        ref.read(homeMonthBudgetSummaryProvider.future),
        ref.read(homeCategoryStructureProvider.future),
        ref.read(homeRecentTransactionsProvider.future),
      ]),
    );
  }

  Future<void> _ignoreErrors(Future<dynamic> future) async {
    try {
      await future;
    } catch (_) {
      // Home should stay responsive even if background preloading fails.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _HomeDashboard extends ConsumerWidget {
  const _HomeDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedMonth = ref.watch(homeMoneySelectedMonthProvider);
    final monthTransactions = ref.watch(homeMonthTransactionsProvider);
    final todaySummary = ref.watch(homeTodaySpendingSummaryProvider);
    final weeklyPoints = ref.watch(homeWeeklySpendingProvider);
    final weekOffset = ref.watch(homeWeekOffsetProvider);
    final weekCount = ref.watch(homeWeeklyWeekCountProvider);
    final budgetSummary = ref.watch(homeMonthBudgetSummaryProvider);
    final categoryType = ref.watch(homeCategoryStructureTypeProvider);
    final categoryItems = ref.watch(homeCategoryStructureProvider);
    final recentItems = ref.watch(homeRecentTransactionsProvider);
    final reminderItems = ref.watch(
      currentUserPendingReminderCenterItemsProvider,
    );
    final currentUser = ref.watch(currentUserProvider);
    final userDisplayName = currentUser.asData?.value?.displayName;
    final hasLoading =
        monthTransactions.maybeWhen(loading: () => true, orElse: () => false) ||
        todaySummary.maybeWhen(loading: () => true, orElse: () => false) ||
        weeklyPoints.maybeWhen(loading: () => true, orElse: () => false) ||
        budgetSummary.maybeWhen(loading: () => true, orElse: () => false) ||
        categoryItems.maybeWhen(loading: () => true, orElse: () => false) ||
        recentItems.maybeWhen(loading: () => true, orElse: () => false) ||
        reminderItems.maybeWhen(loading: () => true, orElse: () => false);

    if (monthTransactions.hasError ||
        todaySummary.hasError ||
        budgetSummary.hasError ||
        categoryItems.hasError ||
        recentItems.hasError) {
      return AppErrorState(
        title: '读取首页数据失败',
        onRetry: () {
          ref.read(moneyDataRefreshCoordinatorProvider).refreshHome();
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 840;
        final todayCard = HomeTodaySpendingCard(
          selectedMonth: selectedMonth,
          weeklyPoints: weeklyPoints.maybeWhen(
            data: (value) => value,
            orElse: () => null,
          ),
          summary: todaySummary.maybeWhen(
            data: (value) => value,
            orElse: () => null,
          ),
          isLoading:
              todaySummary.maybeWhen(
                loading: () => true,
                orElse: () => false,
              ) ||
              weeklyPoints.maybeWhen(loading: () => true, orElse: () => false),
          weekOffset: weekOffset,
          totalWeeks: weekCount,
          onWeekChanged: (offset) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final isCurrentMonth =
                selectedMonth.year == now.year &&
                selectedMonth.month == now.month;

            DateTime centerDay;
            if (isCurrentMonth) {
              centerDay = today
                  .subtract(const Duration(days: 3))
                  .add(Duration(days: offset * 7));
            } else {
              final monthStartMonday = selectedMonth.subtract(
                Duration(days: selectedMonth.weekday - 1),
              );
              centerDay = monthStartMonday
                  .add(const Duration(days: 3))
                  .add(Duration(days: offset * 7));
            }

            if (centerDay.month != selectedMonth.month ||
                centerDay.year != selectedMonth.year) {
              ref
                  .read(homeMoneySelectedMonthProvider.notifier)
                  .set(DateTime(centerDay.year, centerDay.month));
              return;
            }

            ref.read(homeWeekOffsetProvider.notifier).set(offset);
          },
        );
        final budgetCard = HomeMonthBudgetCard(
          summary: budgetSummary.maybeWhen(
            data: (value) => value,
            orElse: () => null,
          ),
          isLoading: budgetSummary.maybeWhen(
            loading: () => true,
            orElse: () => false,
          ),
          onCreateBudget: () {
            unawaited(_openBudgetDialog(context, ref));
          },
        );
        final greeting = HomeDashboardGreeting(
          userDisplayName: userDisplayName,
        );
        final categoryPanel = HomeCategoryStructurePanel(
          type: categoryType,
          onTypeChanged: (value) {
            ref.read(homeCategoryStructureTypeProvider.notifier).set(value);
          },
          items: categoryItems.maybeWhen(
            data: (items) => items,
            orElse: () => const [],
          ),
          isLoading: categoryItems.maybeWhen(
            loading: () => true,
            orElse: () => false,
          ),
        );
        final urgentRemindersPanel = HomeUrgentRemindersPanel(
          items: reminderItems.maybeWhen(
            data: (items) => items.take(3).toList(growable: false),
            orElse: () => const [],
          ),
          isLoading: reminderItems.maybeWhen(
            loading: () => true,
            orElse: () => false,
          ),
          onOpenAll: () => _openRemindersPage(context),
        );
        final recentPanel = HomeRecentTransactionsPanel(
          items: recentItems.maybeWhen(
            data: (items) => items,
            orElse: () => const [],
          ),
          isLoading: recentItems.maybeWhen(
            loading: () => true,
            orElse: () => false,
          ),
          onOpenAll: () => _openTransactionsPage(context),
          onOpenItem: (id) {
            final transaction = _transactionById(
              monthTransactions.maybeWhen(
                data: (items) => items,
                orElse: () => const <MoneyTransactionEntity>[],
              ),
              id,
            );
            if (transaction != null) {
              unawaited(_showTransactionDetail(context, ref, transaction));
            }
          },
        );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasLoading) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 8),
              ],
              if (compact) ...[
                AppSectionEntrance(
                  delay: const Duration(milliseconds: 40),
                  child: greeting,
                ),
                const SizedBox(height: 12),
                AppSectionEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: todayCard,
                ),
                const SizedBox(height: 12),
                AppSectionEntrance(
                  delay: const Duration(milliseconds: 100),
                  child: budgetCard,
                ),
                if (reminderItems.maybeWhen(
                  data: (items) => items.isNotEmpty,
                  loading: () => true,
                  orElse: () => false,
                )) ...[
                  const SizedBox(height: 12),
                  AppSectionEntrance(
                    delay: const Duration(milliseconds: 115),
                    child: urgentRemindersPanel,
                  ),
                ],
                const SizedBox(height: 12),
                AppSectionEntrance(
                  delay: const Duration(milliseconds: 130),
                  child: categoryPanel,
                ),
                const SizedBox(height: 12),
                AppSectionEntrance(
                  delay: const Duration(milliseconds: 160),
                  child: recentPanel,
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSectionEntrance(
                            delay: const Duration(milliseconds: 40),
                            child: greeting,
                          ),
                          const SizedBox(height: 12),
                          AppSectionEntrance(
                            delay: const Duration(milliseconds: 100),
                            child: todayCard,
                          ),
                          const SizedBox(height: 12),
                          AppSectionEntrance(
                            delay: const Duration(milliseconds: 160),
                            child: recentPanel,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSectionEntrance(
                            delay: const Duration(milliseconds: 70),
                            child: budgetCard,
                          ),
                          if (reminderItems.maybeWhen(
                            data: (items) => items.isNotEmpty,
                            loading: () => true,
                            orElse: () => false,
                          )) ...[
                            const SizedBox(height: 12),
                            AppSectionEntrance(
                              delay: const Duration(milliseconds: 115),
                              child: urgentRemindersPanel,
                            ),
                          ],
                          const SizedBox(height: 12),
                          AppSectionEntrance(
                            delay: const Duration(milliseconds: 130),
                            child: categoryPanel,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openRemindersPage(BuildContext context) {
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': 'reminders'},
      ).toString(),
    );
  }

  void _openTransactionsPage(BuildContext context) {
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': 'transactions'},
      ).toString(),
    );
  }

  Future<void> _openBudgetDialog(BuildContext context, WidgetRef ref) async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const BudgetFormDialog(),
    );
    if (!context.mounted || result is! MoneyBudgetDraft) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyBudgetActionsProvider)
          .createBudget(result);
      if (!context.mounted) return;
      AppToast.success(_ensureToast(context), context, '预算已创建');
    } catch (error) {
      if (!context.mounted) return;
      AppToast.error(
        _ensureToast(context),
        context,
        _errorText(error, '创建预算失败'),
      );
    }
  }

  Future<void> _showTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    MoneyTransactionEntity transaction,
  ) async {
    Future<void> refreshHome() async {
      ref.read(moneyDataRefreshCoordinatorProvider).refreshHome();
    }

    MoneyTransactionActions actions() {
      return MoneyTransactionActions(
        context: context,
        ref: ref,
        ensureToast: () => _ensureToast(context),
        isMounted: () => context.mounted,
        onChanged: refreshHome,
      );
    }

    return showTransactionDetailProviderDialog(
      context: context,
      transaction: transaction,
      onEdit: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(actions().edit(transaction));
            },
      onDelete: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(actions().delete(transaction));
            },
      onRefund:
          transaction.isInstallmentPosting ||
              transaction.type != MoneyTransactionType.expense ||
              transaction.status != MoneyTransactionStatus.completed ||
              transaction.amountMinor <= transaction.refundAmountMinor
          ? null
          : () {
              unawaited(actions().refund(transaction));
            },
    );
  }

  FToast _ensureToast(BuildContext context) {
    return FToast()..init(context);
  }

  MoneyTransactionEntity? _transactionById(
    List<MoneyTransactionEntity> transactions,
    String id,
  ) {
    for (final transaction in transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }
    return null;
  }

  String _errorText(Object error, String fallback) {
    if (error is! MoneyRepositoryException) {
      return fallback;
    }
    return switch (error.code) {
      MoneyRepositoryErrorCode.insufficientFunds => '账户余额不足',
      MoneyRepositoryErrorCode.invalidTransferAccounts => '转账账户不能相同',
      MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额',
      MoneyRepositoryErrorCode.ledgerNotFound => '账本不可用',
      _ => fallback,
    };
  }
}
