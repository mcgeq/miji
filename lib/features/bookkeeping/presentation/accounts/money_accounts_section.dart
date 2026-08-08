import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';
import 'package:miji/core/presentation/components/paged_load_more_list.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/credit_card_statement_reconciliation_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_account_grouping.dart';
import 'package:miji/features/bookkeeping/presentation/transactions/transfer_form_dialog.dart';

enum _CreditCardStatementAction { adjust, repay }

enum MoneyAccountStatusFilter {
  all,
  active,
  inactive;

  String get label {
    return switch (this) {
      MoneyAccountStatusFilter.all => '全部',
      MoneyAccountStatusFilter.active => '启用',
      MoneyAccountStatusFilter.inactive => '停用',
    };
  }
}

enum MoneyAccountSortField {
  updatedAt,
  createdAt,
  name,
  balance,
  type;

  String get label {
    return switch (this) {
      MoneyAccountSortField.updatedAt => '更新时间',
      MoneyAccountSortField.createdAt => '创建时间',
      MoneyAccountSortField.name => '名称',
      MoneyAccountSortField.balance => '余额',
      MoneyAccountSortField.type => '类型',
    };
  }
}

class MoneyAccountsSection extends ConsumerWidget {
  const MoneyAccountsSection({super.key, this.onViewTransactions});

  final ValueChanged<MoneyAccountEntity>? onViewTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(currentUserVisibleAccountsProvider);
    final summaries = ref.watch(currentUserAccountMonthlySummariesProvider);
    final defaultCurrencyCode = ref
        .watch(currentUserPreferencesProvider)
        .maybeWhen(
          data: (preferences) => preferences?.currencyCode,
          orElse: () => null,
        );

    return accounts.when(
      data: (value) => _MoneyAccountsContent(
        accounts: value,
        defaultCurrencyCode: defaultCurrencyCode,
        monthlySummaries: summaries.maybeWhen(
          data: (value) => value,
          orElse: () => const <String, MoneyAccountMonthlySummary>{},
        ),
        onViewTransactions: onViewTransactions,
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => AppErrorState(
        title: '读取账户失败',
        onRetry: () => ref.invalidate(currentUserVisibleAccountsProvider),
      ),
    );
  }
}

class _MoneyAccountsContent extends ConsumerStatefulWidget {
  const _MoneyAccountsContent({
    required this.accounts,
    required this.defaultCurrencyCode,
    required this.monthlySummaries,
    required this.onViewTransactions,
  });

  final List<MoneyAccountEntity> accounts;
  final String? defaultCurrencyCode;
  final Map<String, MoneyAccountMonthlySummary> monthlySummaries;
  final ValueChanged<MoneyAccountEntity>? onViewTransactions;

  @override
  ConsumerState<_MoneyAccountsContent> createState() =>
      _MoneyAccountsContentState();
}

class _MoneyAccountsContentState extends ConsumerState<_MoneyAccountsContent> {
  MoneyAccountStatusFilter _statusFilter = MoneyAccountStatusFilter.all;
  MoneyAccountType? _typeFilter;
  String? _currencyFilter;
  MoneyAccountSortField _sortField = MoneyAccountSortField.updatedAt;
  bool _sortAscending = false;

  bool get _hasActiveFilters =>
      _statusFilter != MoneyAccountStatusFilter.all ||
      _typeFilter != null ||
      _currencyFilter != null ||
      _sortField != MoneyAccountSortField.updatedAt ||
      _sortAscending;

  MoneyAccountDisplayGroupKind? _selectedGroupKind;
  int _visibleAccountCount = _loadMorePageSize;
  final Set<String> _hiddenAccountIds = <String>{};
  static const _loadMorePageSize = 8;
  static const _hiddenIdsPrefKey = 'account_hidden_ids';

  @override
  void initState() {
    super.initState();
    _loadHiddenIds();
  }

