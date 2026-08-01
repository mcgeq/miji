import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyUpcomingCashFlowCard extends StatelessWidget {
  const MoneyUpcomingCashFlowCard({super.key, required this.summary});

  final MoneyUpcomingCashFlowSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    if (summary.items.isEmpty && summary.monthlyRecurringMinor == 0) {
      return AppContentPanel(
        title: '未来现金流',
        subtitle: '分期、账单与每月固定支出',
        child: const AppEmptyState(
          title: '暂无未来支出预测',
          message: '添加分期计划或账单提醒后，这里会显示未来现金流预测。',
        ),
      );
    }

    return AppContentPanel(
      title: '未来现金流',
      subtitle: '分期、账单与每月固定支出',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _MetricBucket(
                label: '30 天应付',
                amountMinor: summary.next30DaysMinor,
                color: moneyColors.expense,
              ),
              const SizedBox(width: 12),
              _MetricBucket(
                label: '90 天应付',
                amountMinor: summary.next90DaysMinor,
                color: moneyColors.warning,
              ),
              const SizedBox(width: 12),
              _MetricBucket(
                label: '每月固定',
                amountMinor: summary.monthlyRecurringMinor,
                color: colorScheme.primary,
              ),
            ],
          ),
          if (summary.items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 10),
            Text(
              '未来支出明细',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            for (final item in summary.items) _CashFlowRow(item: item),
          ],
        ],
      ),
    );
  }
}

class _MetricBucket extends StatelessWidget {
  const _MetricBucket({
    required this.label,
    required this.amountMinor,
    required this.color,
  });

  final String label;
  final int amountMinor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              formatMoneyMinor(amountMinor, 'CNY'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashFlowRow extends StatelessWidget {
  const _CashFlowRow({required this.item});

  final MoneyUpcomingCashFlowItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('M月d日');
    final daysLeft = item.dueDate.difference(DateTime.now()).inDays;
    final dueLabel = daysLeft <= 0
        ? '今天'
        : daysLeft == 1
        ? '明天'
        : '$daysLeft 天后';

    final Color tagColor;
    final String tagLabel;
    switch (item.sourceType) {
      case 'installment':
        tagColor = theme.moneyColors.warning;
        tagLabel = '分期';
      case 'bill':
        tagColor = theme.moneyColors.expense;
        tagLabel = '账单';
      default:
        tagColor = colorScheme.primary;
        tagLabel = item.sourceType;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              tagLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: tagColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$dueLabel · ${dateFmt.format(item.dueDate)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: daysLeft <= 3
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoneyMinor(item.amountMinor, item.currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
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
