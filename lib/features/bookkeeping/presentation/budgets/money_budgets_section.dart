import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_allocation_summary.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_allocation_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_card.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_history_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_form_dialog.dart';

enum _BudgetScopeFilter { all, category, account, categoryAccount }

enum _BudgetStatusFilter { all, normal, alerting, overspent, completed }

class MoneyBudgetsSection extends ConsumerStatefulWidget {
  const MoneyBudgetsSection({super.key, this.onViewTransactions});

  final ValueChanged<MoneyBudgetEntity>? onViewTransactions;

  @override
  ConsumerState<MoneyBudgetsSection> createState() =>
      _MoneyBudgetsSectionState();
}

class _MoneyBudgetsSectionState extends ConsumerState<MoneyBudgetsSection> {
  FToast? _toast;
  MoneyBudgetTrackingType? _trackingTypeFilter;
  MoneyBudgetPeriodType? _periodTypeFilter;
  _BudgetScopeFilter _scopeFilter = _BudgetScopeFilter.all;
  _BudgetStatusFilter _statusFilter = _BudgetStatusFilter.all;

  @override
  Widget build(BuildContext context) {
    final budgets = ref.watch(currentUserBudgetsProvider);
    final expenseCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    final incomeCatalog = ref.watch(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    final currentLedger = ref.watch(currentUserCurrentLedgerValueProvider);
    final accounts = currentLedger == null
        ? const AsyncValue<List<MoneyAccountEntity>>.data(
            <MoneyAccountEntity>[],
          )
        : ref.watch(currentUserMoneyLedgerAccountsProvider(currentLedger.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 6),
        Expanded(
          child: budgets.when(
            data: (budgetRows) => expenseCatalog.when(
              data: (expenseCatalogValue) => incomeCatalog.when(
                data: (incomeCatalogValue) => accounts.when(
                  data: (accountRows) {
                    final accountsById = {
                      for (final account in accountRows) account.id: account,
                    };
                    final filteredBudgets = _filterBudgets(budgetRows);
                    return budgetRows.isEmpty
                        ? _EmptyBudgetsPanel(
                            onCreate: () => _openBudgetDialog(),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppFilterSheetTrigger(
                                title: '筛选预算',
                                children: [
                                  _BudgetFilterFields(
                                    trackingType: _trackingTypeFilter,
                                    periodType: _periodTypeFilter,
                                    scopeFilter: _scopeFilter,
                                    statusFilter: _statusFilter,
                                    onTrackingTypeChanged: (value) =>
                                        _updateFilters(() {
                                          _trackingTypeFilter = value;
                                        }),
                                    onPeriodTypeChanged: (value) =>
                                        _updateFilters(() {
                                          _periodTypeFilter = value;
                                        }),
                                    onScopeChanged: (value) =>
                                        _updateFilters(() {
                                          _scopeFilter = value;
                                        }),
                                    onStatusChanged: (value) =>
                                        _updateFilters(() {
                                          _statusFilter = value;
                                        }),
                                    onReset: () =>
                                        _updateFilters(_resetFilters),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (filteredBudgets.isEmpty)
                                _NoMatchedBudgetsPanel(
                                  onReset: () => _updateFilters(_resetFilters),
                                )
                              else
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    itemCount: filteredBudgets.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (context, index) {
                                      final budget = filteredBudgets[index];
                                      final catalogValue = budget.isIncomeTarget
                                          ? incomeCatalogValue
                                          : expenseCatalogValue;
                                      final allocations = ref.watch(
                                        currentUserBudgetAllocationsProvider(
                                          budget.id,
                                        ),
                                      );
                                      final allocationSummary = allocations
                                          .maybeWhen(
                                            data: (rows) =>
                                                BudgetAllocationSummary.fromAllocations(
                                                  budgetAmountMinor:
                                                      budget.amountMinor,
                                                  allocations: rows,
                                                ),
                                            orElse: () => null,
                                          );
                                      return BudgetCard(
                                        budget: budget,
                                        catalog: catalogValue,
                                        accountsById: accountsById,
                                        ledger: currentLedger,
                                        allocationSummary: allocationSummary,
                                        onViewTransactions:
                                            widget.onViewTransactions == null
                                            ? () {}
                                            : () => widget.onViewTransactions!(
                                                budget,
                                              ),
                                        onViewHistory: () =>
                                            _openHistoryDialog(budget),
                                        onManageAllocations: () =>
                                            _openAllocationDialog(
                                              budget,
                                              catalogValue,
                                              currentLedger,
                                            ),
                                        onEdit: () => _openBudgetDialog(budget),
                                        onDelete: () => _confirmDelete(budget),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) =>
                      AppErrorState(title: '读取账户失败', onRetry: _retryLoad),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) =>
                    AppErrorState(title: '读取收入分类失败', onRetry: _retryLoad),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) =>
                  AppErrorState(title: '读取支出分类失败', onRetry: _retryLoad),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                AppErrorState(title: '读取预算失败', onRetry: _retryLoad),
          ),
        ),
      ],
    );
  }

  List<MoneyBudgetEntity> _filterBudgets(List<MoneyBudgetEntity> budgets) {
    return budgets.where((budget) {
      final trackingType = _trackingTypeFilter;
      if (trackingType != null && budget.trackingType != trackingType) {
        return false;
      }

      final periodType = _periodTypeFilter;
      if (periodType != null && budget.periodType != periodType) {
        return false;
      }

      if (!_matchesScopeFilter(budget)) {
        return false;
      }

      if (!_matchesStatusFilter(budget)) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _matchesScopeFilter(MoneyBudgetEntity budget) {
    return switch (_scopeFilter) {
      _BudgetScopeFilter.all => true,
      _BudgetScopeFilter.category =>
        budget.scopeType == MoneyBudgetScopeType.category,
      _BudgetScopeFilter.account =>
        budget.scopeType == MoneyBudgetScopeType.account,
      _BudgetScopeFilter.categoryAccount =>
        budget.scopeType == MoneyBudgetScopeType.categoryAccount,
    };
  }

  bool _matchesStatusFilter(MoneyBudgetEntity budget) {
    return switch (_statusFilter) {
      _BudgetStatusFilter.all => true,
      _BudgetStatusFilter.normal =>
        !budget.shouldAlert && !budget.isOverspent && !budget.isCompleted,
      _BudgetStatusFilter.alerting => budget.shouldAlert,
      _BudgetStatusFilter.overspent => budget.isOverspent,
      _BudgetStatusFilter.completed => budget.isCompleted,
    };
  }

  void _updateFilters(VoidCallback update) {
    setState(update);
  }

  void _resetFilters() {
    _trackingTypeFilter = null;
    _periodTypeFilter = null;
    _scopeFilter = _BudgetScopeFilter.all;
    _statusFilter = _BudgetStatusFilter.all;
  }

  Future<void> _openBudgetDialog([MoneyBudgetEntity? budget]) async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => BudgetFormDialog(budget: budget),
    );
    if (result == null || !mounted) {
      return;
    }

    try {
      if (result is MoneyBudgetDraft) {
        await ref
            .read(currentUserMoneyBudgetActionsProvider)
            .createBudget(result);
        if (!mounted) return;
        AppToast.success(_ensureToast(), context, '预算已创建');
        return;
      }
      if (result is MoneyBudgetUpdate) {
        await ref
            .read(currentUserMoneyBudgetActionsProvider)
            .updateBudget(result);
        if (!mounted) return;
        AppToast.success(_ensureToast(), context, '预算已更新');
      }
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  Future<void> _openAllocationDialog(
    MoneyBudgetEntity budget,
    MoneyCategoryCatalog catalog,
    MoneyLedgerEntity? ledger,
  ) {
    return showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => BudgetAllocationDialog(
        budget: budget,
        catalog: catalog,
        ledger: ledger,
      ),
    );
  }

  Future<void> _openHistoryDialog(MoneyBudgetEntity budget) {
    return showAppResponsiveDialog<void>(
      context: context,
      builder: (context) => BudgetHistorySheet(budget: budget),
    );
  }

  Future<void> _confirmDelete(MoneyBudgetEntity budget) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除预算',
      message: '确认删除“${budget.name}”？流水不会被删除。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserMoneyBudgetActionsProvider)
          .deleteBudget(budget.id);
      if (!mounted) return;
      AppToast.success(_ensureToast(), context, '预算已删除');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(_ensureToast(), context, _errorText(error));
    }
  }

  void _retryLoad() {
    ref.invalidate(currentUserBudgetsProvider);
    ref.invalidate(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.expense),
    );
    ref.invalidate(
      currentUserCategoryCatalogProvider(MoneyCategoryKind.income),
    );
    ref.invalidate(currentUserVisibleAccountsProvider);
  }

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  String _errorText(Object error) {
    if (error is MoneyRepositoryException) {
      return switch (error.code) {
        MoneyRepositoryErrorCode.invalidBudgetAmount => '预算金额必须大于 0',
        MoneyRepositoryErrorCode.invalidBudgetScope => '请选择分类或账户',
        MoneyRepositoryErrorCode.unsupportedBudgetPeriod => '预算周期不可用',
        MoneyRepositoryErrorCode.categoryNotFound => '分类不可用',
        MoneyRepositoryErrorCode.budgetNotFound => '预算不存在',
        MoneyRepositoryErrorCode.databaseReadFailed => '读取失败',
        MoneyRepositoryErrorCode.databaseWriteFailed => '保存失败',
        MoneyRepositoryErrorCode.invalidAccountBalance => '账户余额不满足规则',
        MoneyRepositoryErrorCode.invalidTransactionAmount => '金额必须大于 0',
        MoneyRepositoryErrorCode.accountNotFound => '账户不可用',
        MoneyRepositoryErrorCode.insufficientFunds => '账户余额不足',
        MoneyRepositoryErrorCode.invalidTransferAccounts => '转账账户无效',
        MoneyRepositoryErrorCode.creditCardLimitExceeded => '信用账户占用额度不能超过信用额度',
        MoneyRepositoryErrorCode.invalidInstallmentAmount => '请检查分期金额和期数',
        MoneyRepositoryErrorCode.invalidInstallmentAccount => '请选择信用账户',
        MoneyRepositoryErrorCode.installmentPlanNotFound => '分期计划不可用',
        MoneyRepositoryErrorCode.invalidInstallmentStatus => '当前分期状态不可操作',
        MoneyRepositoryErrorCode.invalidTransactionStatus => '当前流水状态不可操作',
        MoneyRepositoryErrorCode.ledgerNotFound => '分摊账本不可用',
        MoneyRepositoryErrorCode.memberNotFound => '分摊成员不可用',
        MoneyRepositoryErrorCode.activeSplitAlreadyExists => '此流水已有分摊记录',
        MoneyRepositoryErrorCode.invalidSplitAmount => '请检查分摊金额或比例',
        MoneyRepositoryErrorCode.invalidSplitTransaction => '当前流水不支持分摊',
        MoneyRepositoryErrorCode.cannotUnlinkPersonalLedger => '个人账本不能移出',
        MoneyRepositoryErrorCode.cannotDeletePersonalLedger => '个人账本不能删除',
        MoneyRepositoryErrorCode.cannotUnlinkLedgerWithActiveSplit =>
          '请先取消分摊，再移出家庭账本',
        MoneyRepositoryErrorCode.splitRecordNotFound => '分摊记录不存在',
        MoneyRepositoryErrorCode.reminderNotFound => '提醒不存在',
        MoneyRepositoryErrorCode.autoPostingTemplateNotFound => '自动记账模板不可用',
        MoneyRepositoryErrorCode.invalidCategoryName => '分类名称无效',
      };
    }
    return '操作失败';
  }
}

class _BudgetFilterFields extends StatelessWidget {
  const _BudgetFilterFields({
    required this.trackingType,
    required this.periodType,
    required this.scopeFilter,
    required this.statusFilter,
    required this.onTrackingTypeChanged,
    required this.onPeriodTypeChanged,
    required this.onScopeChanged,
    required this.onStatusChanged,
    required this.onReset,
  });

  final MoneyBudgetTrackingType? trackingType;
  final MoneyBudgetPeriodType? periodType;
  final _BudgetScopeFilter scopeFilter;
  final _BudgetStatusFilter statusFilter;
  final ValueChanged<MoneyBudgetTrackingType?> onTrackingTypeChanged;
  final ValueChanged<MoneyBudgetPeriodType?> onPeriodTypeChanged;
  final ValueChanged<_BudgetScopeFilter> onScopeChanged;
  final ValueChanged<_BudgetStatusFilter> onStatusChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final closeSheet = AppFilterSheetTrigger.maybeCloserOf(context);
    void apply(VoidCallback onChange) {
      onChange();
      closeSheet?.call();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FormDropdown<MoneyBudgetTrackingType?>(
          key: ValueKey('budget-tracking-${trackingType?.name ?? 'all'}'),
          width: 132,
          initialSelection: trackingType,
          label: '类型',
          leadingIcon: const Icon(Icons.tune_rounded),
          onSelected: (value) => apply(() => onTrackingTypeChanged(value)),
          entries: const [
            DropdownMenuEntry<MoneyBudgetTrackingType?>(
              value: null,
              label: '全部类型',
            ),
            DropdownMenuEntry<MoneyBudgetTrackingType?>(
              value: MoneyBudgetTrackingType.expenseLimit,
              label: '支出限额',
            ),
            DropdownMenuEntry<MoneyBudgetTrackingType?>(
              value: MoneyBudgetTrackingType.incomeTarget,
              label: '收入目标',
            ),
          ],
        ),
        FormDropdown<MoneyBudgetPeriodType?>(
          key: ValueKey('budget-period-${periodType?.name ?? 'all'}'),
          width: 140,
          initialSelection: periodType,
          label: '周期',
          leadingIcon: const Icon(Icons.event_repeat_rounded),
          onSelected: (value) => apply(() => onPeriodTypeChanged(value)),
          entries: const [
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: null,
              label: '全部周期',
            ),
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: MoneyBudgetPeriodType.daily,
              label: '每天',
            ),
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: MoneyBudgetPeriodType.weekly,
              label: '每周',
            ),
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: MoneyBudgetPeriodType.monthly,
              label: '每月',
            ),
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: MoneyBudgetPeriodType.billingCycle,
              label: '账单周期',
            ),
            DropdownMenuEntry<MoneyBudgetPeriodType?>(
              value: MoneyBudgetPeriodType.yearly,
              label: '每年',
            ),
          ],
        ),
        FormDropdown<_BudgetScopeFilter>(
          key: ValueKey('budget-scope-${scopeFilter.name}'),
          width: 132,
          initialSelection: scopeFilter,
          label: '范围',
          leadingIcon: const Icon(Icons.account_tree_rounded),
          onSelected: (value) {
            if (value != null) {
              apply(() => onScopeChanged(value));
            }
          },
          entries: const [
            DropdownMenuEntry(value: _BudgetScopeFilter.all, label: '全部范围'),
            DropdownMenuEntry(
              value: _BudgetScopeFilter.category,
              label: '分类预算',
            ),
            DropdownMenuEntry(value: _BudgetScopeFilter.account, label: '账户预算'),
            DropdownMenuEntry(
              value: _BudgetScopeFilter.categoryAccount,
              label: '分类+账户',
            ),
          ],
        ),
        FormDropdown<_BudgetStatusFilter>(
          key: ValueKey('budget-status-${statusFilter.name}'),
          width: 132,
          initialSelection: statusFilter,
          label: '状态',
          leadingIcon: const Icon(Icons.flag_rounded),
          onSelected: (value) {
            if (value != null) {
              apply(() => onStatusChanged(value));
            }
          },
          entries: const [
            DropdownMenuEntry(value: _BudgetStatusFilter.all, label: '全部状态'),
            DropdownMenuEntry(value: _BudgetStatusFilter.normal, label: '正常'),
            DropdownMenuEntry(
              value: _BudgetStatusFilter.alerting,
              label: '接近阈值',
            ),
            DropdownMenuEntry(
              value: _BudgetStatusFilter.overspent,
              label: '已超支',
            ),
            DropdownMenuEntry(
              value: _BudgetStatusFilter.completed,
              label: '已完成',
            ),
          ],
        ),
        IconButton.outlined(
          tooltip: '重置筛选',
          onPressed: onReset,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _EmptyBudgetsPanel extends StatelessWidget {
  const _EmptyBudgetsPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: '还没有预算',
      message: '新增预算后可以跟踪月度、周期或分类支出',
      icon: Icons.flag_rounded,
      action: AppIconActionButton(
        tooltip: '新增预算',
        onPressed: onCreate,
        icon: Icons.add_rounded,
        variant: AppIconActionVariant.filled,
      ),
    );
  }
}

class _NoMatchedBudgetsPanel extends StatelessWidget {
  const _NoMatchedBudgetsPanel({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppPlainPanel(
        child: AppEmptyState(
          title: '没有匹配的预算',
          icon: Icons.filter_alt_off_rounded,
          padding: EdgeInsets.zero,
          action: AppIconActionButton(
            tooltip: '重置筛选',
            onPressed: onReset,
            icon: Icons.refresh_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ),
      ),
    );
  }
}
