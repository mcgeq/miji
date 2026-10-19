import 'package:flutter/material.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_icon_catalog.dart';

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
                labelWidget: AccountOptionContent(
                  account: account,
                  // 全局「隐藏金额」优先于逐账户设置。
                  masked: MoneyPrivacy.of(context) || isAmountHidden(account),
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

/// 账户选择列表里的一行：图标 + 「名称 · 类型」+ 余额。
///
/// 老表单的账户下拉与分类记账（dock）的账户选择面板共用它——余额格式与
/// 「隐藏金额」口径必须一致，各写一遍必然漂移。
///
/// [masked] **由调用方传入**，而不是在这里读 `MoneyPrivacy.of(context)`：
/// 这个组件也会被放进 `showModalBottomSheet`，而弹窗挂在根 Navigator 上，
/// 祖先链里没有 `AppShellPage` 的 `MoneyPrivacyScope`——就地读只会拿到
/// `false`，把余额原样照出来。调用方（在页面树里）先读好再传进来。
class AccountOptionContent extends StatelessWidget {
  const AccountOptionContent({
    super.key,
    required this.account,
    this.masked = false,
  });

  final MoneyAccountEntity account;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        AccountIconView(
          account: account,
          size: 20,
          // 品牌 logo 自带轮廓，给到 22 才和 20 的字形视觉分量相当。
          imageSize: 22,
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
          maskedMoneyOr(
            formatMoneyMinor(account.displayBalanceMinor, account.currencyCode),
            masked,
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
