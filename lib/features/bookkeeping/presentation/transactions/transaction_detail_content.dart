import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

class TransactionDetailContent extends ConsumerWidget {
  const TransactionDetailContent({
    super.key,
    required this.transaction,
    required this.accounts,
    required this.expenseCatalog,
    required this.incomeCatalog,
    this.onEdit,
    this.onDelete,
    this.onRefund,
    this.onAddSplit,
    this.onAddToFamilyLedger,
    this.onRemoveFromFamilyLedger,
    this.onEditSplit,
    this.onCancelSplit,
  });

  final MoneyTransactionEntity transaction;
  final List<MoneyAccountEntity> accounts;
  final MoneyCategoryCatalog expenseCatalog;
  final MoneyCategoryCatalog incomeCatalog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRefund;
  final VoidCallback? onAddSplit;
  final VoidCallback? onAddToFamilyLedger;
  final ValueChanged<MoneyLedgerEntity>? onRemoveFromFamilyLedger;
  final ValueChanged<MoneySplitRecordEntity>? onEditSplit;
  final ValueChanged<MoneySplitRecordEntity>? onCancelSplit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final amountColor = _amountColor(theme);
    final splitRecords = ref.watch(
      currentUserSplitRecordsForTransactionProvider(transaction.id),
    );
    final ledgerMemberships = ref.watch(
      currentUserTransactionLedgersProvider(transaction.id),
    );
    final isReadOnly = transaction.isInstallmentPosting;
    final familyLedgerCount = ledgerMemberships.maybeWhen(
      data: (items) => items.where((ledger) => ledger.isFamily).length,
      orElse: () => 0,
    );
    final canAddSplit =
        !isReadOnly &&
        familyLedgerCount > 0 &&
        _canAddSplit &&
        splitRecords.maybeWhen(
          data: (records) => records.isEmpty,
          orElse: () => false,
        );

