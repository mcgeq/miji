import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 环形进度替代原来的细进度条：一屏能看更多张，且百分比更醒目。
                _BudgetProgressRing(
                  progress: progress,
                  percentLabel:
                      '${(budget.progress * 100).clamp(0, 999).round()}%',
                  color: budget.isOverspent ? colorScheme.error : accent,
                  trackColor: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(width: 14),
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
                        '$_scopeLabel · $_periodLabel',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
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
                            label: totalLabel,
                            amountMinor: budget.amountMinor,
                            currencyCode: budget.currencyCode,
                            tone: MoneyAmountTone.neutral,
                          ),
                          _AmountText(
                            label: remainingLabel,
                            amountMinor: remaining.abs(),
                            currencyCode: budget.currencyCode,
                            tone: remainingColor == null
                                ? MoneyAmountTone.neutral
                                : MoneyAmountTone.expense,
                          ),
                        ],
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
            if (_paceHint(theme, MoneyPrivacy.of(context))
                case final hint?) ...[
              const SizedBox(height: 8),
              Text(
                hint.$1,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: hint.$2,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
            if (allocationSummary case final summary?
                when summary.hasAllocations) ...[
              const SizedBox(height: 12),
              _BudgetAllocationOverview(
                summary: summary,
                currencyCode: budget.currencyCode,
              ),
            ],
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: onViewTransactions,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('查看流水'),
                ),
                const Spacer(),
                if (allocationSummary case final summary?
                    when summary.hasAllocations)
                  Text(
                    '${summary.count} 项子分配',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                const SizedBox(width: 6),
                // ⋯ 菜单：原来 5 个操作全在左滑里，没有任何视觉提示，
                // 手机上左滑按钮条一次只能看到 2~3 个。左滑保留为快捷方式。
                PopupMenuButton<_BudgetMenuAction>(
                  tooltip: '更多操作',
                  position: PopupMenuPosition.under,
                  onSelected: (action) {
                    switch (action) {
                      case _BudgetMenuAction.history:
                        onViewHistory();
                      case _BudgetMenuAction.allocations:
                        onManageAllocations();
                      case _BudgetMenuAction.edit:
                        onEdit();
                      case _BudgetMenuAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    _menuItem(
                      context,
                      _BudgetMenuAction.history,
                      Icons.history_rounded,
                      '预算历史',
                    ),
                    _menuItem(
                      context,
                      _BudgetMenuAction.allocations,
                      Icons.account_tree_rounded,
                      '子分配设置',
                    ),
                    _menuItem(
                      context,
                      _BudgetMenuAction.edit,
                      Icons.edit_rounded,
                      '编辑预算',
                    ),
                    _menuItem(
                      context,
                      _BudgetMenuAction.delete,
                      Icons.delete_outline_rounded,
                      '删除预算',
                      color: colorScheme.error,
                    ),
                  ],
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      size: 17,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
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

  /// 「日均可用 / 还剩 N 天」这类决策信息。
  ///
  /// 卡片原本只给出「剩余 ¥464」，用户还得自己除以剩余天数。
  /// 这里把它算好；收入目标 / 已完成 / 周期已结束的预算不展示。
  (String, Color)? _paceHint(ThemeData theme, bool masked) {
    if (budget.isIncomeTarget || budget.isCompleted) {
      return null;
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = budget.periodEnd;
    final lastDay = DateTime(end.year, end.month, end.day);
    final daysLeft = lastDay.difference(today).inDays;
    if (daysLeft < 0) {
      return null;
    }
    final moneyColors = theme.moneyColors;
    if (budget.isOverspent) {
      final overspentText = maskedMoneyOr(
        formatMoneyMinor(-budget.remainingAmountMinor, budget.currencyCode),
        masked,
      );
      return (
        '已超支 $overspentText${daysLeft > 0 ? ' · 仅剩 $daysLeft 天' : ''}',
        moneyColors.expense,
      );
    }
    if (daysLeft == 0) {
      return (
        maskedMoneyOr(
          '周期最后一天 · 还可花 ${formatMoneyMinor(budget.remainingAmountMinor, budget.currencyCode)}',
          masked,
        ),
        moneyColors.warning,
      );
    }
    final perDay = budget.remainingAmountMinor ~/ daysLeft;
    return (
      maskedMoneyOr(
        '日均可用 ${formatMoneyMinor(perDay, budget.currencyCode)} · 还剩 $daysLeft 天',
        masked,
      ),
      moneyColors.success,
    );
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

enum _BudgetMenuAction { history, allocations, edit, delete }

PopupMenuItem<_BudgetMenuAction> _menuItem(
  BuildContext context,
  _BudgetMenuAction action,
  IconData icon,
  String label, {
  Color? color,
}) {
  final theme = Theme.of(context);
  return PopupMenuItem<_BudgetMenuAction>(
    value: action,
    child: Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: color ?? theme.colorScheme.onSurfaceVariant,
        ),
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
    ),
  );
}

/// 预算进度环：中心直接给百分比，比细进度条更容易「扫」。
class _BudgetProgressRing extends StatelessWidget {
  const _BudgetProgressRing({
    required this.progress,
    required this.percentLabel,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final String percentLabel;
  final Color color;
  final Color trackColor;

  static const size = 58.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: trackColor,
            ),
          ),
          Text(
            percentLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
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
            value: maskedMoneyOr(
              formatMoneyMinor(summary.allocatedAmountMinor, currencyCode),
              MoneyPrivacy.of(context),
            ),
            color: colorScheme.onSurfaceVariant,
          ),
          _AllocationMetric(
            label: unallocatedLabel,
            value: maskedMoneyOr(
              formatMoneyMinor(
                summary.unallocatedAmountMinor.abs(),
                currencyCode,
              ),
              MoneyPrivacy.of(context),
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
      constraints: const BoxConstraints(minWidth: 72),
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
          MoneyText(
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
