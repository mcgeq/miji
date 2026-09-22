import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_section_entrance.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/user/providers/user_providers.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transaction_actions.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/application/home_preference_providers.dart';
import 'package:miji/features/home/presentation/home_alerts_strip.dart';
import 'package:miji/features/home/presentation/home_balance_hero_card.dart';
import 'package:miji/features/home/presentation/home_category_structure_panel.dart';
import 'package:miji/features/home/presentation/home_greeting_header.dart';
import 'package:miji/features/home/presentation/home_health_strip.dart';
import 'package:miji/features/home/presentation/home_insight_strip.dart';
import 'package:miji/features/home/presentation/home_onboarding_view.dart';
import 'package:miji/features/home/presentation/home_quick_actions_row.dart';
import 'package:miji/features/home/presentation/home_recent_transactions_panel.dart';
import 'package:miji/features/home/presentation/home_stat_tiles.dart';
import 'package:miji/features/home/presentation/home_weekly_trend_card.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 首页快捷动作（按使用频率排序）。
const _homeQuickActions = [
  MoneyQuickAction.expense,
  MoneyQuickAction.income,
  MoneyQuickAction.transfer,
  MoneyQuickAction.budget,
];

/// 双栏布局断点，与 [AppResponsive] 的 rail 断点解耦，
/// 保证内容区在平板上也不会挤成单列。
const _twoColumnBreakpoint = 840.0;

