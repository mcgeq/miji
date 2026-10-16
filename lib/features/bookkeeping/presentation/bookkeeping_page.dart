import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_module_section_picker.dart';
import 'package:miji/core/router/app_module_nav.dart';
import 'package:miji/core/router/app_routes.dart';
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
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';
import 'package:miji/features/bookkeeping/presentation/reminders/money_reminder_center_section.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_statistics_section.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transactions_section.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:flutter/services.dart';

class BookkeepingPage extends ConsumerStatefulWidget {
  const BookkeepingPage({
    super.key,
    this.initialSection,
    this.initialAccountId,
    this.initialAction,
  });

  final String? initialSection;
  final String? initialAccountId;

  /// 进入后立即执行的快捷动作，目前只有 `expense`（记一笔支出）。
  ///
  /// 通知带来的入口：点「今天还没记账」通知如果只落到流水列表，用户还得再
  /// 找一遍按钮，通知就算白推了。
  final String? initialAction;

  @override
  ConsumerState<BookkeepingPage> createState() => _BookkeepingPageState();
}

class _BookkeepingPageState extends ConsumerState<BookkeepingPage> {
  // 默认落在流水：记账里最高频的动线，打开即记账，而不是先看净资产。
  _BookkeepingPanel _selectedPanel = _BookkeepingPanel.transactions;
  final Set<_BookkeepingPanel> _loadedPanels = <_BookkeepingPanel>{};
  MoneyTransactionQuery _transactionQuery = const MoneyTransactionQuery();
  MoneyTransactionFilterContext? _transactionFilterContext;
  bool _initialActionConsumed = false;

  /// 进分类页之前的那个面板。
  ///
  /// 分类页是整屏的分类列表 + 吸底记账条，自带返回顶栏；退出来要回到用户
  /// 进来时看的那个面板（直接带 `?section=categories` 进来时没有「上一个」，
  /// 退回流水）。
  _BookkeepingPanel? _panelBeforeCategories;

  @override
  void initState() {
    super.initState();
    _selectedPanel = _panelFromSection(widget.initialSection);
    _applyInitialTransactionQuery();
    _loadedPanels.add(_selectedPanel);
  }

