import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/paged_load_more_list.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/application/money_export_service.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_form_dialog.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_usage.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_summary_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_bulk_edit_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_card.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_panel.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transaction_actions.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_recycle_bin_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_split_dialog.dart';

class MoneyTransactionsSection extends ConsumerStatefulWidget {
  const MoneyTransactionsSection({
    super.key,
    this.initialQuery,
    this.filterContext,
  });

  final MoneyTransactionQuery? initialQuery;
  final MoneyTransactionFilterContext? filterContext;

  @override
  ConsumerState<MoneyTransactionsSection> createState() =>
      _MoneyTransactionsSectionState();
}

class _BudgetAppliedFilterSnapshot {
  const _BudgetAppliedFilterSnapshot({
    required this.type,
    required this.status,
    required this.accountId,
    required this.categoryId,
    required this.subCategoryId,
    required this.paymentMethod,
    required this.merchant,
    required this.customPaymentMethodName,
    required this.dateStart,
    required this.dateEnd,
    required this.keyword,
  });

  final MoneyTransactionType? type;
  final MoneyTransactionStatus? status;
  final String? accountId;
  final String? categoryId;
  final String? subCategoryId;
  final MoneyPaymentMethod? paymentMethod;
  final String? merchant;
  final String? customPaymentMethodName;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final String? keyword;
}

