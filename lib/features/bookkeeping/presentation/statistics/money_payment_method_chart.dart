import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyPaymentMethodChart extends StatelessWidget {
  const MoneyPaymentMethodChart({
    super.key,
    required this.slices,
    required this.currencyCode,
    this.onSliceTap,
  });

  final List<MoneyStatisticsPaymentMethodSlice> slices;
  final String currencyCode;
  final ValueChanged<MoneyStatisticsPaymentMethodSlice>? onSliceTap;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return const AppEmptyState(title: '暂无支付渠道数据');
    }

    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amountMinor);
    final topSlices = slices.take(7).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final chart = SizedBox(
          width: compact ? 150 : 174,
          height: compact ? 150 : 174,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: compact ? 44 : 54,
                  startDegreeOffset: -90,
                  pieTouchData: onSliceTap == null
                      ? PieTouchData(enabled: false)
                      : PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response == null) {
                              return;
                            }
                            final index =
                                response.touchedSection?.touchedSectionIndex;
                            if (index == null || index < 0) {
                              return;
                            }
                            if (index >= topSlices.length) {
                              return;
                            }
                            onSliceTap?.call(topSlices[index]);
                          },
                        ),
                  sections: [
                    for (var index = 0; index < topSlices.length; index += 1)
                      PieChartSectionData(
                        value: topSlices[index].amountMinor.toDouble(),
                        color: _sliceColor(context, index),
                        radius: compact ? 18 : 22,
                        showTitle: false,
                        cornerRadius: 4,
                      ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '渠道合计',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoneyMinor(total, currencyCode),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        final ranking = Column(
          children: [
            for (var index = 0; index < slices.length; index += 1)
              _PaymentMethodRankRow(
                slice: slices[index],
                currencyCode: currencyCode,
                color: _sliceColor(context, index),
                onTap: onSliceTap == null
                    ? null
                    : () => onSliceTap!(slices[index]),
              ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: chart),
              const SizedBox(height: 16),
              ranking,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 18),
            Expanded(child: ranking),
          ],
        );
      },
    );
  }

  Color _sliceColor(BuildContext context, int index) {
    final theme = Theme.of(context);
    final palette = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.moneyColors.expense,
      Colors.teal,
      Colors.orange,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    return palette[index % palette.length];
  }
}

class _PaymentMethodRankRow extends StatelessWidget {
  const _PaymentMethodRankRow({
    required this.slice,
    required this.currencyCode,
    required this.color,
    this.onTap,
  });

  final MoneyStatisticsPaymentMethodSlice slice;
  final String currencyCode;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = '${(slice.percentage * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: AppLegendItem(
              color: color,
              label: slice.label,
              subtitle: '${slice.transactionCount} 笔 · $percentage',
              trailing: Text(
                formatMoneyMinor(slice.amountMinor, currencyCode),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
