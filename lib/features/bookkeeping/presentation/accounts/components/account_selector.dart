import 'package:flutter/material.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_presentation_helpers.dart';

class AccountSelector extends StatelessWidget {
  const AccountSelector({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.onChanged,
    this.labelText = '账户',
    this.emptyText = '暂无可选账户',
    this.enabled = true,
    this.showQuickSelect = false,
    this.quickSelectCount = 2,
    this.allowClear = false,
    this.clearLabel = '不限账户',
    this.isAmountHidden = _defaultAmountVisibility,
    this.enableFilter = true,
  });

  final List<MoneyAccountEntity> accounts;
  final String? selectedAccountId;
  final ValueChanged<MoneyAccountEntity?> onChanged;
  final String labelText;
  final String emptyText;
  final bool enabled;
  final bool showQuickSelect;
  final int quickSelectCount;
  final bool allowClear;
  final String clearLabel;
  final bool Function(MoneyAccountEntity account) isAmountHidden;
  final bool enableFilter;

  @override
  Widget build(BuildContext context) {
    final selectedExists = accounts.any(
      (account) => account.id == selectedAccountId,
    );
    final quickAccounts = accounts
        .where((account) => account.isActive)
        .take(quickSelectCount)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showQuickSelect && quickAccounts.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final account in quickAccounts)
                ChoiceChip(
                  label: Text(account.name),
                  selected: selectedAccountId == account.id,
                  onSelected: !enabled
                      ? null
                      : (_) {
                          onChanged(account);
                        },
                ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        FormDropdown<String>(
          initialSelection: selectedExists
              ? selectedAccountId
              : allowClear
              ? ''
              : null,
          label: labelText,
          leadingIcon: const Icon(Icons.account_balance_wallet_rounded),
          enabled: enabled && (accounts.isNotEmpty || allowClear),
          enableFilter: enableFilter,
          onSelected: (accountId) {
            if (accountId == null || accountId.isEmpty) {
              onChanged(null);
              return;
            }
            MoneyAccountEntity? selectedAccount;
            for (final account in accounts) {
              if (account.id == accountId) {
                selectedAccount = account;
                break;
              }
            }
            onChanged(selectedAccount);
          },
          entries: [
            if (allowClear)
              DropdownMenuEntry(
                value: '',
                label: clearLabel,
                labelWidget: _ClearAccountSelectorItem(label: clearLabel),
              ),
            ...accounts.map(
              (account) => DropdownMenuEntry(
                value: account.id,
                label: account.name,
                labelWidget: _AccountSelectorItem(
                  account: account,
                  isAmountHidden: isAmountHidden(account),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

bool _defaultAmountVisibility(MoneyAccountEntity account) {
  return false;
}

class _AccountSelectorItem extends StatelessWidget {
  const _AccountSelectorItem({
    required this.account,
    required this.isAmountHidden,
  });

  final MoneyAccountEntity account;
  final bool isAmountHidden;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          accountIconDataForType(account.type),
          size: 20,
          color: account.isActive
              ? colorScheme.primary
              : colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${account.name} · ${account.type.label}',
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          isAmountHidden
              ? '***'
              : formatMoneyMinor(
                  account.displayBalanceMinor,
                  account.currencyCode,
                ),
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

class _ClearAccountSelectorItem extends StatelessWidget {
  const _ClearAccountSelectorItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          Icons.all_inclusive_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
          ),
        ),
      ],
    );
  }
}