class _MoneyTransactionsSectionState
    extends ConsumerState<MoneyTransactionsSection> {
  static const _pageSize = 20;

  FToast? _toast;
  late final TextEditingController _keywordController;
  late final TextEditingController _merchantController;
  final List<MoneyTransactionEntity> _transactions = <MoneyTransactionEntity>[];
  Timer? _keywordDebounce;
  Timer? _merchantDebounce;
  int _page = 1;
  int _loadSerial = 0;
  bool _hasMore = false;
  bool _isLoadingInitial = true;
  bool _isExporting = false;
  bool _isConfirmingAll = false;
  bool _isBulkBusy = false;
  bool _isRestoring = false;

  /// 改筛选时保留旧列表，只在顶部走一条细进度条。
  ///
  /// 原来 `_refreshFromFilterChange` 会清空 `_transactions` 并置
  /// `_isLoadingInitial`，于是点一下任一 chip 整屏闪一次骨架 —— 列表每次都
  /// 要重新「长出来」。现在只有首次进入才用骨架。
  bool _isRefreshing = false;
  Object? _loadError;
  MoneyTransactionType? _typeFilter;
  MoneyTransactionStatus? _statusFilter;
  List<String> _tagFilter = const <String>[];
  String? _budgetIdFilter;
  _BudgetAppliedFilterSnapshot? _budgetAppliedFilterSnapshot;
  String? _accountIdFilter;
  String? _categoryIdFilter;
  String? _subCategoryIdFilter;
  MoneyPaymentMethod? _paymentMethodFilter;
  String? _merchantFilter;
  String? _customPaymentMethodNameFilter;
  DateTime? _dateStartFilter;
  MoneyTransactionSortField _sortField =
      MoneyTransactionSortField.transactionAt;
  bool _sortAscending = false;
  DateTime? _dateEndFilter;
  String? _keywordFilter;

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _statusFilter != null ||
      _tagFilter.isNotEmpty ||
      _budgetIdFilter != null ||
      _accountIdFilter != null ||
      _categoryIdFilter != null ||
      _subCategoryIdFilter != null ||
      _paymentMethodFilter != null ||
      _customPaymentMethodNameFilter != null ||
      _merchantFilter != null ||
      _dateStartFilter != null ||
      _keywordFilter != null;

  /// 只统计「高级筛选」抽屉里的条件。
  ///
  /// 类型在分段控件上、搜索词在搜索框里、状态与日期在常用筛选条上，各自
  /// 都有可见的载体，不需要再靠一个图标变色去暗示「其实还筛了别的」。
  bool get _hasAdvancedFilters =>
      _budgetIdFilter != null ||
      _accountIdFilter != null ||
      _categoryIdFilter != null ||
      _subCategoryIdFilter != null ||
      _paymentMethodFilter != null ||
      _customPaymentMethodNameFilter != null ||
      _merchantFilter != null;

  /// 常用筛选条上的生效项数量（状态 / 日期区间 / 标签）。
  int get _activeStripFilterCount =>
      (_statusFilter == null ? 0 : 1) +
      (_dateStartFilter == null && _dateEndFilter == null ? 0 : 1) +
      _tagFilter.length;

  /// 顶部「筛选」开关上的角标：类型 + 常用筛选条 + 抽屉，都算。
  int get _activeFilterCount =>
      _activeStripFilterCount +
      (_hasAdvancedFilters ? 1 : 0) +
      (_typeFilter == null ? 0 : 1);

  /// 常用筛选条是否展开。默认折叠，只显示已生效项。
  bool _filterStripExpanded = false;

  String? _selectedTransactionId;
  String? _activeLedgerId;

  /// 多选模式下选中的流水 id。
  ///
  /// 只保留当前列表里还存在的 id：翻页 / 改筛选 / 批量删除之后，
  /// 旧 id 如果留在集合里，操作条会一直报一个已经看不见的条数。
  final Set<String> _bulkSelectedIds = <String>{};

  bool get _isBulkMode => _bulkSelectedIds.isNotEmpty;

  bool get _isTypeLocked => widget.filterContext?.lockType ?? false;

  bool get _isAccountLocked => widget.filterContext?.lockAccount ?? false;

  bool get _isCategoryLocked => widget.filterContext?.lockCategory ?? false;

  bool get _isDateLocked => widget.filterContext?.lockDateRange ?? false;

  MoneyTransactionQuery get _effectiveInitialQuery {
    return widget.initialQuery ?? const MoneyTransactionQuery();
  }

  @override
  void initState() {
    super.initState();
    _keywordController = TextEditingController();
    _merchantController = TextEditingController();
    _applyQuery(_effectiveInitialQuery, updateController: true);
    unawaited(Future<void>.microtask(_refreshTransactions));
  }

  @override
  void didUpdateWidget(covariant MoneyTransactionsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.filterContext?.contextLabel !=
            widget.filterContext?.contextLabel) {
      _applyQuery(_effectiveInitialQuery, updateController: true);
      _transactions.clear();
      _page = 1;
      _hasMore = false;
      _isLoadingInitial = true;
      _loadError = null;
      _selectedTransactionId = null;
      _bulkSelectedIds.clear();
      unawaited(_refreshTransactions());
    }
  }

  @override
  void dispose() {
    _keywordDebounce?.cancel();
    _merchantDebounce?.cancel();
    _keywordController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(moneyDataRefreshVersionProvider, (previous, next) {
      if (previous == null || previous == next) {
        return;
      }
      unawaited(_refreshTransactions());
    });

    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));
    final ledgerId = currentLedger?.id;
    _syncActiveLedger(ledgerId);
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    final installmentPlans = ref.watch(currentUserInstallmentPlansProvider);
    final budgets = ref.watch(currentUserBudgetsProvider);
    final accountRows = accounts.maybeWhen(
      data: (value) => value,
      orElse: () => const <MoneyAccountEntity>[],
    );
    final expenseCatalogValue = expenseCatalog.maybeWhen(
      data: (value) => value,
      orElse: () => const MoneyCategoryCatalog.empty(),
    );
    final incomeCatalogValue = incomeCatalog.maybeWhen(
      data: (value) => value,
      orElse: () => const MoneyCategoryCatalog.empty(),
    );
    final installmentPlanRows = installmentPlans.maybeWhen(
      data: (value) => value,
      orElse: () => const <MoneyInstallmentPlanEntity>[],
    );
    final budgetRows = budgets.maybeWhen(
      data: (value) => value,
      orElse: () => const <MoneyBudgetEntity>[],
    );
    final tagCandidates = ref
        .watch(currentUserTagCandidatesProvider)
        .maybeWhen(data: (value) => value, orElse: () => const <String>[]);
    final categoryUsage = ref
        .watch(currentUserCategoryUsageStatsProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final budgetPreset = _budgetPresetFromFilters(
      expenseCatalog: expenseCatalogValue,
      incomeCatalog: incomeCatalogValue,
      accounts: accountRows,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        // 第一行：常驻搜索 + 筛选开关。
        //
        // 关键词搜索原来在筛选抽屉第 8 位，要四步才能开始打字；现在一行到底，
        // 右侧的开关负责展开「常用筛选条」（状态 / 日期），角标给出生效数量。
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: _keywordController,
                hintText: '搜索名称、备注、商家',
                prefixIcon: const Icon(Icons.search_rounded, size: 19),
                onChanged: _setKeywordFilterDebounced,
                suffixIcon: (_keywordFilter ?? '').isEmpty
                    ? null
                    : IconButton(
                        tooltip: '清除搜索',
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _keywordController.clear();
                          _setKeywordFilterDebounced('');
                        },
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _TransactionFilterToggle(
              expanded: _filterStripExpanded,
              activeCount: _activeFilterCount,
              onPressed: () =>
                  setState(() => _filterStripExpanded = !_filterStripExpanded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 第二行：类型分段 + 排序 + 高级筛选 + 更多。
        //
        // 导出流水与回收站都是低频动作，收进 ⋯ 之后，分段控件从它们手里拿回
        // 96dp，「全部 / 支出 / 收入 / 转账」不再贴着右边被压窄。
        Row(
          children: [
            Expanded(
              child: AppSlidingSegmentedControl<MoneyTransactionType?>(
                height: 38,
                // 44 能让「全部/支出/收入/转账」在 360dp 手机上完整放下；
                // 56 时四段至少 224dp，会被右侧三个图标按钮盖住。
                minSegmentWidth: 44,
                value: _typeFilter,
                onChanged: _setTypeFilter,
                segments: const [
                  AppSlidingSegment(value: null, label: '全部'),
                  AppSlidingSegment(
                    value: MoneyTransactionType.expense,
                    label: '支出',
                  ),
                  AppSlidingSegment(
                    value: MoneyTransactionType.income,
                    label: '收入',
                  ),
                  AppSlidingSegment(
                    value: MoneyTransactionType.transfer,
                    label: '转账',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TransactionsSortButton(
              sortField: _sortField,
              sortAscending: _sortAscending,
              onChanged: (field, ascending) {
                setState(() {
                  _sortField = field;
                  _sortAscending = ascending;
                });
                unawaited(_refreshTransactions());
              },
            ),
            const SizedBox(width: 8),
            AppFilterSheetTrigger(
              title: '高级筛选',
              // 只有抽屉里的字段才算——类型在分段控件上、状态与日期在常用
              // 筛选条上，各自都有可见载体，不需要靠这个图标变色去暗示。
              hasActiveFilters: _hasAdvancedFilters,
              children: [
                _TransactionFilterFields(
                  type: _typeFilter,
                  budgetId: _budgetIdFilter,
                  accountId: _accountIdFilter,
                  paymentMethod: _paymentMethodFilter,
                  categoryId: _categoryIdFilter,
                  subCategoryId: _subCategoryIdFilter,
                  dateStart: _dateStartFilter,
                  dateEnd: _dateEndFilter,
                  budgets: budgetRows,
                  accounts: accountRows,
                  catalog: _typeFilter == MoneyTransactionType.income
                      ? incomeCatalogValue
                      : expenseCatalogValue,
                  categoryKind: _typeFilter == MoneyTransactionType.income
                      ? MoneyCategoryKind.income
                      : MoneyCategoryKind.expense,
                  contextLabel: widget.filterContext?.contextLabel,
                  isTypeLocked: _isTypeLocked,
                  isAccountLocked: _isAccountLocked,
                  isCategoryLocked: _isCategoryLocked,
                  isDateLocked: _isDateLocked,
                  keywordController: _keywordController,
                  merchantController: _merchantController,
                  onBudgetChanged: (value) =>
                      _setBudgetFilter(value, budgetRows),
                  onTypeChanged: _setTypeFilter,
                  onAccountChanged: _setAccountFilter,
                  onPaymentMethodChanged: _setPaymentMethodFilter,
                  onCategoryChanged: _setCategoryFilter,
                  onSubCategoryChanged: _setSubCategoryFilter,
                  onDateRangePressed: _pickDateRange,
                  onClearDateRange: _clearDateRange,
                  onKeywordChanged: _setKeywordFilterDebounced,
                  onMerchantChanged: _setMerchantFilterDebounced,
                  onClearContext: widget.filterContext?.onClear,
                ),
              ],
            ),
            const SizedBox(width: 8),
            _TransactionsMoreMenu(
              exporting: _isExporting,
              onExport: _exportTransactions,
              onOpenRecycleBin: _openRecycleBin,
            ),
          ],
        ),
        // 第三行：常用筛选条。
        //
        // 折叠态只显示已生效的条件，一条都没有就整块不占高度；展开后才给出
        // 状态与日期两组预设。原来这两条 chips 无论用不用都常驻 82dp。
        _TransactionFilterStrip(
          expanded: _filterStripExpanded,
          status: _statusFilter,
          pendingCount: ref
              .watch(currentUserPendingTransactionCountProvider)
              .maybeWhen(data: (value) => value, orElse: () => 0),
          dateStart: _dateStartFilter,
          dateEnd: _dateEndFilter,
          activeChips: _activeFilterChips(
            accounts: accountRows,
            expenseCatalog: expenseCatalogValue,
            incomeCatalog: incomeCatalogValue,
            budgets: budgetRows,
          ),
          onStatusChanged: _setStatusFilter,
          onPickDateRange: _pickDateRange,
          onSelectDatePreset: _applyDatePreset,
        ),
        if (_statusFilter == MoneyTransactionStatus.pending) ...[
          const SizedBox(height: 10),
          _PendingConfirmBanner(
            count: ref
                .watch(currentUserTransactionSummaryProvider(_summaryQuery))
                .maybeWhen(data: (value) => value.count, orElse: () => 0),
            busy: _isConfirmingAll,
            onConfirmAll: _confirmAllPending,
          ),
        ],
        if (widget.filterContext?.account != null) ...[
          const SizedBox(height: 10),
          _AccountTransactionSummaryPanel(
            account: widget.filterContext!.account!,
            summary: widget.filterContext!.accountSummary,
          ),
        ],
        if (budgetPreset != null) ...[
          const SizedBox(height: 10),
          _BudgetShortcutBanner(
            label: budgetPreset.label,
            onCreate: () => _openBudgetDialog(budgetPreset),
          ),
        ],
        const SizedBox(height: 10),
        // 列表区。改筛选时保留旧结果，只降透明度 + 顶部压一条细进度条 ——
        // 原来每次筛选都先清空列表，点一下 chip 整屏闪一次骨架。
        // 用 Stack 而不是在 Column 里插一条，是为了不引起一次布局跳动。
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: _isRefreshing ? 0.5 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return _buildTransactionsArea(
                        isWide: constraints.maxWidth >= 840,
                        accounts: accountRows,
                        currentLedger: currentLedger,
                        installmentPlans: installmentPlanRows,
                        expenseCatalog: expenseCatalogValue,
                        incomeCatalog: incomeCatalogValue,
                        budgets: budgetRows,
                      );
                    },
                  ),
                ),
              ),
              if (_isRefreshing)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _InlineRefreshBar(),
                ),
            ],
          ),
        ),
        // 底部槽位：多选时是批量操作条，其余时候是筛选结果汇总。
        //
        // 两者共用同一格，既不再跟列表抢上方空间，也不会叠在列表上遮住内容。
        // 导航条由 Scaffold 的 bottomNavigationBar 承担，body 在它上方结束，
        // 所以这个槽位天然停在导航胶囊之上。
        if (_isBulkMode) ...[
          const SizedBox(height: 10),
          _TransactionBulkActionBar(
            selectedCount: _bulkSelectedIds.length,
            visibleCount: _transactions.length,
            busy: _isBulkBusy,
            onSelectAllVisible: _selectAllVisible,
            onEdit: () => _openBulkEditSheet(
              accounts: accountRows,
              expenseCatalog: expenseCatalogValue,
              incomeCatalog: incomeCatalogValue,
              usage: categoryUsage,
              tagCandidates: tagCandidates,
            ),
            onConfirm: () => _bulkSetStatus(MoneyTransactionStatus.completed),
            onVoid: () => _bulkSetStatus(MoneyTransactionStatus.voided),
            onDelete: _bulkDelete,
            onClear: _clearBulkSelection,
          ),
        ] else
          Padding(
            // 宽屏 / 桌面端没有底部导航，FAB 会挪到右下角，这里给它留出位置；
            // 移动端 FAB 整颗嵌在导航胶囊里，不需要额外避让。
            padding: EdgeInsets.only(
              top: 10,
              right: AppResponsive.of(context).prefersRailNavigation ? 64 : 0,
            ),
            child: _TransactionSummaryBar(
              query: _summaryQuery,
              onClear: _clearAllFilters,
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionsArea({
    required bool isWide,
    required List<MoneyAccountEntity> accounts,
    required MoneyLedgerEntity? currentLedger,
    required List<MoneyInstallmentPlanEntity> installmentPlans,
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
    required List<MoneyBudgetEntity> budgets,
  }) {
    if (_isLoadingInitial) {
      return const AppSkeletonList();
    }
    if (_loadError != null) {
      return AppErrorState(title: '读取流水失败', onRetry: _refreshTransactions);
    }

    final selectedTransaction = _selectedTransaction;
    final detailPanelOpen = isWide && selectedTransaction != null;
    final list = ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: PagedLoadMoreList<MoneyTransactionEntity>(
        items: _transactions,
        hasMore: _hasMore,
        onRefresh: _refreshTransactions,
        onLoadMore: _loadMoreTransactions,
        // 空态分流：带筛选查不到东西，和「一笔都没记过」是两回事。
        // 前者是筛选条件的问题，再劝用户「快速新增」只会让他记重复账。
        emptyBuilder: (context) => _EmptyTransactionsPanel(
          onCreate: _openCreateFromEmptyState,
          hasActiveFilters: _hasActiveFilters,
          filterDescription: _activeFilterDescription(
            accounts: accounts,
            expenseCatalog: expenseCatalog,
            incomeCatalog: incomeCatalog,
            budgets: budgets,
          ),
          onClearFilters: _clearAllFilters,
        ),
        itemBuilder: (context, transaction, index) {
          final ledgerMemberships = ref
              .watch(currentUserTransactionLedgersProvider(transaction.id))
              .maybeWhen(
                data: (items) => items,
                orElse: () => const <MoneyLedgerEntity>[],
              );
          final previous = index > 0 ? _transactions[index - 1] : null;
          final showDayHeader =
              previous == null ||
              !sameDayKey(previous.transactionAt, transaction.transactionAt);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showDayHeader)
                _DayGroupHeader(
                  date: transaction.transactionAt,
                  expenseMinor: _dayExpenseMinorFor(transaction.transactionAt),
                  incomeMinor: _dayIncomeMinorFor(transaction.transactionAt),
                  currencyCode: _dayCurrencyFor(transaction.transactionAt),
                ),
              TransactionCard(
                key: ValueKey(transaction.id),
                transaction: transaction,
                accounts: accounts,
                expenseCatalog: expenseCatalog,
                incomeCatalog: incomeCatalog,
                installmentPlans: installmentPlans,
                ledgerMemberships: ledgerMemberships,
                currentLedger: currentLedger,
                isSelected: isWide && transaction.id == _selectedTransactionId,
                swipeCloseSignal: _selectedTransactionId,
                bulkSelectionMode: _isBulkMode,
                bulkSelected: _bulkSelectedIds.contains(transaction.id),
                onLongPress: () => _startBulkSelection(transaction.id),
                onToggleBulkSelect: () => _toggleBulkSelection(transaction.id),
                onTap: () => _openTransactionDetail(
                  transaction: transaction,
                  isWide: isWide,
                  accounts: accounts,
                  expenseCatalog: expenseCatalog,
                  incomeCatalog: incomeCatalog,
                ),
                onConfirm:
                    detailPanelOpen ||
                        transaction.isInstallmentPosting ||
                        transaction.status != MoneyTransactionStatus.pending
                    ? null
                    : () => _confirmPending(transaction),
                onEdit: detailPanelOpen || transaction.isInstallmentPosting
                    ? null
                    : () => _openEditDialog(transaction),
                onDelete: detailPanelOpen || transaction.isInstallmentPosting
                    ? null
                    : () => _confirmDelete(transaction),
                onRefund:
                    detailPanelOpen ||
                        transaction.isInstallmentPosting ||
                        transaction.type != MoneyTransactionType.expense ||
                        transaction.status !=
                            MoneyTransactionStatus.completed ||
                        transaction.amountMinor <= transaction.refundAmountMinor
                    ? null
                    : () => _openRefundDialog(transaction),
              ),
            ],
          );
        },
        separatorBuilder: (context, index) {
          final current = _transactions.elementAtOrNull(index);
          final next = _transactions.elementAtOrNull(index + 1);
          if (current != null &&
              next != null &&
              !sameDayKey(current.transactionAt, next.transactionAt)) {
            return const SizedBox(height: 8);
          }
          return const SizedBox(height: 10);
        },
        padding: const EdgeInsets.only(bottom: 12),
      ),
    );

    if (!isWide || selectedTransaction == null) {
      return list;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
        const SizedBox(width: 12),
        SizedBox(
          width: 340,
          child: TransactionDetailPanel(
            transaction: selectedTransaction,
            accounts: accounts,
            expenseCatalog: expenseCatalog,
            incomeCatalog: incomeCatalog,
            onClose: _closeTransactionDetail,
            onEdit: selectedTransaction.isInstallmentPosting
                ? null
                : () => _openEditDialog(selectedTransaction),
            onDelete: selectedTransaction.isInstallmentPosting
                ? null
                : () => _confirmDelete(selectedTransaction),
            onRefund:
                selectedTransaction.isInstallmentPosting ||
                    selectedTransaction.type != MoneyTransactionType.expense ||
                    selectedTransaction.status !=
                        MoneyTransactionStatus.completed ||
                    selectedTransaction.amountMinor <=
                        selectedTransaction.refundAmountMinor
                ? null
                : () => _openRefundDialog(selectedTransaction),
            onDuplicate:
                selectedTransaction.isInstallmentPosting ||
                    selectedTransaction.type == MoneyTransactionType.transfer
                ? null
                : () => _openDuplicateDialog(selectedTransaction),
            onAddSplit: selectedTransaction.isInstallmentPosting
                ? null
                : () => _openSplitDialog(selectedTransaction),
            onAddToFamilyLedger: selectedTransaction.isInstallmentPosting
                ? null
                : () => _openAddToFamilyLedgerDialog(selectedTransaction),
            onRemoveFromFamilyLedger: selectedTransaction.isInstallmentPosting
                ? null
                : (ledger) => _removeTransactionFromFamilyLedger(
                    selectedTransaction,
                    ledger,
                  ),
            onEditSplit: selectedTransaction.isInstallmentPosting
                ? null
                : (split) => _editSplit(selectedTransaction, split),
            onCancelSplit: selectedTransaction.isInstallmentPosting
                ? null
                : (split) => _cancelSplit(selectedTransaction, split),
            onSetStatus: selectedTransaction.isInstallmentPosting
                ? null
                : (status) => _changeStatus(selectedTransaction, status),
          ),
        ),
      ],
    );
  }

  MoneyTransactionEntity? get _selectedTransaction {
    final selectedId = _selectedTransactionId;
    if (selectedId == null) {
      return null;
    }
    for (final transaction in _transactions) {
      if (transaction.id == selectedId) {
        return transaction;
      }
    }
    return null;
  }

  Future<void> _openTransactionDetail({
    required MoneyTransactionEntity transaction,
    required bool isWide,
    required List<MoneyAccountEntity> accounts,
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
  }) async {
    if (isWide) {
      setState(() {
        _selectedTransactionId = transaction.id;
      });
      return;
    }

    await showTransactionDetailDialog(
      context: context,
      transaction: transaction,
      accounts: accounts,
      expenseCatalog: expenseCatalog,
      incomeCatalog: incomeCatalog,
      onEdit: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(_openEditDialog(transaction));
            },
      onDelete: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(_confirmDelete(transaction));
            },
      onRefund:
          transaction.isInstallmentPosting ||
              transaction.type != MoneyTransactionType.expense ||
              transaction.status != MoneyTransactionStatus.completed ||
              transaction.amountMinor <= transaction.refundAmountMinor
          ? null
          : () {
              unawaited(_openRefundDialog(transaction));
            },
      onDuplicate:
          transaction.isInstallmentPosting ||
              transaction.type == MoneyTransactionType.transfer
          ? null
          : () {
              unawaited(_openDuplicateDialog(transaction));
            },
      onAddSplit: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(_openSplitDialog(transaction));
            },
      onAddToFamilyLedger: transaction.isInstallmentPosting
          ? null
          : () {
              unawaited(_openAddToFamilyLedgerDialog(transaction));
            },
      onRemoveFromFamilyLedger: transaction.isInstallmentPosting
          ? null
          : (ledger) {
              unawaited(
                _removeTransactionFromFamilyLedger(transaction, ledger),
              );
            },
      onEditSplit: transaction.isInstallmentPosting
          ? null
          : (split) {
              unawaited(_editSplit(transaction, split));
            },
      onCancelSplit: transaction.isInstallmentPosting
          ? null
          : (split) {
              unawaited(_cancelSplit(transaction, split));
            },
      onSetStatus: transaction.isInstallmentPosting
          ? null
          : (status) {
              unawaited(_changeStatus(transaction, status));
            },
    );
  }

  void _closeTransactionDetail() {
    setState(() {
      _selectedTransactionId = null;
    });
  }

  Future<void> _changeStatus(
    MoneyTransactionEntity transaction,
    MoneyTransactionStatus status,
  ) async {
    final toast = _ensureToast();
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .setTransactionStatus(transaction.id, status);
      if (!mounted) return;
      AppToast.success(
        toast,
        context,
        status == MoneyTransactionStatus.completed ? '已确认入账' : '已作废',
      );
      await _refreshTransactions();
    } catch (error) {
      if (!mounted) return;
      AppToast.error(toast, context, moneyTransactionActionErrorText(error));
    }
  }

  int _dayExpenseMinorFor(DateTime date) {
    var total = 0;
    for (final t in _transactions) {
      if (!sameDayKey(t.transactionAt, date)) continue;
      if (t.type == MoneyTransactionType.expense &&
          t.status == MoneyTransactionStatus.completed) {
        total += t.amountMinor - t.refundAmountMinor;
      }
    }
    return total;
  }

  /// 当天已完成流水的币种。
  ///
  /// 原来日期头把币种硬编码成 CNY，多币种用户的日元流水会被标上「¥ 人民币」。
  /// 跨币种求和本身没有意义，这里返回 null，让日期头只显示日期。
  String? _dayCurrencyFor(DateTime date) {
    String? currency;
    for (final t in _transactions) {
      if (!sameDayKey(t.transactionAt, date)) continue;
      if (t.status != MoneyTransactionStatus.completed) continue;
      if (currency == null) {
        currency = t.currencyCode;
      } else if (currency != t.currencyCode) {
        return null;
      }
    }
    return currency;
  }

  int _dayIncomeMinorFor(DateTime date) {
    var total = 0;
    for (final t in _transactions) {
      if (!sameDayKey(t.transactionAt, date)) continue;
      if (t.type == MoneyTransactionType.income &&
          t.status == MoneyTransactionStatus.completed) {
        total += t.amountMinor - t.refundAmountMinor;
      }
    }
    return total;
  }

  Future<void> _refreshTransactions() async {
    if (mounted) {
      setState(() {
        // 只有手里一条都没有时才用骨架；有旧结果就先留着，新的一页到了再整体替换。
        _isLoadingInitial = _transactions.isEmpty;
        _isRefreshing = _transactions.isNotEmpty;
        _loadError = null;
      });
    }
    await _loadTransactions(reset: true);
  }

  /// 导出当前筛选条件下的流行为 CSV（上限 5000 条）。
  Future<void> _exportTransactions() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);
    final toast = _ensureToast();
    try {
      const exportPageSize = 500;
      const maxRows = 5000;
      final all = <MoneyTransactionEntity>[];
      var page = 1;
      while (all.length < maxRows) {
        final result = await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .listTransactions(
              _currentQuery(page: page, pageSize: exportPageSize),
            );
        all.addAll(result.items);
        if (!result.hasMore) break;
        page += 1;
      }
      if (!mounted) return;
      if (all.isEmpty) {
        AppToast.error(toast, context, '当前筛选没有可导出的流水');
        return;
      }

      final accounts = ref
          .read(currentUserVisibleAccountsProvider)
          .maybeWhen(
            data: (value) => value,
            orElse: () => const <MoneyAccountEntity>[],
          );
      final expenseCatalog = ref
          .read(currentUserCategoryCatalogProvider(MoneyCategoryKind.expense))
          .maybeWhen(
            data: (value) => value,
            orElse: () => const MoneyCategoryCatalog.empty(),
          );
      final incomeCatalog = ref
          .read(currentUserCategoryCatalogProvider(MoneyCategoryKind.income))
          .maybeWhen(
            data: (value) => value,
            orElse: () => const MoneyCategoryCatalog.empty(),
          );
      final csv = buildTransactionsCsv(
        transactions: all,
        accountNames: {for (final a in accounts) a.id: a.name},
        categoryNames: {
          for (final c in [
            ...expenseCatalog.categories,
            ...incomeCatalog.categories,
          ])
            c.id: c.name,
        },
        subCategoryNames: {
          for (final s in [
            ...expenseCatalog.subCategories,
            ...incomeCatalog.subCategories,
          ])
            s.id: s.name,
        },
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/miji_transactions.csv');
      await file.writeAsString(csv, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Miji 记账流水导出'),
      );
    } catch (_) {
      if (mounted) AppToast.error(toast, context, '导出失败');
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _loadMoreTransactions() async {
    await _loadTransactions(reset: false);
  }

  Future<void> _loadTransactions({required bool reset}) async {
    final nextPage = reset ? 1 : _page + 1;
    final loadSerial = reset ? ++_loadSerial : _loadSerial;
    try {
      final page = await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .listTransactions(_currentQuery(page: nextPage));
      if (!mounted || loadSerial != _loadSerial) return;
      setState(() {
        if (reset) {
          _transactions.clear();
        }
        _transactions.addAll(page.items);
        if (_selectedTransactionId != null && _selectedTransaction == null) {
          _selectedTransactionId = null;
        }
        _pruneBulkSelection();
        _page = page.page;
        _hasMore = page.hasMore;
        _loadError = null;
        _isLoadingInitial = false;
        _isRefreshing = false;
      });
    } catch (error) {
      if (!mounted || loadSerial != _loadSerial) return;
      setState(() {
        _loadError = reset ? error : null;
        _isLoadingInitial = false;
        _isRefreshing = false;
      });
      if (!reset) {
        AppToast.error(_ensureToast(), context, '加载更多失败');
      }
    }
  }

  /// 丢掉已经不在列表里的选中项（翻页 / 改筛选 / 批量删除之后）。
  void _pruneBulkSelection() {
    if (_bulkSelectedIds.isEmpty) {
      return;
    }
    final visible = <String>{for (final item in _transactions) item.id};
    _bulkSelectedIds.retainWhere(visible.contains);
  }

  MoneyTransactionQuery _currentQuery({required int page, int? pageSize}) {
    return MoneyTransactionQuery(
      page: page,
      pageSize: pageSize ?? _pageSize,
      type: _typeFilter,
      status: _statusFilter,
      tags: _tagFilter,
      accountId: _accountIdFilter,
      categoryId: _categoryIdFilter,
      subCategoryId: _subCategoryIdFilter,
      paymentMethod: _paymentMethodFilter,
      merchant: _merchantFilter,
      customPaymentMethodName: _customPaymentMethodNameFilter,
      dateStart: _dateStartFilter == null
          ? null
          : _startOfDay(_dateStartFilter!),
      dateEnd: _dateEndFilter == null ? null : _endOfDay(_dateEndFilter!),
      keyword: _keywordFilter,
      ledgerId: _activeLedgerId ?? _effectiveInitialQuery.ledgerId,
      budgetId: _budgetIdFilter,
      sortField: _sortField,
      sortAscending: _sortAscending,
    );
  }

  /// 汇总用的 query：与列表同一套筛选条件，但去掉分页。
  MoneyTransactionQuery get _summaryQuery =>
      _currentQuery(page: 1).copyWith(page: 1);

  /// 日期快捷区间。
  void _applyDatePreset(DateTime? start, DateTime? end) {
    setState(() {
      _dateStartFilter = start;
      _dateEndFilter = end;
    });
    _refreshFromFilterChange();
  }

  void _syncActiveLedger(String? ledgerId) {
    if (_activeLedgerId == ledgerId) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeLedgerId == ledgerId) {
        return;
      }
      setState(() {
        _activeLedgerId = ledgerId;
        _transactions.clear();
        _page = 1;
        _hasMore = false;
        _isLoadingInitial = true;
        _loadError = null;
        _selectedTransactionId = null;
        _bulkSelectedIds.clear();
      });
      unawaited(_refreshTransactions());
    });
  }

  void _applyQuery(
    MoneyTransactionQuery query, {
    required bool updateController,
  }) {
    _typeFilter = query.type;
    _statusFilter = query.status;
    _tagFilter = query.tags;
    _budgetIdFilter = query.budgetId;
    _budgetAppliedFilterSnapshot = null;
    _accountIdFilter = query.accountId;
    _categoryIdFilter = query.categoryId;
    _subCategoryIdFilter = query.subCategoryId;
    _paymentMethodFilter = query.paymentMethod;
    _merchantFilter = query.merchant?.trim();
    _customPaymentMethodNameFilter = query.customPaymentMethodName?.trim();
    _dateStartFilter = query.dateStart == null
        ? null
        : _startOfDay(query.dateStart!.toLocal());
    _dateEndFilter = query.dateEnd == null
        ? null
        : _startOfDay(query.dateEnd!.toLocal());
    _keywordFilter = query.keyword?.trim();
    if (updateController) {
      _keywordController.text = _keywordFilter ?? '';
      _merchantController.text = _merchantFilter ?? '';
    }
  }

  void _refreshFromFilterChange() {
    setState(() {
      _page = 1;
      _hasMore = false;
      _loadError = null;
      _selectedTransactionId = null;
      _bulkSelectedIds.clear();
      // 这里故意不清空 `_transactions`、也不置 `_isLoadingInitial`：
      // 交还给 `_refreshTransactions` 去判断「有旧结果就保留」。清空会让列表
      // 先塌成骨架再长回来，点一下筛选整屏白一下。
    });
    unawaited(_refreshTransactions());
  }

  void _setTypeFilter(MoneyTransactionType? value) {
    if (_isTypeLocked) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _typeFilter = value;
      _categoryIdFilter = null;
      _subCategoryIdFilter = null;
    });
    _refreshFromFilterChange();
  }

  /// 状态筛选（待确认 / 已作废）。
  ///
  /// 待确认流水不占余额也不进统计，之前记完就只能靠列表里的角标认出来，
  /// 没有任何入口能把它们筛出来。
  void _setStatusFilter(MoneyTransactionStatus? value) {
    if (_statusFilter == value) {
      return;
    }
    setState(() {
      _statusFilter = value;
      if (value != null) {
        // 待确认 / 已作废往往横跨很久，留着日期区间多半查不到东西。
        _budgetIdFilter = null;
        _budgetAppliedFilterSnapshot = null;
        if (!_isDateLocked) {
          _dateStartFilter = null;
          _dateEndFilter = null;
        }
      }
    });
    _refreshFromFilterChange();
  }

  /// 确认单笔待处理流水入账。
  Future<void> _confirmPending(MoneyTransactionEntity transaction) async {
    await _changeStatus(transaction, MoneyTransactionStatus.completed);
  }

  /// 把当前筛选下的所有待确认流水一次性入账。
  ///
  /// 走当前 query 而不是「全库 pending」：用户在某个账户/分类下点确认，
  /// 不该把手伸到别的地方去。
  Future<void> _confirmAllPending() async {
    if (_isConfirmingAll) {
      return;
    }
    setState(() => _isConfirmingAll = true);
    final toast = _ensureToast();
    try {
      const pageSize = 500;
      const maxRows = 5000;
      final ids = <String>[];
      var page = 1;
      while (ids.length < maxRows) {
        final result = await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .listTransactions(_currentQuery(page: page, pageSize: pageSize));
        ids.addAll(
          result.items
              .where((item) => item.status == MoneyTransactionStatus.pending)
              .map((item) => item.id),
        );
        if (!result.hasMore) {
          break;
        }
        page += 1;
      }
      if (!mounted) {
        return;
      }
      if (ids.isEmpty) {
        AppToast.error(toast, context, '当前筛选没有待确认的流水');
        return;
      }
      final applied = await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .setTransactionsStatus(ids, MoneyTransactionStatus.completed);
      if (!mounted) {
        return;
      }
      if (applied <= 0) {
        AppToast.error(toast, context, '没有可确认的流水');
        return;
      }
      AppToast.success(toast, context, '已确认入账 $applied 笔');
      await _refreshTransactions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(toast, context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _isConfirmingAll = false);
      }
    }
  }

  /// 长按进入多选：顺手关掉右侧详情面板，否则「选中」和「打开详情」会打架。
  void _startBulkSelection(String transactionId) {
    setState(() {
      _selectedTransactionId = null;
      _bulkSelectedIds.add(transactionId);
    });
  }

  void _toggleBulkSelection(String transactionId) {
    setState(() {
      if (!_bulkSelectedIds.remove(transactionId)) {
        _bulkSelectedIds.add(transactionId);
      }
    });
  }

  void _clearBulkSelection() {
    setState(() => _bulkSelectedIds.clear());
  }

  void _selectAllVisible() {
    setState(() {
      _bulkSelectedIds.addAll(_transactions.map((item) => item.id));
    });
  }

  /// 批量操作统一入口：负责 busy 态、条数反馈与刷新。
  ///
  /// 实际写入条数可能少于选中条数（转账 / 分期入账 / 已作废会被跳过），
  /// 这里把跳过数说清楚，否则用户会以为点错了。
  Future<void> _applyBulk(
    Future<int> Function(
      CurrentUserMoneyTransactionActions actions,
      List<String> ids,
    )
    run, {
    required String label,
    bool undoable = false,
  }) async {
    if (_isBulkBusy) {
      return;
    }
    final ids = _bulkSelectedIds.toList(growable: false);
    if (ids.isEmpty) {
      return;
    }
    setState(() => _isBulkBusy = true);
    final toast = _ensureToast();
    try {
      final applied = await run(
        ref.read(currentUserMoneyTransactionActionsProvider),
        ids,
      );
      if (!mounted) {
        return;
      }
      if (applied <= 0) {
        AppToast.error(toast, context, '没有符合条件的流水');
        return;
      }
      final skipped = ids.length - applied;
      final message = skipped > 0
          ? '$label $applied 笔，跳过 $skipped 笔'
          : '$label $applied 笔';
      if (undoable) {
        // 批量删除一次能干掉几十笔，必须留撤销。
        AppToast.undo(
          toast: toast,
          context: context,
          message: message,
          actionLabel: '撤销',
          onAction: () => _restoreTransactions(ids),
        );
      } else {
        AppToast.success(toast, context, message);
      }
      setState(() => _bulkSelectedIds.clear());
      await _refreshTransactions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(toast, context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _isBulkBusy = false);
      }
    }
  }

  Future<void> _bulkSetStatus(MoneyTransactionStatus status) {
    return _applyBulk(
      (actions, ids) => actions.setTransactionsStatus(ids, status),
      label: status == MoneyTransactionStatus.completed ? '已确认入账' : '已作废',
    );
  }

  Future<void> _bulkDelete() async {
    final count = _bulkSelectedIds.length;
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除流水',
      message: '将删除选中的 $count 笔流水并回滚账户余额，确认继续？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _applyBulk(
      (actions, ids) => actions.deleteTransactions(ids),
      label: '已删除',
      undoable: true,
    );
  }

  /// 撤销删除（单条删除走的是 [MoneyTransactionActions] 里的同一套逻辑）。
  Future<void> _restoreTransactions(List<String> ids) async {
    if (_isRestoring) {
      return;
    }
    setState(() => _isRestoring = true);
    final toast = _ensureToast();
    try {
      final applied = await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .restoreTransactions(ids);
      if (!mounted) {
        return;
      }
      if (applied <= 0) {
        AppToast.error(toast, context, '已无法恢复');
        return;
      }
      final skipped = ids.length - applied;
      AppToast.success(
        toast,
        context,
        skipped > 0 ? '已恢复 $applied 笔，跳过 $skipped 笔' : '已恢复 $applied 笔',
      );
      await _refreshTransactions();
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.error(toast, context, _errorText(error));
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  /// 「批量修改」面板：改分类 / 改账户 / 加标签 / 移除标签。
  Future<void> _openBulkEditSheet({
    required List<MoneyAccountEntity> accounts,
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
    required MoneyCategoryUsage? usage,
    required List<String> tagCandidates,
  }) async {
    if (_isBulkBusy) {
      return;
    }
    final selected = _transactions
        .where((item) => _bulkSelectedIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) {
      return;
    }
    final types = <MoneyTransactionType>{
      for (final item in selected) item.type,
    };
    if (types.length == 1 && types.single == MoneyTransactionType.transfer) {
      AppToast.error(_ensureToast(), context, '转账流水不支持批量修改');
      return;
    }
    final existingTags = <String>{
      for (final item in selected) ...item.tags,
    }.toList()..sort();

    final patch = await showTransactionBulkEditSheet(
      context: context,
      selectedCount: selected.length,
      type: types.length == 1 ? types.single : null,
      expenseCatalog: expenseCatalog,
      incomeCatalog: incomeCatalog,
      usage: usage,
      accounts: accounts,
      tagCandidates: tagCandidates,
      existingTags: existingTags,
    );
    if (patch == null || !mounted) {
      return;
    }
    await _applyBulk(
      (actions, ids) => actions.updateTransactions(ids, patch),
      label: '已更新',
    );
  }

  void _setAccountFilter(String? value) {
    if (_isAccountLocked) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _accountIdFilter = value;
    });
    _refreshFromFilterChange();
  }

  void _setPaymentMethodFilter(MoneyPaymentMethod? value) {
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _paymentMethodFilter = value;
      _customPaymentMethodNameFilter = null;
    });
    _refreshFromFilterChange();
  }

  void _setCategoryFilter(String? value) {
    if (_isCategoryLocked) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _categoryIdFilter = value;
      _subCategoryIdFilter = null;
    });
    _refreshFromFilterChange();
  }

  void _setSubCategoryFilter(String? value) {
    if (_isCategoryLocked) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _subCategoryIdFilter = value;
    });
    _refreshFromFilterChange();
  }

  void _setBudgetFilter(String? budgetId, List<MoneyBudgetEntity> budgets) {
    if (budgetId == null) {
      setState(() {
        final snapshot = _budgetAppliedFilterSnapshot;
        _budgetIdFilter = null;
        _budgetAppliedFilterSnapshot = null;
        if (snapshot != null) {
          _typeFilter = snapshot.type;
          _statusFilter = snapshot.status;
          _accountIdFilter = snapshot.accountId;
          _categoryIdFilter = snapshot.categoryId;
          _subCategoryIdFilter = snapshot.subCategoryId;
          _paymentMethodFilter = snapshot.paymentMethod;
          _merchantFilter = snapshot.merchant;
          _customPaymentMethodNameFilter = snapshot.customPaymentMethodName;
          _dateStartFilter = snapshot.dateStart;
          _dateEndFilter = snapshot.dateEnd;
          _keywordFilter = snapshot.keyword;
          _keywordController.text = snapshot.keyword ?? '';
          _merchantController.text = snapshot.merchant ?? '';
        } else {
          _typeFilter = null;
          _statusFilter = null;
          _accountIdFilter = null;
          _categoryIdFilter = null;
          _subCategoryIdFilter = null;
          _paymentMethodFilter = null;
          _customPaymentMethodNameFilter = null;
          _dateStartFilter = null;
          _dateEndFilter = null;
          _keywordFilter = null;
          _keywordController.clear();
          _merchantController.clear();
        }
      });
      _refreshFromFilterChange();
      return;
    }

    MoneyBudgetEntity? selectedBudget;
    for (final budget in budgets) {
      if (budget.id == budgetId) {
        selectedBudget = budget;
        break;
      }
    }
    final budget = selectedBudget;
    if (budget == null) {
      setState(() => _budgetIdFilter = null);
      return;
    }

    setState(() {
      _budgetAppliedFilterSnapshot = _BudgetAppliedFilterSnapshot(
        type: _typeFilter,
        status: _statusFilter,
        accountId: _accountIdFilter,
        categoryId: _categoryIdFilter,
        subCategoryId: _subCategoryIdFilter,
        paymentMethod: _paymentMethodFilter,
        merchant: _merchantFilter,
        customPaymentMethodName: _customPaymentMethodNameFilter,
        dateStart: _dateStartFilter,
        dateEnd: _dateEndFilter,
        keyword: _keywordFilter,
      );
      _budgetIdFilter = budget.id;
      _typeFilter = budget.isIncomeTarget
          ? MoneyTransactionType.income
          : MoneyTransactionType.expense;
      // 预算只看已入账的流水：待确认还没占用额度，混进来会让执行率虚高。
      _statusFilter = MoneyTransactionStatus.completed;
      _accountIdFilter = budget.accountId;
      _categoryIdFilter = budget.categoryId;
      _subCategoryIdFilter = budget.subCategoryId;
      _paymentMethodFilter = null;
      _customPaymentMethodNameFilter = null;
      _merchantFilter = null;
      _dateStartFilter = _startOfDay(budget.periodStart.toLocal());
      _dateEndFilter = _startOfDay(budget.periodEnd.toLocal());
      _keywordFilter = null;
      _keywordController.clear();
      _merchantController.clear();
    });
    _refreshFromFilterChange();
  }

  Future<void> _pickDateRange() async {
    if (_isDateLocked) {
      return;
    }
    final picked = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateStartFilter == null || _dateEndFilter == null
          ? null
          : DateTimeRange(start: _dateStartFilter!, end: _dateEndFilter!),
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _dateStartFilter = picked.start;
      _dateEndFilter = picked.end;
    });
    _refreshFromFilterChange();
  }

  void _clearDateRange() {
    if (_isDateLocked) {
      return;
    }
    setState(() {
      _budgetIdFilter = null;
      _budgetAppliedFilterSnapshot = null;
      _dateStartFilter = null;
      _dateEndFilter = null;
    });
    _refreshFromFilterChange();
  }

  /// 汇总条右侧的「清除筛选」。
  ///
  /// 原实现的按钮是 `onPressed: () {}`——点了完全没反应。这里接上真正的
  /// 清除逻辑；被上下文锁定的条件（从预算/账户点进来）保留。
  void _clearAllFilters() {
    _keywordDebounce?.cancel();
    _merchantDebounce?.cancel();
    _keywordController.clear();
    _merchantController.clear();
    // 预算筛选会带着类型/账户/分类/日期一起进来，先还原快照再清其余条件。
    if (_budgetIdFilter != null) {
      _setBudgetFilter(null, const <MoneyBudgetEntity>[]);
    }
    setState(() {
      if (!_isTypeLocked) {
        _typeFilter = null;
        _budgetIdFilter = null;
        _budgetAppliedFilterSnapshot = null;
      }
      _statusFilter = null;
      _tagFilter = const <String>[];
      if (!_isAccountLocked) {
        _accountIdFilter = null;
      }
      if (!_isCategoryLocked) {
        _categoryIdFilter = null;
        _subCategoryIdFilter = null;
      }
      if (!_isDateLocked) {
        _dateStartFilter = null;
        _dateEndFilter = null;
      }
      _paymentMethodFilter = null;
      _customPaymentMethodNameFilter = null;
      _merchantFilter = null;
      _keywordFilter = null;
    });
    _refreshFromFilterChange();
  }

  /// 已生效条件的可移除 chip。
  ///
  /// 类型和关键词不在其中：类型一直在分段控件上、关键词一直在搜索框里，
  /// 再来一个 chip 就是同一件事说两遍。被上下文锁定（从账户 / 预算下钻进来）
  /// 的条件也不放，它们本来就由页面里的上下文条说明，且本来就不许清除。
  List<Widget> _activeFilterChips({
    required List<MoneyAccountEntity> accounts,
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
    required List<MoneyBudgetEntity> budgets,
  }) {
    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;
    final chips = <Widget>[];

    Widget removable(
      String label, {
      Color? accent,
      required VoidCallback onRemove,
    }) {
      return _buildFilterChip(
        context,
        label: label,
        selected: true,
        accent: accent,
        trailing: '✕',
        onTap: onRemove,
        onTrailingTap: onRemove,
      );
    }

    final status = _statusFilter;
    if (status != null) {
      final pending = status == MoneyTransactionStatus.pending;
      chips.add(
        removable(
          pending ? '待确认' : '已作废',
          accent: pending ? moneyColors.warning : theme.colorScheme.error,
          onRemove: () => _setStatusFilter(null),
        ),
      );
    }

    final hasDateRange = _dateStartFilter != null || _dateEndFilter != null;
    if (!_isDateLocked && hasDateRange) {
      chips.add(
        removable(
          '${_shortDayLabel(_dateStartFilter)} - '
          '${_shortDayLabel(_dateEndFilter)}',
          onRemove: _clearDateRange,
        ),
      );
    }

    if (!_isAccountLocked && _accountIdFilter != null) {
      chips.add(
        removable(
          '账户：${_accountName(accounts, _accountIdFilter)}',
          onRemove: () => _setAccountFilter(null),
        ),
      );
    }

    final catalog = _typeFilter == MoneyTransactionType.income
        ? incomeCatalog
        : expenseCatalog;
    if (!_isCategoryLocked && _categoryIdFilter != null) {
      final name = catalog.categoryById(_categoryIdFilter)?.name;
      chips.add(
        removable(
          '分类：${name ?? '已删除'}',
          onRemove: () => _setCategoryFilter(null),
        ),
      );
    }
    if (!_isCategoryLocked && _subCategoryIdFilter != null) {
      final name = catalog.subCategoryById(_subCategoryIdFilter)?.name;
      chips.add(
        removable(
          '子类：${name ?? '已删除'}',
          onRemove: () => _setSubCategoryFilter(null),
        ),
      );
    }

    final paymentMethod = _paymentMethodFilter;
    if (paymentMethod != null) {
      chips.add(
        removable(
          '渠道：${paymentMethod.label}',
          onRemove: () => _setPaymentMethodFilter(null),
        ),
      );
    }

    final merchant = _merchantFilter;
    if (merchant != null) {
      chips.add(
        removable(
          '商家：$merchant',
          onRemove: () {
            _merchantDebounce?.cancel();
            _merchantController.clear();
            setState(() => _merchantFilter = null);
            _refreshFromFilterChange();
          },
        ),
      );
    }

    if (_budgetIdFilter != null) {
      String? budgetName;
      for (final budget in budgets) {
        if (budget.id == _budgetIdFilter) {
          budgetName = budget.name;
          break;
        }
      }
      chips.add(
        removable(
          '预算：${budgetName ?? '已删除'}',
          onRemove: () => _setBudgetFilter(null, const <MoneyBudgetEntity>[]),
        ),
      );
    }

    // 标签筛选目前只从统计页下钻带过来，页面上没有独立入口。
    // 少了这枚 chip，列表会安静地少掉一部分流水，用户只会以为数据丢了。
    for (final tag in _tagFilter) {
      chips.add(
        removable(
          '#$tag',
          onRemove: () {
            setState(() {
              _tagFilter = _tagFilter
                  .where((item) => item != tag)
                  .toList(growable: false);
            });
            _refreshFromFilterChange();
          },
        ),
      );
    }

    return chips;
  }

  /// 空态里那句「当前筛选：……」，只列真正在生效的条件。
  String _activeFilterDescription({
    required List<MoneyAccountEntity> accounts,
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
    required List<MoneyBudgetEntity> budgets,
  }) {
    final parts = <String>[];
    final type = _typeFilter;
    if (type != null) {
      parts.add(switch (type) {
        MoneyTransactionType.expense => '支出',
        MoneyTransactionType.income => '收入',
        MoneyTransactionType.transfer => '转账',
      });
    }
    final keyword = _keywordFilter;
    if (keyword != null) {
      parts.add('含「$keyword」');
    }
    if (_dateStartFilter != null || _dateEndFilter != null) {
      parts.add(
        '${_shortDayLabel(_dateStartFilter)} - '
        '${_shortDayLabel(_dateEndFilter)}',
      );
    }
    if (_accountIdFilter != null) {
      parts.add(_accountName(accounts, _accountIdFilter));
    }
    final catalog = type == MoneyTransactionType.income
        ? incomeCatalog
        : expenseCatalog;
    final category = catalog.categoryById(_categoryIdFilter)?.name;
    if (category != null) {
      parts.add(category);
    }
    final subCategory = catalog.subCategoryById(_subCategoryIdFilter)?.name;
    if (subCategory != null) {
      parts.add(subCategory);
    }
    final paymentMethod = _paymentMethodFilter;
    if (paymentMethod != null) {
      parts.add(paymentMethod.label);
    }
    final merchant = _merchantFilter;
    if (merchant != null) {
      parts.add(merchant);
    }
    final status = _statusFilter;
    if (status != null) {
      parts.add(status == MoneyTransactionStatus.pending ? '待确认' : '已作废');
    }
    if (_budgetIdFilter != null) {
      for (final budget in budgets) {
        if (budget.id == _budgetIdFilter) {
          parts.add('预算「${budget.name}」');
          break;
        }
      }
    }
    parts.addAll(_tagFilter.map((tag) => '#$tag'));

    if (parts.isEmpty) {
      return '当前没有生效的筛选条件。';
    }
    return '当前筛选：${parts.join(' · ')}';
  }

  String _shortDayLabel(DateTime? value) {
    if (value == null) {
      return '—';
    }
    final local = value.toLocal();
    return '${local.month}/${local.day}';
  }

  void _setKeywordFilterDebounced(String value) {
    _keywordDebounce?.cancel();
    _keywordDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      setState(() {
        final keyword = value.trim();
        _keywordFilter = keyword.isEmpty ? null : keyword;
      });
      _refreshFromFilterChange();
    });
  }

  void _setMerchantFilterDebounced(String value) {
    _merchantDebounce?.cancel();
    _merchantDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      setState(() {
        final merchant = value.trim();
        _merchantFilter = merchant.isEmpty ? null : merchant;
      });
      _refreshFromFilterChange();
    });
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  MoneyTransactionActions _transactionActions() {
    return MoneyTransactionActions(
      context: context,
      ref: ref,
      ensureToast: _ensureToast,
      isMounted: () => mounted,
      onChanged: _refreshTransactions,
    );
  }

  Future<void> _openCreateFromEmptyState() async {
    final type = _typeFilter == MoneyTransactionType.income
        ? MoneyTransactionType.income
        : _typeFilter == MoneyTransactionType.transfer
        ? MoneyTransactionType.transfer
        : MoneyTransactionType.expense;
    if (type == MoneyTransactionType.transfer) {
      await _openTransferDialog();
      return;
    }
    await _openTransactionDialog(type);
  }

  Future<void> _openTransactionDialog(MoneyTransactionType type) async {
    final ledger = ref.read(currentUserEffectiveTransactionLedgerValueProvider);

    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(
        type: type,
        ledger: ledger,
        // 表单自己调用写入，才能支持「保存并继续」
        // （保持表单打开、只清金额），并在失败时就地回显错误。
        onSubmit: (result) => _createFromForm(type, result),
      ),
    );
  }

  /// 返回错误文案（null = 成功）。
  Future<String?> _createFromForm(
    MoneyTransactionType type,
    Object result,
  ) async {
    if (result is! TransactionCreateFormResult) {
      return null;
    }
    try {
      final splitConfig = result.splitConfig;
      if (splitConfig == null) {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransaction(result.draft);
      } else {
        await ref
            .read(currentUserMoneyTransactionActionsProvider)
            .createTransactionWithSplit(result.draft, splitConfig);
      }
      if (mounted) {
        AppToast.success(_ensureToast(), context, '${type.label}已记录');
      }
      return null;
    } catch (error) {
      return _errorText(error);
    }
  }

  Future<void> _openTransferDialog() async {
    // 写入交给表单自己（onSubmit），「保存并继续」才能在同一个对话框里连着记
    // 多笔；失败时错误文案回显在表单上，而不是发一个转瞬即逝的 toast。
    await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransferFormDialog(onSubmit: _createTransfer),
    );
  }

  /// 返回错误文案（null = 成功），供转账表单回显。
  Future<String?> _createTransfer(MoneyTransferDraft draft) async {
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(draft);
      if (mounted) {
        AppToast.success(_ensureToast(), context, '转账已记录');
      }
      return null;
    } catch (error) {
      return _errorText(error);
    }
  }

  Future<void> _openEditDialog(MoneyTransactionEntity transaction) async {
    await _transactionActions().edit(transaction);
  }

  Future<void> _openRefundDialog(MoneyTransactionEntity transaction) async {
    await _transactionActions().refund(transaction);
  }

  Future<void> _openDuplicateDialog(MoneyTransactionEntity transaction) async {
    await _transactionActions().duplicate(transaction);
  }

  Future<void> _openSplitDialog(MoneyTransactionEntity transaction) async {
    if (transaction.type != MoneyTransactionType.expense) {
      AppToast.error(_ensureToast(), context, '只有支出流水可以分摊');
      return;
    }
    final ledger = await _selectSplitLedgerForTransaction(transaction);
    if (ledger == null) {
      return;
    }
    final members = await ref.read(
      currentUserMoneyLedgerMembersProvider(ledger.id).future,
    );
    if (members.length < 2) {
      if (mounted) {
        AppToast.error(_ensureToast(), context, '当前账本至少需要两个成员才能分摊');
      }
      return;
    }
    if (!mounted) {
      return;
    }
    final result = await showAppResponsiveDialog<MoneySplitConfigDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionSplitDialog(
        ledgerId: ledger.id,
        initialMembers: members,
        amountMinor: transaction.amountMinor,
        currencyCode: transaction.currencyCode,
        title: '添加分摊',
        confirmLabel: '创建分摊',
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .createSplitForTransaction(result.forTransaction(transaction.id));
      if (!mounted) return;
      await _refreshTransactions();
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分摊已创建');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _openAddToFamilyLedgerDialog(
    MoneyTransactionEntity transaction,
  ) async {
    final familyLedgers = await _availableFamilyLedgersForTransaction(
      transaction.id,
    );
    if (!mounted) {
      return;
    }
    if (familyLedgers.isEmpty) {
      AppToast.error(_ensureToast(), context, '没有可加入的家庭账本');
      return;
    }
    final ledger = await _pickFamilyLedger(
      familyLedgers,
      title: '加入家庭账本',
      subtitle: '此流水仍会保留在个人账本中',
      confirmTooltip: '加入',
      confirmIcon: Icons.group_add_outlined,
    );
    if (ledger == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .linkTransactionToLedger(
            transactionId: transaction.id,
            ledgerId: ledger.id,
          );
      if (!mounted) return;
      await _refreshTransactions();
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '已加入家庭账本');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<MoneyLedgerEntity?> _selectSplitLedgerForTransaction(
    MoneyTransactionEntity transaction,
  ) async {
    final ledgers = await ref.read(
      currentUserTransactionLedgersProvider(transaction.id).future,
    );
    if (!mounted) {
      return null;
    }
    final familyLedgers = ledgers.where((ledger) => ledger.isFamily).toList();
    final currentLedger = ref.read(currentUserCurrentLedgerValueProvider);
    if (currentLedger != null && currentLedger.isFamily) {
      for (final ledger in familyLedgers) {
        if (ledger.id == currentLedger.id) {
          return ledger;
        }
      }
    }
    if (familyLedgers.length == 1) {
      return familyLedgers.first;
    }
    if (familyLedgers.length > 1) {
      return _pickFamilyLedger(
        familyLedgers,
        title: '选择分摊账本',
        subtitle: '此流水属于多个家庭账本',
        confirmTooltip: '继续',
      );
    }

    final availableLedgers = await _availableFamilyLedgersForTransaction(
      transaction.id,
    );
    if (!mounted) {
      return null;
    }
    if (availableLedgers.isEmpty) {
      AppToast.error(_ensureToast(), context, '没有可用于分摊的家庭账本');
      return null;
    }
    return _pickFamilyLedger(
      availableLedgers,
      title: '选择家庭账本',
      subtitle: '创建分摊后，此流水会加入所选家庭账本',
      confirmTooltip: '继续',
    );
  }

  Future<List<MoneyLedgerEntity>> _availableFamilyLedgersForTransaction(
    String transactionId,
  ) async {
    final ledgers = await ref.read(currentUserMoneyLedgersProvider.future);
    final memberships = await ref.read(
      currentUserTransactionLedgersProvider(transactionId).future,
    );
    final linkedIds = memberships.map((ledger) => ledger.id).toSet();
    return ledgers
        .where((ledger) => ledger.isFamily && !linkedIds.contains(ledger.id))
        .toList();
  }

  Future<MoneyLedgerEntity?> _pickFamilyLedger(
    List<MoneyLedgerEntity> ledgers, {
    required String title,
    String? subtitle,
    String confirmTooltip = '确定',
    IconData confirmIcon = Icons.check_rounded,
  }) {
    return showAppResponsiveDialog<MoneyLedgerEntity>(
      context: context,
      builder: (context) => _FamilyLedgerPickerDialog(
        title: title,
        subtitle: subtitle,
        ledgers: ledgers,
        confirmTooltip: confirmTooltip,
        confirmIcon: confirmIcon,
      ),
    );
  }

  Future<void> _removeTransactionFromFamilyLedger(
    MoneyTransactionEntity transaction,
    MoneyLedgerEntity ledger,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '移出家庭账本',
      message: '此流水仍会保留在个人账本中。',
      confirmLabel: '移出',
      icon: Icons.link_off_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .unlinkTransactionFromLedger(
            transactionId: transaction.id,
            ledgerId: ledger.id,
          );
      if (!mounted) return;
      await _refreshTransactions();
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '已移出家庭账本');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _editSplit(
    MoneyTransactionEntity transaction,
    MoneySplitRecordEntity split,
  ) async {
    final members = await ref.read(
      currentUserMoneyLedgerMembersProvider(split.ledgerId).future,
    );
    if (!mounted) {
      return;
    }

    final result = await showAppResponsiveDialog<MoneySplitConfigDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionSplitDialog(
        ledgerId: split.ledgerId,
        initialMembers: members,
        amountMinor: transaction.amountMinor,
        currencyCode: transaction.currencyCode,
        initialRecord: split,
        title: '编辑分摊',
        confirmLabel: '保存分摊',
      ),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .replaceSplitForTransaction(result.forTransaction(transaction.id));
      if (!mounted) return;
      await _refreshTransactions();
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分摊已更新');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _cancelSplit(
    MoneyTransactionEntity transaction,
    MoneySplitRecordEntity split,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '取消分摊',
      message: '取消后，此流水仍会保留，分摊记录不再展示为有效记录。',
      confirmLabel: '取消分摊',
      icon: Icons.close_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .cancelSplitRecord(
            splitRecordId: split.id,
            transactionId: transaction.id,
            ledgerId: split.ledgerId,
          );
      if (!mounted) return;
      await _refreshTransactions();
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '分摊已取消');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _confirmDelete(MoneyTransactionEntity transaction) async {
    await _transactionActions().delete(transaction);
  }

  Future<void> _openRecycleBin() {
    return showAppResponsiveDialog<void>(
      context: context,
      builder: (context) => const TransactionRecycleBinSheet(),
    );
  }

  /// 当前筛选能不能直接翻译成一个预算 scope。
  ///
  /// 只认「分类 / 账户 / 标签」这三个预算支持的维度：关键词、支付方式、
  /// 日期这些预算 scope 里没有，硬凑出来的预算会对不上账。
  _BudgetPreset? _budgetPresetFromFilters({
    required MoneyCategoryCatalog expenseCatalog,
    required MoneyCategoryCatalog incomeCatalog,
    required List<MoneyAccountEntity> accounts,
  }) {
    final isIncome = _typeFilter == MoneyTransactionType.income;
    final catalog = isIncome ? incomeCatalog : expenseCatalog;
    final trackingType = isIncome
        ? MoneyBudgetTrackingType.incomeTarget
        : MoneyBudgetTrackingType.expenseLimit;

    if (_tagFilter.isNotEmpty) {
      final tag = _tagFilter.first;
      return _BudgetPreset(
        scopeType: MoneyBudgetScopeType.tag,
        tag: tag,
        trackingType: trackingType,
        label: '为标签「$tag」设预算',
      );
    }

    final categoryId = _categoryIdFilter;
    final accountId = _accountIdFilter;
    if (categoryId != null) {
      final category = catalog.categoryById(categoryId);
      final subCategory = catalog.subCategoryById(_subCategoryIdFilter);
      final categoryName = subCategory?.name ?? category?.name ?? '该分类';
      final accountName = _accountName(accounts, accountId);
      if (accountId != null) {
        return _BudgetPreset(
          scopeType: MoneyBudgetScopeType.categoryAccount,
          categoryId: categoryId,
          subCategoryId: _subCategoryIdFilter,
          accountId: accountId,
          trackingType: trackingType,
          label: '为「$categoryName · $accountName」设预算',
        );
      }
      return _BudgetPreset(
        scopeType: MoneyBudgetScopeType.category,
        categoryId: categoryId,
        subCategoryId: _subCategoryIdFilter,
        trackingType: trackingType,
        label: '为「$categoryName」设预算',
      );
    }

    if (accountId != null) {
      return _BudgetPreset(
        scopeType: MoneyBudgetScopeType.account,
        accountId: accountId,
        trackingType: trackingType,
        label: '为「${_accountName(accounts, accountId)}」设预算',
      );
    }
    return null;
  }

  String _accountName(List<MoneyAccountEntity> accounts, String? accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.name;
      }
    }
    return '该账户';
  }

  Future<void> _openBudgetDialog(_BudgetPreset preset) {
    return showAppResponsiveDialog<void>(
      context: context,
      builder: (context) => BudgetFormDialog(
        initialScopeType: preset.scopeType,
        initialCategoryId: preset.categoryId,
        initialSubCategoryId: preset.subCategoryId,
        initialAccountId: preset.accountId,
        initialTag: preset.tag,
        initialTrackingType: preset.trackingType,
      ),
    );
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _errorText(Object error) {
    return moneyTransactionActionErrorText(error);
  }
}

