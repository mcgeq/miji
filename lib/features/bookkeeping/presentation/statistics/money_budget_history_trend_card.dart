import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyBudgetHistoryTrendCard extends StatelessWidget {
  const MoneyBudgetHistoryTrendCard({super.key, required this.points});

  final List<MoneyBudgetHistoryTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (points.isEmpty) {
      return AppContentPanel(
        title: '预算执行趋势',
        subtitle: '近 6 个周期预算使用率',
        child: const AppEmptyState(
          title: '暂无预算快照数据',
          message: '有预算执行记录后，这里会显示历史执行趋势。',
        ),
      );
    }

    final display = points.length > 6
        ? points.sublist(points.length - 6)
        : points;
    final maxRate = display.fold<double>(
      0.0,
      (m, p) => p.usageRate > m ? p.usageRate : m,
    );
    final maxY = (maxRate * 1.3).clamp(0.5, 2.0).toDouble();
    final dateFmt = DateFormat('M月');

    return AppContentPanel(
      title: '预算执行趋势',
      subtitle: '近 ${display.length} 个周期预算使用率',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((spot) {
                      final idx = spot.x.toInt();
                      if (idx < 0 || idx >= display.length) return null;
                      final point = display[idx];
                      final pct =
                          '${(point.usageRate * 100).toStringAsFixed(0)}%';
                      return LineTooltipItem(
                        '$pct\n${formatMoneyMinor(point.usedAmountMinor, 'CNY')} / ${formatMoneyMinor(point.budgetAmountMinor, 'CNY')}',
                        theme.textTheme.labelSmall!.copyWith(
                          color: Colors.white,
                          letterSpacing: 0,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= display.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          dateFmt.format(display[idx].periodStart),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 0.5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value * 100).toInt()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                lineBarsData: [
                  // 100% reference line
                  LineChartBarData(
                    spots: [
                      FlSpot(0, 1),
                      FlSpot((display.length - 1).toDouble(), 1),
                    ],
                    isCurved: false,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    barWidth: 1,
                    isStrokeCapRound: true,
                    dashArray: [4, 4],
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                  // Usage rate line
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < display.length; i++)
                        FlSpot(i.toDouble(), display[i].usageRate),
                    ],
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, x, y, color) => FlDotCirclePainter(
                        radius: 3,
                        color: colorScheme.primary,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: colorScheme.primary, label: '执行率'),
              const SizedBox(width: 14),
              _LegendDot(color: colorScheme.outlineVariant, label: '100% 参考线'),
              const Spacer(),
              Text(
                '${display.last.overspentBudgetCount}/${display.last.budgetCount} 超支',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: display.last.overspentBudgetCount > 0
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
