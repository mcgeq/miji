import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

class HomeTodaySpendingCard extends StatefulWidget {
  const HomeTodaySpendingCard({
    super.key,
    required this.selectedMonth,
    required this.weeklyPoints,
    required this.summary,
    required this.isLoading,
    required this.weekOffset,
    required this.totalWeeks,
    required this.onWeekChanged,
  });

  final DateTime selectedMonth;
  final List<HomeDailySpendingPoint>? weeklyPoints;
  final HomeTodaySpendingSummary? summary;
  final bool isLoading;
  final int weekOffset;
  final int totalWeeks;
  final ValueChanged<int> onWeekChanged;

  @override
  State<HomeTodaySpendingCard> createState() => _HomeTodaySpendingCardState();
}

class _HomeTodaySpendingCardState extends State<HomeTodaySpendingCard> {
  int _selectedBarIndex = 3;

  @override
  void didUpdateWidget(HomeTodaySpendingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekOffset != widget.weekOffset) {
      _selectedBarIndex = 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final value = widget.summary ?? const HomeTodaySpendingSummary.empty();
    final isCurrentMonth = _isCurrentMonth(widget.selectedMonth);
    final title = isCurrentMonth ? '今日概览' : '月度概览';
    final points = widget.weeklyPoints ?? const <HomeDailySpendingPoint>[];

    final leadingIcon = isCurrentMonth
        ? Icons.today_rounded
        : Icons.calendar_month_rounded;

    return AppContentPanel(
      title: title,
      leadingWidget: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: theme.moneyColors.expense.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(leadingIcon, size: 16, color: theme.moneyColors.expense),
      ),
      trailing: widget.isLoading
          ? const SizedBox(
              width: 88,
              child: LinearProgressIndicator(minHeight: 3),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 104,
            child: _WeekBarChart(
              points: points,
              isCurrentMonth: isCurrentMonth,
              theme: theme,
              dailyAverageMinor: value.dailyAverageExpenseMinor,
              weekOffset: widget.weekOffset,
              onWeekChanged: widget.onWeekChanged,
              selectedIndex: _selectedBarIndex,
              onBarTapped: (index) {
                setState(() => _selectedBarIndex = index);
              },
            ),
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.38),
          ),
          const SizedBox(height: 8),
          _Footer(
            summary: value,
            weekPoints: points,
            isCurrentMonth: isCurrentMonth,
            weekOffset: widget.weekOffset,
            totalWeeks: widget.totalWeeks,
            selectedMonth: widget.selectedMonth,
            onDotTap: widget.onWeekChanged,
            selectedIndex: _selectedBarIndex,
          ),
        ],
      ),
    );
  }

  bool _isCurrentMonth(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year && value.month == now.month;
  }
}

// ============================================================================
// 周柱状图（可滑动）
// ============================================================================
class _WeekBarChart extends StatelessWidget {
  const _WeekBarChart({
    required this.points,
    required this.isCurrentMonth,
    required this.theme,
    required this.dailyAverageMinor,
    required this.weekOffset,
    required this.onWeekChanged,
    required this.selectedIndex,
    required this.onBarTapped,
  });

  final List<HomeDailySpendingPoint> points;
  final bool isCurrentMonth;
  final ThemeData theme;
  final int dailyAverageMinor;
  final int weekOffset;
  final ValueChanged<int> onWeekChanged;
  final int selectedIndex;
  final ValueChanged<int> onBarTapped;

  @override
  Widget build(BuildContext context) {
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
    final maxY = maxExpense * 1.7;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity == null) return;
        if (details.primaryVelocity! < -50) {
          onWeekChanged(weekOffset + 1);
        } else if (details.primaryVelocity! > 50) {
          onWeekChanged(weekOffset - 1);
        }
      },
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: maxY,
          minY: 0,
          barGroups: List.generate(7, (i) {
            final point = i < points.length ? points[i] : null;
            final expense = point?.expenseMinor.toDouble() ?? 0;
            final isToday = point != null && point.date == today;
            final isInMonth = point?.isInMonth ?? true;

            Color barColor;
            if (isToday && isCurrentMonth) {
              barColor = colorScheme.primary;
            } else if (!isInMonth) {
              barColor = colorScheme.outlineVariant;
            } else {
              barColor = moneyColors.expense;
            }

            final showLabel = expense > 0;
            final labelText = showLabel ? _compactAmount(expense.round()) : '';

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: expense,
                  color: barColor,
                  width: 14,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  label: BarChartRodLabel(
                    show: showLabel,
                    text: labelText,
                    style: TextStyle(
                      color: colorScheme.onSurface,
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
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: hasData,
                reservedSize: 34,
                interval: maxExpense > 0 ? (maxY / 3).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  if (value <= 0) return const SizedBox.shrink();
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      _compactAxisAmount(value.round()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        letterSpacing: 0,
                      ),
                    ),
                  );
                },
              ),
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
                  final isToday = point.date == today;
                  final label = isToday && isCurrentMonth
                      ? '今天'
                      : DateFormat('M/d').format(point.date);
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(
                      meta,
                      enabled: true,
                      distanceFromEdge: 2,
                    ),
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isToday && isCurrentMonth
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: isToday && isCurrentMonth
                            ? FontWeight.w800
                            : FontWeight.w500,
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
            horizontalInterval: maxExpense > 0 ? (maxY / 3).ceilToDouble() : 1,
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
            touchCallback: (event, response) {
              if (event is FlTapUpEvent && response?.spot != null) {
                final index = response!.spot!.touchedBarGroupIndex;
                if (index >= 0 && index < points.length) {
                  onBarTapped(index);
                }
              }
            },
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
                  formatMoneyMinor(point.expenseMinor, 'CNY'),
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
      ),
    );
  }
}