  Future<void> _loadHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hiddenIdsPrefKey);
    if (raw == null || raw.isEmpty) return;
    setState(() {
      _hiddenAccountIds.addAll(raw.split(','));
    });
  }

  Future<void> _saveHiddenIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hiddenIdsPrefKey, _hiddenAccountIds.join(','));
  }

  @override
  Widget build(BuildContext context) {
    final filteredAccounts = _filteredAndSortedAccounts;
    final displayGroups = buildMoneyAccountDisplayGroups(filteredAccounts);
    final selectedGroup = _selectedDisplayGroup(displayGroups);
    final selectedAccounts =
        selectedGroup?.accounts ?? const <MoneyAccountEntity>[];
    final visibleAccounts = selectedAccounts
        .take(_visibleAccountCount)
        .toList();
    final visibleCreditStatements = <MoneyCreditCardStatement>[];
    for (final account in visibleAccounts) {
      if (!account.type.isCreditLike) {
        continue;
      }
      final bill = ref
          .watch(currentUserCreditCardBillViewProvider(account.id))
          .maybeWhen(data: (value) => value, orElse: () => null);
      final statement = bill?.toStatement();
      if (statement != null) {
        visibleCreditStatements.add(statement);
      }
    }
    final creditStatementSummary = summarizeCreditAccountStatements(
      visibleCreditStatements,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _summaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            AppFilterSheetTrigger(
              title: '筛选账户',
              hasActiveFilters: _hasActiveFilters,
              children: [
                _AccountFilterFields(
                  accounts: widget.accounts,
                  statusFilter: _statusFilter,
                  typeFilter: _typeFilter,
                  currencyFilter: _currencyFilter,
                  sortField: _sortField,
                  sortAscending: _sortAscending,
                  onStatusChanged: (value) => _updateFilters(() {
                    _statusFilter = value;
                  }),
                  onTypeChanged: (value) => _updateFilters(() {
                    _typeFilter = value;
                  }),
                  onCurrencyChanged: (value) => _updateFilters(() {
                    _currencyFilter = value;
                  }),
                  onSortFieldChanged: (value) => _updateFilters(() {
                    _sortField = value;
                  }),
                  onToggleSortDirection: () => _updateFilters(() {
                    _sortAscending = !_sortAscending;
                  }),
                ),
              ],
            ),
            if (widget.accounts.isNotEmpty) ...[
              const SizedBox(width: 4),
              AppIconActionButton(
                tooltip: _areAllAmountsHidden ? '显示全部金额' : '隐藏全部金额',
                onPressed: _toggleAllAmountsHidden,
                icon: _areAllAmountsHidden
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                variant: AppIconActionVariant.outlined,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        if (widget.accounts.isEmpty)
          _EmptyAccountsPanel(onCreate: () => _openCreateDialog(context, ref))
        else ...[
          const SizedBox(height: 4),
          if (filteredAccounts.isEmpty || selectedGroup == null)
            _NoMatchedAccountsPanel(
              onReset: () => _updateFilters(_resetFilters),
            )
          else ...[
            _AccountGroupSelector(
              groups: displayGroups,
              selectedKind: selectedGroup.kind,
              summary:
                  selectedGroup.kind ==
                      MoneyAccountDisplayGroupKind.creditAndDebt
                  ? _creditSummaryText(creditStatementSummary)
                  : null,
              onChanged: (kind) {
                setState(() {
                  _selectedGroupKind = kind;
                  _visibleAccountCount = _loadMorePageSize;
                });
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: PagedLoadMoreList<MoneyAccountEntity>(
                items: visibleAccounts,
                hasMore: visibleAccounts.length < selectedAccounts.length,
                onRefresh: () async {
                  setState(() {
                    _visibleAccountCount = _loadMorePageSize;
                  });
                  ref.invalidate(currentUserAccountMonthlySummariesProvider);
                  final _ = await ref.refresh(
                    currentUserVisibleAccountsProvider.future,
                  );
                },
                onLoadMore: () async {
                  setState(() {
                    _visibleAccountCount += _loadMorePageSize;
                  });
                },
                itemBuilder: (context, account, index) {
                  return _AccountTile(
                    account: account,
                    monthlySummary: widget.monthlySummaries[account.id],
                    isAmountHidden: _isAmountHidden(account.id),
                    onToggleAmountHidden: () =>
                        _toggleAccountAmountHidden(account.id),
                    onEdit: () => _openEditDialog(context, ref, account),
                    onToggleActive: () =>
                        _toggleAccountActive(context, ref, account),
                    onDelete: () => _deleteAccount(context, ref, account),
                    onViewTransactions: widget.onViewTransactions == null
                        ? null
                        : () => widget.onViewTransactions!(account),
                  );
                },
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                padding: const EdgeInsets.only(bottom: 18),
              ),
            ),
          ],
        ],
      ],
    );
  }

  MoneyAccountDisplayGroup? _selectedDisplayGroup(
    List<MoneyAccountDisplayGroup> groups,
  ) {
    if (groups.isEmpty) {
      return null;
    }
    for (final group in groups) {
      if (group.kind == _selectedGroupKind) {
        return group;
      }
    }
    return groups.first;
  }

  String? _creditSummaryText(MoneyCreditStatementSummary? summary) {
    if (summary == null || !summary.hasStatements) {
      return null;
    }

    final parts = <String>[];
    final dueText = _moneyMapText(summary.amountDueByCurrency);
    if (dueText != null) {
      parts.add('本期应还 $dueText');
    }
    final creditText = _moneyMapText(summary.availableCreditByCurrency);
    if (creditText != null) {
      parts.add('可用额度 $creditText');
    }
    if (summary.overdueCount > 0) {
      parts.add('逾期 ${summary.overdueCount} 笔');
    } else if (summary.dueSoonCount > 0) {
      parts.add('待还 ${summary.dueSoonCount} 笔');
    }
    return parts.join(' · ');
  }

  String? _moneyMapText(Map<String, int> values) {
    if (values.isEmpty) {
      return null;
    }
    return values.entries
        .map((entry) => formatMoneyMinor(entry.value, entry.key))
        .join(' / ');
  }

  String get _summaryText {
    if (widget.accounts.isEmpty) {
      return '还没有可见账户';
    }

    final grouped = <String, int>{};
    for (final account in widget.accounts.where(
      (account) => account.isActive && account.type.isAssetLike,
    )) {
      grouped.update(
        account.currencyCode,
        (value) => value + account.balanceMinor,
        ifAbsent: () => account.balanceMinor,
      );
    }

    if (grouped.isEmpty) {
      final hasActiveAccount = widget.accounts.any(
        (account) => account.isActive,
      );
      return hasActiveAccount
          ? '账户 ${widget.accounts.length} · 暂无资产账户'
          : '账户 ${widget.accounts.length} · 全部已停用';
    }

    final totals = grouped.entries
        .map((entry) => formatMoneyMinor(entry.value, entry.key))
        .join(' / ');
    if (_areAllAmountsHidden) {
      return '账户 ${widget.accounts.length} · 资产 ***';
    }
    return '账户 ${widget.accounts.length} · 资产 $totals';
  }

  bool get _areAllAmountsHidden {
    final accountIds = widget.accounts.map((account) => account.id);
    return widget.accounts.isNotEmpty &&
        accountIds.every(_hiddenAccountIds.contains);
  }

  List<MoneyAccountEntity> get _filteredAndSortedAccounts {
    final filtered = widget.accounts.where((account) {
      final matchesStatus = switch (_statusFilter) {
        MoneyAccountStatusFilter.all => true,
        MoneyAccountStatusFilter.active => account.isActive,
        MoneyAccountStatusFilter.inactive => !account.isActive,
      };
      final matchesType = _typeFilter == null || account.type == _typeFilter;
      final matchesCurrency =
          _currencyFilter == null || account.currencyCode == _currencyFilter;
      return matchesStatus && matchesType && matchesCurrency;
    }).toList();

    filtered.sort((a, b) {
      final result = switch (_sortField) {
        MoneyAccountSortField.updatedAt => a.updatedAt.compareTo(b.updatedAt),
        MoneyAccountSortField.createdAt => a.createdAt.compareTo(b.createdAt),
        MoneyAccountSortField.name => a.name.compareTo(b.name),
        MoneyAccountSortField.balance => a.balanceMinor.compareTo(
          b.balanceMinor,
        ),
        MoneyAccountSortField.type => a.type.label.compareTo(b.type.label),
      };
      return _sortAscending ? result : -result;
    });

    return filtered;
  }

  void _updateFilters(VoidCallback update) {
    setState(() {
      update();
      _visibleAccountCount = _loadMorePageSize;
    });
  }

  void _resetFilters() {
    _statusFilter = MoneyAccountStatusFilter.all;
    _typeFilter = null;
    _currencyFilter = null;
    _sortField = MoneyAccountSortField.updatedAt;
    _sortAscending = false;
  }

  bool _isAmountHidden(String accountId) {
    return _hiddenAccountIds.contains(accountId);
  }

  void _toggleAccountAmountHidden(String accountId) {
    setState(() {
      if (!_hiddenAccountIds.add(accountId)) {
        _hiddenAccountIds.remove(accountId);
      }
    });
    _saveHiddenIds();
  }

  void _toggleAllAmountsHidden() {
    setState(() {
      if (_areAllAmountsHidden) {
        _hiddenAccountIds.clear();
        return;
      }

      _hiddenAccountIds
        ..clear()
        ..addAll(widget.accounts.map((account) => account.id));
    });
    _saveHiddenIds();
  }

  Future<void> _openCreateDialog(BuildContext context, WidgetRef ref) async {
    final result = await showAppResponsiveDialog<AccountFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) =>
          AccountFormDialog(defaultCurrencyCode: widget.defaultCurrencyCode),
    );
    if (result?.draft == null || !context.mounted) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .createAccount(result!.draft!);
      if (context.mounted) {
        AppToast.success(toast, context, '账户已创建');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          toast,
          context,
          _accountWriteErrorMessage(error, '创建账户失败'),
        );
      }
    }
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
  ) async {
    final result = await showAppResponsiveDialog<AccountFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => AccountFormDialog(account: account),
    );
    if (result?.update == null || !context.mounted) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .updateAccount(result!.update!);
      if (context.mounted) {
        AppToast.success(toast, context, '账户已更新');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          toast,
          context,
          _accountWriteErrorMessage(error, '更新账户失败'),
        );
      }
    }
  }

  Future<void> _toggleAccountActive(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
  ) async {
    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .setAccountActive(account.id, !account.isActive);
      if (context.mounted) {
        AppToast.success(toast, context, account.isActive ? '账户已停用' : '账户已启用');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(toast, context, '操作失败');
      }
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
  ) async {
    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除账户',
      message: '确定删除“${account.name}”？',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .deleteAccount(account.id);
      if (context.mounted) {
        AppToast.success(toast, context, '账户已删除');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(toast, context, '删除账户失败');
      }
    }
  }

  String _accountWriteErrorMessage(Object error, String fallback) {
    if (error is MoneyRepositoryException &&
        error.code == MoneyRepositoryErrorCode.invalidAccountBalance) {
      return '账户余额规则不满足';
    }
    return fallback;
  }
}