/// Riverpod 3 的 `AsyncValue` 只暴露 `value`，这里补一个显式的可空读取，
/// 避免每处都写 `asData?.value`。
extension HomeAsyncValueX<T> on AsyncValue<T> {
  T? get valueOrNull => asData?.value;
}

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      data: (_) => const Stack(
        children: [
          AppPageFrame(child: _HomeDashboard()),
          _HomeDataPreloader(),
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

/// 分阶段预加载首页数据，避免一次性并发太多查询。
class _HomeDataPreloader extends ConsumerStatefulWidget {
  const _HomeDataPreloader();

  @override
  ConsumerState<_HomeDataPreloader> createState() => _HomeDataPreloaderState();
}

class _HomeDataPreloaderState extends ConsumerState<_HomeDataPreloader> {
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
        ref.read(homeNetAssetSummaryProvider.future),
        ref.read(homeCategoryBudgetSummaryProvider.future),
        ref.read(homeStreakProvider.future),
        ref.read(homeInsightProvider.future),
      ]),
    );

    if (!mounted) {
      return;
    }

    if (ref.read(homeShowHealthStripProvider)) {
      await _ignoreErrors(ref.read(homeHealthHintProvider.future));
    }
  }

  Future<void> _ignoreErrors(Future<dynamic> future) async {
    try {
      await future;
    } catch (_) {
      // 首页应在后台预加载失败时保持可用。
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
    final launcher = MoneyQuickActionLauncher(
      context: context,
      ref: ref,
      ensureToast: () => FToast()..init(context),
    );

    final selectedMonth = ref.watch(homeMoneySelectedMonthProvider);
    final monthTransactions = ref.watch(homeMonthTransactionsProvider);
    final todaySummary = ref.watch(homeTodaySpendingSummaryProvider);
    final weeklyPoints = ref.watch(homeWeeklySpendingProvider);
    final trendWindow = ref.watch(homeTrendWindowProvider);
    final budgetSummary = ref.watch(homeMonthBudgetSummaryProvider);
    final categoryBudgets = ref.watch(homeCategoryBudgetSummaryProvider);
    final categoryType = ref.watch(homeCategoryStructureTypeProvider);
    final categoryItems = ref.watch(homeCategoryStructureProvider);
    final recentItems = ref.watch(homeRecentTransactionsProvider);
    final insight = ref.watch(homeInsightProvider);
    final netAsset = ref.watch(homeNetAssetSummaryProvider);
    final streak = ref.watch(homeStreakProvider);
    final reminders = ref.watch(currentUserPendingReminderCenterItemsProvider);
    final todayActions = ref.watch(todayActionItemsProvider);
    final accounts = ref.watch(currentUserVisibleAccountsProvider);
    final budgets = ref.watch(currentUserBudgetsProvider);
    final showHealthStrip = ref.watch(homeShowHealthStripProvider);
    final healthHint = showHealthStrip
        ? ref.watch(homeHealthHintProvider)
        : const AsyncValue<HomeHealthHint?>.data(null);
    final masked = ref.watch(homeMaskMoneyAmountsProvider);
    final showTodayAction = ref.watch(homeShowTodayActionProvider);
    final userDisplayName = ref
        .watch(currentUserProvider)
        .asData
        ?.value
        ?.displayName;

    if (todaySummary.hasError ||
        budgetSummary.hasError ||
        categoryItems.hasError ||
        recentItems.hasError ||
        monthTransactions.hasError) {
      return AppErrorState(
        title: '读取首页数据失败',
        onRetry: () =>
            ref.read(moneyDataRefreshCoordinatorProvider).refreshHome(),
      );
    }

    // 首次使用：账户与账单都为空时，用引导页替代整个 dashboard。
    final accountsValue = accounts.valueOrNull;
    final transactionsValue = monthTransactions.valueOrNull;
    final isFirstRun =
        accountsValue != null &&
        accountsValue.isEmpty &&
        transactionsValue != null &&
        transactionsValue.isEmpty &&
        !monthTransactions.isLoading;

    if (isFirstRun) {
      return SingleChildScrollView(
        child: AppSectionEntrance(
          child: HomeOnboardingView(
            hasAccount: false,
            hasBudget: (budgets.valueOrNull ?? const []).isNotEmpty,
            hasTransaction: false,
            onCreateAccount: () => launcher.run(MoneyQuickAction.account),
            onSetBudget: () => launcher.run(MoneyQuickAction.budget),
            onRecordTransaction: () => launcher.run(MoneyQuickAction.expense),
          ),
        ),
      );
    }

    final isLoading =
        todaySummary.isLoading ||
        budgetSummary.isLoading ||
        weeklyPoints.isLoading ||
        categoryItems.isLoading ||
        recentItems.isLoading;
    final isInitialLoading =
        isLoading &&
        !todaySummary.hasValue &&
        !budgetSummary.hasValue &&
        !monthTransactions.hasValue;

    if (isInitialLoading) {
      return const _HomeSkeleton();
    }

    final hero = HomeBalanceHeroCard(
      budget: budgetSummary.valueOrNull,
      today: todaySummary.valueOrNull,
      categoryBudgets: categoryBudgets.valueOrNull,
      isLoading: budgetSummary.isLoading || todaySummary.isLoading,
      masked: masked,
      onTapBudget: () => launcher.run(MoneyQuickAction.budget),
    );

    final quickActions = HomeQuickActionsRow(
      actions: _homeQuickActions,
      onAction: launcher.run,
    );

    final insightStrip = HomeInsightStrip(
      insight: insight.valueOrNull,
      onSelectTarget: (target) => _openInsightTarget(context, target),
    );

    final alerts = HomeAlertsStrip(
      items: reminders.valueOrNull ?? const [],
      isLoading: reminders.isLoading,
      onOpenAll: () => _openRemindersPage(context),
      maxItems: 2,
    );

    final weeklyTrend = HomeWeeklyTrendCard(
      points: weeklyPoints.valueOrNull ?? const [],
      window: trendWindow,
      selectedMonth: selectedMonth,
      dailyAverageMinor:
          todaySummary.valueOrNull?.dailyAverageExpenseMinor ?? 0,
      currencyCode: todaySummary.valueOrNull?.currencyCode ?? 'CNY',
      isLoading: weeklyPoints.isLoading,
      masked: masked,
      onWeekChanged: (offset) => _onWeekChanged(ref, offset),
    );

    final categoryPanel = HomeCategoryStructurePanel(
      type: categoryType,
      onTypeChanged: (value) =>
          ref.read(homeCategoryStructureTypeProvider.notifier).set(value),
      items: categoryItems.valueOrNull ?? const [],
      isLoading: categoryItems.isLoading,
    );

    final recentPanel = HomeRecentTransactionsPanel(
      items: recentItems.valueOrNull ?? const [],
      isLoading: recentItems.isLoading,
      onOpenAll: () => _openTransactionsPage(context),
      onOpenItem: (id) => _openTransactionDetail(context, ref, id),
      onRecordTransaction: () => launcher.run(MoneyQuickAction.expense),
    );

    final healthHintValue = healthHint.valueOrNull;
    final healthStrip = healthHintValue == null
        ? null
        : HomeHealthStrip(
            hint: healthHintValue,
            onTap: () => context.go(AppRoutes.health),
          );

    final todayActionTile = showTodayAction
        ? HomeTodayActionTile(
            view: todayActions.valueOrNull,
            isLoading: todayActions.isLoading,
            onTap: () => context.push(AppRoutes.gtd),
          )
        : null;

    final netAssetTile = HomeNetAssetTile(
      summary: netAsset.valueOrNull,
      isLoading: netAsset.isLoading,
      onTap: () => _openOverview(context),
    );

    final greeting = HomeGreetingHeader(
      userDisplayName: userDisplayName,
      streak: streak.valueOrNull,
    );

    final quote = HomeQuoteFooter();

    final hasAlerts =
        reminders.isLoading || (reminders.valueOrNull ?? const []).isNotEmpty;

    return SingleChildScrollView(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoColumn = constraints.maxWidth >= _twoColumnBreakpoint;

          if (!twoColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(0, greeting),
                _gap,
                _section(1, hero),
                _gap,
                _section(2, quickActions),
                _gap,
                _section(3, insightStrip),
                if (hasAlerts) ...[_gap, _section(4, alerts)],
                _gap,
                _section(
                  5,
                  Row(
                    children: [
                      if (todayActionTile != null)
                        Expanded(child: todayActionTile),
                      if (todayActionTile != null) const SizedBox(width: 12),
                      Expanded(child: netAssetTile),
                    ],
                  ),
                ),
                if (healthStrip != null) ...[_gap, _section(6, healthStrip)],
                _gap,
                _section(7, weeklyTrend),
                _gap,
                _section(8, categoryPanel),
                _gap,
                _section(9, recentPanel),
                const SizedBox(height: 8),
                quote,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(0, greeting),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _section(1, hero),
                        _gap,
                        _section(2, quickActions),
                        _gap,
                        _section(3, insightStrip),
                        _gap,
                        _section(4, weeklyTrend),
                        _gap,
                        _section(5, recentPanel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasAlerts) ...[_section(6, alerts), _gap],
                        if (todayActionTile != null) ...[
                          _section(7, todayActionTile),
                          _gap,
                        ],
                        _section(8, netAssetTile),
                        _gap,
                        if (healthStrip != null) ...[
                          _section(9, healthStrip),
                          _gap,
                        ],
                        _section(10, categoryPanel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              quote,
            ],
          );
        },
      ),
    );
  }

  static const _gap = SizedBox(height: 12);

  Widget _section(int index, Widget child) {
    return AppSectionEntrance(
      delay: Duration(milliseconds: 40 + index * 15),
      child: child,
    );
  }

  /// 切换选中的周。
  ///
  /// 这里**只改周，不改月份**。旧实现会在「第 N 周的中心日落到下个月」时
  /// 顺手把选中月份切走，而新月份（尤其是未来月份）没有数据，用户会以为
  /// 数据丢了。周窗口现在按月份切分，永远不会跨月切换。
  void _onWeekChanged(WidgetRef ref, int offset) {
    ref.read(homeWeekOffsetProvider.notifier).set(offset);
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

  void _openInsightTarget(BuildContext context, HomeInsightTarget target) {
    switch (target) {
      case HomeInsightTarget.transactions:
        _openTransactionsPage(context);
      case HomeInsightTarget.categories:
        _openBookkeepingSection(context, 'categories');
      case HomeInsightTarget.budgets:
        _openBookkeepingSection(context, 'budgets');
    }
  }

  void _openBookkeepingSection(BuildContext context, String section) {
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': section},
      ).toString(),
    );
  }

  void _openOverview(BuildContext context) {
    // 记账页已经没有 overview 面板（职责已整体上收到首页），之前这里拼的
    // `?section=overview` 会静静地回落到账户页。直接指向账户面板。
    _openBookkeepingSection(context, 'accounts');
  }

  Future<void> _openTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final transactions =
        ref.read(homeMonthTransactionsProvider).valueOrNull ??
        const <MoneyTransactionEntity>[];
    final transaction = _transactionById(transactions, id);
    if (transaction == null) {
      return;
    }

    Future<void> refreshHome() async {
      ref.read(moneyDataRefreshCoordinatorProvider).refreshHome();
    }

    MoneyTransactionActions actions() {
      return MoneyTransactionActions(
        context: context,
        ref: ref,
        ensureToast: () => FToast()..init(context),
        isMounted: () => context.mounted,
        onChanged: refreshHome,
      );
    }

    await showTransactionDetailProviderDialog(
      context: context,
      transaction: transaction,
      onEdit: transaction.isInstallmentPosting
          ? null
          : () => unawaited(actions().edit(transaction)),
      onDelete: transaction.isInstallmentPosting
          ? null
          : () => unawaited(actions().delete(transaction)),
      onRefund:
          transaction.isInstallmentPosting ||
              transaction.type != MoneyTransactionType.expense ||
              transaction.status != MoneyTransactionStatus.completed ||
              transaction.amountMinor <= transaction.refundAmountMinor
          ? null
          : () => unawaited(actions().refund(transaction)),
    );
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
}

/// 首屏骨架：高度固定，避免数据回来时整页重排。
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 168, height: 24),
              Spacer(),
              _SkeletonBox(width: 80, height: 24, radius: 999),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SkeletonBox(height: 78)),
              SizedBox(width: 8),
              Expanded(child: _SkeletonBox(height: 78)),
              SizedBox(width: 8),
              Expanded(child: _SkeletonBox(height: 78)),
              SizedBox(width: 8),
              Expanded(child: _SkeletonBox(height: 78)),
            ],
          ),
          SizedBox(height: 12),
          _SkeletonBox(height: 232),
          SizedBox(height: 12),
          _SkeletonBox(height: 76),
          SizedBox(height: 12),
          _SkeletonBox(height: 180),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, this.radius = 16});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
