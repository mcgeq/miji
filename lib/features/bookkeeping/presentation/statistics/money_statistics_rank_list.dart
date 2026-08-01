import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyStatisticsRankList extends StatelessWidget {
  const MoneyStatisticsRankList({
    super.key,
    required this.slices,
    required this.currencyCode,
    required this.emptyTitle,
    this.onSliceTap,
  });

  final List<MoneyStatisticsRankSlice> slices;
  final String currencyCode;
  final String emptyTitle;
  final ValueChanged<MoneyStatisticsRankSlice>? onSliceTap;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return AppEmptyState(title: emptyTitle);
    }

    final maxAmount = slices.fold<int>(
      1,
      (max, slice) => slice.amountMinor > max ? slice.amountMinor : max,
    );

    return Column(
      children: [
        for (var index = 0; index < slices.length; index += 1)
          _RankRow(
            rank: index + 1,
            slice: slices[index],
            currencyCode: currencyCode,
            maxAmount: maxAmount,
            onTap: onSliceTap == null ? null : () => onSliceTap!(slices[index]),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.slice,
    required this.currencyCode,
    required this.maxAmount,
    this.onTap,
  });

  final int rank;
  final MoneyStatisticsRankSlice slice;
  final String currencyCode;
  final int maxAmount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = (slice.amountMinor / maxAmount).clamp(0.04, 1.0).toDouble();
    final percentage = '${(slice.percentage * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$rank',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: rank <= 3
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
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
                            slice.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${slice.transactionCount} 笔 · $percentage',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatMoneyMinor(slice.amountMinor, currencyCode),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: ratio,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