class _EmptyAccountsPanel extends StatelessWidget {
  const _EmptyAccountsPanel({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: '还没有账户',
      message: '先创建一个现金、银行卡或储蓄账户。',
      icon: Icons.account_balance_wallet_outlined,
      padding: EdgeInsets.zero,
      action: AppIconActionButton(
        tooltip: '新增账户',
        onPressed: onCreate,
        icon: Icons.add_rounded,
        variant: AppIconActionVariant.filled,
      ),
    );
  }
}

class _NoMatchedAccountsPanel extends StatelessWidget {
  const _NoMatchedAccountsPanel({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppPlainPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.filter_alt_off_rounded,
            size: 36,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 10),
          Text(
            '没有匹配的账户',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          AppIconActionButton(
            tooltip: '重置筛选',
            onPressed: onReset,
            icon: Icons.refresh_rounded,
            variant: AppIconActionVariant.outlined,
          ),
        ],
      ),
    );
  }
}

class _AccountGroupSelector extends StatelessWidget {
  const _AccountGroupSelector({
    required this.groups,
    required this.selectedKind,
    required this.onChanged,
    this.summary,
  });

  final List<MoneyAccountDisplayGroup> groups;
  final MoneyAccountDisplayGroupKind selectedKind;
  final ValueChanged<MoneyAccountDisplayGroupKind> onChanged;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSlidingSegmentedControl<MoneyAccountDisplayGroupKind>(
          minSegmentWidth: 112,
          height: 34,
          showTrack: false,
          value: selectedKind,
          onChanged: onChanged,
          segments: [
            for (final group in groups)
              AppSlidingSegment(
                value: group.kind,
                label: group.kind.title,
                tooltip: '${group.kind.title} ${group.accounts.length} 个',
              ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              summary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountFilterFields extends StatelessWidget {
  const _AccountFilterFields({
    required this.accounts,
    required this.statusFilter,
    required this.typeFilter,
    required this.currencyFilter,
    required this.sortField,
    required this.sortAscending,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onCurrencyChanged,
    required this.onSortFieldChanged,
    required this.onToggleSortDirection,
  });

  final List<MoneyAccountEntity> accounts;
  final MoneyAccountStatusFilter statusFilter;
  final MoneyAccountType? typeFilter;
  final String? currencyFilter;
  final MoneyAccountSortField sortField;
  final bool sortAscending;
  final ValueChanged<MoneyAccountStatusFilter> onStatusChanged;
  final ValueChanged<MoneyAccountType?> onTypeChanged;
  final ValueChanged<String?> onCurrencyChanged;
  final ValueChanged<MoneyAccountSortField> onSortFieldChanged;
  final VoidCallback onToggleSortDirection;

  @override
  Widget build(BuildContext context) {
    final types = accounts.map((account) => account.type).toSet().toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    final currencies =
        accounts.map((account) => account.currencyCode).toSet().toList()
          ..sort();
    final closeSheet = AppFilterSheetTrigger.maybeCloserOf(context);
    void apply(VoidCallback onChange) {
      onChange();
      closeSheet?.call();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FormDropdown<MoneyAccountStatusFilter>(
          key: ValueKey('account-status-${statusFilter.name}'),
          width: 120,
          initialSelection: statusFilter,
          label: '状态',
          onSelected: (value) {
            if (value != null) {
              apply(() => onStatusChanged(value));
            }
          },
          entries: MoneyAccountStatusFilter.values
              .map(
                (value) => DropdownMenuEntry(value: value, label: value.label),
              )
              .toList(),
        ),
        FormDropdown<MoneyAccountType?>(
          key: ValueKey('account-type-${typeFilter?.name ?? 'all'}'),
          width: 120,
          initialSelection: typeFilter,
          label: '类型',
          onSelected: (value) => apply(() => onTypeChanged(value)),
          enableFilter: true,
          menuHeight: 250,
          entries: [
            const DropdownMenuEntry<MoneyAccountType?>(
              value: null,
              label: '全部类型',
            ),
            ...types.map(
              (type) => DropdownMenuEntry<MoneyAccountType?>(
                value: type,
                label: type.label,
              ),
            ),
          ],
        ),
        FormDropdown<String?>(
          key: ValueKey('account-currency-${currencyFilter ?? 'all'}'),
          width: 120,
          initialSelection: currencyFilter,
          label: '币种',
          onSelected: (value) => apply(() => onCurrencyChanged(value)),
          enableFilter: true,
          entries: [
            const DropdownMenuEntry<String?>(value: null, label: '全部币种'),
            ...currencies.map(
              (currency) =>
                  DropdownMenuEntry<String?>(value: currency, label: currency),
            ),
          ],
        ),
        FormDropdown<MoneyAccountSortField>(
          key: ValueKey('account-sort-${sortField.name}'),
          width: 120,
          initialSelection: sortField,
          label: '排序',
          onSelected: (value) {
            if (value != null) {
              apply(() => onSortFieldChanged(value));
            }
          },
          entries: MoneyAccountSortField.values
              .map(
                (field) => DropdownMenuEntry(value: field, label: field.label),
              )
              .toList(),
        ),
        AppIconActionButton(
          tooltip: sortAscending ? '升序' : '降序',
          onPressed: onToggleSortDirection,
          icon: sortAscending
              ? Icons.arrow_upward_rounded
              : Icons.arrow_downward_rounded,
          variant: AppIconActionVariant.outlined,
        ),
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    required this.account,
    required this.monthlySummary,
    required this.isAmountHidden,
    required this.onToggleAmountHidden,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    required this.onViewTransactions,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? monthlySummary;
  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback? onViewTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final creditBill = account.type.isCreditLike
        ? ref
              .watch(currentUserCreditCardBillViewProvider(account.id))
              .maybeWhen(data: (value) => value, orElse: () => null)
        : null;
    final creditStatement = creditBill?.toStatement();
    return AppSwipeActionTile(
      onTap: onViewTransactions,
      actions: [
        AppSwipeAction(
          tooltip: '编辑',
          icon: Icons.edit_rounded,
          foreground: colorScheme.onPrimaryContainer,
          background: colorScheme.primaryContainer,
          onPressed: onEdit,
        ),
        AppSwipeAction(
          tooltip: account.isActive ? '停用' : '启用',
          icon: account.isActive
              ? Icons.pause_circle_outline_rounded
              : Icons.play_circle_outline_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onToggleActive,
        ),
        AppSwipeAction(
          tooltip: '删除',
          icon: Icons.delete_outline_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: onDelete,
        ),
      ],
      child: _AccountTileContent(
        account: account,
        monthlySummary: monthlySummary,
        creditStatement: creditStatement,
        isAmountHidden: isAmountHidden,
        onToggleAmountHidden: onToggleAmountHidden,
        onViewTransactions: onViewTransactions,
        onViewStatement: creditStatement == null
            ? null
            : () => _openCreditCardStatement(
                context,
                ref,
                account,
                creditStatement,
              ),
      ),
    );
  }

  Future<void> _openCreditCardStatement(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
    MoneyCreditCardStatement statement,
  ) async {
    final action = await showAppResponsiveDialog<_CreditCardStatementAction>(
      context: context,
      expandCompactSheet: true,
      builder: (sheetContext) => CreditCardStatementReconciliationSheet(
        account: account,
        statement: statement,
        onAdjust: () =>
            Navigator.of(sheetContext).pop(_CreditCardStatementAction.adjust),
        onRepay: () =>
            Navigator.of(sheetContext).pop(_CreditCardStatementAction.repay),
      ),
    );
    if (!context.mounted || action == null) {
      return;
    }

    switch (action) {
      case _CreditCardStatementAction.adjust:
        await _recordCreditCardStatementAdjustment(
          context,
          ref,
          account,
          statement,
        );
      case _CreditCardStatementAction.repay:
        await _recordCreditCardStatementRepayment(
          context,
          ref,
          account,
          statement,
        );
    }
  }

  Future<void> _recordCreditCardStatementAdjustment(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
    MoneyCreditCardStatement statement,
  ) async {
    final differenceMinor =
        statement.purchaseAmountMinor -
        statement.repaymentAmountMinor -
        statement.amountDueMinor;
    if (differenceMinor <= 0) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransaction(
            MoneyTransactionDraft(
              type: MoneyTransactionType.expense,
              transactionAt: statement.periodEndInclusive,
              amountMinor: differenceMinor,
              currencyCode: statement.currencyCode,
              description: '信用账单差额补记',
              notes: '账单核对自动补记，不计入收支统计',
              accountId: account.id,
              categoryId: 'system_transfer',
              paymentMethod: _paymentMethodForCreditAccount(account),
              actualPayerAccount: 'transfer_out',
            ),
            rememberDefaults: false,
          );
      ref.invalidate(currentUserCreditCardStatementProvider(account.id));
      ref.invalidate(currentUserCreditCardBillViewProvider(account.id));
      ref.invalidate(currentUserVisibleAccountsProvider);
      ref.invalidate(currentUserAccountMonthlySummariesProvider);
      if (context.mounted) {
        AppToast.success(toast, context, '差额已补记');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(toast, context, '补记失败');
      }
    }
  }

  Future<void> _recordCreditCardStatementRepayment(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
    MoneyCreditCardStatement statement,
  ) async {
    final result = await showAppResponsiveDialog<Object>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => TransferFormDialog(
        initialToAccountId: account.id,
        initialAmountMinor: statement.amountDueMinor,
        initialNotes: '信用卡还款',
      ),
    );
    if (!context.mounted || result is! MoneyTransferDraft) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyTransactionActionsProvider)
          .createTransfer(result);
      ref.invalidate(currentUserCreditCardStatementProvider(account.id));
      ref.invalidate(currentUserCreditCardBillViewProvider(account.id));
      ref.invalidate(currentUserVisibleAccountsProvider);
      ref.invalidate(currentUserAccountMonthlySummariesProvider);
      if (context.mounted) {
        AppToast.success(toast, context, '还款已记录');
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(toast, context, '还款失败');
      }
    }
  }
}

MoneyPaymentMethod _paymentMethodForCreditAccount(MoneyAccountEntity account) {
  return switch (account.type) {
    MoneyAccountType.huabei => MoneyPaymentMethod.huabei,
    MoneyAccountType.baitiao => MoneyPaymentMethod.baitiao,
    MoneyAccountType.meituanCredit ||
    MoneyAccountType.otherCredit => MoneyPaymentMethod.onlinePayment,
    _ => MoneyPaymentMethod.creditCard,
  };
}

class _AccountTileContent extends StatelessWidget {
  const _AccountTileContent({
    required this.account,
    required this.monthlySummary,
    required this.creditStatement,
    required this.isAmountHidden,
    required this.onToggleAmountHidden,
    required this.onViewTransactions,
    required this.onViewStatement,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? monthlySummary;
  final MoneyCreditCardStatement? creditStatement;
  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;
  final VoidCallback? onViewTransactions;
  final VoidCallback? onViewStatement;

  @override
  Widget build(BuildContext context) {
    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final balance = _AccountBalance(
            account: account,
            isAmountHidden: isAmountHidden,
            compact: constraints.maxWidth < 560,
          );
          final privacyAction = _AccountPrivacyAction(
            isAmountHidden: isAmountHidden,
            onToggleAmountHidden: onToggleAmountHidden,
          );
          final details = _AccountDetails(
            account: account,
            monthlySummary: monthlySummary,
            creditStatement: creditStatement,
            isAmountHidden: isAmountHidden,
            canViewTransactions: onViewTransactions != null,
            onViewStatement: onViewStatement,
            compact: constraints.maxWidth < 560,
          );

          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountIcon(account: account),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    privacyAction,
                  ],
                ),
                const SizedBox(height: 10),
                balance,
              ],
            );
          }

          return Row(
            children: [
              _AccountIcon(account: account),
              const SizedBox(width: 14),
              Expanded(child: details),
              const SizedBox(width: 12),
              balance,
              const SizedBox(width: 8),
              privacyAction,
            ],
          );
        },
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({
    required this.account,
    required this.monthlySummary,
    required this.creditStatement,
    required this.isAmountHidden,
    required this.canViewTransactions,
    required this.onViewStatement,
    required this.compact,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? monthlySummary;
  final MoneyCreditCardStatement? creditStatement;
  final bool isAmountHidden;
  final bool canViewTransactions;
  final VoidCallback? onViewStatement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInactive = !account.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: isInactive
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (isInactive) ...[
              const SizedBox(width: 8),
              _StatusChip(label: '已停用'),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _accountMetaText(account),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (_accountBillingText(account) case final billingText?) ...[
          const SizedBox(height: 4),
          Text(
            billingText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.start,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
        if (creditStatement case final statement?) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppBadge(
                      label:
                          '本期应还 ${formatMoneyMinor(statement.amountDueMinor, statement.currencyCode)}',
                      tone: _creditStatementTone(statement.state),
                    ),
                    AppBadge(
                      label:
                          '${statement.repaymentDate.month}月${statement.repaymentDate.day}日还款',
                      tone: AppBadgeTone.neutral,
                    ),
                    AppBadge(
                      label: statement.state.label,
                      tone: AppBadgeTone.neutral,
                    ),
                  ],
                ),
              ),
              if (onViewStatement != null) ...[
                const SizedBox(width: 4),
                AppIconActionButton(
                  tooltip: '账单',
                  onPressed: onViewStatement,
                  icon: Icons.receipt_long_rounded,
                  iconSize: 18,
                  variant: AppIconActionVariant.plain,
                ),
              ],
            ],
          ),
        ],
        if (account.description?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            account.description!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 6),
        _AccountMonthlyComparison(
          account: account,
          monthlySummary: monthlySummary,
          isAmountHidden: isAmountHidden,
          canViewTransactions: canViewTransactions,
          compact: compact,
        ),
      ],
    );
  }

  String _accountMetaText(MoneyAccountEntity account) {
    return '${account.type.label} · ${account.currencyCode}';
  }

  String? _accountBillingText(MoneyAccountEntity account) {
    if (!account.hasBillingCycle) {
      return null;
    }
    return '账单日 ${account.statementDay} 日 · 还款日 ${account.repaymentDay} 日';
  }

  AppBadgeTone _creditStatementTone(MoneyCreditCardStatementState state) {
    return switch (state) {
      MoneyCreditCardStatementState.overdue => AppBadgeTone.error,
      MoneyCreditCardStatementState.dueSoon => AppBadgeTone.tertiary,
      MoneyCreditCardStatementState.settled => AppBadgeTone.primary,
      MoneyCreditCardStatementState.open ||
      MoneyCreditCardStatementState.pending => AppBadgeTone.neutral,
    };
  }
}

