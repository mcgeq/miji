import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_confirm_dialog.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class CurrentLedgerSelector extends ConsumerStatefulWidget {
  const CurrentLedgerSelector({super.key}) : compact = false;

  const CurrentLedgerSelector.compact({super.key}) : compact = true;

  final bool compact;

  static const _createFamilyLedgerValue = '__create_family_ledger__';

  @override
  ConsumerState<CurrentLedgerSelector> createState() =>
      _CurrentLedgerSelectorState();
}

class _CurrentLedgerSelectorState extends ConsumerState<CurrentLedgerSelector> {
  int _resetSerial = 0;

  @override
  Widget build(BuildContext context) {
    final ledgers = ref.watch(currentUserMoneyLedgersProvider);
    final selectedLedgerId = ref.watch(currentMoneyLedgerIdProvider);

    return ledgers.when(
      data: (items) {
        final selected = _resolveSelectedLedger(items, selectedLedgerId);
        if (items.isEmpty) {
          return const LinearProgressIndicator();
        }
        if (widget.compact) {
          return _buildCompactSelector(context, items, selected);
        }

        return Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 356),
            child: Row(
              children: [
                Expanded(
                  child: FormDropdown<String>(
                    key: ValueKey('${selected?.id ?? ''}-$_resetSerial'),
                    initialSelection: selected?.id,
                    label: '账本',
                    leadingIcon: const Icon(Icons.menu_book_rounded),
                    width: double.infinity,
                    enableFilter: true,
                    entries: [
                      for (final ledger in items)
                        DropdownMenuEntry<String>(
                          value: ledger.id,
                          label: ledger.name,
                          labelWidget: _LedgerMenuItem(ledger: ledger),
                        ),
                      const DropdownMenuEntry<String>(
                        value: CurrentLedgerSelector._createFamilyLedgerValue,
                        label: '新增家庭账本',
                        labelWidget: _CreateLedgerMenuItem(),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == null) {
                        return;
                      }
                      if (value ==
                          CurrentLedgerSelector._createFamilyLedgerValue) {
                        await _showCreateLedgerDialog(context);
                        if (mounted) {
                          setState(() => _resetSerial++);
                        }
                        return;
                      }
                      ref
                          .read(currentMoneyLedgerIdProvider.notifier)
                          .set(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _LedgerMembersButton(ledger: selected),
                if (selected?.isFamily == true) ...[
                  const SizedBox(width: 8),
                  _LedgerAccountsButton(ledger: selected),
                ],
              ],
            ),
          ),
        );
      },
      loading: () =>
          const SizedBox(width: 180, child: LinearProgressIndicator()),
      error: (error, stackTrace) => Text(
        '账本读取失败',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  Widget _buildCompactSelector(
    BuildContext context,
    List<MoneyLedgerEntity> items,
    MoneyLedgerEntity? selected,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = selected?.isPersonal == true
        ? Icons.person_outline_rounded
        : Icons.groups_2_outlined;

    return Tooltip(
      message: '切换账本',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => _showCompactLedgerSheet(context, items, selected),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: colorScheme.primary),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: Text(
                    selected?.name ?? '账本',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCompactLedgerSheet(
    BuildContext context,
    List<MoneyLedgerEntity> items,
    MoneyLedgerEntity? selected,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _CompactLedgerSwitcherSheet(
        ledgers: items,
        selectedLedger: selected,
        onSelectLedger: (ledger) {
          Navigator.of(sheetContext).pop();
          ref.read(currentMoneyLedgerIdProvider.notifier).set(ledger.id);
        },
        onCreateLedger: () {
          Navigator.of(sheetContext).pop();
          unawaited(
            _showCreateLedgerDialog(context).then((_) {
              if (mounted) {
                setState(() => _resetSerial++);
              }
            }),
          );
        },
        onManageMembers: selected?.isFamily != true
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(_showLedgerMembersDialog(context, selected!));
              },
        onManageAccounts: selected?.isFamily != true
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                unawaited(_showLedgerAccountsDialog(context, selected!));
              },
      ),
    );
  }

  Future<void> _showCreateLedgerDialog(BuildContext context) async {
    await showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const _CreateLedgerDialog(),
    );
  }

  Future<void> _showLedgerMembersDialog(
    BuildContext context,
    MoneyLedgerEntity ledger,
  ) {
    return showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _LedgerMembersDialog(ledger: ledger),
    );
  }

  Future<void> _showLedgerAccountsDialog(
    BuildContext context,
    MoneyLedgerEntity ledger,
  ) {
    return showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _LedgerAccountsDialog(ledger: ledger),
    );
  }

