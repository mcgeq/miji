import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_page_toolbar.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
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
    final sectionChanged = oldWidget.initialSection != widget.initialSection;
    final accountChanged =
        oldWidget.initialAccountId != widget.initialAccountId;
    if (!sectionChanged && !accountChanged) {
      return;
    }
    // 面板自己写回 URL 时会再次走到这里，此时 section 已经等于当前面板，
    // 直接返回，避免重复 setState 和重置筛选。
    final nextPanel = _panelFromSection(widget.initialSection);
    if (nextPanel != _selectedPanel) {
      _selectedPanel = nextPanel;
      _loadedPanels.add(nextPanel);
    }
    _applyInitialTransactionQuery();
  }

  @override
  Widget build(BuildContext context) {
    final showPageLedgerSelector = !AppResponsive.of(context).isCompact;

    return Stack(
      children: [
        AppPageFrame(
          maxWidth: 1280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showPageLedgerSelector) ...[
                AppPageToolbar(
                  showSurface: false,
                  primary: const CurrentLedgerSelector(),
                ),
                const SizedBox(height: 6),
              ],
              _BookkeepingTabBar(
                selected: _selectedPanel,
                onSelect: _selectPanel,
              ),
              const SizedBox(height: 16),
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
      _BookkeepingPanel.more => _BookkeepingMorePanel(onSelect: _selectPanel),
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
    if (panel == _selectedPanel) {
      return;
    }
    setState(() {
      _selectedPanel = panel;
      _loadedPanels.add(panel);
    });
    _syncPanelToUrl(panel);
  }

  /// 把当前面板写回 URL。
  ///
  /// 路由一直支持 `?section=`，但之前只当初始值读一次：面板切换不写回，
  /// 于是系统返回键会直接退出记账模块（而不是回到上一个面板），
  /// 从首页/通知带 section 跳进来后返回栈也不对。
  void _syncPanelToUrl(_BookkeepingPanel panel) {
    final route = GoRouterState.of(context);
    if (route.uri.queryParameters['section'] == panel.name) {
      return;
    }
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': panel.name},
      ).toString(),
    );
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
    _syncPanelToUrl(_BookkeepingPanel.transactions);
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

/// 一级导航：流水 / 账户 / 预算 / 统计 + 更多。
///
/// 原来是 8 个只有图标的横条：44px × 8 = 352px，而 360dp 手机上可用宽度只有
/// 336px，末尾两个面板被裁掉，而且没有文字（标签只做 tooltip，手机上要长按）。
class _BookkeepingTabBar extends StatelessWidget {
  const _BookkeepingTabBar({required this.selected, required this.onSelect});

  final _BookkeepingPanel selected;
  final ValueChanged<_BookkeepingPanel> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moreActive =
        _morePanels.contains(selected) || selected == _BookkeepingPanel.more;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.42,
            ),
            borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            children: [
              for (final panel in _primaryPanels)
                _BookkeepingTab(
                  icon: _panelIcon(panel),
                  label: _panelLabel(panel),
                  selected: selected == panel,
                  onTap: () => onSelect(panel),
                ),
              _BookkeepingTab(
                icon: _panelIcon(_BookkeepingPanel.more),
                // 二级面板激活时直接把面板名显示在「更多」上，用户才知道自己在哪。
                label: moreActive && selected != _BookkeepingPanel.more
                    ? _panelLabel(selected)
                    : _panelLabel(_BookkeepingPanel.more),
                selected: moreActive,
                onTap: () => onSelect(_BookkeepingPanel.more),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookkeepingTab extends StatelessWidget {
  const _BookkeepingTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Expanded(
      child: Tooltip(
        message: label,
        child: Material(
          color: selected ? colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            onTap: onTap,
            child: Semantics(
              button: true,
              selected: selected,
              label: label,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: foreground),
                    const SizedBox(height: 3),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: foreground,
                        fontWeight: selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「更多」页：分类 / 分期 / 自动记账 / 提醒。
class _BookkeepingMorePanel extends ConsumerWidget {
  const _BookkeepingMorePanel({required this.onSelect});

  final ValueChanged<_BookkeepingPanel> onSelect;

  static const _descriptions = <_BookkeepingPanel, String>{
    _BookkeepingPanel.categories: '分类、子分类与颜色',
    _BookkeepingPanel.installments: '分期计划与每期入账',
    _BookkeepingPanel.autoPosting: '定时自动生成流水',
    _BookkeepingPanel.reminders: '账单、还款与预算提醒',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 待处理提醒数量作为「需要关注」的角标。
    final pendingReminders = ref
        .watch(currentUserPendingReminderCenterItemsProvider)
        .maybeWhen(data: (items) => items.length, orElse: () => 0);

    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.65,
          children: [
            for (final panel in _morePanels)
              _MoreTile(
                icon: _panelIcon(panel),
                label: _panelLabel(panel),
                description: _descriptions[panel] ?? '',
                badge:
                    panel == _BookkeepingPanel.reminders && pendingReminders > 0
                    ? '$pendingReminders'
                    : null,
                onTap: () => onSelect(panel),
              ),
          ],
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppListItemPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppListItemIcon(icon: icon, color: colorScheme.primary, size: 34),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onError,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const Spacer(),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
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

  /// 预取「首屏一定会用到」的数据。
  ///
  /// 原来一次 `Future.wait` 12 个 provider（含账单提醒、自动记账执行、分期、
  /// 统计上下文与整份统计报表）——切到记账 Tab 的耗时就被这个固定开销决定，
  /// 而用户可能只想看账户或流水。这里只留两批：基础选择器 + 流水首页。
  /// 其余面板在打开时按需加载（`_LazyBookkeepingPanelStack` 本来就是懒加载）。
  Future<void> _preload() async {
    // 未解锁时所有 provider 都只会返回空数据，预取没有意义。
    if (!ref.read(authSessionControllerProvider).isUnlocked) {
      return;
    }

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

    // 流水是第二高频的落点。
    await _ignoreErrors(
      ref
          .read(currentUserMoneyTransactionActionsProvider)
          .listTransactions(const MoneyTransactionQuery()),
    );
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
  transactions,
  accounts,
  budgets,
  statistics,
  categories,
  installments,
  autoPosting,
  reminders,
  more,
}

/// 一级导航。「看数据」的四个面板常驻，其余收进「更多」。
const _primaryPanels = <_BookkeepingPanel>[
  _BookkeepingPanel.transactions,
  _BookkeepingPanel.accounts,
  _BookkeepingPanel.budgets,
  _BookkeepingPanel.statistics,
];

/// 「更多」里的二级面板。
const _morePanels = <_BookkeepingPanel>[
  _BookkeepingPanel.categories,
  _BookkeepingPanel.installments,
  _BookkeepingPanel.autoPosting,
  _BookkeepingPanel.reminders,
];

String _panelLabel(_BookkeepingPanel panel) {
  return switch (panel) {
    _BookkeepingPanel.transactions => '流水',
    _BookkeepingPanel.accounts => '账户',
    _BookkeepingPanel.budgets => '预算',
    _BookkeepingPanel.statistics => '统计',
    _BookkeepingPanel.categories => '分类',
    _BookkeepingPanel.installments => '分期',
    _BookkeepingPanel.autoPosting => '自动记账',
    _BookkeepingPanel.reminders => '提醒',
    _BookkeepingPanel.more => '更多',
  };
}

IconData _panelIcon(_BookkeepingPanel panel) {
  return switch (panel) {
    _BookkeepingPanel.transactions => Icons.receipt_long_rounded,
    _BookkeepingPanel.accounts => Icons.account_balance_wallet_rounded,
    _BookkeepingPanel.budgets => Icons.flag_rounded,
    _BookkeepingPanel.statistics => Icons.query_stats_rounded,
    _BookkeepingPanel.categories => Icons.category_rounded,
    _BookkeepingPanel.installments => Icons.calendar_month_rounded,
    _BookkeepingPanel.autoPosting => Icons.event_repeat_rounded,
    _BookkeepingPanel.reminders => Icons.notifications_active_rounded,
    _BookkeepingPanel.more => Icons.grid_view_rounded,
  };
}

_BookkeepingPanel _panelFromSection(String? section) {
  return switch (section) {
    'transactions' => _BookkeepingPanel.transactions,
    'accounts' => _BookkeepingPanel.accounts,
    'budgets' => _BookkeepingPanel.budgets,
    'statistics' => _BookkeepingPanel.statistics,
    'categories' => _BookkeepingPanel.categories,
    'installments' => _BookkeepingPanel.installments,
    'autoPosting' => _BookkeepingPanel.autoPosting,
    'reminders' => _BookkeepingPanel.reminders,
    'more' => _BookkeepingPanel.more,
    _ => _BookkeepingPanel.accounts,
  };
}
