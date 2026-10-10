import 'package:flutter/material.dart';

import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

/// 预算的「未来义务」清单。
///
/// 只给一个「已预留 ¥4200」的数字没人会信，必须让用户看到是哪几笔、
/// 分别在几号，才能核对出有没有算错 / 算重。
class BudgetCommitmentSheet extends StatelessWidget {
  const BudgetCommitmentSheet({
    super.key,
    required this.budget,
    required this.commitment,
  });

  final MoneyBudgetEntity budget;
  final MoneyBudgetCommitment commitment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = appColorFromHex(budget.color ?? '#F97316');
    final currencyCode = budget.currencyCode;
    final committed = commitment.totalMinor;
    final available = budget.remainingAmountMinor - committed;

    return AppDialogScaffold(
      title: '${budget.name} · 未来义务',
      subtitle:
          '${_dateText(commitment.periodStart)} - ${_dateText(commitment.periodEnd.subtract(const Duration(milliseconds: 1)))} 内预计发生',
      maxWidth: 560,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(theme.radiusTokens.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '已预留 ${formatMoneyMinor(committed, currencyCode)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      '${commitment.items.length} 项',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '已用 ${formatMoneyMinor(budget.usedAmountMinor, currencyCode)}'
                  ' · 预算 ${formatMoneyMinor(budget.amountMinor, currencyCode)}'
                  ' · 还可花 ${formatMoneyMinor(available < 0 ? 0 : available, currencyCode)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (commitment.items.isEmpty)
            const AppEmptyState(title: '本周期内没有待发生的自动记账或分期')
          else
            // AppDialogScaffold 的 body 本身就在滚动容器里，这里必须
            // shrinkWrap + 禁用自身滚动，不能再套 Flexible（会拿到无限高度）。
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: commitment.items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                return _CommitmentRow(
                  item: commitment.items[index],
                  currencyCode: currencyCode,
                );
              },
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

class _CommitmentRow extends StatelessWidget {
  const _CommitmentRow({required this.item, required this.currencyCode});

  final MoneyBudgetCommitmentItem item;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.source.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dateText(item.date)}${item.detail == null ? '' : ' · ${item.detail}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            formatMoneyMinor(item.amountMinor, currencyCode),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _dateText(DateTime date) {
  return '${date.month}月${date.day}日';
}