  MoneyLedgerEntity? _resolveSelectedLedger(
    List<MoneyLedgerEntity> ledgers,
    String? selectedLedgerId,
  ) {
    if (ledgers.isEmpty) {
      return null;
    }
    if (selectedLedgerId != null) {
      for (final ledger in ledgers) {
        if (ledger.id == selectedLedgerId) {
          return ledger;
        }
      }
    }
    for (final ledger in ledgers) {
      if (ledger.isPersonal) {
        return ledger;
      }
    }
    return ledgers.first;
  }
}

class _CompactLedgerSwitcherSheet extends StatelessWidget {
  const _CompactLedgerSwitcherSheet({
    required this.ledgers,
    required this.selectedLedger,
    required this.onSelectLedger,
    required this.onCreateLedger,
    required this.onManageMembers,
    required this.onManageAccounts,
  });

  final List<MoneyLedgerEntity> ledgers;
  final MoneyLedgerEntity? selectedLedger;
  final ValueChanged<MoneyLedgerEntity> onSelectLedger;
  final VoidCallback onCreateLedger;
  final VoidCallback? onManageMembers;
  final VoidCallback? onManageAccounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selected = selectedLedger;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Material(
        color: colorScheme.surface,
        elevation: 18,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _CurrentLedgerSummaryCard(ledger: selected),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: ledgers.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final ledger = ledgers[index];
                      return _CompactLedgerTile(
                        ledger: ledger,
                        selected: ledger.id == selected?.id,
                        onTap: () => onSelectLedger(ledger),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _LedgerSheetActionButton(
                      tooltip: onManageMembers == null ? '账本成员不可用' : '账本成员',
                      icon: Icons.group_outlined,
                      label: '成员',
                      onPressed: onManageMembers,
                    ),
                    if (selected?.isFamily == true)
                      _LedgerSheetActionButton(
                        tooltip: onManageAccounts == null ? '账本账户不可用' : '账本账户',
                        icon: Icons.account_balance_wallet_outlined,
                        label: '账户',
                        onPressed: onManageAccounts,
                      ),
                    _LedgerSheetActionButton(
                      tooltip: '新增家庭账本',
                      icon: Icons.add_home_work_outlined,
                      label: '新增',
                      onPressed: onCreateLedger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentLedgerSummaryCard extends StatelessWidget {
  const _CurrentLedgerSummaryCard({required this.ledger});

  final MoneyLedgerEntity? ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFamily = ledger?.isFamily == true;

    return Material(
      color: colorScheme.primaryContainer.withValues(alpha: 0.54),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              child: Icon(
                isFamily ? Icons.groups_2_rounded : Icons.person_rounded,
                size: 21,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ledger?.name ?? '账本',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isFamily ? '家庭账本' : '个人账本',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.76,
                      ),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
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

class _CompactLedgerTile extends StatelessWidget {
  const _CompactLedgerTile({
    required this.ledger,
    required this.selected,
    required this.onTap,
  });

  final MoneyLedgerEntity ledger;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isFamily = ledger.isFamily;

    return Material(
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                isFamily ? Icons.groups_2_outlined : Icons.person_outline,
                color: selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ledger.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected
                        ? colorScheme.onSecondaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isFamily ? '家庭' : '个人',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected
                      ? colorScheme.onSecondaryContainer.withValues(alpha: 0.76)
                      : colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle_rounded,
                  color: colorScheme.onSecondaryContainer,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LedgerSheetActionButton extends StatelessWidget {
  const _LedgerSheetActionButton({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          backgroundColor: colorScheme.surfaceContainerHighest,
          foregroundColor: colorScheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

class _LedgerAccountsButton extends ConsumerWidget {
  const _LedgerAccountsButton({required this.ledger});

  final MoneyLedgerEntity? ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ledger?.id;
    final accountCount = ledgerId == null
        ? 0
        : ref
              .watch(currentUserMoneyLedgerAccountsProvider(ledgerId))
              .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final enabled = ledgerId != null && ledger?.isFamily == true;

    return AppIconActionButton(
      tooltip: enabled ? '账本账户' : '账本账户不可用',
      variant: AppIconActionVariant.outlined,
      onPressed: !enabled
          ? null
          : () => showAppResponsiveDialog<void>(
              context: context,
              expandCompactSheet: true,
              builder: (context) => _LedgerAccountsDialog(ledger: ledger!),
            ),
      child: Badge.count(
        count: accountCount,
        isLabelVisible: accountCount > 0,
        child: const Icon(Icons.account_balance_wallet_outlined),
      ),
    );
  }
}

class _LedgerAccountsDialog extends ConsumerStatefulWidget {
  const _LedgerAccountsDialog({required this.ledger});

  final MoneyLedgerEntity ledger;

  @override
  ConsumerState<_LedgerAccountsDialog> createState() =>
      _LedgerAccountsDialogState();
}

class _LedgerAccountsDialogState extends ConsumerState<_LedgerAccountsDialog> {
  String? _updatingAccountId;
  String? _errorText;

  @override
  Widget build(BuildContext context) {
    final allAccounts = ref.watch(currentUserVisibleAccountsProvider);
    final linkedAccounts = ref.watch(
      currentUserMoneyLedgerAccountsProvider(widget.ledger.id),
    );

    return AppDialogScaffold(
      title: '账本账户',
      subtitle: widget.ledger.name,
      maxWidth: 440,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: allAccounts.when(
        data: (accounts) => linkedAccounts.when(
          data: (linked) => _buildAccountList(accounts, linked),
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) => const Text('账本账户读取失败'),
        ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('账户读取失败'),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
        confirmTooltip: '完成',
      ),
    );
  }

  Widget _buildAccountList(
    List<MoneyAccountEntity> accounts,
    List<MoneyAccountEntity> linkedAccounts,
  ) {
    if (accounts.isEmpty) {
      return const AppEmptyState(title: '暂无账户');
    }

    final linkedIds = linkedAccounts.map((account) => account.id).toSet();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final account in accounts)
          _LedgerAccountTile(
            account: account,
            selected: linkedIds.contains(account.id),
            isUpdating: _updatingAccountId == account.id,
            onChanged: _updatingAccountId == null
                ? (selected) => _toggleAccount(account, selected)
                : null,
          ),
        if (_errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorText!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _toggleAccount(MoneyAccountEntity account, bool selected) async {
    setState(() {
      _updatingAccountId = account.id;
      _errorText = null;
    });
    try {
      final actions = ref.read(currentUserMoneyLedgerActionsProvider);
      if (selected) {
        await actions.addAccountToLedger(
          ledgerId: widget.ledger.id,
          accountId: account.id,
        );
      } else {
        await actions.removeAccountFromLedger(
          ledgerId: widget.ledger.id,
          accountId: account.id,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '账本账户更新失败');
    } finally {
      if (mounted) {
        setState(() => _updatingAccountId = null);
      }
    }
  }
}

class _LedgerAccountTile extends StatelessWidget {
  const _LedgerAccountTile({
    required this.account,
    required this.selected,
    required this.isUpdating,
    required this.onChanged,
  });

  final MoneyAccountEntity account;
  final bool selected;
  final bool isUpdating;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: selected
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            foregroundColor: selected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            child: Icon(_accountIcon(account.type), size: 20),
          ),
          title: Text(
            account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            '${account.type.label} · ${account.currencyCode}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          trailing: isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch.adaptive(value: selected, onChanged: onChanged),
        ),
      ),
    );
  }

  IconData _accountIcon(MoneyAccountType type) {
    return switch (type) {
      MoneyAccountType.cash => Icons.payments_outlined,
      MoneyAccountType.bank ||
      MoneyAccountType.saving => Icons.account_balance_outlined,
      MoneyAccountType.creditCard ||
      MoneyAccountType.huabei ||
      MoneyAccountType.baitiao ||
      MoneyAccountType.meituanCredit ||
      MoneyAccountType.otherCredit => Icons.credit_card_outlined,
      MoneyAccountType.alipay ||
      MoneyAccountType.wechat ||
      MoneyAccountType.cloudQuickPass => Icons.wallet_outlined,
      MoneyAccountType.investment => Icons.trending_up_rounded,
      MoneyAccountType.loan => Icons.request_quote_outlined,
      MoneyAccountType.prepaidCard => Icons.card_giftcard_outlined,
      MoneyAccountType.internal => Icons.sync_alt_rounded,
      MoneyAccountType.other => Icons.account_balance_wallet_outlined,
    };
  }
}

class _LedgerMembersButton extends ConsumerWidget {
  const _LedgerMembersButton({required this.ledger});

  final MoneyLedgerEntity? ledger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerId = ledger?.id;
    final memberCount = ledgerId == null
        ? 0
        : ref
              .watch(currentUserMoneyLedgerMembersProvider(ledgerId))
              .maybeWhen(data: (value) => value.length, orElse: () => 0);
    final enabled = ledgerId != null;

    return AppIconActionButton(
      tooltip: enabled ? '账本成员' : '账本不可用',
      variant: AppIconActionVariant.outlined,
      onPressed: !enabled
          ? null
          : () => showAppResponsiveDialog<void>(
              context: context,
              expandCompactSheet: true,
              builder: (context) => _LedgerMembersDialog(ledger: ledger!),
            ),
      child: Badge.count(
        count: memberCount,
        isLabelVisible: memberCount > 0,
        child: const Icon(Icons.group_outlined),
      ),
    );
  }
}

class _LedgerMembersDialog extends ConsumerStatefulWidget {
  const _LedgerMembersDialog({required this.ledger});

  final MoneyLedgerEntity ledger;

  @override
  ConsumerState<_LedgerMembersDialog> createState() =>
      _LedgerMembersDialogState();
}

class _LedgerMembersDialogState extends ConsumerState<_LedgerMembersDialog> {
  String? _errorText;
  bool _isAdding = false;
  String? _updatingMemberId;
  String? _deletingMemberId;

  @override
  Widget build(BuildContext context) {
    final canAddMembers = widget.ledger.isFamily;
    final members = ref.watch(
      currentUserMoneyLedgerMembersProvider(widget.ledger.id),
    );

    return AppDialogScaffold(
      title: '账本成员',
      subtitle: widget.ledger.name,
      maxWidth: 420,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: members.when(
        data: (items) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (items.isEmpty)
              Text(
                '暂无成员',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              )
            else
              ...items.map(
                (member) => _LedgerMemberTile(
                  member: member,
                  isUpdating: _updatingMemberId == member.id,
                  isDeleting: _deletingMemberId == member.id,
                  onEdit: member.role == 'owner'
                      ? null
                      : () => _showEditMemberDialog(member),
                  onDelete: member.role == 'owner'
                      ? null
                      : () => _showDeleteMemberDialog(member),
                ),
              ),
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (canAddMembers)
              Align(
                alignment: Alignment.center,
                child: AppIconActionButton(
                  tooltip: _isAdding ? '正在添加' : '添加成员',
                  onPressed: _isAdding ? null : () => _showAddMemberDialog(),
                  variant: AppIconActionVariant.filledTonal,
                  child: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_add_alt_1_rounded),
                ),
              )
            else
              Text(
                '个人账本不支持添加成员',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
          ],
        ),
        loading: () => const LinearProgressIndicator(),
        error: (error, stackTrace) => const Text('成员读取失败'),
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: () => Navigator.of(context).pop(),
        confirmTooltip: '完成',
      ),
    );
  }

  Future<void> _showAddMemberDialog() async {
    if (!widget.ledger.isFamily) {
      setState(() => _errorText = '个人账本不支持添加成员');
      return;
    }
    final draft = await showAppResponsiveDialog<MoneyMemberDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => const _AddLedgerMemberDialog(),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _isAdding = true;
      _errorText = null;
    });
    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .createMember(draft, ledgerId: widget.ledger.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '成员添加失败');
    } finally {
      if (mounted) {
        setState(() => _isAdding = false);
      }
    }
  }

  Future<void> _showDeleteMemberDialog(MoneyMemberEntity member) async {
    if (!widget.ledger.isFamily || member.role == 'owner') {
      setState(() => _errorText = '此成员不支持删除');
      return;
    }

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '删除成员',
      message: '确定删除“${member.name}”吗？删除后该成员在本账本中将不可用。',
      confirmLabel: '删除',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) {
      return;
    }

    setState(() {
      _deletingMemberId = member.id;
      _errorText = null;
    });
    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .deleteMember(memberId: member.id, ledgerId: widget.ledger.id);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '成员删除失败');
    } finally {
      if (mounted) {
        setState(() => _deletingMemberId = null);
      }
    }
  }

  Future<void> _showEditMemberDialog(MoneyMemberEntity member) async {
    if (!widget.ledger.isFamily || member.role == 'owner') {
      setState(() => _errorText = '此成员不支持编辑');
      return;
    }
    final draft = await showAppResponsiveDialog<MoneyMemberDraft>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => _AddLedgerMemberDialog(member: member),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      _updatingMemberId = member.id;
      _errorText = null;
    });
    try {
      await ref
          .read(currentUserMoneySplitActionsProvider)
          .updateMember(
            MoneyMemberUpdate(
              id: member.id,
              name: draft.name,
              role: draft.role,
              color: draft.color,
            ),
            ledgerId: widget.ledger.id,
          );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _errorText = '成员编辑失败');
    } finally {
      if (mounted) {
        setState(() => _updatingMemberId = null);
      }
    }
  }
}

