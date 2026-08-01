import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyNetWorthTrendCard extends StatelessWidget {
  const MoneyNetWorthTrendCard({super.key, required this.points});

  final List<MoneyNetWorthTrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    if (points.isEmpty) {
      return AppContentPanel(
        title: '净资产趋势',
        subtitle: '近 90 天资产与负债变化',
        child: const AppEmptyState(
          title: '暂无资产快照数据',
          message: '首次使用将自动采集当日账户余额，后续每日更新。',
        ),
      );
    }

    final display = points;
    final dateFmt = DateFormat('M/d');

    double maxVal = 0;
    double minVal = 0;
    for (final p in display) {
      if (p.netMinor > maxVal) maxVal = p.netMinor.toDouble();
      if (p.netMinor < minVal) minVal = p.netMinor.toDouble();
    }
    final padding = (maxVal - minVal) * 0.25;
    if (padding < 1000) {
      maxVal += 1000;
      minVal -= 1000;
    } else {
      maxVal += padding;
      minVal -= padding;
    }

    return AppContentPanel(
      title: '净资产趋势',
      subtitle: '近 ${display.length} 天资产与负债变化',
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
                      return LineTooltipItem(
                        '净资产 ${formatMoneyMinor(point.netMinor, 'CNY')}\n'
                        '资产 ${formatMoneyMinor(point.assetMinor, 'CNY')}\n'
                        '负债 ${formatMoneyMinor(point.liabilityMinor, 'CNY')}',
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
                      interval: (display.length / 4).ceilToDouble().clamp(
                        1,
                        30,
                      ),
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= display.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          dateFmt.format(display[idx].date),
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
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        final v = value.toInt();
                        if (v.abs() >= 1000000) {
                          return Text(
                            '${(v / 1000000).toStringAsFixed(1)}M',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          );
                        }
                        if (v.abs() >= 10000) {
                          return Text(
                            '${(v / 10000).toStringAsFixed(0)}万',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              letterSpacing: 0,
                            ),
                          );
                        }
                        return Text(
                          '$v',
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
                minY: minVal,
                maxY: maxVal,
                lineBarsData: [
                  // Net worth line
                  LineChartBarData(
                    spots: [
                      for (var i = 0; i < display.length; i++)
                        FlSpot(i.toDouble(), display[i].netMinor.toDouble()),
                    ],
                    isCurved: true,
                    color: colorScheme.primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: colorScheme.primary.withValues(alpha: 0.08),
                    ),
                  ),
                  // Zero reference line
                  LineChartBarData(
                    spots: const [FlSpot(0, 0), FlSpot(1, 0)],
                    isCurved: false,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    barWidth: 1,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [_LegendDot(color: colorScheme.primary, label: '净资产')],
          ),
          if (display.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                _NetWorthMetric(
                  label: '总资产',
                  amountMinor: display.last.assetMinor,
                  color: moneyColors.income,
                ),
                const SizedBox(width: 12),
                _NetWorthMetric(
                  label: '总负债',
                  amountMinor: display.last.liabilityMinor,
                  color: moneyColors.expense,
                ),
                const SizedBox(width: 12),
                _NetWorthMetric(
                  label: '净资产',
                  amountMinor: display.last.netMinor,
                  color: display.last.netMinor >= 0
                      ? moneyColors.success
                      : moneyColors.expense,
                ),
              ],
            ),
          ],
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

class _NetWorthMetric extends StatelessWidget {
  const _NetWorthMetric({
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              formatMoneyMinor(amountMinor, 'CNY'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