String _compactAmount(int amountMinor) {
  final amount = amountMinor / 100;
  if (amount >= 10000) {
    final val = (amount / 10000 * 100).floorToDouble() / 100;
    return '${val.toStringAsFixed(2)}万';
  }
  if (amount >= 1000) {
    final val = (amount / 1000 * 100).floorToDouble() / 100;
    return '${val.toStringAsFixed(2)}千';
  }
  if (amount == amount.truncateToDouble()) {
    return '¥${amount.toInt()}';
  }
  return '¥${amount.toStringAsFixed(2)}';
}

String _compactSignedAmount(int amountMinor) {
  if (amountMinor == 0) return '¥0';
  final abs = _compactAmount(amountMinor.abs());
  return amountMinor > 0 ? '+$abs' : '-$abs';
}

String _compactAxisAmount(int amountMinor) {
  final amount = amountMinor / 100;
  if (amount >= 10000) {
    return '${(amount / 10000).toStringAsFixed(1)}万';
  }
  if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}千';
  }
  return amount.toStringAsFixed(0);
}

// ============================================================================
// Footer
// ============================================================================
class _Footer extends StatelessWidget {
  const _Footer({
    required this.summary,
    required this.weekPoints,
    required this.isCurrentMonth,
    required this.weekOffset,
    required this.totalWeeks,
    required this.selectedMonth,
    required this.onDotTap,
    required this.selectedIndex,
  });

  final HomeTodaySpendingSummary summary;
  final List<HomeDailySpendingPoint> weekPoints;
  final bool isCurrentMonth;
  final int weekOffset;
  final int totalWeeks;
  final DateTime selectedMonth;
  final ValueChanged<int> onDotTap;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final weekExpense = weekPoints.fold<int>(
      0,
      (sum, p) => sum + p.expenseMinor,
    );
    final weekIncome = weekPoints.fold<int>(0, (sum, p) => sum + p.incomeMinor);
    final weekCount = weekPoints.fold<int>(
      0,
      (sum, p) => sum + p.transactionCount,
    );

    final selectedPoint = isCurrentMonth && selectedIndex < weekPoints.length
        ? weekPoints[selectedIndex]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: monthly totals
        Row(
          children: [
            Expanded(
              child: _OverviewMetricTile(
                label: '本月支出',
                value: _compactAmount(summary.monthExpenseMinor),
                color: theme.moneyColors.expense,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewMetricTile(
                label: '本月收入',
                value: _compactSignedAmount(summary.monthIncomeMinor),
                color: theme.moneyColors.income,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewMetricTile(
                label: '结余',
                value: _compactSignedAmount(summary.monthNetMinor),
                color: summary.monthNetMinor >= 0
                    ? theme.moneyColors.income
                    : theme.moneyColors.expense,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 2: week summary + selected day income
        Row(
          children: [
            Expanded(
              child: _OverviewMetricTile(
                label: '周支出',
                value: _compactAmount(weekExpense),
                color: theme.moneyColors.expense,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _OverviewMetricTile(
                label: '周收入',
                value: _compactSignedAmount(weekIncome),
                color: theme.moneyColors.income,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: selectedPoint == null
                  ? _OverviewMetricTile(
                      label: '周结余',
                      value: _compactSignedAmount(weekIncome - weekExpense),
                      color: weekIncome - weekExpense >= 0
                          ? theme.moneyColors.income
                          : theme.moneyColors.expense,
                    )
                  : _OverviewMetricTile(
                      label: _selectedDayLabel(selectedPoint),
                      value: _compactSignedAmount(selectedPoint.incomeMinor),
                      color: theme.moneyColors.income,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Row 3: week dots
        Row(
          children: [
            Text(
              '$weekCount 笔',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            _WeekDots(
              totalWeeks: totalWeeks,
              activeIndex: _activeDotIndex(),
              onDotTap: onDotTap,
            ),
          ],
        ),
      ],
    );
  }

  String _selectedDayLabel(HomeDailySpendingPoint point) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return point.date == today && isCurrentMonth
        ? '今日收入'
        : '${DateFormat('M/d').format(point.date)}收入';
  }

  int _activeDotIndex() {
    return weekOffset.clamp(0, totalWeeks - 1);
  }
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  const _WeekDots({
    required this.totalWeeks,
    required this.activeIndex,
    required this.onDotTap,
  });

  final int totalWeeks;
  final int activeIndex;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(totalWeeks, (i) {
        final isActive = i == activeIndex;
        return GestureDetector(
          onTap: () => onDotTap(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          ),
        );
      }),
    );
  }
}