class _LedgerMemberTile extends StatelessWidget {
  const _LedgerMemberTile({
    required this.member,
    this.isUpdating = false,
    this.isDeleting = false,
    this.onEdit,
    this.onDelete,
  });

  final MoneyMemberEntity member;
  final bool isUpdating;
  final bool isDeleting;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasActions = onDelete != null || onEdit != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text(member.name.characters.first.toUpperCase()),
          ),
          title: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          subtitle: Text(
            _memberRoleLabel(member.role),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          trailing: !hasActions
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onDelete != null) ...[
                      AppIconActionButton(
                        tooltip: isDeleting ? '正在删除' : '删除成员',
                        variant: AppIconActionVariant.outlined,
                        onPressed: isDeleting ? null : onDelete,
                        child: isDeleting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_outline_rounded),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (onEdit != null)
                      AppIconActionButton(
                        tooltip: isUpdating ? '正在保存' : '编辑成员',
                        onPressed: isUpdating ? null : onEdit,
                        child: isUpdating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.edit_rounded),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  String _memberRoleLabel(String role) {
    return switch (role.trim().toLowerCase()) {
      'owner' => '拥有者',
      'admin' || 'manager' => '管理员',
      _ => '成员',
    };
  }
}

class _AddLedgerMemberDialog extends StatefulWidget {
  const _AddLedgerMemberDialog({this.member});