  /// 首帧后消费一次性动作。
  ///
  /// 放在 `build` 里而不是 `initState`：动作需要 `context` 和已经就绪的
  /// provider，首帧前两者都不可用。
  void _consumeInitialAction() {
    if (_initialActionConsumed || widget.initialAction != 'expense') {
      _initialActionConsumed = true;
      return;
    }
    _initialActionConsumed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      MoneyQuickActionLauncher(
        context: context,
        ref: ref,
        ensureToast: () => FToast()..init(context),
      ).run(MoneyQuickAction.expense);
    });
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
    _consumeInitialAction();
    final responsive = AppResponsive.of(context);
    // 页内不再有任何浮层：面板入口要么在底栏（窄屏「记账」两态唤出选择器），
    // 要么在下面这条工具行的左端（宽屏 / 窄窗桌面，`prefersRailNavigation`
    // 为真时没有底栏）。
    //
    // 上一版把入口做成了浮在内容右上角的胶囊：它是 `Stack` 的兄弟节点，不占
    // 页面流、绘制并命中在内容之上，正好压在 8 个面板里 7 个的首行右侧动作上
    // （流水「筛选」、账户「新建账户」、统计动作组……）——不是「看不全」，是
    // 「点不到」。那 77px 现在全数还给内容。
    final showToolbarRow = !responsive.isCompact;

    return AppPageFrame(
      maxWidth: 1280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showToolbarRow) ...[
            _buildToolbarRow(),
            const SizedBox(height: 6),
          ],
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
    );
  }

  /// 宽屏工具行：左端是「面板 chip」（显示当前面板名，点开即选择器），
  /// 后面跟着原来的账本选择器。
  ///
  /// 两者都是本来就存在的行内内容，chip 不新增行高、不覆盖任何东西；
  /// 面板名常驻显示，顺手兼任「我现在在哪」的标识（原来是浮层胶囊在扛这件事）。
  Widget _buildToolbarRow() {
    return Row(
      children: [
        AppModuleSectionChip(
          spec: bookkeepingModuleNav,
          sectionId: _sectionOfPanel(_selectedPanel),
          onTap: _openSectionPicker,
        ),
        const SizedBox(width: 12),
        const Expanded(child: CurrentLedgerSelector()),
      ],
    );
  }

  Future<void> _openSectionPicker() async {
    final current = _sectionOfPanel(_selectedPanel);
    final picked = await showAppModuleSectionPicker(
      context,
      spec: bookkeepingModuleNav,
      currentSectionId: current,
    );
    if (picked == null || picked == current) {
      return;
    }
    _selectPanel(_panelFromSection(picked));
  }

  Widget _buildPanelChild(_BookkeepingPanel panel) {
    return switch (panel) {
      _BookkeepingPanel.transactions => Consumer(
        builder: (context, ref, child) {
          return MoneyTransactionsSection(
            initialQuery: _transactionQuery,
            filterContext: _effectiveTransactionFilterContext(ref),
          );
        },
      ),
      _BookkeepingPanel.accounts => MoneyAccountsSection(
        onViewTransactions: _showAccountTransactions,
      ),
      _BookkeepingPanel.statistics => MoneyStatisticsSection(
        onOpenTransactions: _showTransactionsFromStatistics,
      ),
      _BookkeepingPanel.categories => MoneyCategoriesSection(
        onExit: _exitCategories,
      ),
      _BookkeepingPanel.budgets => MoneyBudgetsSection(
        onViewTransactions: _showBudgetTransactions,
      ),
      _BookkeepingPanel.installments => const MoneyInstallmentsSection(),
      // 自动记账页底部的「相关」链接直接切到分期面板：分期还款计划只保留
      // 一处入口，避免两边各维护一份列表。
      _BookkeepingPanel.autoPosting => MoneyAutoPostingsSection(
        onOpenInstallments: () => _selectPanel(_BookkeepingPanel.installments),
      ),
      _BookkeepingPanel.reminders => const MoneyReminderCenterSection(),
    };
  }

  void _selectPanel(_BookkeepingPanel panel) {
    if (panel == _selectedPanel) {
      return;
    }
    // 切换一级面板给一次轻微触感，移动端「操作被接住」的感觉主要来自这里。
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      if (panel == _BookkeepingPanel.categories) {
        _panelBeforeCategories = _selectedPanel;
      }
      _selectedPanel = panel;
      _loadedPanels.add(panel);
    });
    _syncPanelToUrl(panel);
  }

  /// 分类页顶栏的「返回」：回到进来时的那个面板。
  void _exitCategories() {
    _selectPanel(_panelBeforeCategories ?? _BookkeepingPanel.transactions);
  }

  /// 把当前面板写回 URL。
  ///
  /// 路由一直支持 `?section=`，但之前只当初始值读一次：面板切换不写回，
  /// 于是系统返回键会直接退出记账模块（而不是回到上一个面板），
  /// 从首页/通知带 section 跳进来后返回栈也不对。
  void _syncPanelToUrl(_BookkeepingPanel panel) {
    final route = GoRouterState.of(context);
    final section = _sectionOfPanel(panel);
    if (route.uri.queryParameters['section'] == section) {
      return;
    }
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': section},
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

/// 记账的面板。
///
/// 与 `bookkeepingModuleNav.sections` **一一对应且顺序一致**（`values[index]`
/// 就是 `sections[index]`）；`_panelFromSection` / `_sectionOfPanel` 是这对
/// 映射的唯一出入口，新增面板时三处一起改。
///
/// 用枚举而不是裸字符串：`_buildPanelChild` 的 `switch` 能被编译器穷尽检查，
/// 少写一个分支编不过，而字符串写错会静默落到流水。
enum _BookkeepingPanel {
  transactions,
  accounts,
  budgets,
  statistics,
  categories,
  installments,
  autoPosting,
  reminders,
}

_BookkeepingPanel _panelFromSection(String? section) {
  return switch (bookkeepingModuleNav.resolveSectionId(section)) {
    'accounts' => _BookkeepingPanel.accounts,
    'budgets' => _BookkeepingPanel.budgets,
    'statistics' => _BookkeepingPanel.statistics,
    'categories' => _BookkeepingPanel.categories,
    'installments' => _BookkeepingPanel.installments,
    'autoPosting' => _BookkeepingPanel.autoPosting,
    'reminders' => _BookkeepingPanel.reminders,
    _ => _BookkeepingPanel.transactions,
  };
}

String _sectionOfPanel(_BookkeepingPanel panel) {
  return switch (panel) {
    _BookkeepingPanel.transactions => 'transactions',
    _BookkeepingPanel.accounts => 'accounts',
    _BookkeepingPanel.budgets => 'budgets',
    _BookkeepingPanel.statistics => 'statistics',
    _BookkeepingPanel.categories => 'categories',
    _BookkeepingPanel.installments => 'installments',
    _BookkeepingPanel.autoPosting => 'autoPosting',
    _BookkeepingPanel.reminders => 'reminders',
  };
}
