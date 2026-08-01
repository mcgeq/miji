import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyCategoryShareChart extends StatelessWidget {
  const MoneyCategoryShareChart({
    super.key,
    required this.slices,
    required this.currencyCode,
    required this.emptyTitle,
    required this.centerLabel,
    required this.baseColor,
    this.onSliceTap,
  });

  final List<MoneyStatisticsCategorySlice> slices;
  final String currencyCode;
  final String emptyTitle;
  final String centerLabel;
  final Color baseColor;
  final ValueChanged<MoneyStatisticsCategorySlice>? onSliceTap;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return AppEmptyState(title: emptyTitle);
    }

    final theme = Theme.of(context);
    final total = slices.fold<int>(0, (sum, slice) => sum + slice.amountMinor);
    final topSlices = slices.take(6).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final chart = SizedBox(
          width: compact ? 150 : 176,
          height: compact ? 150 : 176,
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
                    centerLabel,
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
              _CategoryRankRow(
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
      baseColor,
      theme.colorScheme.tertiary,
      theme.colorScheme.primary,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    return palette[index % palette.length];
  }
}

class _CategoryRankRow extends StatelessWidget {
  const _CategoryRankRow({
    required this.slice,
    required this.currencyCode,
    required this.color,
    this.onTap,
  });

  final MoneyStatisticsCategorySlice slice;
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
              label: slice.categoryName,
              subtitle: percentage,
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
