import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_amount_text.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/presentation/budgets/budget_allocation_summary.dart';

class BudgetCard extends StatelessWidget {
  const BudgetCard({
    super.key,
    required this.budget,
    required this.catalog,
    required this.accountsById,
    this.ledger,
    this.allocationSummary,
    required this.onViewTransactions,
    required this.onViewHistory,
    required this.onManageAllocations,
    required this.onEdit,
    required this.onDelete,
  });

  final MoneyBudgetEntity budget;
  final MoneyCategoryCatalog catalog;
  final Map<String, MoneyAccountEntity> accountsById;
  final MoneyLedgerEntity? ledger;
  final BudgetAllocationSummary? allocationSummary;
  final VoidCallback onViewTransactions;
  final VoidCallback onViewHistory;
  final VoidCallback onManageAllocations;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = appColorFromHex(budget.color ?? '#F97316');
    final progress = budget.progress.clamp(0.0, 1.0).toDouble();
    final remaining = budget.remainingAmountMinor;
    final usedLabel = budget.isIncomeTarget ? '已赚' : '已用';
    final remainingLabel = budget.isIncomeTarget
        ? (budget.isCompleted ? '超额' : '待完成')
        : (budget.isOverspent ? '超出' : '剩余');
    final totalLabel = budget.isIncomeTarget ? '目标' : '预算';
    final remainingColor = budget.isExpenseLimit && budget.isOverspent
        ? colorScheme.error
        : null;

    return AppSwipeActionTile(
      onTap: onViewTransactions,
      actions: [
        AppSwipeAction(
          tooltip: '查看流水',
          icon: Icons.receipt_long_rounded,
          foreground: colorScheme.onSecondaryContainer,
          background: colorScheme.secondaryContainer,
          onPressed: onViewTransactions,
        ),
        AppSwipeAction(
          tooltip: '预算历史',
          icon: Icons.history_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onViewHistory,
        ),
        AppSwipeAction(
          tooltip: '预算分配',
          icon: Icons.account_tree_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: onManageAllocations,
        ),
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
      child: AppListItemPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppListItemIcon(icon: _icon, color: accent, size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _scopeLabel,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _periodLabel,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                      if (ledger != null) ...[
                        const SizedBox(height: 6),
                        _BudgetLedgerBadge(ledger: ledger!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(999),
              color: budget.isOverspent ? colorScheme.error : accent,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _AmountText(
                  label: usedLabel,
                  amountMinor: budget.usedAmountMinor,
                  currencyCode: budget.currencyCode,
                  tone: budget.isIncomeTarget
                      ? MoneyAmountTone.income
                      : MoneyAmountTone.expense,
                ),
                _AmountText(
                  label: remainingLabel,
                  amountMinor: remaining.abs(),
                  currencyCode: budget.currencyCode,
                  tone: remainingColor == null
                      ? MoneyAmountTone.neutral
                      : MoneyAmountTone.expense,
                ),
                _AmountText(
                  label: totalLabel,
                  amountMinor: budget.amountMinor,
                  currencyCode: budget.currencyCode,
                  tone: MoneyAmountTone.neutral,
                ),
              ],
            ),
            if (allocationSummary case final summary?
                when summary.hasAllocations) ...[
              const SizedBox(height: 12),
              _BudgetAllocationOverview(
                summary: summary,
                currencyCode: budget.currencyCode,
              ),
            ],
            if (budget.shouldAlert) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '已达到 ${budget.alertThresholdPercent}% 提醒阈值',
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData get _icon {
    return budget.isIncomeTarget
        ? Icons.trending_up_rounded
        : Icons.flag_rounded;
  }

  String get _scopeLabel {
    if (budget.isAllScope) {
      return '全部范围';
    }
    if (budget.tag != null) {
      return '标签：${budget.tag}';
    }
    final labels = <String>[];
    final category = catalog.categoryById(budget.categoryId);
    final subCategory = catalog.subCategoryById(budget.subCategoryId);
    if (category != null) {
      labels.add(
        subCategory == null
            ? category.name
            : '${category.name} / ${subCategory.name}',
      );
    } else if (budget.categoryId != null) {
      labels.add('分类已不可用');
    }

    final accountId = budget.accountId;
    if (accountId != null) {
      labels.add(accountsById[accountId]?.name ?? '账户已不可用');
    }

    return labels.isEmpty ? '未设置范围' : labels.join(' · ');
  }

  String get _periodLabel {
    return '${budget.periodType.label} · ${_shortDate(budget.periodStart)} 至 ${_shortDate(budget.periodEnd)}';
  }

  String _shortDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _BudgetAllocationOverview extends StatelessWidget {
  const _BudgetAllocationOverview({
    required this.summary,
    required this.currencyCode,
  });

  final BudgetAllocationSummary summary;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final attentionColor = summary.needsAttention
        ? colorScheme.error
        : colorScheme.secondary;
    final unallocatedLabel = summary.isOverAllocated ? '超分配' : '未分配';
    final unallocatedColor = summary.isOverAllocated
        ? colorScheme.error
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _AllocationInfoChip(
            icon: Icons.account_tree_rounded,
            label: '${summary.count} 项分配',
            color: colorScheme.secondary,
          ),
          _AllocationMetric(
            label: '已分配',
            value: formatMoneyMinor(summary.allocatedAmountMinor, currencyCode),
            color: colorScheme.onSurfaceVariant,
          ),
          _AllocationMetric(
            label: unallocatedLabel,
            value: formatMoneyMinor(
              summary.unallocatedAmountMinor.abs(),
              currencyCode,
            ),
            color: unallocatedColor,
          ),
          if (summary.needsAttention)
            _AllocationInfoChip(
              icon: Icons.warning_amber_rounded,
              label: summary.overspentCount > 0
                  ? '${summary.overspentCount} 项超支'
                  : '${summary.alertingCount} 项接近阈值',
              color: attentionColor,
            ),
        ],
      ),
    );
  }
}

class _AllocationInfoChip extends StatelessWidget {
  const _AllocationInfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AllocationMetric extends StatelessWidget {
  const _AllocationMetric({
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
    return Text(
      '$label $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );
  }
}

class _BudgetLedgerBadge extends StatelessWidget {
  const _BudgetLedgerBadge({required this.ledger});

  final MoneyLedgerEntity ledger;

  @override
  Widget build(BuildContext context) {
    final isFamily = ledger.isFamily;

    return AppBadge(
      icon: isFamily
          ? Icons.diversity_3_rounded
          : Icons.account_circle_outlined,
      label: isFamily ? '家庭账本 · ${ledger.name}' : '个人账本',
      tone: isFamily ? AppBadgeTone.tertiary : AppBadgeTone.secondary,
      maxWidth: 220,
    );
  }
}

class _AmountText extends StatelessWidget {
  const _AmountText({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.tone,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final MoneyAmountTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96),
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
          const SizedBox(height: 2),
          MoneyAmountText(
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            tone: tone,
            textStyle: theme.textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}