    final hasMemoInfo =
        _hasText(transaction.notes) ||
        _hasText(transaction.merchant) ||
        _hasText(transaction.location) ||
        transaction.tags.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TransactionDetailSummary(
          icon: _icon,
          title: _title,
          typeLabel: _typeLabel,
          statusLabel: _statusLabel,
          dateTimeText: _dateTimeText(transaction.transactionAt),
          amountText:
              '$_amountPrefix${formatMoneyMinor(_displayAmountMinor, transaction.currencyCode)}',
          amountColor: amountColor,
          onEdit: isReadOnly ? null : onEdit,
          onDelete: isReadOnly ? null : onDelete,
          onRefund:
              isReadOnly ||
                  transaction.type != MoneyTransactionType.expense ||
                  transaction.status != MoneyTransactionStatus.completed ||
                  transaction.amountMinor <= transaction.refundAmountMinor
              ? null
              : onRefund,
          onAddSplit: canAddSplit ? onAddSplit : null,
          onAddToFamilyLedger: !isReadOnly && _canManageLedgerMembership
              ? onAddToFamilyLedger
              : null,
        ),
        const SizedBox(height: 10),
        _DetailInfoGrid(
          title: '核心信息',
          items: [
            _DetailInfoItem(
              icon: Icons.account_balance_wallet_outlined,
              label: '账户',
              value: _accountName(transaction.accountId),
            ),
            if (transaction.toAccountId != null)
              _DetailInfoItem(
                icon: Icons.swap_horiz_rounded,
                label: transaction.type == MoneyTransactionType.transfer
                    ? '对方账户'
                    : '目标账户',
                value: _accountName(transaction.toAccountId!),
              ),
            _DetailInfoItem(
              icon: Icons.category_outlined,
              label: '分类',
              value: _categoryText,
            ),
            _DetailInfoItem(
              icon: Icons.payments_outlined,
              label: '支付方式',
              value: _paymentMethodText,
            ),
            _DetailInfoItem(
              icon: Icons.currency_exchange_rounded,
              label: '币种',
              value: transaction.currencyCode,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LedgerMembershipSection(
          ledgers: ledgerMemberships,
          onRemoveFromFamilyLedger: isReadOnly
              ? null
              : onRemoveFromFamilyLedger,
        ),
        if (hasMemoInfo) ...[
          const SizedBox(height: 10),
          _DetailSection(
            icon: Icons.notes_rounded,
            title: '备注',
            children: [
              if (_hasText(transaction.notes))
                _DetailLine(label: '备注', value: transaction.notes!.trim()),
              if (_hasText(transaction.merchant))
                _DetailLine(label: '商家', value: transaction.merchant!.trim()),
              if (_hasText(transaction.location))
                _DetailLine(label: '地点', value: transaction.location!.trim()),
              if (transaction.tags.isNotEmpty)
                _DetailLine(label: '标签', value: transaction.tags.join('、')),
            ],
          ),
        ],
        if (_hasRelationInfo) ...[
          const SizedBox(height: 10),
          _DetailSection(
            icon: Icons.link_rounded,
            title: '关联信息',
            children: [
              if (_hasText(transaction.relatedTransactionId))
                _DetailLine(
                  label: '关联流水',
                  value: transaction.relatedTransactionId!,
                ),
              if (_hasText(transaction.installmentPlanId))
                _DetailLine(
                  label: '分期计划',
                  value: transaction.installmentPlanId!,
                ),
              if (transaction.refundAmountMinor > 0)
                _DetailLine(
                  label: '原金额',
                  value: formatMoneyMinor(
                    transaction.amountMinor,
                    transaction.currencyCode,
                  ),
                ),
              if (transaction.refundAmountMinor > 0)
                _DetailLine(
                  label: '已退款',
                  value: formatMoneyMinor(
                    transaction.refundAmountMinor,
                    transaction.currencyCode,
                  ),
                ),
              if (transaction.refundAmountMinor > 0)
                _DetailLine(
                  label: '实际支出',
                  value: formatMoneyMinor(
                    _displayAmountMinor,
                    transaction.currencyCode,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _SplitRecordsSection(
          splitRecords: splitRecords,
          currencyCode: transaction.currencyCode,
          onEditSplit: isReadOnly ? null : onEditSplit,
          onCancelSplit: isReadOnly ? null : onCancelSplit,
        ),
      ],
    );
  }

  bool get _canAddSplit {
    return transaction.type == MoneyTransactionType.expense &&
        transaction.status == MoneyTransactionStatus.completed;
  }

  bool get _canManageLedgerMembership {
    return transaction.status == MoneyTransactionStatus.completed;
  }

  IconData get _icon {
    return switch (transaction.type) {
      MoneyTransactionType.income => Icons.trending_up_rounded,
      MoneyTransactionType.expense => Icons.trending_down_rounded,
      MoneyTransactionType.transfer => Icons.swap_horiz_rounded,
    };
  }

  String get _title {
    final notes = transaction.notes?.trim();
    if (notes != null && notes.isNotEmpty) {
      return notes;
    }
    return _typeLabel;
  }

  String get _typeLabel {
    if (transaction.type == MoneyTransactionType.transfer) {
      return transaction.actualPayerAccount == 'transfer_in' ? '转入' : '转出';
    }
    return transaction.type.label;
  }

  String get _amountPrefix {
    return switch (transaction.type) {
      MoneyTransactionType.income => '+',
      MoneyTransactionType.expense => '-',
      MoneyTransactionType.transfer =>
        transaction.actualPayerAccount == 'transfer_in' ? '+' : '-',
    };
  }

  int get _displayAmountMinor {
    final refunded = transaction.refundAmountMinor;
    if (transaction.type == MoneyTransactionType.expense) {
      return (transaction.amountMinor - refunded)
          .clamp(0, transaction.amountMinor)
          .toInt();
    }
    return transaction.amountMinor;
  }

  String get _statusLabel {
    return switch (transaction.status) {
      MoneyTransactionStatus.completed => '已完成',
      MoneyTransactionStatus.pending => '待确认',
      MoneyTransactionStatus.voided => '已作废',
    };
  }

  String get _paymentMethodText {
    final customName = transaction.customPaymentMethodName?.trim();
    if (customName != null && customName.isNotEmpty) {
      return '${transaction.paymentMethod.label} · $customName';
    }
    return transaction.paymentMethod.label;
  }

  String get _categoryText {
    final catalog = transaction.type == MoneyTransactionType.income
        ? incomeCatalog
        : expenseCatalog;
    final category = catalog.categoryById(transaction.categoryId);
    final subCategory = catalog.subCategoryById(transaction.subCategoryId);
    if (category == null) {
      return '分类已不可用';
    }
    if (subCategory == null) {
      return category.name;
    }
    return '${category.name} / ${subCategory.name}';
  }

  bool get _hasRelationInfo {
    return _hasText(transaction.relatedTransactionId) ||
        _hasText(transaction.installmentPlanId) ||
        transaction.refundAmountMinor > 0;
  }

  Color _amountColor(ThemeData theme) {
    final moneyColors = theme.moneyColors;
    return switch (transaction.type) {
      MoneyTransactionType.income => moneyColors.income,
      MoneyTransactionType.expense => moneyColors.expense,
      MoneyTransactionType.transfer => moneyColors.transfer,
    };
  }

  String _accountName(String accountId) {
    for (final account in accounts) {
      if (account.id == accountId) {
        return account.name;
      }
    }
    return '账户已不可用';
  }

  bool _hasText(String? value) {
    return value != null && value.trim().isNotEmpty;
  }

  String _dateTimeText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _TransactionDetailSummary extends StatelessWidget {
  const _TransactionDetailSummary({
    required this.icon,
    required this.title,
    required this.typeLabel,
    required this.statusLabel,
    required this.dateTimeText,
    required this.amountText,
    required this.amountColor,
    required this.onEdit,
    required this.onDelete,
    required this.onRefund,
    required this.onAddSplit,
    required this.onAddToFamilyLedger,
  });

  final IconData icon;
  final String title;
  final String typeLabel;
  final String statusLabel;
  final String dateTimeText;
  final String amountText;
  final Color amountColor;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onRefund;
  final VoidCallback? onAddSplit;
  final VoidCallback? onAddToFamilyLedger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shouldShowTitle = title.trim() != typeLabel.trim();

    return AppSurface(
      tone: AppSurfaceTone.accent,
      padding: const EdgeInsets.all(16),
      backgroundColor: amountColor.withValues(alpha: 0.08),
      borderColor: amountColor.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppListItemIcon(icon: icon, color: amountColor, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppBadge(
                          label: typeLabel,
                          backgroundColor: amountColor.withValues(alpha: 0.12),
                          borderColor: amountColor.withValues(alpha: 0.22),
                          foregroundColor: amountColor,
                        ),
                        AppBadge(label: statusLabel),
                      ],
                    ),
                    if (shouldShowTitle) ...[
                      const SizedBox(height: 10),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      dateTimeText,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              final amount = Text(
                amountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: amountColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              );
              final actions = Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (onEdit != null)
                    AppIconActionButton(
                      tooltip: '编辑',
                      onPressed: onEdit!,
                      icon: Icons.edit_outlined,
                      variant: AppIconActionVariant.filled,
                    ),
                  if (onDelete != null)
                    AppIconActionButton(
                      tooltip: '删除',
                      onPressed: onDelete!,
                      icon: Icons.delete_outline_rounded,
                      variant: AppIconActionVariant.outlined,
                    ),
                  if (onRefund != null)
                    AppIconActionButton(
                      tooltip: '退款',
                      onPressed: onRefund!,
                      icon: Icons.reply_rounded,
                      variant: AppIconActionVariant.outlined,
                    ),
                  if (onAddSplit != null)
                    AppIconActionButton(
                      tooltip: '分摊',
                      onPressed: onAddSplit!,
                      icon: Icons.call_split_rounded,
                      variant: AppIconActionVariant.outlined,
                    ),
                  if (onAddToFamilyLedger != null)
                    AppIconActionButton(
                      tooltip: '加入家庭账本',
                      onPressed: onAddToFamilyLedger!,
                      icon: Icons.group_add_outlined,
                      variant: AppIconActionVariant.outlined,
                    ),
                ],
              );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    amount,
                    if (actions.children.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: amount),
                  if (actions.children.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    actions,
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DetailInfoItem {
  const _DetailInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _DetailInfoGrid extends StatelessWidget {
  const _DetailInfoGrid({required this.title, required this.items});

  final String title;
  final List<_DetailInfoItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _DetailSection(
      icon: Icons.dashboard_customize_outlined,
      title: title,
      padding: const EdgeInsets.all(12),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 8.0;
            final columns = constraints.maxWidth >= 420 ? 2 : 1;
            final itemWidth = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final item in items)
                  SizedBox(
                    width: itemWidth,
                    child: AppSurface(
                      tone: AppSurfaceTone.inset,
                      bordered: false,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            item.icon,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    letterSpacing: 0,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.value,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.all(12),
    this.childSpacing = 8,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double childSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < children.length; index += 1) ...[
            children[index],
            if (index != children.length - 1) SizedBox(height: childSpacing),
          ],
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 66,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _LedgerMembershipSection extends StatelessWidget {
  const _LedgerMembershipSection({
    required this.ledgers,
    required this.onRemoveFromFamilyLedger,
  });

  final AsyncValue<List<MoneyLedgerEntity>> ledgers;
  final ValueChanged<MoneyLedgerEntity>? onRemoveFromFamilyLedger;

  @override
  Widget build(BuildContext context) {
    return ledgers.when(
      data: (items) {
        if (items.isEmpty) {
          return const _DetailSection(
            icon: Icons.account_tree_outlined,
            title: '账本归属',
            children: [_DetailLine(label: '状态', value: '未关联账本')],
          );
        }
        final personalLedgers = items
            .where((ledger) => ledger.isPersonal)
            .toList();
        final familyLedgers = items.where((ledger) => ledger.isFamily).toList();

        return _DetailSection(
          icon: Icons.account_tree_outlined,
          title: '账本归属',
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (personalLedgers.isEmpty)
                  const AppBadge(label: '未关联个人账本')
                else
                  for (final ledger in personalLedgers)
                    AppBadge(
                      label: ledger.name,
                      icon: Icons.person_outline_rounded,
                      tone: AppBadgeTone.primary,
                    ),
              ],
            ),
            for (final ledger in familyLedgers)
              _FamilyLedgerMembershipRow(
                ledger: ledger,
                onRemove: onRemoveFromFamilyLedger,
              ),
          ],
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stackTrace) => const _DetailSection(
        icon: Icons.account_tree_outlined,
        title: '账本归属',
        children: [_DetailLine(label: '状态', value: '读取失败')],
      ),
    );
  }
}

class _FamilyLedgerMembershipRow extends StatelessWidget {
  const _FamilyLedgerMembershipRow({
    required this.ledger,
    required this.onRemove,
  });

  final MoneyLedgerEntity ledger;
  final ValueChanged<MoneyLedgerEntity>? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            Icons.groups_2_outlined,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ledger.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                Text(
                  '家庭账本',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            AppIconActionButton(
              tooltip: '移出家庭账本',
              icon: Icons.link_off_rounded,
              onPressed: () => onRemove!(ledger),
              variant: AppIconActionVariant.outlined,
            ),
        ],
      ),
    );
  }
}

class _SplitRecordsSection extends StatelessWidget {
  const _SplitRecordsSection({
    required this.splitRecords,
    required this.currencyCode,
    required this.onEditSplit,
    required this.onCancelSplit,
  });

  final AsyncValue<List<MoneySplitRecordEntity>> splitRecords;
  final String currencyCode;
  final ValueChanged<MoneySplitRecordEntity>? onEditSplit;
  final ValueChanged<MoneySplitRecordEntity>? onCancelSplit;

  @override
  Widget build(BuildContext context) {
    return splitRecords.when(
      data: (records) {
        if (records.isEmpty) {
          return const SizedBox.shrink();
        }
        return _DetailSection(
          icon: Icons.call_split_rounded,
          title: '分摊',
          childSpacing: 8,
          children: records.map((record) {
            return _SplitRecordTile(
              record: record,
              currencyCode: currencyCode,
              onEditSplit: onEditSplit,
              onCancelSplit: onCancelSplit,
            );
          }).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (error, stackTrace) => const _DetailSection(
        icon: Icons.call_split_rounded,
        title: '分摊',
        children: [_DetailLine(label: '状态', value: '读取失败')],
      ),
    );
  }
}

class _SplitRecordTile extends StatelessWidget {
  const _SplitRecordTile({
    required this.record,
    required this.currencyCode,
    required this.onEditSplit,
    required this.onCancelSplit,
  });

  final MoneySplitRecordEntity record;
  final String currencyCode;
  final ValueChanged<MoneySplitRecordEntity>? onEditSplit;
  final ValueChanged<MoneySplitRecordEntity>? onCancelSplit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.inset,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.splitType.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              if (record.status == MoneySplitRecordStatus.active) ...[
                AppIconActionButton(
                  tooltip: '编辑分摊',
                  icon: Icons.edit_outlined,
                  onPressed: onEditSplit == null
                      ? null
                      : () => onEditSplit!(record),
                  variant: AppIconActionVariant.outlined,
                ),
                const SizedBox(width: 6),
                AppIconActionButton(
                  tooltip: '取消分摊',
                  icon: Icons.close_rounded,
                  onPressed: onCancelSplit == null
                      ? null
                      : () => onCancelSplit!(record),
                  variant: AppIconActionVariant.outlined,
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '付款人 ${record.payerMemberName}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          for (final detail in record.details)
            _SplitDetailRow(
              detail: detail,
              currencyCode: currencyCode,
              percentageText: detail.percentageBasisPoints == null
                  ? null
                  : '${_formatBasisPoints(detail.percentageBasisPoints!)}%',
            ),
          if (record.notes != null && record.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              record.notes!.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatBasisPoints(int basisPoints) {
    final value = basisPoints / 100;
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }
}

class _SplitDetailRow extends StatelessWidget {
  const _SplitDetailRow({
    required this.detail,
    required this.currencyCode,
    required this.percentageText,
  });

  final MoneySplitRecordDetailEntity detail;
  final String currencyCode;
  final String? percentageText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.memberName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          if (percentageText != null) ...[
            const SizedBox(width: 8),
            Text(
              percentageText!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(width: 10),
          Text(
            formatMoneyMinor(detail.amountMinor, currencyCode),
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
