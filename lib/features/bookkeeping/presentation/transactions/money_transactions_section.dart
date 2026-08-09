import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/paged_load_more_list.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/date_picker.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_card.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_panel.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_detail_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/money_transaction_actions.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transaction_form_dialog.dart';
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
  Object? _loadError;
  MoneyTransactionType? _typeFilter;
  String? _budgetIdFilter;
  _BudgetAppliedFilterSnapshot? _budgetAppliedFilterSnapshot;
  String? _accountIdFilter;
  String? _categoryIdFilter;
  String? _subCategoryIdFilter;
  MoneyPaymentMethod? _paymentMethodFilter;
  String? _merchantFilter;
  String? _customPaymentMethodNameFilter;
  DateTime? _dateStartFilter;
  DateTime? _dateEndFilter;
  String? _keywordFilter;

  bool get _hasActiveFilters =>
      _typeFilter != null ||
      _budgetIdFilter != null ||
      _accountIdFilter != null ||
      _categoryIdFilter != null ||
      _subCategoryIdFilter != null ||
      _paymentMethodFilter != null ||
      _merchantFilter != null ||
      _dateStartFilter != null ||
      _keywordFilter != null;

  String? _selectedTransactionId;
  String? _activeLedgerId;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        AppFilterSheetTrigger(
          title: '筛选流水',
          hasActiveFilters: _hasActiveFilters,
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
              onBudgetChanged: (value) => _setBudgetFilter(value, budgetRows),
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
        const SizedBox(height: 12),
        if (widget.filterContext?.account != null) ...[
          _AccountTransactionSummaryPanel(
            account: widget.filterContext!.account!,
            summary: widget.filterContext!.accountSummary,
          ),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return _buildTransactionsArea(
                isWide: constraints.maxWidth >= 840,
                accounts: accountRows,
                currentLedger: currentLedger,
                installmentPlans: installmentPlanRows,
                expenseCatalog: expenseCatalogValue,
                incomeCatalog: incomeCatalogValue,
              );
            },
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
  }) {
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
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
        emptyBuilder: (context) =>
            _EmptyTransactionsPanel(onCreate: _openCreateFromEmptyState),
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
                onTap: () => _openTransactionDetail(
                  transaction: transaction,
                  isWide: isWide,
                  accounts: accounts,
                  expenseCatalog: expenseCatalog,
                  incomeCatalog: incomeCatalog,
                ),
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
    );
  }

  void _closeTransactionDetail() {
    setState(() {
      _selectedTransactionId = null;
    });
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
        _isLoadingInitial = _transactions.isEmpty;
        _loadError = null;
      });
    }
    await _loadTransactions(reset: true);
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
        _page = page.page;
        _hasMore = page.hasMore;
        _loadError = null;
        _isLoadingInitial = false;
      });
    } catch (error) {
      if (!mounted || loadSerial != _loadSerial) return;
      setState(() {
        _loadError = reset ? error : null;
        _isLoadingInitial = false;
      });
      if (!reset) {
        AppToast.error(_ensureToast(), context, '加载更多失败');
      }
    }
  }

  MoneyTransactionQuery _currentQuery({required int page}) {
    return MoneyTransactionQuery(
      page: page,
      pageSize: _pageSize,
      type: _typeFilter,
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
    );
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
      });
      unawaited(_refreshTransactions());
    });
  }

  void _applyQuery(
    MoneyTransactionQuery query, {
    required bool updateController,
  }) {
    _typeFilter = query.type;
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
      _transactions.clear();
      _page = 1;
      _hasMore = false;
      _isLoadingInitial = true;
      _loadError = null;
      _selectedTransactionId = null;
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

    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransactionFormDialog(type: type, ledger: ledger),
    );
    if (!mounted || result is! TransactionCreateFormResult) {
      return;
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
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '${type.label}已记录');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _openTransferDialog() async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const TransferFormDialog(),
    );
    if (!mounted || result is! MoneyTransferDraft) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(result);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '转账已记录');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _openEditDialog(MoneyTransactionEntity transaction) async {
    await _transactionActions().edit(transaction);
  }

  Future<void> _openRefundDialog(MoneyTransactionEntity transaction) async {
    await _transactionActions().refund(transaction);
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
                value: formatMoneyMinor(
                  account.displayBalanceMinor,
                  account.currencyCode,
                ),
                valueColor: colorScheme.primary,
              ),
              _SummaryMetric(
                label: account.type.isCreditLike ? '信用额度' : '初始余额',
                value: formatMoneyMinor(
                  account.type.isCreditLike
                      ? account.effectiveCreditLimitMinor
                      : account.initialBalanceMinor,
                  account.currencyCode,
                ),
              ),
              if (account.type.isCreditLike) ...[
                _SummaryMetric(
                  label: '已入账负债',
                  value: formatMoneyMinor(
                    account.effectivePostedDebtMinor,
                    account.currencyCode,
                  ),
                  valueColor: colorScheme.error,
                ),
                _SummaryMetric(
                  label: '冻结额度',
                  value: formatMoneyMinor(
                    account.effectiveFrozenCreditMinor,
                    account.currencyCode,
                  ),
                ),
              ],
              _SummaryMetric(
                label: '本月收入',
                value: formatMoneyMinor(currentIncome, account.currencyCode),
                valueColor: moneyColors.income,
              ),
              _SummaryMetric(
                label: '本月支出',
                value: formatMoneyMinor(currentExpense, account.currencyCode),
                valueColor: colorScheme.error,
              ),
              _SummaryMetric(
                label: currentNet >= 0 ? '本月净胜' : '本月净支出',
                value: formatMoneyMinor(currentNet.abs(), account.currencyCode),
              ),
              _SummaryMetric(label: '支出对比', value: _expenseChangeText),
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
    return '较上月$label $value';
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
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
          Text(
            value,
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
              label: '类型',
              enabled: !isTypeLocked,
              leadingIcon: const Icon(Icons.tune_rounded),
              onSelected: (value) => apply(() => onTypeChanged(value)),
              entries: [
                const DropdownMenuEntry<MoneyTransactionType?>(
                  value: null,
                  label: '全部类型',
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
                  label: '全部渠道',
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
                hintText: '搜索备注',
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
  });

  final DateTime date;
  final int expenseMinor;
  final int incomeMinor;

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
          const SizedBox(width: 8),
          if (expenseMinor > 0)
            Text(
              '支出 ${formatMoneyMinor(expenseMinor, 'CNY')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.moneyColors.expense,
                letterSpacing: 0,
              ),
            ),
          if (expenseMinor > 0 && incomeMinor > 0) const SizedBox(width: 10),
          if (incomeMinor > 0)
            Text(
              '收入 ${formatMoneyMinor(incomeMinor, 'CNY')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.moneyColors.income,
                letterSpacing: 0,
              ),
            ),
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

class _EmptyTransactionsPanel extends StatelessWidget {
  const _EmptyTransactionsPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
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
