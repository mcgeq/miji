import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_net_worth_entity.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_card_background.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/paged_load_more_list.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/account_card_info.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_repository.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_form_dialog.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_detail_sheet.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/components/account_progress_bar.dart';
import 'package:miji/features/bookkeeping/presentation/components/bookkeeping_panel_header.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_balance_adjustment_sheet.dart';
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

  /// 「在流水中查看全部」：切到流水面板并按账户筛选。
  ///
  /// 点卡片 / 点「查看流水」都不再走这里 —— 它们打开账户弹窗。
  /// 这个出口只保留给弹窗底部的次要按钮：批量改分类、跨账户搜索仍然
  /// 只有老的流水面板能做。
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
      loading: () => const AppSkeletonList(),
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

  /// 显式「显示」的账户。
  ///
  /// 原来只有「显式隐藏」一个集合，于是**全局遮罩打开时逐账户开关会失效**：
  /// 金额是隐藏的，但菜单里却显示「隐藏金额」，点下去也没有任何变化。
  /// 加一个显式显示集合，语义变成三态：
  /// 显式显示 > 显式隐藏 > 全局遮罩。
  final Set<String> _revealedAccountIds = <String>{};
  static const _loadMorePageSize = 8;
  static const _hiddenIdsPrefKey = 'account_hidden_ids';
  static const _revealedIdsPrefKey = 'account_revealed_ids';

  /// 按用户隔离的存储 key。
  ///
  /// 原实现只用 `account_hidden_ids` 这一个全局 key，多用户共用设备时
  /// 后登录的人会继承前一个人的隐藏设置（隐藏的是账户 id，跨用户没有意义），
  /// 这里加上 userId 后缀。
  static String _hiddenIdsPrefKeyFor(String userId) =>
      '${_hiddenIdsPrefKey}_$userId';

  static String _revealedIdsPrefKeyFor(String userId) =>
      '${_revealedIdsPrefKey}_$userId';

  /// 已加载过隐藏设置的 userId，避免重复读取覆盖内存状态。
  String? _hiddenIdsLoadedForUserId;

  @override
  void initState() {
    super.initState();
    _hiddenIdsLoadedForUserId = _currentUserId;
    unawaited(_loadHiddenIds(_hiddenIdsLoadedForUserId));
  }

  String? get _currentUserId => ref.read(authSessionControllerProvider).userId;

  Future<void> _loadHiddenIds(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final rawHidden = prefs.getString(_hiddenIdsPrefKeyFor(userId));
    final rawRevealed = prefs.getString(_revealedIdsPrefKeyFor(userId));
    if (!mounted || _hiddenIdsLoadedForUserId != userId) {
      return;
    }
    setState(() {
      _hiddenAccountIds.clear();
      if (rawHidden != null && rawHidden.isNotEmpty) {
        _hiddenAccountIds.addAll(rawHidden.split(','));
      }
      _revealedAccountIds.clear();
      if (rawRevealed != null && rawRevealed.isNotEmpty) {
        _revealedAccountIds.addAll(rawRevealed.split(','));
      }
    });
  }

  Future<void> _saveHiddenIds() async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _hiddenIdsPrefKeyFor(userId),
      _hiddenAccountIds.join(','),
    );
    await prefs.setString(
      _revealedIdsPrefKeyFor(userId),
      _revealedAccountIds.join(','),
    );
  }

  /// 用户切换时重新载入对应账号的隐藏设置。
  void _syncHiddenIdsForUser(String? userId) {
    if (userId == _hiddenIdsLoadedForUserId) {
      return;
    }
    _hiddenIdsLoadedForUserId = userId;
    _hiddenAccountIds.clear();
    _revealedAccountIds.clear();
    unawaited(_loadHiddenIds(userId));
  }

  @override
  Widget build(BuildContext context) {
    _syncHiddenIdsForUser(ref.watch(authSessionControllerProvider).userId);
    // 响应式读取（原来是 ref.read，导致切换开关后本页不刷新）。
    _globalMasked = ref.watch(moneyAmountsMaskedProvider);
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
    // 只有选中「信用/负债」分组时才展示额度与还款汇总。
    final creditSummaryText =
        selectedGroup?.kind == MoneyAccountDisplayGroupKind.creditAndDebt
        ? _creditSummaryText(creditStatementSummary)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.accounts.isNotEmpty) ...[
          _AccountsHeader(
            groups: displayGroups,
            selectedKind: selectedGroup?.kind,
            onGroupChanged: (kind) {
              setState(() {
                _selectedGroupKind = kind;
                _visibleAccountCount = _loadMorePageSize;
              });
            },
            sortField: _sortField,
            sortAscending: _sortAscending,
            allAmountsHidden: _areAllAmountsHidden,
            onSortFieldChanged: (value) => _updateFilters(() {
              _sortField = value;
            }),
            onToggleSortDirection: () => _updateFilters(() {
              _sortAscending = !_sortAscending;
            }),
            onToggleAllAmountsHidden: _toggleAllAmountsHidden,
            onCreate: () => _openCreateDialog(context, ref),
            filterTrigger: AppFilterSheetTrigger(
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
          ),
          const SizedBox(height: 10),
          _NetWorthHero(allAmountsHidden: _areAllAmountsHidden),
          if (creditSummaryText != null) ...[
            const SizedBox(height: 6),
            Text(
              creditSummaryText,
              maxLines: 2,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
        const SizedBox(height: 4),
        if (widget.accounts.isEmpty)
          _EmptyAccountsPanel(onCreate: () => _openCreateDialog(context, ref))
        else ...[
          const SizedBox(height: 4),
          _DeletedAccountsBanner(
            deletedCount: ref
                .watch(currentUserDeletedAccountsProvider)
                .maybeWhen(data: (items) => items.length, orElse: () => 0),
            onOpen: () => _openDeletedAccountsDialog(context, ref),
          ),
          const SizedBox(height: 4),
          if (filteredAccounts.isEmpty || selectedGroup == null)
            _NoMatchedAccountsPanel(
              onReset: () => _updateFilters(_resetFilters),
            )
          else
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
                    isAmountHidden: _isEffectivelyHidden(account.id),
                    onToggleAmountHidden: () =>
                        _toggleAccountAmountHidden(account.id),
                    onEdit: () => _openEditDialog(context, ref, account),
                    // 信用账户的「余额」是可用额度，改它等于改额度——
                    // 那条路是账单对账，不是余额校正。
                    onAdjustBalance:
                        account.type.isAssetLike && !account.isVirtual
                        ? () => _adjustAccountBalance(context, ref, account)
                        : null,
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
    if (_globalMasked) {
      return '••••';
    }
    return values.entries
        .map((entry) => formatMoneyMinor(entry.value, entry.key))
        .join(' / ');
  }

  /// 全局「隐藏金额」开关（设置里）也应该把账户页遮住：账户页自己的逐账户隐藏
  /// 是进阶能力，全局开关是兜底。
  /// 全局遮罩开关。
  ///
  /// 必须用 `watch`（原来这里是 `ref.read`）——否则在设置/首页切换开关后，
  /// 已经被保活的账户面板不会重建，遮罩不会立刻生效。
  /// 见 [build] 里的 `_globalMasked = ...`。
  bool _globalMasked = false;

  bool get _areAllAmountsHidden {
    final accountIds = widget.accounts.map((account) => account.id);
    return widget.accounts.isNotEmpty && accountIds.every(_isEffectivelyHidden);
  }

  /// 生效的隐藏状态：显式显示 > 显式隐藏 > 全局遮罩。
  bool _isEffectivelyHidden(String accountId) {
    if (_revealedAccountIds.contains(accountId)) {
      return false;
    }
    if (_hiddenAccountIds.contains(accountId)) {
      return true;
    }
    return _globalMasked;
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

  void _toggleAccountAmountHidden(String accountId) {
    final currentlyHidden = _isEffectivelyHidden(accountId);
    setState(() {
      if (currentlyHidden) {
        // 要「显示」：清掉显式隐藏，并记下显式显示（可以盖过全局遮罩）。
        _hiddenAccountIds.remove(accountId);
        _revealedAccountIds.add(accountId);
      } else {
        _revealedAccountIds.remove(accountId);
        _hiddenAccountIds.add(accountId);
      }
    });
    _saveHiddenIds();
  }

  void _toggleAllAmountsHidden() {
    final accountIds = widget.accounts.map((account) => account.id).toList();
    setState(() {
      if (_areAllAmountsHidden) {
        // 「全部显示」：显式显示优先，因此这里同时清掉显式隐藏。
        _hiddenAccountIds.clear();
        _revealedAccountIds
          ..clear()
          ..addAll(accountIds);
        return;
      }

      _revealedAccountIds.clear();
      _hiddenAccountIds
        ..clear()
        ..addAll(accountIds);
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

  /// 余额校正：账面余额对不上银行实际余额时，直接把账面数对齐过去。
  ///
  /// 差额走初始余额而不是补一笔流水：漏记的小额支出逐笔补记不现实，
  /// 而且补出来的流水会污染分类排行和收支统计。
  Future<void> _adjustAccountBalance(
    BuildContext context,
    WidgetRef ref,
    MoneyAccountEntity account,
  ) async {
    final targetMinor = await showAccountBalanceAdjustmentSheet(
      context: context,
      account: account,
    );
    if (targetMinor == null || !context.mounted) {
      return;
    }

    final toast = FToast()..init(context);
    try {
      await ref
          .read(currentUserMoneyAccountActionsProvider)
          .adjustAccountBalance(account.id, targetMinor);
      if (context.mounted) {
        AppToast.success(toast, context, '余额已校正');
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(
          toast,
          context,
          _accountWriteErrorMessage(error, '余额校正失败'),
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

  Future<void> _openDeletedAccountsDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final deleted = await ref.read(currentUserDeletedAccountsProvider.future);
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '账户回收站',
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 0),
                ),
                const SizedBox(height: 4),
                Text(
                  '已删除账户的历史流水不会丢失，恢复后账户重新可用。',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
                if (deleted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('回收站是空的')),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: deleted.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final account = deleted[index];
                        return ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                          ),
                          leading: const Icon(
                            Icons.account_balance_wallet_outlined,
                          ),
                          title: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(account.type.label),
                          trailing: TextButton.icon(
                            onPressed: () async {
                              final toast = FToast()..init(dialogContext);
                              try {
                                await ref
                                    .read(
                                      currentUserMoneyAccountActionsProvider,
                                    )
                                    .restoreAccount(account.id);
                                if (dialogContext.mounted) {
                                  AppToast.success(
                                    toast,
                                    dialogContext,
                                    '账户已恢复',
                                  );
                                  Navigator.of(dialogContext).pop();
                                }
                              } catch (_) {
                                if (dialogContext.mounted) {
                                  AppToast.error(
                                    toast,
                                    dialogContext,
                                    '恢复账户失败',
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.restore_rounded, size: 16),
                            label: const Text('恢复'),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _accountWriteErrorMessage(Object error, String fallback) {
    if (error is MoneyRepositoryException &&
        error.code == MoneyRepositoryErrorCode.invalidAccountBalance) {
      return '账户余额规则不满足';
    }
    return fallback;
  }
}

/// 净资产 Hero。
///
/// 只保留「净资产 + 总资产 / 负债 一行 + 细占比条」，去掉了原来两个
/// 带内边距的单元格和占比图例：分组 chips 已经不再显示金额，
/// 这里就是唯一的口径，不重复也不占地方。
class _NetWorthHero extends ConsumerWidget {
  const _NetWorthHero({required this.allAmountsHidden});

  final bool allAmountsHidden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final worth = ref
        .watch(currentUserNetWorthSummaryProvider)
        .maybeWhen(
          data: (value) => value,
          orElse: () => const MoneyNetWorthSummary.empty(),
        );
    final hidden = allAmountsHidden;

    final gradient = theme.heroGradients.netWorth;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        gradient: gradient.linear,
        boxShadow: [
          BoxShadow(
            color: gradient.shadow.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 12),
            spreadRadius: -16,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        child: Stack(
          children: [
            Positioned(
              right: -60,
              top: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: gradient.onColor.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '净资产',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: gradient.onColor.withValues(
                              alpha: AppHeroGradient.secondaryOpacity,
                            ),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _HeroAmount(
                          amountMinor: worth.netAssetMinor,
                          currencyCode: worth.currencyCode,
                          hidden: hidden,
                          compact: true,
                          onColor: gradient.onColor,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CompactHeroTotal(
                        label: '总资产',
                        value: hidden
                            ? '••••'
                            : formatMoneyMinor(
                                worth.assetMinor,
                                worth.currencyCode,
                              ),
                        color: gradient.onColor,
                      ),
                      const SizedBox(height: 4),
                      _CompactHeroTotal(
                        label: '负债',
                        value: hidden
                            ? '••••'
                            : formatMoneyMinor(
                                worth.liabilityMinor,
                                worth.currencyCode,
                              ),
                        // 净资产卡是亮卡，次级数字不能再用暖琥珀（那是深卡上的告警色），
                        // 改成同一套深字降不透明度——0.78 是在最亮那一档上仍过 4.5:1 的上限。
                        color: gradient.onColor.withValues(
                          alpha: AppHeroGradient.secondaryOpacity,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: gradient.onColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 净资产卡右侧的紧凑「标签 + 金额」。
///
/// 与 Hero 并排时不再用 `Expanded`（那需要一个有界宽度），改为 `mainAxisSize.min`
/// + `FittedBox(scaleDown)`：空间不够时整体等比缩小，不溢出也不换行。
class _CompactHeroTotal extends StatelessWidget {
  const _CompactHeroTotal({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            maxLines: 1,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.amountMinor,
    required this.currencyCode,
    required this.hidden,
    required this.onColor,
    this.compact = false,
  });

  final int amountMinor;
  final String currencyCode;
  final bool hidden;

  /// 卡上正文色。亮卡（净资产）是深字、深卡才配白字，由 `AppHeroGradient.onColor` 决定。
  final Color onColor;

  /// 紧凑布局下用更小一号的字，避免与右侧的「总资产 / 负债」并排时被压窄。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        (compact ? theme.textTheme.headlineSmall : theme.textTheme.displaySmall)
            ?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1.05,
            );

    if (hidden) {
      return Text('••••', style: style);
    }

    final text = formatMoneyMinor(amountMinor, currencyCode);
    final dotIndex = text.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex < text.length - 3) {
      return Text(text, maxLines: 1, style: style);
    }
    // 样式必须挂在根 TextSpan 上，否则整数部分会回退到默认正文字号。
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: text.substring(0, dotIndex)),
          TextSpan(
            text: text.substring(dotIndex),
            style: style?.copyWith(
              fontSize: (style.fontSize ?? 36) * 0.56,
              fontWeight: FontWeight.w700,
              color: onColor.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

/// 账户页 header 菜单里「非排序」的动作。
enum _AccountHeaderMenuAction { toggleHideAmounts }

/// 分组 chips + 排序 / 隐私 / 筛选 / 新建，合并成一行。
///
/// chips 只显示名称与数量：金额已经在净资产卡里给过（总资产、负债），
/// 再在 chips 上重复一遍既占高度又容易让人以为口径不同。
class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({
    required this.groups,
    required this.selectedKind,
    required this.onGroupChanged,
    required this.sortField,
    required this.sortAscending,
    required this.allAmountsHidden,
    required this.onSortFieldChanged,
    required this.onToggleSortDirection,
    required this.onToggleAllAmountsHidden,
    required this.onCreate,
    required this.filterTrigger,
  });

  final List<MoneyAccountDisplayGroup> groups;
  final MoneyAccountDisplayGroupKind? selectedKind;
  final ValueChanged<MoneyAccountDisplayGroupKind> onGroupChanged;
  final MoneyAccountSortField sortField;
  final bool sortAscending;
  final bool allAmountsHidden;
  final ValueChanged<MoneyAccountSortField> onSortFieldChanged;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleAllAmountsHidden;
  final VoidCallback onCreate;
  final Widget filterTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BookkeepingPanelHeader(
      leading: SizedBox(
        height: 32,
        child: groups.length <= 1
            ? const SizedBox.shrink()
            : ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(width: 3),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final total = _groupTotal(group);
                  return _GroupChip(
                    label: _title(group.kind),
                    count: group.accounts.length,
                    amountText: total == null
                        ? null
                        : allAmountsHidden
                        ? '••••'
                        : formatMoneyMinorCompact(
                            total.minor,
                            total.currencyCode,
                          ),
                    selected: group.kind == selectedKind,
                    onTap: () => onGroupChanged(group.kind),
                  );
                },
              ),
      ),
      actions: [
        // 排序与「隐藏全部金额」合并进同一个菜单：账户页的 header 原来一排塞了
        // 分组 chips + 4 个图标按钮，360dp 下 chips 被压得只剩两条，「停用」组
        // 常常滚出首屏。把低频的隐私开关收进排序菜单，只留 3 个常驻按钮。
        PopupMenuButton<Object>(
          tooltip: '排序：${sortField.label}${sortAscending ? ' 升序' : ' 降序'}',
          position: PopupMenuPosition.under,
          onSelected: (value) {
            if (value is MoneyAccountSortField) {
              onSortFieldChanged(value);
            } else if (value == _AccountHeaderMenuAction.toggleHideAmounts) {
              onToggleAllAmountsHidden();
            }
          },
          itemBuilder: (context) => [
            for (final field in MoneyAccountSortField.values)
              PopupMenuItem<Object>(
                value: field,
                child: Row(
                  children: [
                    Icon(
                      field == sortField
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: field == sortField
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Text(field.label),
                  ],
                ),
              ),
            const PopupMenuDivider(),
            PopupMenuItem<Object>(
              value: _AccountHeaderMenuAction.toggleHideAmounts,
              child: Row(
                children: [
                  Icon(
                    allAmountsHidden
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Text(allAmountsHidden ? '显示全部金额' : '隐藏全部金额'),
                ],
              ),
            ),
          ],
          child: _headerButton(
            context,
            icon: sortAscending
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
          ),
        ),
        filterTrigger,
        // 页面级新增入口统一规则：本页的 ＋ 只负责本页实体（账户 / 预算 /
        // 分期 / 自动记账），流水类动作一律走全局 FAB。
        // 四个页面的 ＋ 都必须是 filled，与同排的 plain 图标按钮区分开。
        AppIconActionButton(
          tooltip: '新增账户',
          onPressed: onCreate,
          icon: Icons.add_rounded,
          iconSize: 19,
          variant: AppIconActionVariant.filled,
        ),
      ],
    );
  }

  Widget _headerButton(BuildContext context, {required IconData icon}) {
    final theme = Theme.of(context);
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
    );
  }

  String _title(MoneyAccountDisplayGroupKind kind) {
    return switch (kind) {
      MoneyAccountDisplayGroupKind.assets => '资产',
      MoneyAccountDisplayGroupKind.creditAndDebt => '信用负债',
      MoneyAccountDisplayGroupKind.inactive => '停用',
    };
  }

  /// 分组的金额合计。
  ///
  /// 口径与统计页的账户切片一致：资产类看可用余额，信用类看已用额度，
  /// 负债类看欠款；停用组不给金额（它们退出日常视野，合计没有意义）。
  ///
  /// **多币种时返回 null**——把 CNY 和 USD 直接相加是错的，宁可只显示数量。
  ({String currencyCode, int minor})? _groupTotal(
    MoneyAccountDisplayGroup group,
  ) {
    if (group.kind == MoneyAccountDisplayGroupKind.inactive) {
      return null;
    }
    final currencies = group.accounts
        .map((account) => account.currencyCode)
        .toSet();
    if (currencies.length != 1) {
      return null;
    }
    var total = 0;
    for (final account in group.accounts) {
      total += _accountAmountMinor(account);
    }
    return (currencyCode: currencies.first, minor: total);
  }

  int _accountAmountMinor(MoneyAccountEntity account) {
    if (account.type.isCreditLike) {
      return account.usedCreditMinor.abs();
    }
    if (account.type.isDebtLike) {
      return account.balanceMinor.abs();
    }
    return account.displayBalanceMinor.abs();
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.amountText,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  /// 该组的金额合计。多币种或停用组为 null，此时只显示数量。
  final String? amountText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.4)
                  : colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              // 分组时最想看的其实是钱：资产一共多少、信用一共欠多少。
              // 原来只有名称 + 数量，还得点进去才知道。
              if (amountText != null) ...[
                const SizedBox(width: 4),
                Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.5)
                        : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  amountText!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeletedAccountsBanner extends StatelessWidget {
  const _DeletedAccountsBanner({
    required this.deletedCount,
    required this.onOpen,
  });

  final int deletedCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (deletedCount <= 0) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '回收站中有 $deletedCount 个已删除账户',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
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
        ),
      ),
    );
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
      // 空态是一个新用户唯一能看到的界面 —— 只给一个纯图标按钮，
      // 要悬停看 tooltip 才知道它是什么，等于没告诉人家下一步做什么。
      action: FilledButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: const Text('新增账户'),
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
          width: 148,
          initialSelection: typeFilter,
          label: '账户类型',
          onSelected: (value) => apply(() => onTypeChanged(value)),
          enableFilter: true,
          menuHeight: 250,
          entries: [
            const DropdownMenuEntry<MoneyAccountType?>(
              value: null,
              label: '全部账户类型',
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
    this.onAdjustBalance,
  });

  final MoneyAccountEntity account;
  final MoneyAccountMonthlySummary? monthlySummary;
  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;
  final VoidCallback onEdit;

  /// 余额校正；信用 / 虚拟账户没有这个入口，传 null 由菜单隐藏。
  final VoidCallback? onAdjustBalance;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;
  final VoidCallback? onViewTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creditBill = account.type.isCreditLike
        ? ref
              .watch(currentUserCreditCardBillViewProvider(account.id))
              .maybeWhen(data: (value) => value, orElse: () => null)
        : null;
    final creditStatement = creditBill?.toStatement();
    final colorScheme = Theme.of(context).colorScheme;
    return AppSwipeActionTile(
      // 点卡片本体 = 打开账户弹窗（概览 + 流水），不再切走面板。
      // 原来的行为是「点一下把整页换成流水列表」，回来时筛选还挂在
      // 这个账户上 —— 想回账户列表反而要多点一次。
      onTap: () => _openDetailSheet(context, ref),
      // 左滑只留「编辑 / 删除」，与预算卡片保持同一口径。
      // 「停用 / 启用」收进右上角 ⋯ 菜单 —— 它本来就低频，而左滑条在手机上
      // 一次只露得出 2~3 个按钮，塞第三个的代价是前两个也要滑一下才看清。
      actions: [
        AppSwipeAction(
          tooltip: '编辑',
          icon: Icons.edit_rounded,
          foreground: colorScheme.onPrimaryContainer,
          background: colorScheme.primaryContainer,
          onPressed: onEdit,
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
        creditStatement: creditStatement,
        monthlySummary: monthlySummary,
        isAmountHidden: isAmountHidden,
        actionsMenu: _AccountActionsMenu(
          account: account,
          isAmountHidden: isAmountHidden,
          onToggleAmountHidden: onToggleAmountHidden,
          onEdit: onEdit,
          onAdjustBalance: onAdjustBalance,
          onToggleActive: onToggleActive,
          onDelete: onDelete,
        ),
        onViewStatement: creditStatement == null
            ? null
            : () => _openCreditCardStatement(
                context,
                ref,
                account,
                creditStatement,
              ),
        onViewFlows: () => _openDetailSheet(context, ref),
      ),
    );
  }

  Future<void> _openDetailSheet(BuildContext context, WidgetRef ref) async {
    await showAccountDetailSheet(
      context: context,
      account: account,
      onOpenFullTransactions: onViewTransactions,
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
      builder: (sheetContext) => MoneyPrivacy(
        // 账单对账里的每一行金额都走 maskedMoneyOr，读的就是这个作用域。
        masked: isAmountHidden,
        child: CreditCardStatementReconciliationSheet(
          account: account,
          statement: statement,
          onAdjust: () =>
              Navigator.of(sheetContext).pop(_CreditCardStatementAction.adjust),
          onRepay: () =>
              Navigator.of(sheetContext).pop(_CreditCardStatementAction.repay),
        ),
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

/// 账户卡内容：四槽位骨架。
///
/// 槽位固定、内容按语义组替换：
/// ① 图标 + 名称 + 状态徽章 + ⋯ ｜ ② 主值（标签 + 金额）
/// ｜ ③ 右侧 1～2 个辅助值 ｜ ④ 进度条 + 底部动作行。
///
/// 为什么不给 16 种类型各写一套：账户一多一屏只放得下两三张，骨架一致
/// 才能靠「位置」扫视；组间差异全部落在文案与那一行进度上。原来那版把
/// 贷款账户当成资产渲染（显示「当前余额 −¥486,200 / 初始 −¥600,000」），
/// 就是因为只有一条 `if (isCreditLike)` 分支。
class _AccountTileContent extends StatelessWidget {
  const _AccountTileContent({
    required this.account,
    required this.creditStatement,
    required this.monthlySummary,
    required this.isAmountHidden,
    required this.actionsMenu,
    required this.onViewStatement,
    required this.onViewFlows,
  });

  final MoneyAccountEntity account;
  final MoneyCreditCardStatement? creditStatement;
  final MoneyAccountMonthlySummary? monthlySummary;
  final bool isAmountHidden;
  final Widget actionsMenu;
  final VoidCallback? onViewStatement;
  final VoidCallback onViewFlows;

  @override
  Widget build(BuildContext context) {
    final semantic = accountCardSemanticOf(account);
    // 背景容器按账户设置渲染 默认 / 纯色 / 图片 三种外观；默认外观与
    // 原 AppListItemPanel 逐像素一致（内边距 12 也搬进了容器）。
    return AccountCardBackground(
      account: account,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _AccountIcon(account: account),
              const SizedBox(width: 12),
              Expanded(child: _AccountIdentity(account: account)),
              actionsMenu,
            ],
          ),
          const SizedBox(height: 10),
          _AccountPrimaryRow(
            account: account,
            semantic: semantic,
            creditStatement: creditStatement,
            monthlySummary: monthlySummary,
            isAmountHidden: isAmountHidden,
          ),
          if (semantic.hasProgressBar) ...[
            const SizedBox(height: 10),
            _AccountProgressSection(
              account: account,
              semantic: semantic,
              isAmountHidden: isAmountHidden,
            ),
          ],
          const SizedBox(height: 6),
          _AccountFooterRow(
            ghost: _ghost,
            onGhostTap: onViewStatement,
            onViewFlows: onViewFlows,
          ),
        ],
      ),
    );
  }

  /// 底部动作行左侧那一小段文字。
  ///
  /// 左边是**对象级入口**（现在只有信用卡有「账单详情」，其余组留空，
  /// 宁可空着也不塞别的信息占位），右边是「查看流水」按钮。
  ({String text, bool tappable})? get _ghost {
    final semantic = accountCardSemanticOf(account);
    switch (semantic) {
      case AccountCardSemantic.credit:
        if (onViewStatement == null) {
          return null;
        }
        return (text: '账单详情 ›', tappable: true);
      case AccountCardSemantic.spendable:
      case AccountCardSemantic.holding:
        final summary = monthlySummary;
        if (summary == null || !summary.hasCurrentActivity) {
          return null;
        }
        final income = _money(summary.currentIncomeMinor);
        final expense = _money(summary.currentExpenseMinor);
        return (text: '本月 收 $income · 支 $expense', tappable: false);
      case AccountCardSemantic.debt:
        final progress = accountDebtProgressOf(account);
        if (!progress.hasProgress) {
          return null;
        }
        // 项目里没有「贷款总额」字段，本金是建账时录入的初始值，
        // 文案必须标明来源，否则对不上真实合同时会被当成 bug。
        return (
          text: '本金 ${_money(progress.principalMinor)}（建账时录入）',
          tappable: false,
        );
      case AccountCardSemantic.prepaid:
        return null;
    }
  }

  String _money(int minor) {
    if (isAmountHidden) {
      return '••••';
    }
    return formatMoneyMinor(minor, account.currencyCode);
  }
}

/// 主值行：左侧「标签 + 金额」，右侧 1～2 个辅助值。
class _AccountPrimaryRow extends StatelessWidget {
  const _AccountPrimaryRow({
    required this.account,
    required this.semantic,
    required this.creditStatement,
    required this.monthlySummary,
    required this.isAmountHidden,
  });

  final MoneyAccountEntity account;
  final AccountCardSemantic semantic;
  final MoneyCreditCardStatement? creditStatement;
  final MoneyAccountMonthlySummary? monthlySummary;
  final bool isAmountHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInactive = !account.isActive;
    final primaryAmount = accountCardPrimaryAmountMinor(account);
    // 自定义背景上金额与标签走卡片前景色（credit 语气色可能与背景冲突）。
    final onSurface = AccountCardScope.textColorOf(
      context,
      fallback: colorScheme.onSurface,
    );
    final onVariant = AccountCardScope.textColorOf(
      context,
      fallback: colorScheme.onSurfaceVariant,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                semantic.primaryLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: onVariant.withValues(
                    alpha: AccountCardScope.secondaryOpacity,
                  ),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              MoneyAmountText(
                amountMinor: primaryAmount,
                currencyCode: account.currencyCode,
                hidden: isAmountHidden,
                tone: _tone(primaryAmount),
                color: isInactive
                    ? onVariant
                    : AccountCardScope.maybeOf(context) == null
                    ? null
                    : onSurface,
                textStyle: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _side(context),
      ],
    );
  }

  MoneyAmountTone _tone(int primaryAmount) {
    if (semantic == AccountCardSemantic.credit) {
      return MoneyAmountTone.credit;
    }
    // 资产类账户余额为负（透支 / 记账错向）时不该还是中性色。
    if (semantic != AccountCardSemantic.debt && primaryAmount < 0) {
      return MoneyAmountTone.expense;
    }
    return MoneyAmountTone.neutral;
  }

  Widget _side(BuildContext context) {
    final theme = Theme.of(context);
    final onVariant = AccountCardScope.textColorOf(
      context,
      fallback: theme.colorScheme.onSurfaceVariant,
    );
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: onVariant.withValues(alpha: AccountCardScope.secondaryOpacity),
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    switch (semantic) {
      case AccountCardSemantic.credit:
        final statement = creditStatement;
        final due =
            statement?.amountDueMinor ?? account.effectivePostedDebtMinor;
        final color = _statementColor(context, statement);
        return _SideColumn(
          label: '本期应还',
          labelStyle: labelStyle,
          value: MoneyAmountText(
            amountMinor: due,
            currencyCode: account.currencyCode,
            hidden: isAmountHidden,
            color: color,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          hint: _statementHint(statement),
          hintColor: color,
        );
      case AccountCardSemantic.debt:
        final progress = accountDebtProgressOf(account);
        return _SideColumn(
          label: '已还进度',
          labelStyle: labelStyle,
          value: Text(
            '${(progress.ratio * 100).round()}%',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isAmountHidden ? onVariant : theme.moneyColors.expense,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
      case AccountCardSemantic.prepaid:
        return _SideColumn(
          label: '本月支出',
          labelStyle: labelStyle,
          value: MoneyAmountText(
            amountMinor: monthlySummary?.currentExpenseMinor ?? 0,
            currencyCode: account.currencyCode,
            hidden: isAmountHidden,
            tone: MoneyAmountTone.expense,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
      case AccountCardSemantic.spendable:
      case AccountCardSemantic.holding:
        final summary = monthlySummary;
        // 本月没有收支就不占右侧：一个恒为 0 的数字只会和余额抢注意力。
        if (summary == null || !summary.hasCurrentActivity) {
          return const SizedBox.shrink();
        }
        final net = summary.currentNetMinor;
        return _SideColumn(
          label: '本月净',
          labelStyle: labelStyle,
          value: MoneyAmountText(
            amountMinor: net,
            currencyCode: account.currencyCode,
            hidden: isAmountHidden,
            tone: net > 0
                ? MoneyAmountTone.income
                : (net < 0 ? MoneyAmountTone.expense : MoneyAmountTone.neutral),
            showSign: true,
            textStyle: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        );
    }
  }

  Color _statementColor(
    BuildContext context,
    MoneyCreditCardStatement? statement,
  ) {
    final theme = Theme.of(context);
    return switch (statement?.state) {
      MoneyCreditCardStatementState.overdue => theme.colorScheme.error,
      MoneyCreditCardStatementState.dueSoon => theme.moneyColors.warning,
      _ => AccountCardScope.textColorOf(
        context,
        fallback: theme.colorScheme.onSurface,
      ),
    };
  }

  String? _statementHint(MoneyCreditCardStatement? statement) {
    if (statement == null) {
      return null;
    }
    final date = statement.repaymentDate;
    final dateText = '${date.month}月${date.day}日';
    if (statement.state == MoneyCreditCardStatementState.overdue) {
      return '已逾期 · $dateText应还';
    }
    if (statement.state == MoneyCreditCardStatementState.settled) {
      return '本期已还清';
    }
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(_today()).inDays;
    if (days < 0) {
      return '$dateText还款';
    }
    if (days == 0) {
      return '今天还款';
    }
    return '$dateText还款 · 还剩 $days 天';
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

/// 右侧「标签 + 值 + 可选提示」。
class _SideColumn extends StatelessWidget {
  const _SideColumn({
    required this.label,
    required this.labelStyle,
    required this.value,
    this.hint,
    this.hintColor,
  });

  final String label;
  final TextStyle? labelStyle;
  final Widget value;
  final String? hint;
  final Color? hintColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: 2),
        value,
        if (hint != null) ...[
          const SizedBox(height: 1),
          Text(
            hint!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: hintColor ?? theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

/// 状态行：授信看额度使用率，负债看已还比例。
class _AccountProgressSection extends StatelessWidget {
  const _AccountProgressSection({
    required this.account,
    required this.semantic,
    required this.isAmountHidden,
  });

  final MoneyAccountEntity account;
  final AccountCardSemantic semantic;
  final bool isAmountHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inScope = AccountCardScope.maybeOf(context) != null;
    final textColor = AccountCardScope.textColorOf(
      context,
      fallback: theme.colorScheme.onSurfaceVariant,
    );
    final isCredit = semantic == AccountCardSemantic.credit;
    final usage = accountCreditUsageOf(account);
    final debt = accountDebtProgressOf(account);

    final color = isCredit
        ? switch (usage.level) {
            AccountCreditUsageLevel.critical => theme.colorScheme.error,
            AccountCreditUsageLevel.warning => theme.moneyColors.warning,
            AccountCreditUsageLevel.normal => AccountCardScope.textColorOf(
              context,
              fallback: theme.moneyColors.credit,
            ),
          }
        : theme.moneyColors.expense;

    final caption = isAmountHidden
        ? (isCredit ? '已用 *** / 额度 ***' : '已还 *** / 本金 ***')
        : isCredit
        ? '已用 ${formatMoneyMinor(usage.usedMinor, account.currencyCode)}'
              ' / 额度 ${formatMoneyMinor(usage.limitMinor, account.currencyCode)}'
        : '已还 ${formatMoneyMinor(debt.repaidMinor, account.currencyCode)}'
              ' / 本金 ${formatMoneyMinor(debt.principalMinor, account.currencyCode)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AccountProgressBar(
          value: isCredit ? usage.ratio : debt.ratio,
          color: color,
          // 自定义背景上轨道用前景色淡染（原语义色淡底可能与背景打架）。
          trackColor: inScope
              ? textColor.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.14),
        ),
        const SizedBox(height: 6),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: textColor.withValues(
              alpha: AccountCardScope.secondaryOpacity,
            ),
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

/// 底部动作行：左侧对象级入口（可缺省），右侧「查看流水」。
class _AccountFooterRow extends StatelessWidget {
  const _AccountFooterRow({
    required this.ghost,
    required this.onGhostTap,
    required this.onViewFlows,
  });

  final ({String text, bool tappable})? ghost;
  final VoidCallback? onGhostTap;
  final VoidCallback onViewFlows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final inScope = AccountCardScope.maybeOf(context) != null;
    final ghost = this.ghost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          height: 1,
          thickness: 1,
          color: inScope
              ? AccountCardScope.textColorOf(
                  context,
                  fallback: colorScheme.onSurface,
                ).withValues(alpha: 0.22)
              : colorScheme.outlineVariant.withValues(alpha: 0.34),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: ghost == null
                    ? const SizedBox.shrink()
                    : InkWell(
                        onTap: ghost.tappable ? onGhostTap : null,
                        borderRadius: BorderRadius.circular(
                          theme.radiusTokens.sm,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            ghost.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: ghost.tappable
                                  ? AccountCardScope.textColorOf(
                                      context,
                                      fallback: colorScheme.primary,
                                    )
                                  : AccountCardScope.textColorOf(
                                      context,
                                      fallback: colorScheme.onSurfaceVariant,
                                    ).withValues(
                                      alpha: AccountCardScope.secondaryOpacity,
                                    ),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 8),
            _FlowActionButton(onPressed: onViewFlows),
          ],
        ),
      ],
    );
  }
}

/// 「查看流水」按钮。
///
/// 与点卡片打开同一个弹窗 —— 它是那条路径的显式入口，不是第二条路；
/// 所以点按钮和点卡片看到的数据必须完全一致（包括遮罩状态）。
///
/// 只留图标：卡底已经有「账单详情 ›」一行文字，再并一个「查看流水」文字
/// 按钮会把动作行挤满，账户名一长就要省略号。图标靠 tooltip 与语义标签
/// 说明用途，读屏仍能念出「查看流水」。
class _FlowActionButton extends StatelessWidget {
  const _FlowActionButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scope = AccountCardScope.maybeOf(context);
    final foreground = scope == null ? colorScheme.primary : scope.onColor;
    final background = scope == null
        ? colorScheme.primary.withValues(alpha: 0.10)
        : scope.onColor.withValues(alpha: 0.16);

    return Tooltip(
      message: '查看流水',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            width: 28,
            height: 24,
            child: Icon(
              Icons.receipt_long_rounded,
              size: 15,
              color: foreground,
              semanticLabel: '查看流水',
            ),
          ),
        ),
      ),
    );
  }
}

/// 账户名称 + 类型 / 币种。
class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.account});

  final MoneyAccountEntity account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInactive = !account.isActive;
    // 自定义背景上文字走卡片前景色；默认背景维持主题色。
    final titleColor = AccountCardScope.textColorOf(
      context,
      fallback: isInactive
          ? colorScheme.onSurfaceVariant
          : colorScheme.onSurface,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                account.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: titleColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            for (final chip in _chips) ...[
              const SizedBox(width: 6),
              _StatusChip(label: chip),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _metaText(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AccountCardScope.textColorOf(
              context,
              fallback: colorScheme.onSurfaceVariant,
            ).withValues(alpha: AccountCardScope.secondaryOpacity),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  /// 名称后的徽章只放「会变的状态」。
  ///
  /// 类型标签已经在第二行 `银行账户 · CNY` 里了，不该在名字后面再重复一遍；
  /// 用户自定义的说明（如「工资卡」）和停用 / 共享 / 虚拟这些状态才是
  /// 扫视时真正需要的区分信息。最多两枚，多了一行挤不下。
  List<String> get _chips {
    final description = account.description?.trim();
    return <String>[
      if (description != null && description.isNotEmpty) description,
      if (!account.isActive) '已停用',
      if (account.isShared) '共享',
      if (account.isVirtual) '虚拟',
    ].take(2).toList(growable: false);
  }

  String _metaText() {
    final parts = <String>[account.type.label, account.currencyCode];
    if (account.type.isCreditLike && account.hasBillingCycle) {
      parts.add('还款日 ${account.repaymentDay} 日');
    }
    return parts.join(' · ');
  }
}

/// 账户操作菜单。
///
/// 左滑手势保留为快捷方式，但点整行会打开账户弹窗 —— 如果编辑只藏在
/// 左滑里，第一次用的人根本找不到。
///
/// 「查看流水」从菜单里删掉了：它现在是卡底动作行的可见按钮，
/// 同一个动作放两处只会让人猜这两处是不是不一样。
class _AccountActionsMenu extends StatelessWidget {
  const _AccountActionsMenu({
    required this.account,
    required this.isAmountHidden,
    required this.onToggleAmountHidden,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
    this.onAdjustBalance,
  });

  final MoneyAccountEntity account;
  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  /// 余额校正（仅资产类账户）。
  final VoidCallback? onAdjustBalance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_AccountMenuAction>(
      tooltip: '更多操作',
      position: PopupMenuPosition.under,
      // 只有图标，菜单就该只有图标宽。Material 默认 minWidth 112，会把
      // 纯图标行撑成一条宽条。48 = 图标 20 + 左右 padding 14 + 14。
      constraints: const BoxConstraints(minWidth: 48, maxWidth: 48),
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.toggleAmount:
            onToggleAmountHidden();
          case _AccountMenuAction.edit:
            onEdit();
          case _AccountMenuAction.adjustBalance:
            onAdjustBalance?.call();
          case _AccountMenuAction.toggleActive:
            onToggleActive();
          case _AccountMenuAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        _menuItem(
          context,
          value: _AccountMenuAction.toggleAmount,
          icon: isAmountHidden
              ? Icons.visibility_rounded
              : Icons.visibility_off_rounded,
          label: isAmountHidden ? '显示金额' : '隐藏金额',
        ),
        _menuItem(
          context,
          value: _AccountMenuAction.edit,
          icon: Icons.edit_rounded,
          label: '编辑账户',
        ),
        if (onAdjustBalance != null)
          _menuItem(
            context,
            value: _AccountMenuAction.adjustBalance,
            icon: Icons.sync_alt_rounded,
            label: '余额校正',
          ),
        _menuItem(
          context,
          value: _AccountMenuAction.toggleActive,
          icon: account.isActive
              ? Icons.pause_circle_outline_rounded
              : Icons.play_circle_outline_rounded,
          label: account.isActive ? '停用账户' : '启用账户',
        ),
        _menuItem(
          context,
          value: _AccountMenuAction.delete,
          icon: Icons.delete_outline_rounded,
          label: '删除账户',
          color: theme.colorScheme.error,
        ),
      ],
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 自定义背景上边框/图标跟随卡片前景色，默认背景维持主题色。
          border: Border.all(
            color:
                AccountCardScope.textColorOf(
                  context,
                  fallback: theme.colorScheme.outlineVariant,
                ).withValues(
                  alpha: AccountCardScope.maybeOf(context) == null ? 0.7 : 0.4,
                ),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 17,
          color: AccountCardScope.textColorOf(
            context,
            fallback: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 菜单项：只留图标。
  ///
  /// 文字退到长按提示（`Tooltip`）与读屏语义（`semanticLabel`）里，
  /// 这样菜单更紧凑，又不会让屏幕阅读器变成一堆无名的图标按钮。
  PopupMenuItem<_AccountMenuAction> _menuItem(
    BuildContext context, {
    required _AccountMenuAction value,
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final theme = Theme.of(context);
    return PopupMenuItem<_AccountMenuAction>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Tooltip(
        message: label,
        child: Icon(
          icon,
          size: 20,
          semanticLabel: label,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

enum _AccountMenuAction {
  toggleAmount,
  edit,
  adjustBalance,
  toggleActive,
  delete,
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.account});

  final MoneyAccountEntity account;

  /// 图标槽位边长，整列账户卡共用，保证左侧竖线对齐。
  static const double _slot = 42;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = AccountCardScope.maybeOf(context);

    // 自定义图标是用户自己的品牌 logo（多为透明底位图 / SVG），本身就是
    // 一块完整图形：铺满槽位、不画底壳和描边。套上浅色圆角壳会把图形压到
    // 21 大小，看着又小又闷，和系统里其他 App 图标的观感也不一致。
    // 字形图标没有自带轮廓，仍然需要浅色底衬托。
    if (AccountIconView.usesCustomImage(account)) {
      return SizedBox(
        width: _slot,
        height: _slot,
        child: Center(
          child: AccountIconView(
            account: account,
            size: 21,
            imageSize: accountCardLogoSize,
          ),
        ),
      );
    }

    // 未显式设置颜色时用类型对应的品牌色，一列账户能靠颜色区分。
    final accentColor = account.color == null
        ? appColorFromHex(defaultAccountColorForType(account.type))
        : appColorFromHex(account.color);

    // 自定义背景（纯色/图片）上，彩色浅底图标会看不清：改成磨砂反色块，
    // 图标走卡片前景色。
    if (scope != null) {
      final isLight = theme.brightness == Brightness.light;
      final frosted = isLight ? Colors.white : Colors.black;
      return Container(
        width: _slot,
        height: _slot,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: frosted.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
          border: Border.all(color: scope.onColor.withValues(alpha: 0.28)),
        ),
        child: AccountIconView(
          account: account,
          size: 21,
          color: scope.onColor,
        ),
      );
    }

    return Container(
      width: _slot,
      height: _slot,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: AccountIconView(account: account, size: 21, color: accentColor),
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