class _AccountMonthlyComparison extends StatelessWidget {
  const _AccountMonthlyComparison({
    required this.account,
    required this.monthlySummary,
    required this.isAmountHidden,
    required this.canViewTransactions,
    required this.compact,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? monthlySummary;
  final bool isAmountHidden;
  final bool canViewTransactions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.insights_rounded,
              size: 15,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              _summaryText,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _summaryText {
    final summary = monthlySummary;
    if (summary == null || !summary.hasCurrentActivity) {
      return canViewTransactions ? '暂无本月流水 · 点击查看账户流水' : '暂无本月流水';
    }
    if (isAmountHidden) {
      return '本月收支 *** · 较上月 ***';
    }

    final currentNet = summary.currentNetMinor;
    final currentLabel = currentNet >= 0 ? '本月净胜' : '本月净支出';
    final currentText = formatMoneyMinor(
      currentNet.abs(),
      account.currencyCode,
    );

    if (!summary.hasPreviousExpense) {
      return '$currentLabel $currentText · 暂无上月支出对比';
    }

    if (summary.expenseChangeMinor == 0) {
      return '$currentLabel $currentText · 支出较上月持平';
    }

    final changeLabel = summary.expenseChangeMinor > 0 ? '多' : '少';
    final changeText = formatMoneyMinor(
      summary.expenseChangeMinor.abs(),
      account.currencyCode,
    );
    return '$currentLabel $currentText · 支出较上月$changeLabel $changeText';
  }
}

class _AccountBalance extends StatelessWidget {
  const _AccountBalance({
    required this.account,
    required this.isAmountHidden,
    required this.compact,
  });

  final MoneyAccountEntity account;
  final bool isAmountHidden;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInactive = !account.isActive;
    final primaryAmount = account.type.isCreditLike
        ? account.availableCreditMinor
        : account.balanceMinor;
    final secondaryText = account.type.isCreditLike
        ? '额度 ${formatMoneyMinor(account.effectiveCreditLimitMinor, account.currencyCode)} · 已入账 ${formatMoneyMinor(account.effectivePostedDebtMinor, account.currencyCode)} · 冻结 ${formatMoneyMinor(account.effectiveFrozenCreditMinor, account.currencyCode)}'
        : '初始 ${formatMoneyMinor(account.initialBalanceMinor, account.currencyCode)}';

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.end,
      children: [
        MoneyAmountText(
          amountMinor: primaryAmount,
          currencyCode: account.currencyCode,
          hidden: isAmountHidden,
          tone: account.type.isCreditLike
              ? MoneyAmountTone.credit
              : MoneyAmountTone.neutral,
          color: isInactive ? colorScheme.onSurfaceVariant : null,
          textStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isAmountHidden
              ? (account.type.isCreditLike ? '信用 ***' : '初始 ***')
              : secondaryText,
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AccountPrivacyAction extends StatelessWidget {
  const _AccountPrivacyAction({
    required this.isAmountHidden,
    required this.onToggleAmountHidden,
  });

  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;

  @override
  Widget build(BuildContext context) {
    return AppIconActionButton(
      tooltip: isAmountHidden ? '显示金额' : '隐藏金额',
      onPressed: onToggleAmountHidden,
      icon: isAmountHidden
          ? Icons.visibility_off_rounded
          : Icons.visibility_rounded,
    );
  }
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.account});

  final MoneyAccountEntity account;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accentColor = account.color == null
        ? colorScheme.primary
        : appColorFromHex(account.color);

    return AppListItemIcon(
      icon: accountIconDataForType(account.type),
      color: accentColor,
      size: 42,
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AppBadge(label: label);
  }
}