class MoneyTransactionFilterContext {
  const MoneyTransactionFilterContext({
    required this.title,
    required this.subtitle,
    required this.contextLabel,
    required this.onClear,
    this.account,
    this.accountSummary,
    this.lockType = false,
    this.lockAccount = false,
    this.lockCategory = false,
    this.lockDateRange = false,
  });

  final String title;
  final String subtitle;
  final String contextLabel;
  final VoidCallback onClear;
  final MoneyAccountEntity? account;
  final MoneyAccountMonthlySummary? accountSummary;
  final bool lockType;
  final bool lockAccount;
  final bool lockCategory;
  final bool lockDateRange;
}

class _FamilyLedgerPickerDialog extends StatefulWidget {
  const _FamilyLedgerPickerDialog({
    required this.title,
    required this.ledgers,
    required this.confirmTooltip,
    required this.confirmIcon,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<MoneyLedgerEntity> ledgers;
  final String confirmTooltip;
  final IconData confirmIcon;

  @override
  State<_FamilyLedgerPickerDialog> createState() =>
      _FamilyLedgerPickerDialogState();
}

class _FamilyLedgerPickerDialogState extends State<_FamilyLedgerPickerDialog> {
  late String _ledgerId;

  @override
  void initState() {
    super.initState();
    _ledgerId = widget.ledgers.first.id;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      maxWidth: 360,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: FormDropdown<String>(
        initialSelection: _ledgerId,
        label: '家庭账本',
        leadingIcon: const Icon(Icons.groups_2_outlined),
        width: double.infinity,
        entries: [
          for (final ledger in widget.ledgers)
            DropdownMenuEntry<String>(
              value: ledger.id,
              label: ledger.name,
              labelWidget: Row(
                children: [
                  const Icon(Icons.groups_2_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ledger.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
        onSelected: (value) {
          if (value == null) return;
          setState(() => _ledgerId = value);
        },
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: widget.confirmTooltip,
        confirmIcon: widget.confirmIcon,
      ),
    );
  }

  void _submit() {
    for (final ledger in widget.ledgers) {
      if (ledger.id == _ledgerId) {
        Navigator.of(context).pop(ledger);
        return;
      }
    }
    Navigator.of(context).pop();
  }
}

class _AccountTransactionSummaryPanel extends StatelessWidget {
  const _AccountTransactionSummaryPanel({
    required this.account,
    required this.summary,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final currentIncome = summary?.currentIncomeMinor ?? 0;
    final currentExpense = summary?.currentExpenseMinor ?? 0;
    final currentNet = summary?.currentNetMinor ?? 0;

    return AppPlainPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppListItemIcon(
                icon: Icons.account_balance_wallet_rounded,
                color: colorScheme.primary,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${account.type.label} · ${account.currencyCode}',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: [
              _SummaryMetric(
                label: account.type.isCreditLike ? '可用额度' : '当前余额',
                amountMinor: account.displayBalanceMinor,
                currencyCode: account.currencyCode,
                valueColor: colorScheme.primary,
              ),
              _SummaryMetric(
                label: account.type.isCreditLike ? '信用额度' : '初始余额',
                amountMinor: account.type.isCreditLike
                    ? account.effectiveCreditLimitMinor
                    : account.initialBalanceMinor,
                currencyCode: account.currencyCode,
              ),
              if (account.type.isCreditLike) ...[
                _SummaryMetric(
                  label: '已入账负债',
                  amountMinor: account.effectivePostedDebtMinor,
                  currencyCode: account.currencyCode,
                  valueColor: colorScheme.error,
                ),
                _SummaryMetric(
                  label: '冻结额度',
                  amountMinor: account.effectiveFrozenCreditMinor,
                  currencyCode: account.currencyCode,
                ),
              ],
              _SummaryMetric(
                label: '本月收入',
                amountMinor: currentIncome,
                currencyCode: account.currencyCode,
                valueColor: moneyColors.income,
              ),
              _SummaryMetric(
                label: '本月支出',
                amountMinor: currentExpense,
                currencyCode: account.currencyCode,
                valueColor: colorScheme.error,
              ),
              _SummaryMetric(
                label: currentNet >= 0 ? '本月净胜' : '本月净支出',
                amountMinor: currentNet.abs(),
                currencyCode: account.currencyCode,
              ),
              _SummaryMetric(
                label: '支出对比',
                value: maskedMoneyOr(
                  _expenseChangeText,
                  MoneyPrivacy.of(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _expenseChangeText {
    final summary = this.summary;
    if (summary == null || !summary.hasPreviousExpense) {
      return '暂无上月对比';
    }
    if (summary.expenseChangeMinor == 0) {
      return '较上月持平';
    }
    final label = summary.expenseChangeMinor > 0 ? '多' : '少';
    final value = formatMoneyMinor(
      summary.expenseChangeMinor.abs(),
      account.currencyCode,
    );
    // 由调用方套 maskedMoneyOr（见 _SummaryMetric 的 masked 参数）。
    return '较上月$label $value';
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    this.value,
    this.amountMinor,
    this.currencyCode = 'CNY',
    this.valueColor,
  }) : assert(value != null || amountMinor != null);

  final String label;
  final String? value;
  final int? amountMinor;
  final String currencyCode;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 3),
          if (amountMinor != null)
            MoneyText(
              amountMinor: amountMinor!,
              currencyCode: currencyCode,
              color: valueColor,
              textStyle: theme.textTheme.titleSmall?.copyWith(
                color: valueColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            )
          else
            Text(
              value!,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: valueColor ?? colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _TransactionFilterFields extends StatelessWidget {
  const _TransactionFilterFields({
    required this.type,
    required this.budgetId,
    required this.accountId,
    required this.paymentMethod,
    required this.categoryId,
    required this.subCategoryId,
    required this.dateStart,
    required this.dateEnd,
    required this.budgets,
    required this.accounts,
    required this.catalog,
    required this.categoryKind,
    required this.contextLabel,
    required this.isTypeLocked,
    required this.isAccountLocked,
    required this.isCategoryLocked,
    required this.isDateLocked,
    required this.keywordController,
    required this.merchantController,
    required this.onBudgetChanged,
    required this.onTypeChanged,
    required this.onAccountChanged,
    required this.onPaymentMethodChanged,
    required this.onCategoryChanged,
    required this.onSubCategoryChanged,
    required this.onDateRangePressed,
    required this.onClearDateRange,
    required this.onKeywordChanged,
    required this.onMerchantChanged,
    required this.onClearContext,
  });

  final MoneyTransactionType? type;
  final String? budgetId;
  final String? accountId;
  final MoneyPaymentMethod? paymentMethod;
  final String? categoryId;
  final String? subCategoryId;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final List<MoneyBudgetEntity> budgets;
  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog catalog;
  final MoneyCategoryKind categoryKind;
  final String? contextLabel;
  final bool isTypeLocked;
  final bool isAccountLocked;
  final bool isCategoryLocked;
  final bool isDateLocked;
  final TextEditingController keywordController;
  final TextEditingController merchantController;
  final ValueChanged<String?> onBudgetChanged;
  final ValueChanged<MoneyTransactionType?> onTypeChanged;
  final ValueChanged<String?> onAccountChanged;
  final ValueChanged<MoneyPaymentMethod?> onPaymentMethodChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSubCategoryChanged;
  final VoidCallback onDateRangePressed;
  final VoidCallback onClearDateRange;
  final ValueChanged<String> onKeywordChanged;
  final ValueChanged<String> onMerchantChanged;
  final VoidCallback? onClearContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedCategory = catalog.categoryById(categoryId);
    final subCategories = selectedCategory == null
        ? const <MoneySubCategoryEntity>[]
        : catalog.subCategoriesFor(selectedCategory.id);
    final canFilterCategory =
        type == MoneyTransactionType.income ||
        type == MoneyTransactionType.expense;
    final closeSheet = AppFilterSheetTrigger.maybeCloserOf(context);
    void apply(VoidCallback onChange) {
      onChange();
      closeSheet?.call();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (contextLabel != null)
          SizedBox(
            width: 260,
            child: _FilterContextBanner(
              label: contextLabel!,
              onClearContext: onClearContext,
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FormDropdown<String?>(
              key: ValueKey('transaction-budget-${budgetId ?? 'all'}'),
              width: 160,
              initialSelection: budgetId,
              label: '预算',
              leadingIcon: const Icon(Icons.flag_rounded),
              onSelected: (value) => apply(() => onBudgetChanged(value)),
              enableFilter: true,
              menuHeight: 280,
              entries: [
                const DropdownMenuEntry<String?>(value: null, label: '全部预算'),
                ...budgets.map(
                  (budget) => DropdownMenuEntry<String?>(
                    value: budget.id,
                    label: budget.name,
                  ),
                ),
              ],
            ),
            FormDropdown<MoneyTransactionType?>(
              key: ValueKey('transaction-type-${type?.name ?? 'all'}'),
              width: 140,
              initialSelection: type,
              label: '交易类型',
              enabled: !isTypeLocked,
              leadingIcon: const Icon(Icons.tune_rounded),
              onSelected: (value) => apply(() => onTypeChanged(value)),
              entries: [
                const DropdownMenuEntry<MoneyTransactionType?>(
                  value: null,
                  label: '全部交易类型',
                ),
                ...MoneyTransactionType.values.map(
                  (type) => DropdownMenuEntry<MoneyTransactionType?>(
                    value: type,
                    label: type.label,
                  ),
                ),
              ],
            ),
            FormDropdown<String?>(
              key: ValueKey('transaction-account-${accountId ?? 'all'}'),
              width: 140,
              initialSelection: accountId,
              label: '账户',
              enabled: !isAccountLocked,
              leadingIcon: const Icon(Icons.account_balance_wallet_rounded),
              onSelected: (value) => apply(() => onAccountChanged(value)),
              enableFilter: true,
              menuHeight: 280,
              entries: [
                const DropdownMenuEntry<String?>(value: null, label: '全部账户'),
                ...accounts.map(
                  (account) => DropdownMenuEntry<String?>(
                    value: account.id,
                    label: account.name,
                  ),
                ),
              ],
            ),
            FormDropdown<MoneyPaymentMethod?>(
              key: ValueKey(
                'transaction-payment-${paymentMethod?.name ?? 'all'}',
              ),
              width: 140,
              initialSelection: paymentMethod,
              label: '支付渠道',
              leadingIcon: const Icon(Icons.payment_rounded),
              onSelected: (value) => apply(() => onPaymentMethodChanged(value)),
              enableFilter: true,
              menuHeight: 280,
              entries: [
                const DropdownMenuEntry<MoneyPaymentMethod?>(
                  value: null,
                  label: '全部支付渠道',
                ),
                ...MoneyPaymentMethod.values.map(
                  (method) => DropdownMenuEntry<MoneyPaymentMethod?>(
                    value: method,
                    label: method.label,
                  ),
                ),
              ],
            ),
            FormDropdown<String?>(
              key: ValueKey('transaction-category-${categoryId ?? 'all'}'),
              width: 140,
              initialSelection: categoryId,
              label: categoryKind == MoneyCategoryKind.income ? '收入分类' : '支出分类',
              enabled: !isCategoryLocked && canFilterCategory,
              leadingIcon: const Icon(Icons.category_rounded),
              onSelected: (value) => apply(() => onCategoryChanged(value)),
              enableFilter: true,
              menuHeight: 280,
              entries: [
                const DropdownMenuEntry<String?>(value: null, label: '全部分类'),
                ...catalog.categories.map(
                  (category) => DropdownMenuEntry<String?>(
                    value: category.id,
                    label: category.name,
                  ),
                ),
              ],
            ),
            FormDropdown<String?>(
              key: ValueKey(
                'transaction-sub-category-${subCategoryId ?? 'all'}',
              ),
              width: 160,
              initialSelection: subCategoryId,
              label: '子分类',
              enabled:
                  !isCategoryLocked &&
                  canFilterCategory &&
                  selectedCategory != null,
              leadingIcon: const Icon(Icons.sell_rounded),
              onSelected: (value) => apply(() => onSubCategoryChanged(value)),
              enableFilter: true,
              menuHeight: 280,
              entries: [
                const DropdownMenuEntry<String?>(value: null, label: '全部子分类'),
                ...subCategories.map(
                  (subCategory) => DropdownMenuEntry<String?>(
                    value: subCategory.id,
                    label: subCategory.name,
                  ),
                ),
              ],
            ),
            AppIconActionButton(
              tooltip: _dateRangeTooltip,
              onPressed: isDateLocked ? null : onDateRangePressed,
              icon: Icons.date_range_rounded,
              variant: AppIconActionVariant.outlined,
            ),
            if (dateStart != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: Text(
                  _dateRangeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            if (dateStart != null && !isDateLocked)
              IconButton.outlined(
                tooltip: '清除日期',
                onPressed: onClearDateRange,
                icon: const Icon(Icons.event_busy_rounded),
              ),
            SizedBox(
              width: 260,
              child: AppTextField(
                controller: keywordController,
                onChanged: onKeywordChanged,
                textInputAction: TextInputAction.search,
                hintText: '搜索名称 / 备注',
                prefixIcon: const Icon(Icons.search_rounded),
                compact: true,
              ),
            ),
            SizedBox(
              width: 260,
              child: AppTextField(
                controller: merchantController,
                onChanged: onMerchantChanged,
                textInputAction: TextInputAction.search,
                hintText: '搜索商家（模糊匹配）',
                prefixIcon: const Icon(Icons.storefront_rounded),
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String get _dateRangeLabel {
    final start = dateStart;
    final end = dateEnd;
    if (start == null || end == null) {
      return '日期范围';
    }
    return '${_dateText(start)} - ${_dateText(end)}';
  }

  String get _dateRangeTooltip {
    final start = dateStart;
    final end = dateEnd;
    if (start == null || end == null) {
      return '选择日期范围';
    }
    return '日期范围：${_dateText(start)} - ${_dateText(end)}';
  }

  String _dateText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$month-$day';
  }
}

/// 排序按钮：时间 / 金额，点一次切换方向。
class _TransactionsSortButton extends StatelessWidget {
  const _TransactionsSortButton({
    required this.sortField,
    required this.sortAscending,
    required this.onChanged,
  });

  final MoneyTransactionSortField sortField;
  final bool sortAscending;
  final void Function(MoneyTransactionSortField field, bool ascending)
  onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<MoneyTransactionSortField>(
      tooltip: '排序',
      position: PopupMenuPosition.under,
      onSelected: (field) {
        final ascending = field == sortField ? !sortAscending : false;
        onChanged(field, ascending);
      },
      itemBuilder: (context) => [
        for (final field in MoneyTransactionSortField.values)
          PopupMenuItem(
            value: field,
            child: Row(
              children: [
                Icon(
                  field == sortField
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: field == sortField
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
                const SizedBox(width: 10),
                Text(
                  field == sortField
                      ? '${field.label} ${sortAscending ? '↑' : '↓'}'
                      : field.label,
                ),
              ],
            ),
          ),
      ],
      child: Container(
        width: 44,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Icon(
          Icons.swap_vert_rounded,
          size: 19,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 操作行最右侧的 ⋯：收低频动作。
///
/// 导出与回收站原来各占一个 44dp 图标按钮，和排序、高级筛选一起把分段控件
/// 挤到只能靠 minSegmentWidth=44 才放得下四段。收进来之后分段控件拿回 96dp。
class _TransactionsMoreMenu extends StatelessWidget {
  const _TransactionsMoreMenu({
    required this.exporting,
    required this.onExport,
    required this.onOpenRecycleBin,
  });

  final bool exporting;
  final VoidCallback onExport;
  final VoidCallback onOpenRecycleBin;

  static const _exportValue = 'export';
  static const _recycleValue = 'recycle';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      tooltip: '更多操作',
      position: PopupMenuPosition.under,
      onSelected: (value) {
        if (value == _exportValue) {
          onExport();
          return;
        }
        onOpenRecycleBin();
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _exportValue,
          enabled: !exporting,
          child: Row(
            children: [
              Icon(
                Icons.ios_share_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              const Text('导出流水'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _recycleValue,
          child: Row(
            children: [
              Icon(
                Icons.restore_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              const Text('回收站'),
            ],
          ),
        ),
      ],
      // 外形跟排序按钮对齐，操作行里几个控件才是同一条线。
      child: Container(
        width: 44,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 19,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// 改筛选时压在列表顶部的细进度条。
///
/// 位置用 Stack 固定在列表上沿，不参与布局，所以出现和消失都不会让列表跳。
class _InlineRefreshBar extends StatelessWidget {
  const _InlineRefreshBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 2.5,
      child: LinearProgressIndicator(
        minHeight: 2.5,
        backgroundColor: Colors.transparent,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// 流水状态筛选：待确认 / 已作废。
///
/// 这两类流水之前完全查不出来——查询模型里没有状态字段，而它们又
/// 不占余额、不计入统计，等于记完就丢。
class _TransactionStatusChips extends StatelessWidget {
  const _TransactionStatusChips({
    required this.status,
    required this.pendingCount,
    required this.onChanged,
  });

  final MoneyTransactionStatus? status;
  final int pendingCount;
  final ValueChanged<MoneyTransactionStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children:
            [
                  _buildFilterChip(
                    context,
                    label: '全部状态',
                    selected: status == null,
                    onTap: () => onChanged(null),
                    accent: colorScheme.primary,
                  ),
                  _buildFilterChip(
                    context,
                    label: pendingCount > 0 ? '待确认 $pendingCount' : '待确认',
                    selected: status == MoneyTransactionStatus.pending,
                    onTap: () => onChanged(
                      status == MoneyTransactionStatus.pending
                          ? null
                          : MoneyTransactionStatus.pending,
                    ),
                    accent: moneyColors.warning,
                  ),
                  _buildFilterChip(
                    context,
                    label: '已作废',
                    selected: status == MoneyTransactionStatus.voided,
                    onTap: () => onChanged(
                      status == MoneyTransactionStatus.voided
                          ? null
                          : MoneyTransactionStatus.voided,
                    ),
                    accent: colorScheme.error,
                  ),
                ]
                .map(
                  (widget) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: widget,
                  ),
                )
                .toList(),
      ),
    );
  }
}

/// 「筛选」开关：展开 / 收起常用筛选条，右侧角标是生效条件数量。
class _TransactionFilterToggle extends StatelessWidget {
  const _TransactionFilterToggle({
    required this.expanded,
    required this.activeCount,
    required this.onPressed,
  });

  final bool expanded;
  final int activeCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final active = activeCount > 0;
    final foreground = active
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: expanded ? '收起筛选' : '展开筛选',
      child: Material(
        color: active
            ? colorScheme.primaryContainer.withValues(alpha: 0.45)
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active
                    ? colorScheme.primary.withValues(alpha: 0.4)
                    : colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list_rounded, size: 17, color: foreground),
                const SizedBox(width: 6),
                Text(
                  '筛选',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$activeCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 常用筛选条。
///
/// 状态与日期原来各占一条常驻 chips（合计 82dp），不管用不用都摆在那儿。
/// 折叠态只渲染「已生效的条件」——一条都没有就整块不占高度；展开后才铺出
/// 两组预设，展开是显式操作，多占两行是能接受的代价。
class _TransactionFilterStrip extends StatelessWidget {
  const _TransactionFilterStrip({
    required this.expanded,
    required this.status,
    required this.pendingCount,
    required this.dateStart,
    required this.dateEnd,
    required this.activeChips,
    required this.onStatusChanged,
    required this.onPickDateRange,
    required this.onSelectDatePreset,
  });

  final bool expanded;
  final MoneyTransactionStatus? status;
  final int pendingCount;
  final DateTime? dateStart;
  final DateTime? dateEnd;
  final List<Widget> activeChips;
  final ValueChanged<MoneyTransactionStatus?> onStatusChanged;
  final VoidCallback onPickDateRange;
  final void Function(DateTime? start, DateTime? end) onSelectDatePreset;

  @override
  Widget build(BuildContext context) {
    final showActive = activeChips.isNotEmpty;
    if (!expanded && !showActive) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (expanded) ...[
          const SizedBox(height: 10),
          _TransactionStatusChips(
            status: status,
            pendingCount: pendingCount,
            onChanged: onStatusChanged,
          ),
          const SizedBox(height: 8),
          _TransactionDateChips(
            dateStart: dateStart,
            dateEnd: dateEnd,
            onPickRange: onPickDateRange,
            onSelectPreset: onSelectDatePreset,
          ),
        ],
        if (showActive) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final chip in activeChips)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: chip,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// 待确认视图顶部的说明 + 批量入账。
class _PendingConfirmBanner extends StatelessWidget {
  const _PendingConfirmBanner({
    required this.count,
    required this.busy,
    required this.onConfirmAll,
  });

  final int count;
  final bool busy;
  final VoidCallback onConfirmAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(color: moneyColors.warning.withValues(alpha: 0.35)),
        color: moneyColors.warning.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: moneyColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '待确认的流水不占余额、不计入统计，确认入账后才生效。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: busy || count == 0 ? null : onConfirmAll,
            icon: busy
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 16),
            label: Text('确认这 $count 笔'),
          ),
        ],
      ),
    );
  }
}

/// 多选模式下的批量操作条。
///
/// 「改分类 / 改账户 / 改标签」合成一个入口（[onEdit]）：它们是一类操作，
/// 拆成三个按钮在手机宽度上放不下，而用户一次通常也只想改其中一项。
class _TransactionBulkActionBar extends StatelessWidget {
  const _TransactionBulkActionBar({
    required this.selectedCount,
    required this.visibleCount,
    required this.busy,
    required this.onSelectAllVisible,
    required this.onEdit,
    required this.onConfirm,
    required this.onVoid,
    required this.onDelete,
    required this.onClear,
  });

  final int selectedCount;
  final int visibleCount;
  final bool busy;
  final VoidCallback onSelectAllVisible;
  final VoidCallback onEdit;
  final VoidCallback onConfirm;
  final VoidCallback onVoid;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '已选 $selectedCount 笔',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (selectedCount < visibleCount)
              TextButton(
                onPressed: busy ? null : onSelectAllVisible,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('全选 $visibleCount'),
              ),
            _barButton(
              context,
              tooltip: '批量修改',
              icon: Icons.tune_rounded,
              onPressed: onEdit,
            ),
            _barButton(
              context,
              tooltip: '确认入账',
              icon: Icons.check_rounded,
              onPressed: onConfirm,
            ),
            _barButton(
              context,
              tooltip: '作废',
              icon: Icons.block_rounded,
              onPressed: onVoid,
            ),
            _barButton(
              context,
              tooltip: '删除',
              icon: Icons.delete_outline_rounded,
              onPressed: onDelete,
            ),
            _barButton(
              context,
              tooltip: '退出多选',
              icon: Icons.close_rounded,
              onPressed: onClear,
            ),
          ],
        ),
      ),
    );
  }

  /// 不用 AppIconActionButton：它的配色跟主题走，在 inverseSurface 的条上
  /// 会变成深色叠深色。这里直接用 IconButton 指定前景色。
  Widget _barButton(
    BuildContext context, {
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      onPressed: busy ? null : onPressed,
      icon: Icon(icon, size: 19),
      color: colorScheme.onInverseSurface,
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }
}

/// 从当前筛选直接翻译成预算 scope 需要的字段。
class _BudgetPreset {
  const _BudgetPreset({
    required this.scopeType,
    required this.trackingType,
    required this.label,
    this.categoryId,
    this.subCategoryId,
    this.accountId,
    this.tag,
  });

  final MoneyBudgetScopeType scopeType;
  final MoneyBudgetTrackingType trackingType;
  final String label;
  final String? categoryId;
  final String? subCategoryId;
  final String? accountId;
  final String? tag;
}

/// 「看完了，就给它设个预算」的入口。
///
/// 统计页下钻到某个分类的流水、或者用户自己筛出某个账户之后，最自然的
/// 下一步就是定个额度。没有这个入口，用户得记住数字、回到预算页、重新选
/// 一遍分类——多数人走到这一步就放弃了。
class _BudgetShortcutBanner extends StatelessWidget {
  const _BudgetShortcutBanner({required this.label, required this.onCreate});

  final String label;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_rounded,
            size: 18,
            color: colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(onPressed: onCreate, child: const Text('设预算')),
        ],
      ),
    );
  }
}

/// 日期 / 状态筛选共用的胶囊 chip。
Widget _buildFilterChip(
  BuildContext context, {
  required String label,
  required bool selected,
  required VoidCallback onTap,
  String? trailing,
  VoidCallback? onTrailingTap,
  Color? accent,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final highlight = accent ?? colorScheme.primary;

  return Material(
    color: selected
        ? colorScheme.primaryContainer.withValues(alpha: 0.45)
        : colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(999),
    child: InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? highlight.withValues(alpha: 0.4)
                : colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? highlight : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onTrailingTap,
                child: Text(
                  trailing,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: highlight,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// 日期快捷区间。覆盖绝大多数看账场景，不用每次开日期选择器。
class _TransactionDateChips extends StatelessWidget {
  const _TransactionDateChips({
    required this.dateStart,
    required this.dateEnd,
    required this.onPickRange,
    required this.onSelectPreset,
  });

  final DateTime? dateStart;
  final DateTime? dateEnd;
  final VoidCallback onPickRange;
  final void Function(DateTime? start, DateTime? end) onSelectPreset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children:
            [
                  _buildFilterChip(
                    context,
                    label: '本周',
                    selected: _isSameRange(_weekRange()),
                    onTap: () {
                      final range = _weekRange();
                      onSelectPreset(range.$1, range.$2);
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: '本月',
                    selected: _isSameRange(_monthRange(0)),
                    onTap: () {
                      final range = _monthRange(0);
                      onSelectPreset(range.$1, range.$2);
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: '上月',
                    selected: _isSameRange(_monthRange(-1)),
                    onTap: () {
                      final range = _monthRange(-1);
                      onSelectPreset(range.$1, range.$2);
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: '近 90 天',
                    selected: false,
                    onTap: () {
                      final now = DateTime.now();
                      onSelectPreset(
                        DateTime(now.year, now.month, now.day - 89),
                        DateTime(now.year, now.month, now.day),
                      );
                    },
                  ),
                  _buildFilterChip(
                    context,
                    label: dateStart == null && dateEnd == null
                        ? '自定义…'
                        : '${_short(dateStart)} - ${_short(dateEnd)}',
                    selected: dateStart != null || dateEnd != null,
                    onTap: onPickRange,
                    trailing: dateStart == null && dateEnd == null ? null : '✕',
                    onTrailingTap: dateStart == null && dateEnd == null
                        ? null
                        : () => onSelectPreset(null, null),
                    accent: colorScheme.primary,
                  ),
                ]
                .map(
                  (widget) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: widget,
                  ),
                )
                .toList(),
      ),
    );
  }

  static String _short(DateTime? value) {
    if (value == null) {
      return '—';
    }
    return '${value.month}/${value.day}';
  }

  bool _isSameRange((DateTime, DateTime) range) {
    if (dateStart == null || dateEnd == null) {
      return false;
    }
    return _sameDay(dateStart!, range.$1) && _sameDay(dateEnd!, range.$2);
  }

  bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  (DateTime, DateTime) _weekRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return (monday, monday.add(const Duration(days: 6)));
  }

  (DateTime, DateTime) _monthRange(int monthOffset) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month + monthOffset);
    final last = DateTime(first.year, first.month + 1, 0);
    return (first, last);
  }
}

/// 筛选结果汇总条。
///
/// 原实现只在「从账户点进来」时才显示汇总面板；按分类或日期筛选后，
/// 「这段时间一共花了多少」这个最核心的问题没有答案。这里走一次全量聚合，
/// 不受列表分页影响。
class _TransactionSummaryBar extends ConsumerWidget {
  const _TransactionSummaryBar({required this.query, this.onClear});

  final MoneyTransactionQuery query;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final summary = ref
        .watch(currentUserTransactionSummaryProvider(query))
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyTransactionSummary.empty(),
        );
    final currencyCode =
        ref
            .watch(currentUserPreferencesProvider)
            .maybeWhen(
              data: (preferences) => preferences?.currencyCode,
              orElse: () => null,
            ) ??
        'CNY';

    final hasFilter = _hasAnyFilter(query);
    final masked = MoneyPrivacy.of(context);
    final moneyColors = theme.moneyColors;

    final expenseText = maskedMoneyOr(
      formatMoneyMinorCompact(summary.expenseMinor, currencyCode),
      masked,
    );
    final incomeText = maskedMoneyOr(
      formatMoneyMinorCompact(summary.incomeMinor, currencyCode),
      masked,
    );
    final netText = masked
        ? '••••'
        : '${summary.netMinor >= 0 ? '+' : '-'}'
              '${formatMoneyMinorCompact(summary.netMinor.abs(), currencyCode)}';
    final netColor = summary.netMinor >= 0
        ? moneyColors.income
        : moneyColors.expense;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(
          color: hasFilter
              ? colorScheme.primary.withValues(alpha: 0.24)
              : colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        color: hasFilter
            ? colorScheme.primaryContainer.withValues(alpha: 0.22)
            : colorScheme.surfaceContainerLowest,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '共 ${summary.count} 笔',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (hasFilter && onClear != null)
                TextButton(
                  onPressed: onClear,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  child: const Text('清除筛选'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _amount(theme, '支出', expenseText, moneyColors.expense),
              _amount(theme, '收入', incomeText, moneyColors.income),
              _amount(theme, '净', netText, netColor),
            ],
          ),
        ],
      ),
    );
  }

  /// 金额格。
  ///
  /// 视觉上只留金额、靠颜色区分方向，但「支出 / 收入 / 净」没有真正丢掉：
  /// 它作为语义标签与长按提示保留，否则读屏用户与色觉缺陷用户拿不到方向信息。
  Widget _amount(ThemeData theme, String label, String value, Color color) {
    return Expanded(
      child: Semantics(
        label: '$label $value',
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasAnyFilter(MoneyTransactionQuery query) {
    return query.type != null ||
        query.status != null ||
        query.accountId != null ||
        query.categoryId != null ||
        query.subCategoryId != null ||
        query.paymentMethod != null ||
        (query.customPaymentMethodName?.trim().isNotEmpty ?? false) ||
        query.dateStart != null ||
        query.dateEnd != null ||
        (query.keyword?.trim().isNotEmpty ?? false) ||
        (query.merchant?.trim().isNotEmpty ?? false) ||
        query.budgetId != null;
  }
}

class _FilterContextBanner extends StatelessWidget {
  const _FilterContextBanner({
    required this.label,
    required this.onClearContext,
  });

  final String label;
  final VoidCallback? onClearContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.filter_alt_rounded, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        if (onClearContext != null)
          AppIconActionButton(
            tooltip: '返回全部流水',
            onPressed: onClearContext,
            icon: Icons.close_rounded,
          ),
      ],
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  const _DayGroupHeader({
    required this.date,
    required this.expenseMinor,
    required this.incomeMinor,
    this.currencyCode,
  });

  final DateTime date;
  final int expenseMinor;
  final int incomeMinor;

  /// 当天单一币种；多币种为 null，此时不显示合计。
  final String? currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final local = date.toLocal();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      child: Row(
        children: [
          Text(
            _dayTitle(local),
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          if (currencyCode != null) ...[
            const SizedBox(width: 8),
            if (expenseMinor > 0)
              Text(
                maskedMoneyOr(
                  '支出 ${formatMoneyMinor(expenseMinor, currencyCode!)}',
                  MoneyPrivacy.of(context),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.moneyColors.expense,
                  letterSpacing: 0,
                ),
              ),
            if (expenseMinor > 0 && incomeMinor > 0) const SizedBox(width: 10),
            if (incomeMinor > 0)
              Text(
                maskedMoneyOr(
                  '收入 ${formatMoneyMinor(incomeMinor, currencyCode!)}',
                  MoneyPrivacy.of(context),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.moneyColors.income,
                  letterSpacing: 0,
                ),
              ),
          ],
          const Spacer(),
          Text(
            _weekdayLabel(local),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }

  String _dayTitle(DateTime local) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${local.month}月${local.day}日';
  }

  String _weekdayLabel(DateTime local) {
    const labels = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final today = DateTime.now();
    if (today.year == local.year &&
        today.month == local.month &&
        today.day == local.day) {
      return labels[local.weekday - 1];
    }
    return '${local.year}年 ${labels[local.weekday - 1]}';
  }
}

bool sameDayKey(DateTime a, DateTime b) {
  final la = a.toLocal();
  final lb = b.toLocal();
  return la.year == lb.year && la.month == lb.month && la.day == lb.day;
}

/// 列表空态。分两种情况，别再把它们说成同一件事。
class _EmptyTransactionsPanel extends StatelessWidget {
  const _EmptyTransactionsPanel({
    required this.onCreate,
    required this.hasActiveFilters,
    required this.filterDescription,
    required this.onClearFilters,
  });

  final VoidCallback onCreate;

  /// 是真的没数据，还是筛选之后没数据 —— 两者的下一步动作完全相反。
  final bool hasActiveFilters;
  final String filterDescription;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    // 带筛选查不到东西时，该做的是改条件。继续劝「快速新增」只会让用户在
    // 已经筛过的视图里记重复账，然后疑惑「我刚记的那笔怎么不在列表里」。
    if (hasActiveFilters) {
      return AppEmptyState(
        title: '没有符合条件的流水',
        message: filterDescription,
        icon: Icons.search_off_rounded,
        padding: EdgeInsets.zero,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
              label: const Text('清除筛选'),
            ),
            TextButton(onPressed: onCreate, child: const Text('或 记一笔新的流水')),
          ],
        ),
      );
    }

    return AppEmptyState(
      title: '还没有流水',
      message: '可以从快速新增记录支出、收入或转账。',
      icon: Icons.receipt_long_rounded,
      padding: EdgeInsets.zero,
      action: AppIconActionButton(
        tooltip: '快速新增',
        onPressed: onCreate,
        icon: Icons.add_rounded,
        variant: AppIconActionVariant.filled,
      ),
    );
  }
}
