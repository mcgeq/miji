import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyAccountDistributionChart extends StatefulWidget {
  const MoneyAccountDistributionChart({
    super.key,
    required this.slices,
    this.onAccountTap,
  });

  final List<MoneyStatisticsAccountSlice> slices;
  final ValueChanged<MoneyStatisticsAccountSlice>? onAccountTap;

  @override
  State<MoneyAccountDistributionChart> createState() =>
      _MoneyAccountDistributionChartState();
}

class _MoneyAccountDistributionChartState
    extends State<MoneyAccountDistributionChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final visibleSlices = widget.slices
        .where((slice) => slice.assetMinor != 0 || slice.liabilityMinor != 0)
        .toList();
    if (visibleSlices.isEmpty) {
      return const AppEmptyState(title: '暂无账户分布数据');
    }

    final theme = Theme.of(context);
    final assetMinor = visibleSlices.fold<int>(
      0,
      (sum, slice) => sum + slice.assetMinor,
    );
    final liabilityMinor = visibleSlices.fold<int>(
      0,
      (sum, slice) => sum + slice.liabilityMinor,
    );
    final currencyCode = visibleSlices.first.currencyCode;
    final selected =
        _selectedIndex == null || _selectedIndex! >= visibleSlices.length
        ? null
        : visibleSlices[_selectedIndex!];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;
        final chart = SizedBox(
          width: compact ? 150 : 170,
          height: compact ? 150 : 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: compact ? 46 : 54,
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      // 仅在点击抬起时切换一次，避免按下/抬起两次 toggle 相互抵消。
                      if (event is! FlTapUpEvent || response == null) {
                        return;
                      }
                      final index =
                          response.touchedSection?.touchedSectionIndex;
                      if (index == null || index < 0) {
                        return;
                      }
                      if (index >= visibleSlices.length) {
                        return;
                      }
                      _handleTap(index);
                    },
                  ),
                  sections: [
                    for (
                      var index = 0;
                      index < visibleSlices.length;
                      index += 1
                    )
                      PieChartSectionData(
                        value: visibleSlices[index].totalMinor.toDouble(),
                        color: _sliceColor(context, index),
                        radius: compact ? 18 : 22,
                        showTitle: false,
                        cornerRadius: 4,
                      ),
                  ],
                ),
              ),
              _AccountCenter(
                selected: selected,
                netWorthMinor: assetMinor - liabilityMinor,
                currencyCode: currencyCode,
              ),
            ],
          ),
        );

        final list = Column(
          children: [
            _AccountTotalRow(
              label: '资产',
              amountMinor: assetMinor,
              currencyCode: currencyCode,
              color: theme.colorScheme.primary,
            ),
            _AccountTotalRow(
              label: '负债',
              amountMinor: liabilityMinor,
              currencyCode: currencyCode,
              color: theme.moneyColors.expense,
            ),
            const SizedBox(height: 6),
            for (var index = 0; index < visibleSlices.length; index += 1)
              _AccountSliceRow(
                slice: visibleSlices[index],
                color: _sliceColor(context, index),
                maxMinor: _maxSliceMinor,
                onTap: widget.onAccountTap == null
                    ? null
                    : () => widget.onAccountTap!(visibleSlices[index]),
              ),
          ],
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: chart),
              const SizedBox(height: 16),
              list,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 18),
            Expanded(child: list),
          ],
        );
      },
    );
  }

  void _handleTap(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  int get _maxSliceMinor {
    var max = 1;
    for (final slice in widget.slices) {
      if (slice.totalMinor > max) {
        max = slice.totalMinor;
      }
    }
    return max;
  }

  Color _sliceColor(BuildContext context, int index) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = <Color>[
      colorScheme.primary,
      theme.moneyColors.expense,
      colorScheme.tertiary,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
    ];
    return palette[index % palette.length];
  }
}

class _AccountCenter extends StatelessWidget {
  const _AccountCenter({
    required this.selected,
    required this.netWorthMinor,
    required this.currencyCode,
  });

  final MoneyStatisticsAccountSlice? selected;
  final int netWorthMinor;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (selected != null) {
      final amountMinor = selected!.assetMinor > 0
          ? selected!.assetMinor
          : selected!.liabilityMinor;
      final total = selected!.assetMinor + selected!.liabilityMinor;
      final percentage = total == 0
          ? '0%'
          : '${((amountMinor / total) * 100).toStringAsFixed(1)}%';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected!.accountName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatMoneyMinor(amountMinor, currencyCode),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            percentage,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '净资产',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatMoneyMinor(netWorthMinor, currencyCode),
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _AccountTotalRow extends StatelessWidget {
  const _AccountTotalRow({
    required this.label,
    required this.amountMinor,
    required this.currencyCode,
    required this.color,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: AppLegendItem(
        color: color,
        label: label,
        trailing: Text(
          formatMoneyMinor(amountMinor, currencyCode),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _AccountSliceRow extends StatelessWidget {
  const _AccountSliceRow({
    required this.slice,
    required this.color,
    required this.maxMinor,
    this.onTap,
  });

  final MoneyStatisticsAccountSlice slice;
  final Color color;
  final int maxMinor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final amountMinor = slice.assetMinor > 0
        ? slice.assetMinor
        : slice.liabilityMinor;
    final ratio = (amountMinor / maxMinor).clamp(0.04, 1.0).toDouble();

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
                    Expanded(
                      child: Text(
                        slice.accountName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      formatMoneyMinor(amountMinor, slice.currencyCode),
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
                    valueColor: AlwaysStoppedAnimation<Color>(color),
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
