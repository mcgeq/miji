import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

class MoneyBudgetExecutionCard extends StatelessWidget {
  const MoneyBudgetExecutionCard({super.key, required this.budgets});

  final List<MoneyBudgetEntity> budgets;

  static const int _maxVisible = 5;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final expenseBudgets = budgets
        .where((b) => b.isActive && b.isExpenseLimit)
        .toList();

    if (expenseBudgets.isEmpty) {
      return AppContentPanel(
        title: '预算执行',
        subtitle: '支出预算执行情况',
        leadingIcon: Icons.flag_rounded,
        leadingColor: colorScheme.primary,
        child: const AppEmptyState(
          title: '暂无支出预算',
          message: '设置预算后，这里会显示执行情况。',
        ),
      );
    }

    // Sort: newest period first, then overspent before normal
    expenseBudgets.sort((a, b) {
      final timeCmp = b.periodStart.compareTo(a.periodStart);
      if (timeCmp != 0) return timeCmp;
      if (a.isOverspent && !b.isOverspent) return -1;
      if (!a.isOverspent && b.isOverspent) return 1;
      return 0;
    });

    final overspentCount = expenseBudgets.where((b) => b.isOverspent).length;
    final totalBudget = expenseBudgets.fold<int>(
      0,
      (s, b) => s + b.amountMinor,
    );
    final totalUsed = expenseBudgets.fold<int>(
      0,
      (s, b) => s + b.usedAmountMinor,
    );
    final overallRate = totalBudget > 0 ? totalUsed / totalBudget : 0.0;
    final isOverspent = overspentCount > 0;

    final visible = expenseBudgets.take(_maxVisible).toList();
    final hidden = expenseBudgets.length - visible.length;

    return AppContentPanel(
      title: '预算执行',
      subtitle: '支出预算执行情况',
      leadingWidget: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (isOverspent ? colorScheme.error : colorScheme.primary)
              .withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.flag_rounded,
          size: 16,
          color: isOverspent ? colorScheme.error : colorScheme.primary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryLine(
            budgetCount: expenseBudgets.length,
            overspentCount: overspentCount,
            overallRate: overallRate,
          ),
          const SizedBox(height: 2),
          for (final budget in visible) _BudgetRow(budget: budget),
          if (hidden > 0) ...[
            const SizedBox(height: 6),
            Text(
              '+ $hidden 项预算',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.budgetCount,
    required this.overspentCount,
    required this.overallRate,
  });

  final int budgetCount;
  final int overspentCount;
  final double overallRate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pct = '${(overallRate * 100).toStringAsFixed(0)}%';

    final statusPart = overspentCount > 0
        ? ' · $overspentCount 个超支'
        : ' · 全部正常';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$budgetCount 个支出预算',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            TextSpan(
              text: statusPart,
              style: theme.textTheme.bodySmall?.copyWith(
                color: overspentCount > 0
                    ? colorScheme.error
                    : theme.moneyColors.success,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            TextSpan(
              text: ' · 综合 $pct',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final MoneyBudgetEntity budget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final isOver = budget.isOverspent;
    final limit = budget.amountMinor;
    final used = budget.usedAmountMinor;
    final remaining = limit - used; // negative if overspent

    final ratio = limit > 0 ? (used / limit).clamp(0.04, 1.0) : 0.0;
    final barColor = isOver ? colorScheme.error : colorScheme.primary;

    final tagLabel = isOver ? '超支' : '剩余';
    final tagAmount = remaining.abs();
    final tagColor = isOver ? colorScheme.error : moneyColors.success;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            budget.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  '${formatMoneyMinor(used, budget.currencyCode)} / ${formatMoneyMinor(limit, budget.currencyCode)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: ratio,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text(
                  '$tagLabel ${formatMoneyMinor(tagAmount, budget.currencyCode)}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tagColor,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