  final MoneyMemberEntity? member;

  @override
  State<_AddLedgerMemberDialog> createState() => _AddLedgerMemberDialogState();
}

class _AddLedgerMemberDialogState extends State<_AddLedgerMemberDialog> {
  final _nameController = TextEditingController();
  String _role = 'participant';
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final member = widget.member;
    if (member != null) {
      _nameController.text = member.name;
      _role = member.role == 'manager' || member.role == 'admin'
          ? 'manager'
          : 'participant';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.member != null;
    return AppDialogScaffold(
      title: isEditing ? '编辑成员' : '添加成员',
      maxWidth: 320,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: AppFormColumn(
        children: [
          AppTextField(
            controller: _nameController,
            autofocus: true,
            labelText: '成员名称',
            prefixIcon: const Icon(Icons.person_outline_rounded),
            errorText: _errorText,
            onSubmitted: (_) => _submit(),
          ),
          FormDropdown<String>(
            initialSelection: _role,
            label: '角色',
            leadingIcon: const Icon(Icons.admin_panel_settings_outlined),
            width: double.infinity,
            entries: const [
              DropdownMenuEntry(value: 'participant', label: '成员'),
              DropdownMenuEntry(value: 'manager', label: '管理员'),
            ],
            onSelected: (value) {
              if (value == null) return;
              setState(() => _role = value);
            },
          ),
        ],
      ),
      actions: appDialogIconActions(
        onCancel: () => Navigator.of(context).pop(),
        onConfirm: _submit,
        confirmTooltip: isEditing ? '保存' : '添加',
        confirmIcon: isEditing ? Icons.check_rounded : Icons.add_rounded,
      ),
    );
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入成员名称');
      return;
    }
    Navigator.of(context).pop(MoneyMemberDraft(name: name, role: _role));
  }
}

