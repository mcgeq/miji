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
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_filter_sheet.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
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

  /// 按用户隔离的存储 key。
  ///
  /// 原实现只用 `account_hidden_ids` 这一个全局 key，多用户共用设备时
  /// 后登录的人会继承前一个人的隐藏设置（隐藏的是账户 id，跨用户没有意义），
  /// 这里加上 userId 后缀。
  static String _hiddenIdsPrefKeyFor(String userId) =>
      '${_hiddenIdsPrefKey}_$userId';

  /// 已加载过隐藏设置的 userId，避免重复读取覆盖内存状态。
  String? _hiddenIdsLoadedForUserId;

  @override
  void initState() {
    super.initState();
    _hiddenIdsLoadedForUserId = _currentUserId;
    unawaited(_loadHiddenIds(_hiddenIdsLoadedForUserId));
  }

  String? get _currentUserId =>
      ref.read(authSessionControllerProvider).userId;

  Future<void> _loadHiddenIds(String? userId) async {
    if (userId == null || userId.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_hiddenIdsPrefKeyFor(userId));
    if (!mounted || _hiddenIdsLoadedForUserId != userId) {
      return;
    }
    setState(() {
      _hiddenAccountIds.clear();
      if (raw != null && raw.isNotEmpty) {
        _hiddenAccountIds.addAll(raw.split(','));
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
  }

  /// 用户切换时重新载入对应账号的隐藏设置。
  void _syncHiddenIdsForUser(String? userId) {
    if (userId == _hiddenIdsLoadedForUserId) {
      return;
    }
    _hiddenIdsLoadedForUserId = userId;
    _hiddenAccountIds.clear();
    unawaited(_loadHiddenIds(userId));
  }

  @override
  Widget build(BuildContext context) {
    _syncHiddenIdsForUser(ref.watch(authSessionControllerProvider).userId);
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
          _NetWorthHero(allAmountsHidden: _areAllAmountsHidden),
          const SizedBox(height: 10),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              theme.colorScheme.primary,
              const Color(0xFF3E4A8C),
              0.72,
            )!,
            Color.lerp(
              theme.colorScheme.secondary,
              const Color(0xFF4F5FB0),
              0.35,
            )!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3E4A8C).withValues(alpha: 0.26),
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
                  color: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '净资产',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _HeroAmount(
                    amountMinor: worth.netAssetMinor,
                    currencyCode: worth.currencyCode,
                    hidden: hidden,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroTotal(
                          label: '总资产',
                          value: hidden
                              ? '••••'
                              : formatMoneyMinor(
                                  worth.assetMinor,
                                  worth.currencyCode,
                                ),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _HeroTotal(
                          label: '负债',
                          value: hidden
                              ? '••••'
                              : formatMoneyMinor(
                                  worth.liabilityMinor,
                                  worth.currencyCode,
                                ),
                          color: const Color(0xFFFFD9A0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 5,
                      child: Row(
                        children: [
                          Expanded(
                            flex: (worth.assetRatio * 1000)
                                .round()
                                .clamp(1, 1000),
                            child: ColoredBox(color: Colors.white),
                          ),
                          Expanded(
                            flex: ((1 - worth.assetRatio) * 1000)
                                .round()
                                .clamp(1, 1000),
                            child: ColoredBox(
                              color: const Color(0xFFFFD9A0),
                            ),
                          ),
                        ],
                      ),
                    ),
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

/// Hero 里的一行「标签 + 金额」，比带内边距的单元格省一半高度。
class _HeroTotal extends StatelessWidget {
  const _HeroTotal({
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
    return Row(
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
        Expanded(
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
      ],
    );
  }
}

class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.amountMinor,
    required this.currencyCode,
    required this.hidden,
  });

  final int amountMinor;
  final String currencyCode;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
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
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
      maxLines: 1,
    );
  }
}

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

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 32,
            child: groups.length <= 1
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: groups.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      return _GroupChip(
                        label: _title(group.kind),
                        count: group.accounts.length,
                        selected: group.kind == selectedKind,
                        onTap: () => onGroupChanged(group.kind),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<MoneyAccountSortField>(
          tooltip: '排序：${sortField.label}${sortAscending ? ' 升序' : ' 降序'}',
          position: PopupMenuPosition.under,
          onSelected: onSortFieldChanged,
          itemBuilder: (context) => [
            for (final field in MoneyAccountSortField.values)
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
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Text(field.label),
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
        const SizedBox(width: 6),
        AppIconActionButton(
          tooltip: allAmountsHidden ? '显示全部金额' : '隐藏全部金额',
          onPressed: onToggleAllAmountsHidden,
          icon: allAmountsHidden
              ? Icons.visibility_off_rounded
              : Icons.visibility_outlined,
          iconSize: 18,
          variant: AppIconActionVariant.plain,
        ),
        filterTrigger,
        AppIconActionButton(
          tooltip: '新建账户',
          onPressed: onCreate,
          icon: Icons.add_rounded,
          iconSize: 19,
          variant: AppIconActionVariant.plain,
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
      child: Icon(
        icon,
        size: 18,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _title(MoneyAccountDisplayGroupKind kind) {
    return switch (kind) {
      MoneyAccountDisplayGroupKind.assets => '资产',
      MoneyAccountDisplayGroupKind.creditAndDebt => '信用负债',
      MoneyAccountDisplayGroupKind.inactive => '停用',
    };
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
              const SizedBox(width: 5),
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

    final creditBill = account.type.isCreditLike
        ? ref
              .watch(currentUserCreditCardBillViewProvider(account.id))
              .maybeWhen(data: (value) => value, orElse: () => null)
        : null;
    final creditStatement = creditBill?.toStatement();
    final colorScheme = Theme.of(context).colorScheme;
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
        creditStatement: creditStatement,
        isAmountHidden: isAmountHidden,
        actionsMenu: _AccountActionsMenu(
          account: account,
          isAmountHidden: isAmountHidden,
          onToggleAmountHidden: onToggleAmountHidden,
          onViewTransactions: onViewTransactions,
          onEdit: onEdit,
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

/// 账户卡内容：主行（图标 + 名称 + ⋯）/ 余额行 / 额度条（仅信用）。
///
/// 原来是 8 层信息堆叠（名称、类型、账单日、3 个徽章、说明、本月对比长句、
/// 余额、额度明细），账户一多一屏只能看 2 张。这里压到 3 行，并把
/// 「本月收支」交给详情页，卡片只回答「这个账户现在有多少钱」。
class _AccountTileContent extends StatelessWidget {
  const _AccountTileContent({
    required this.account,
    required this.creditStatement,
    required this.isAmountHidden,
    required this.actionsMenu,
    required this.onViewStatement,
  });

  final MoneyAccountEntity account;
  final MoneyCreditCardStatement? creditStatement;
  final bool isAmountHidden;
  final Widget actionsMenu;
  final VoidCallback? onViewStatement;

  @override
  Widget build(BuildContext context) {
    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
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
          _AccountBalance(
            account: account,
            creditStatement: creditStatement,
            isAmountHidden: isAmountHidden,
            onViewStatement: onViewStatement,
          ),
          if (account.type.isCreditLike) ...[
            const SizedBox(height: 10),
            _CreditLimitBar(account: account, isAmountHidden: isAmountHidden),
          ],
          if (_dueHint(context, creditStatement) case final hint?) ...[
            const SizedBox(height: 9),
            hint,
          ],
        ],
      ),
    );
  }

  Widget? _dueHint(BuildContext context, MoneyCreditCardStatement? statement) {
    if (statement == null) {
      return null;
    }
    final isOverdue = statement.state == MoneyCreditCardStatementState.overdue;
    final isDueSoon = statement.state == MoneyCreditCardStatementState.dueSoon;
    if (!isOverdue && !isDueSoon) {
      return null;
    }
    final theme = Theme.of(context);
    final color = isOverdue ? theme.colorScheme.error : theme.moneyColors.warning;
    return Text(
      isOverdue
          ? '已逾期 · ${statement.repaymentDate.month}月${statement.repaymentDate.day}日应还'
          : '${statement.repaymentDate.month}月${statement.repaymentDate.day}日还款 · 还剩 ${_daysUntil(statement.repaymentDate)} 天',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
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
                  color: isInactive
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
            if (isInactive) ...[
              const SizedBox(width: 6),
              _StatusChip(label: '已停用'),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          _metaText(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }

  String _metaText() {
    final parts = <String>[account.type.label, account.currencyCode];
    if (account.type.isCreditLike && account.hasBillingCycle) {
      parts.add('还款日 ${account.repaymentDay} 日');
    }
    return parts.join(' · ');
  }
}

/// 余额行：左侧主金额，右侧补充信息（初始余额 / 本期应还）。
class _AccountBalance extends StatelessWidget {
  const _AccountBalance({
    required this.account,
    required this.creditStatement,
    required this.isAmountHidden,
    required this.onViewStatement,
  });

  final MoneyAccountEntity account;
  final MoneyCreditCardStatement? creditStatement;
  final bool isAmountHidden;
  final VoidCallback? onViewStatement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isInactive = !account.isActive;
    final isCredit = account.type.isCreditLike;
    final primaryAmount = isCredit
        ? account.availableCreditMinor
        : account.balanceMinor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isCredit ? '可用额度' : '当前余额',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              MoneyAmountText(
                amountMinor: primaryAmount,
                currencyCode: account.currencyCode,
                hidden: isAmountHidden,
                tone: isCredit
                    ? MoneyAmountTone.credit
                    : MoneyAmountTone.neutral,
                color: isInactive ? colorScheme.onSurfaceVariant : null,
                textStyle: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        if (isCredit) _statementSide(context) else _initialSide(context),
      ],
    );
  }

  Widget _initialSide(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      isAmountHidden
          ? '初始 ***'
          : '初始 ${formatMoneyMinor(account.initialBalanceMinor, account.currencyCode)}',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }

  Widget _statementSide(BuildContext context) {
    final theme = Theme.of(context);
    final statement = creditStatement;
    if (statement == null) {
      return Text(
        isAmountHidden
            ? '已用 ***'
            : '已用 ${formatMoneyMinor(account.effectivePostedDebtMinor, account.currencyCode)}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      );
    }

    final color = switch (statement.state) {
      MoneyCreditCardStatementState.overdue => theme.colorScheme.error,
      MoneyCreditCardStatementState.dueSoon => theme.moneyColors.warning,
      _ => theme.colorScheme.onSurface,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '本期应还',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 2),
        MoneyAmountText(
          amountMinor: statement.amountDueMinor,
          currencyCode: statement.currencyCode,
          hidden: isAmountHidden,
          color: color,
          textStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        if (onViewStatement != null)
          GestureDetector(
            onTap: onViewStatement,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '账单 ›',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 信用额度使用进度条。原来「额度 / 已入账 / 冻结」挤在一行 11px 小字里，
/// 用户算不出用了多少。
class _CreditLimitBar extends StatelessWidget {
  const _CreditLimitBar({required this.account, required this.isAmountHidden});

  final MoneyAccountEntity account;
  final bool isAmountHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = account.effectiveCreditLimitMinor;
    final used = account.usedCreditMinor;
    final ratio = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);

    final color = ratio >= 0.9
        ? theme.colorScheme.error
        : ratio >= 0.8
        ? theme.moneyColors.warning
        : theme.moneyColors.credit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(
                isAmountHidden
                    ? '已用 *** / 额度 ***'
                    : '已用 ${formatMoneyMinor(used, account.currencyCode)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              isAmountHidden
                  ? '***'
                  : '额度 ${formatMoneyMinor(limit, account.currencyCode)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 账户操作菜单。
///
/// 左滑手势保留为快捷方式，但点整行是「看流水」，如果编辑只藏在左滑里，
/// 第一次用的人根本找不到。
class _AccountActionsMenu extends StatelessWidget {
  const _AccountActionsMenu({
    required this.account,
    required this.isAmountHidden,
    required this.onToggleAmountHidden,
    required this.onViewTransactions,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final MoneyAccountEntity account;
  final bool isAmountHidden;
  final VoidCallback onToggleAmountHidden;
  final VoidCallback? onViewTransactions;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_AccountMenuAction>(
      tooltip: '更多操作',
      position: PopupMenuPosition.under,
      onSelected: (action) {
        switch (action) {
          case _AccountMenuAction.toggleAmount:
            onToggleAmountHidden();
          case _AccountMenuAction.viewTransactions:
            onViewTransactions?.call();
          case _AccountMenuAction.edit:
            onEdit();
          case _AccountMenuAction.toggleActive:
            onToggleActive();
          case _AccountMenuAction.delete:
            onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _AccountMenuAction.toggleAmount,
          child: _menuRow(
            context,
            isAmountHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            isAmountHidden ? '显示金额' : '隐藏金额',
          ),
        ),
        if (onViewTransactions != null)
          PopupMenuItem(
            value: _AccountMenuAction.viewTransactions,
            child: _menuRow(context, Icons.receipt_long_rounded, '查看流水'),
          ),
        PopupMenuItem(
          value: _AccountMenuAction.edit,
          child: _menuRow(context, Icons.edit_rounded, '编辑账户'),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.toggleActive,
          child: _menuRow(
            context,
            account.isActive
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded,
            account.isActive ? '停用账户' : '启用账户',
          ),
        ),
        PopupMenuItem(
          value: _AccountMenuAction.delete,
          child: _menuRow(
            context,
            Icons.delete_outline_rounded,
            '删除账户',
            color: theme.colorScheme.error,
          ),
        ),
      ],
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          Icons.more_horiz_rounded,
          size: 17,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _menuRow(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: color ?? theme.colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

enum _AccountMenuAction {
  toggleAmount,
  viewTransactions,
  edit,
  toggleActive,
  delete,
}

class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.account});

  final MoneyAccountEntity account;

  @override
  Widget build(BuildContext context) {

    // 未显式设置颜色时用类型对应的品牌色，一列账户能靠颜色区分。
    final accentColor = account.color == null
        ? appColorFromHex(defaultAccountColorForType(account.type))
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
