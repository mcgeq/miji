import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_page_toolbar.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/presentation/auto_posting/money_auto_postings_section.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_accounts_section.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/money_budgets_section.dart';
import 'package:miji/features/bookkeeping/presentation/categories/money_categories_section.dart';
import 'package:miji/features/bookkeeping/presentation/installments/money_installments_section.dart';
import 'package:miji/features/bookkeeping/presentation/ledgers/ledger_selector.dart';
import 'package:miji/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_statistics_section.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transactions_section.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class BookkeepingPage extends StatefulWidget {
  const BookkeepingPage({
    super.key,
    this.initialSection,
    this.initialAccountId,
  });

  final String? initialSection;
  final String? initialAccountId;

  @override
  State<BookkeepingPage> createState() => _BookkeepingPageState();
}

class _BookkeepingPageState extends State<BookkeepingPage> {
  _BookkeepingPanel _selectedPanel = _BookkeepingPanel.accounts;
  final Set<_BookkeepingPanel> _loadedPanels = <_BookkeepingPanel>{};
  MoneyTransactionQuery _transactionQuery = const MoneyTransactionQuery();
  MoneyTransactionFilterContext? _transactionFilterContext;

  @override
  void initState() {
    super.initState();
    _selectedPanel = _panelFromSection(widget.initialSection);
    _applyInitialTransactionQuery();
    _loadedPanels.add(_selectedPanel);
  }