class _LedgerMenuItem extends StatelessWidget {
  const _LedgerMenuItem({required this.ledger});

  final MoneyLedgerEntity ledger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = ledger.isPersonal
        ? Icons.person_outline_rounded
        : Icons.groups_2_outlined;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            ledger.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          ledger.isPersonal ? '个人' : '家庭',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _CreateLedgerMenuItem extends StatelessWidget {
  const _CreateLedgerMenuItem();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.add_home_work_outlined,
          size: 20,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '新增家庭账本',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _CreateLedgerDialog extends ConsumerStatefulWidget {
  const _CreateLedgerDialog();

  @override
  ConsumerState<_CreateLedgerDialog> createState() =>
      _CreateLedgerDialogState();
}

class _CreateLedgerDialogState extends ConsumerState<_CreateLedgerDialog> {
  final _nameController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogScaffold(
      title: '新增家庭账本',
      maxWidth: 360,
      titleTextAlign: TextAlign.center,
      actionsAlignment: WrapAlignment.center,
      body: AppTextField(
        controller: _nameController,
        autofocus: true,
        labelText: '账本名称',
        hintText: '例如：家庭账本',
        prefixIcon: const Icon(Icons.groups_2_outlined),
        errorText: _errorText,
        enabled: !_isSubmitting,
        onSubmitted: (_) => _submit(),
      ),
      actions: appDialogIconActions(
        onCancel: _isSubmitting ? () {} : () => Navigator.of(context).pop(),
        onConfirm: _isSubmitting ? null : _submit,
        confirmTooltip: '创建',
        confirmIcon: Icons.add_rounded,
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = '请输入账本名称');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });
    try {
      await ref
          .read(currentUserMoneyLedgerActionsProvider)
          .createLedger(MoneyLedgerDraft(name: name));
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _errorText = '账本创建失败';
      });
    }
  }
}
