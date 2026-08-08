import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyAccountTypeDistributionChart extends StatefulWidget {
  const MoneyAccountTypeDistributionChart({super.key, required this.slices});

  final List<MoneyStatisticsAccountTypeSlice> slices;

  @override
  State<MoneyAccountTypeDistributionChart> createState() =>
      _MoneyAccountTypeDistributionChartState();
}

class _MoneyAccountTypeDistributionChartState
    extends State<MoneyAccountTypeDistributionChart> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final visibleSlices = widget.slices
        .where((slice) => slice.totalMinor > 0)
        .toList();
    if (visibleSlices.isEmpty) {
      return const AppEmptyState(title: '暂无账户类型数据');
    }

    final totalMinor = visibleSlices.fold<int>(
      0,
      (sum, slice) => sum + slice.totalMinor,
    );
    final currencyCode = visibleSlices.first.currencyCode;
    final topSlices = visibleSlices.take(8).toList();
    final selected =
        _selectedIndex == null || _selectedIndex! >= topSlices.length
        ? null
        : topSlices[_selectedIndex!];

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
                      if (index >= topSlices.length) {
                        return;
                      }
                      _handleTap(index);
                    },
                  ),
                  sections: [
                    for (var index = 0; index < topSlices.length; index += 1)
                      PieChartSectionData(
                        value: topSlices[index].totalMinor.toDouble(),
                        color: _sliceColor(context, index),
                        radius: compact ? 18 : 22,
                        showTitle: false,
                        cornerRadius: 4,
                      ),
                  ],
                ),
              ),
              _AccountTypeCenter(
                selected: selected,
                total: totalMinor,
                currencyCode: currencyCode,
              ),
            ],
          ),
        );

        final list = Column(
          children: [
            for (var index = 0; index < visibleSlices.length; index += 1)
              _AccountTypeRow(
                slice: visibleSlices[index],
                color: _sliceColor(context, index),
                onTap: index >= topSlices.length
                    ? null
                    : () => _handleTap(index),
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

  Color _sliceColor(BuildContext context, int index) {
    final theme = Theme.of(context);
    final palette = <Color>[
      theme.colorScheme.primary,
      theme.colorScheme.tertiary,
      theme.moneyColors.credit,
      theme.moneyColors.income,
      theme.moneyColors.expense,
      Colors.teal,
      Colors.orange,
      Colors.indigo,
    ];
    return palette[index % palette.length];
  }
}

class _AccountTypeCenter extends StatelessWidget {
  const _AccountTypeCenter({
    required this.selected,
    required this.total,
    required this.currencyCode,
  });

  final MoneyStatisticsAccountTypeSlice? selected;
  final int total;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (selected != null) {
      final amount = selected!.assetMinor > 0
          ? selected!.assetMinor
          : selected!.liabilityMinor;
      final percentage = total == 0
          ? '0%'
          : '${((amount / total) * 100).toStringAsFixed(1)}%';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            selected!.label,
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
            formatMoneyMinor(amount, currencyCode),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${selected!.accountCount} 个账户 · $percentage',
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
          '类型合计',
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
    );
  }
}

class _AccountTypeRow extends StatelessWidget {
  const _AccountTypeRow({required this.slice, required this.color, this.onTap});

  final MoneyStatisticsAccountTypeSlice slice;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = '${(slice.percentage * 100).toStringAsFixed(1)}%';
    final amount = slice.assetMinor > 0
        ? slice.assetMinor
        : slice.liabilityMinor;
    final subtitle = '${slice.accountCount} 个账户 · $percentage';

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
              subtitle: subtitle,
              trailing: Text(
                formatMoneyMinor(amount, slice.currencyCode),
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
