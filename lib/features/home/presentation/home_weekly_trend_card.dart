import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';

/// 周支出趋势。
///
/// 用可点击的周切换条替代原来的「左右滑动 + 底部小圆点」隐藏手势，
/// 滑动只能靠猜，而周切换是高频操作。
class HomeWeeklyTrendCard extends StatelessWidget {
  const HomeWeeklyTrendCard({
    super.key,
    required this.points,
    required this.window,
    required this.selectedMonth,
    required this.dailyAverageMinor,
    required this.currencyCode,
    required this.isLoading,
    required this.masked,
    required this.onWeekChanged,
  });

  final List<HomeDailySpendingPoint> points;
  final HomeTrendWindow window;
  final DateTime selectedMonth;
  final int dailyAverageMinor;
  final String currencyCode;
  final bool isLoading;
  final bool masked;
  final ValueChanged<int> onWeekChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weekTotal = points.fold<int>(0, (sum, p) => sum + p.expenseMinor);
    final weekCount = points.fold<int>(0, (sum, p) => sum + p.transactionCount);

    return AppContentPanel(
      title: '支出趋势',
      leadingIcon: Icons.bar_chart_rounded,
      // 日期区间跟标题同一行、靠右、字号更小。
      keepTrailingInlineOnCompact: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _rangeLabel(),
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
          if (isLoading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 40,
              child: LinearProgressIndicator(minHeight: 3),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (window.blockCount > 1) ...[
            _WeekSelector(
              labels: window.blockLabels,
              activeIndex: window.offset,
              onChanged: onWeekChanged,
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 132,
            child: points.isEmpty
                ? const Center(
                    child: Text('这一周还没有支出', style: TextStyle(fontSize: 13)),
                  )
                : _WeekBarChart(
                    points: points,
                    dailyAverageMinor: dailyAverageMinor,
                    currencyCode: currencyCode,
                    isCurrentMonth: _isCurrentMonth(selectedMonth),
                  ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _LegendDot(color: theme.moneyColors.expense),
              const SizedBox(width: 5),
              Text(
                '日均线',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          masked
                              ? '本周合计 ••••'
                              : '本周合计 '
                                    '${formatMoneyMinor(weekTotal, currencyCode)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· $weekCount 笔',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isCurrentMonth(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month;
  }

  String _rangeLabel() {
    if (points.isEmpty) {
      return '${selectedMonth.year}年${selectedMonth.month}月';
    }
    // 自然周可能跨月（如 8/31 - 9/6），直接展示首尾日期。
    final first = points.first.date;
    final last = points.last.date;
    return '${DateFormat('M/d').format(first)} - '
        '${DateFormat('M/d').format(last)}';
  }
}

class _WeekSelector extends StatelessWidget {
  const _WeekSelector({
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final selected = index == activeIndex;
          return Material(
            color: selected
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onChanged(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    labels[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({
    required this.points,
    required this.dailyAverageMinor,
    required this.currencyCode,
    required this.isCurrentMonth,
  });

  final List<HomeDailySpendingPoint> points;
  final int dailyAverageMinor;
  final String currencyCode;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final hasData = points.any((p) => p.expenseMinor > 0);
    final maxExpense = hasData
        ? points
              .map((p) => p.expenseMinor)
              .reduce((a, b) => a > b ? a : b)
              .toDouble()
        : 1.0;
    final maxY = maxExpense * 1.6;
    final interval = maxExpense > 0 ? (maxY / 3).ceilToDouble() : 1.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        minY: 0,
        barGroups: List.generate(points.length, (index) {
          final point = points[index];
          final expense = point.expenseMinor.toDouble();
          final isToday = point.date == today && isCurrentMonth;

          final Color barColor;
          if (isToday) {
            barColor = colorScheme.primary;
          } else if (!point.isInMonth) {
            barColor = colorScheme.outlineVariant;
          } else {
            barColor = moneyColors.expense.withValues(alpha: 0.72);
          }

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: expense,
                color: barColor,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
                label: BarChartRodLabel(
                  show: expense > 0,
                  text: _compactAmount(expense.round()),
                  style: TextStyle(
                    color: isToday
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                  offset: const Offset(0, 2),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                final point = points[index];
                final isToday = point.date == today && isCurrentMonth;
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(
                    meta,
                    enabled: true,
                    distanceFromEdge: 2,
                  ),
                  child: Text(
                    isToday ? '今天' : DateFormat('M/d').format(point.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isToday
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: hasData,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) {
            if (value <= 0) {
              return const FlLine(color: Colors.transparent);
            }
            return FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          extraLinesOnTop: true,
          horizontalLines: [
            if (dailyAverageMinor > 0 && hasData)
              HorizontalLine(
                y: dailyAverageMinor.toDouble(),
                color: moneyColors.expense.withValues(alpha: 0.5),
                strokeWidth: 1.2,
                dashArray: [4, 4],
              ),
          ],
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= points.length) {
                return null;
              }
              final point = points[groupIndex];
              return BarTooltipItem(
                '${DateFormat('M/d').format(point.date)}\n'
                '${formatMoneyMinor(point.expenseMinor, currencyCode)}',
                theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ) ??
                    const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

String _compactAmount(int amountMinor) {
  final amount = amountMinor / 100;
  if (amount >= 10000) {
    return '${(amount / 10000).toStringAsFixed(1)}万';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}千';
  }
  if (amount == amount.truncateToDouble()) {
    return '¥${amount.toInt()}';
  }
  return '¥${amount.toStringAsFixed(0)}';
}