  @override
  void didUpdateWidget(covariant BookkeepingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection ||
        oldWidget.initialAccountId != widget.initialAccountId) {
      _selectedPanel = _panelFromSection(widget.initialSection);
      _applyInitialTransactionQuery();
      _loadedPanels.add(_selectedPanel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPageLedgerSelector = !AppResponsive.of(context).isCompact;
    final panelSelector = AppSlidingSegmentedControl<_BookkeepingPanel>(
      minSegmentWidth: 44,
      showTrack: false,
      showLabels: false,
      value: _selectedPanel,
      segments: const [
        AppSlidingSegment(
          value: _BookkeepingPanel.accounts,
          icon: Icons.account_balance_wallet_rounded,
          label: '账户',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.transactions,
          icon: Icons.receipt_long_rounded,
          label: '流水',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.statistics,
          icon: Icons.query_stats_rounded,
          label: '统计',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.categories,
          icon: Icons.category_rounded,
          label: '分类',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.budgets,
          icon: Icons.flag_rounded,
          label: '预算',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.installments,
          icon: Icons.calendar_month_rounded,
          label: '分期',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.autoPosting,
          icon: Icons.event_repeat_rounded,
          label: '自动记账',
        ),
        AppSlidingSegment(
          value: _BookkeepingPanel.reminders,
          icon: Icons.notifications_active_rounded,
          label: '提醒',
        ),
      ],
      onChanged: (panel) {
        _selectPanel(panel);
      },
    );

    return Stack(
      children: [
        AppPageFrame(
          maxWidth: 1280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageToolbar(
                showSurface: false,
                primary: showPageLedgerSelector
                    ? const CurrentLedgerSelector()
                    : panelSelector,
                secondary: showPageLedgerSelector ? panelSelector : null,
              ),
              const SizedBox(height: 18),
              Expanded(
                child: _LazyBookkeepingPanelStack(
                  selectedPanel: _selectedPanel,
                  loadedPanels: _loadedPanels,
                  panelBuilder: _buildPanelChild,
                ),
              ),
              const _BookkeepingDataPreloader(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPanelChild(_BookkeepingPanel panel) {
    return switch (panel) {
      _BookkeepingPanel.accounts => MoneyAccountsSection(
        onViewTransactions: _showAccountTransactions,
      ),
      _BookkeepingPanel.transactions => Consumer(
        builder: (context, ref, child) {
          return MoneyTransactionsSection(
            initialQuery: _transactionQuery,
            filterContext: _effectiveTransactionFilterContext(ref),
          );
        },
      ),
      _BookkeepingPanel.statistics => MoneyStatisticsSection(
        onOpenTransactions: _showTransactionsFromStatistics,
      ),
      _BookkeepingPanel.categories => const MoneyCategoriesSection(),
      _BookkeepingPanel.budgets => MoneyBudgetsSection(
        onViewTransactions: _showBudgetTransactions,
      ),
      _BookkeepingPanel.installments => const MoneyInstallmentsSection(),
      _BookkeepingPanel.autoPosting => const MoneyAutoPostingsSection(),
      _BookkeepingPanel.reminders => const MoneyReminderCenterSection(),
    };
  }

  void _selectPanel(_BookkeepingPanel panel) {
    setState(() {
      _selectedPanel = panel;
      _loadedPanels.add(panel);
    });
  }

  void _showAccountTransactions(MoneyAccountEntity account) {
    _showTransactions(MoneyTransactionQuery(accountId: account.id));
  }

  void _showBudgetTransactions(MoneyBudgetEntity budget) {
    _showTransactions(
      MoneyTransactionQuery(
        type: budget.isIncomeTarget
            ? MoneyTransactionType.income
            : MoneyTransactionType.expense,
        accountId: budget.accountId,
        categoryId: budget.categoryId,
        subCategoryId: budget.subCategoryId,
        dateStart: budget.periodStart,
        dateEnd: budget.periodEnd,
        ledgerId: budget.ledgerId,
        budgetId: budget.id,
      ),
    );
  }

  void _showAllTransactions() {
    _showTransactions(const MoneyTransactionQuery());
  }

  void _showTransactions(
    MoneyTransactionQuery query, {
    MoneyTransactionFilterContext? context,
  }) {
    setState(() {
      _selectedPanel = _BookkeepingPanel.transactions;
      _loadedPanels.add(_BookkeepingPanel.transactions);
      _transactionQuery = query;
      _transactionFilterContext = context;
    });
  }

  void _showTransactionsFromStatistics(
    MoneyTransactionQuery query,
    String title,
    String subtitle,
    String? contextLabel,
  ) {
    if (contextLabel == null || _isAccountOnlyStatisticsQuery(query)) {
      _showTransactions(query);
      return;
    }

    _showTransactions(
      query,
      context: MoneyTransactionFilterContext(
        title: title,
        subtitle: subtitle,
        contextLabel: contextLabel,
        onClear: _showAllTransactions,
      ),
    );
  }

  bool _isAccountOnlyStatisticsQuery(MoneyTransactionQuery query) {
    return query.accountId != null &&
        query.type == null &&
        query.categoryId == null &&
        query.subCategoryId == null &&
        query.paymentMethod == null &&
        query.merchant == null &&
        query.dateStart == null &&
        query.dateEnd == null &&
        query.keyword == null &&
        query.budgetId == null;
  }

  void _applyInitialTransactionQuery() {
    if (_panelFromSection(widget.initialSection) !=
        _BookkeepingPanel.transactions) {
      return;
    }

    final accountId = widget.initialAccountId;
    if (accountId == null) {
      _transactionQuery = const MoneyTransactionQuery();
      _transactionFilterContext = null;
      return;
    }

    _transactionQuery = MoneyTransactionQuery(accountId: accountId);
    _transactionFilterContext = null;
  }

  MoneyTransactionFilterContext? _effectiveTransactionFilterContext(
    WidgetRef ref,
  ) {
    final context = _transactionFilterContext;
    if (context == null) {
      return context;
    }

    final account = context.account;
    if (account == null) {
      return context;
    }

    return MoneyTransactionFilterContext(
      title: context.title,
      subtitle: account.name,
      contextLabel: '当前只看账户：${account.name}',
      onClear: context.onClear,
      account: account,
      accountSummary: ref
          .watch(currentUserAccountMonthlySummariesProvider)
          .maybeWhen(
            data: (summaries) => summaries[account.id],
            orElse: () => null,
          ),
      lockType: context.lockType,
      lockAccount: context.lockAccount,
      lockCategory: context.lockCategory,
      lockDateRange: context.lockDateRange,
    );
  }
}

class _LazyBookkeepingPanelStack extends StatelessWidget {
  const _LazyBookkeepingPanelStack({
    required this.selectedPanel,
    required this.loadedPanels,
    required this.panelBuilder,
  });

  final _BookkeepingPanel selectedPanel;
  final Set<_BookkeepingPanel> loadedPanels;
  final Widget Function(_BookkeepingPanel panel) panelBuilder;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final panel in _BookkeepingPanel.values)
          if (loadedPanels.contains(panel))
            _KeepAlivePanel(
              key: ValueKey<_BookkeepingPanel>(panel),
              visible: panel == selectedPanel,
              child: panelBuilder(panel),
            ),
      ],
    );
  }
}

class _KeepAlivePanel extends StatelessWidget {
  const _KeepAlivePanel({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !visible,
      child: TickerMode(enabled: visible, child: child),
    );
  }
}

class _BookkeepingDataPreloader extends ConsumerStatefulWidget {
  const _BookkeepingDataPreloader();

  @override
  ConsumerState<_BookkeepingDataPreloader> createState() =>
      _BookkeepingDataPreloaderState();
}

class _BookkeepingDataPreloaderState
    extends ConsumerState<_BookkeepingDataPreloader> {
  @override
  void initState() {
    super.initState();
    unawaited(_preload());
  }

  Future<void> _preload() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }

    await _ignoreErrors(
      Future.wait([
        ref.read(currentUserMoneyLedgersProvider.future),
        ref.read(currentUserCurrentLedgerProvider.future),
        ref.read(currentUserVisibleAccountsProvider.future),
        ref.read(currentUserAccountMonthlySummariesProvider.future),
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
        ref.read(currentUserBillRemindersProvider.future),
        ref.read(currentUserAutoPostingExecutionProvider.future),
        ref.read(currentUserInstallmentPlansProvider.future),
        ref.read(currentUserCurrentLedgerMembersProvider.future),
        ref.read(moneyStatisticsContextProvider.future),
        ref
            .read(currentUserMoneyTransactionActionsProvider)
            .listTransactions(const MoneyTransactionQuery()),
      ]),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    if (!mounted) {
      return;
    }

    final context = await _valueOrNull(
      ref.read(moneyStatisticsContextProvider.future),
    );
    if (!mounted || context == null || !context.isReady) {
      return;
    }

    final range = MoneyStatisticsDateRange.resolve(
      MoneyStatisticsPeriodPreset.thisMonth,
      DateTime.now(),
    );
    await _ignoreErrors(
      ref.read(
        moneyStatisticsProvider(
          MoneyStatisticsRequest(
            userId: context.userId!,
            query: MoneyStatisticsQuery(
              dateStart: range.start,
              dateEndExclusive: range.endExclusive,
              groupBy: range.groupBy,
              ledgerId: context.ledger!.id,
            ),
          ),
        ).future,
      ),
    );
  }

  Future<T?> _valueOrNull<T>(Future<T> future) async {
    try {
      return await future;
    } catch (_) {
      return null;
    }
  }

  Future<void> _ignoreErrors(Future<dynamic> future) async {
    try {
      await future;
    } catch (_) {
      // Preloading should never block the visible page.
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

enum _BookkeepingPanel {
  accounts,
  transactions,
  statistics,
  categories,
  budgets,
  installments,
  autoPosting,
  reminders,
}

_BookkeepingPanel _panelFromSection(String? section) {
  return switch (section) {
    'accounts' => _BookkeepingPanel.accounts,
    'transactions' => _BookkeepingPanel.transactions,
    'statistics' => _BookkeepingPanel.statistics,
    'categories' => _BookkeepingPanel.categories,
    'budgets' => _BookkeepingPanel.budgets,
    'installments' => _BookkeepingPanel.installments,
    'autoPosting' => _BookkeepingPanel.autoPosting,
    'reminders' => _BookkeepingPanel.reminders,
    _ => _BookkeepingPanel.accounts,
  };
}
