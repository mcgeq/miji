import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_legend_item.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyTrendChart extends StatelessWidget {
  const MoneyTrendChart({
    super.key,
    required this.points,
    required this.currencyCode,
    required this.typeFocus,
    required this.groupBy,
  });

  final List<MoneyStatisticsTrendPoint> points;
  final String currencyCode;
  final MoneyStatisticsTypeFocus typeFocus;
  final MoneyStatisticsGroupBy groupBy;

  @override
  Widget build(BuildContext context) {
    if (!points.any(
      (point) => point.incomeMinor != 0 || point.expenseMinor != 0,
    )) {
      return const AppEmptyState(title: '暂无趋势数据');
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final range = _resolveYRange();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _LegendRow(
          items: [
            if (typeFocus != MoneyStatisticsTypeFocus.expense)
              AppCompactLegendItem(color: moneyColors.income, label: '收入'),
            if (typeFocus != MoneyStatisticsTypeFocus.income)
              AppCompactLegendItem(color: moneyColors.expense, label: '支出'),
            if (typeFocus == MoneyStatisticsTypeFocus.balance)
              AppCompactLegendItem(color: colorScheme.primary, label: '净额'),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 238,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return LineChart(
                LineChartData(
                  minX: 0,
                  maxX: (points.length - 1).toDouble(),
                  minY: range.minY,
                  maxY: range.maxY,
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.32),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46,
                        getTitlesWidget: (value, meta) => _AxisLabel(
                          text: _compactMoney(value.round()),
                          meta: meta,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: _bottomInterval,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          final index = value.round();
                          if (index < 0 || index >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final isEdge =
                              index == 0 || index == points.length - 1;
                          if (!isEdge) {
                            final distanceToEdge = math.min(
                              index,
                              points.length - 1 - index,
                            );
                            final pixelsPerIndex =
                                chartWidth / (points.length - 1);
                            if (distanceToEdge * pixelsPerIndex < 40) {
                              return const SizedBox.shrink();
                            }
                          }
                          return _AxisLabel(
                            text: _bucketLabel(points[index].bucketStart),
                            meta: meta,
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    if (typeFocus != MoneyStatisticsTypeFocus.expense)
                      _line(
                        color: moneyColors.income,
                        valueOf: (point) => point.incomeMinor,
                      ),
                    if (typeFocus != MoneyStatisticsTypeFocus.income)
                      _line(
                        color: moneyColors.expense,
                        valueOf: (point) => point.expenseMinor,
                      ),
                    if (typeFocus == MoneyStatisticsTypeFocus.balance)
                      _line(
                        color: colorScheme.primary,
                        valueOf: (point) => point.netMinor,
                      ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipColor: (_) => colorScheme.inverseSurface,
                      getTooltipItems: (spots) {
                        return spots.map((spot) {
                          return LineTooltipItem(
                            formatMoneyMinor(spot.y.round(), currencyCode),
                            theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onInverseSurface,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ) ??
                                const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  ({double minY, double maxY}) _resolveYRange() {
    var minY = 0.0;
    var maxY = 1.0;
    for (final point in points) {
      final values = <int>[
        if (typeFocus != MoneyStatisticsTypeFocus.expense) point.incomeMinor,
        if (typeFocus != MoneyStatisticsTypeFocus.income) point.expenseMinor,
        if (typeFocus == MoneyStatisticsTypeFocus.balance) point.netMinor,
      ];
      for (final value in values) {
        minY = math.min(minY, value.toDouble());
        maxY = math.max(maxY, value.toDouble());
      }
    }
    if (minY == maxY) {
      return (minY: minY - 1, maxY: maxY + 1);
    }
    final padding = (maxY - minY) * 0.16;
    return (minY: minY - padding, maxY: maxY + padding);
  }

  /// 按点数（即所选周期跨度）自适应选择 X 轴刻度间隔：
  /// 从"整齐天数"档位表（5 天/周/半月/月/季）中取最接近 count/5 的间隔，
  /// 保证标签数量约 6~7 个，且首刻度（月初/起点）和末刻度（月末/终点）都能落位；
  /// 若候选间隔导致末刻度贴边，则优先取更小的档位。
  double get _bottomInterval {
    const steps = <double>[
      1,
      2,
      3,
      5,
      7,
      10,
      14,
      15,
      21,
      30,
      45,
      60,
      90,
      120,
      180,
    ];
    final count = points.length;
    if (count <= 6) {
      return 1;
    }
    final target = count / 5;
    double? below;
    double? above;
    for (final step in steps) {
      if (step <= target) {
        below = step;
      } else {
        above = step;
        break;
      }
    }
    final maxIndex = count - 1;
    bool gapOk(double step) {
      final remainder = maxIndex % step;
      return remainder == 0 || remainder >= step * 0.45;
    }

    if (below != null && gapOk(below)) {
      return below;
    }
    if (above != null && gapOk(above)) {
      return above;
    }
    return below ?? above ?? 1;
  }

  String _bucketLabel(DateTime date) {
    return switch (groupBy) {
      MoneyStatisticsGroupBy.day => DateFormat('M/d').format(date),
      MoneyStatisticsGroupBy.month => DateFormat('M月').format(date),
    };
  }

  String _compactMoney(int amountMinor) {
    final amount = amountMinor.abs() / 100;
    final sign = amountMinor < 0 ? '-' : '';
    if (amount >= 10000) {
      return '$sign${(amount / 10000).toStringAsFixed(1)}万';
    }
    if (amount >= 1000) {
      return '$sign${(amount / 1000).toStringAsFixed(1)}千';
    }
    return '$sign${amount.toStringAsFixed(0)}';
  }

  LineChartBarData _line({
    required Color color,
    required int Function(MoneyStatisticsTrendPoint point) valueOf,
  }) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2.6,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
      spots: [
        for (var index = 0; index < points.length; index += 1)
          FlSpot(index.toDouble(), valueOf(points[index]).toDouble()),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 12, runSpacing: 8, children: items);
  }
}

class _AxisLabel extends StatelessWidget {
  const _AxisLabel({required this.text, required this.meta});

  final String text;
  final TitleMeta meta;

  @override
  Widget build(BuildContext context) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 10,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
