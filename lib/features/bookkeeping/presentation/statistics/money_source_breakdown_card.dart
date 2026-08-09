import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_currency_codes.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneySourceBreakdownCard extends StatelessWidget {
  const MoneySourceBreakdownCard({super.key, required this.insights});

  final MoneyStatisticsInsights insights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasSourceData = insights.sourceSlices.any((s) => s.amountMinor > 0);
    final hasTrendData = insights.sourceTrend.any((p) => p.totalMinor > 0);
    final hasRefundData = insights.refund.refundCount > 0;
    final hasAnyData = hasSourceData || hasTrendData || hasRefundData;

    if (!hasAnyData) {
      return AppContentPanel(
        title: '支出构成',
        subtitle: '分期、自动记账与退款',
        child: const AppEmptyState(
          title: '暂无支出构成数据',
          message: '此时间范围内没有分期、自动记账或退款记录。',
        ),
      );
    }

    return AppContentPanel(
      title: '支出构成',
      subtitle: '分期、自动记账与退款',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasSourceData) ...[
            _SourceBreakdown(
              slices: insights.sourceSlices,
              currencyCode: insights.currencyCode,
            ),
          ],
          if (hasSourceData && hasTrendData) const SizedBox(height: 18),
          if (hasTrendData) ...[
            _SourceTrendChart(
              points: insights.sourceTrend,
              currencyCode: insights.currencyCode,
            ),
          ],
          if ((hasSourceData || hasTrendData) && hasRefundData)
            const SizedBox(height: 14),
          if (hasRefundData) ...[
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 10),
            _RefundSummaryRow(refund: insights.refund),
          ],
        ],
      ),
    );
  }
}

class _SourceBreakdown extends StatelessWidget {
  const _SourceBreakdown({required this.slices, required this.currencyCode});

  final List<MoneyStatisticsSourceSlice> slices;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sorted = List<MoneyStatisticsSourceSlice>.from(slices)
      ..sort((a, b) => b.amountMinor.compareTo(a.amountMinor));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '来源占比',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        for (final slice in sorted)
          _SourceBar(slice: slice, currencyCode: currencyCode),
      ],
    );
  }
}

class _SourceBar extends StatelessWidget {
  const _SourceBar({required this.slice, required this.currencyCode});

  final MoneyStatisticsSourceSlice slice;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = slice.percentage.clamp(0.04, 1.0).toDouble();
    final pct = '${(slice.percentage * 100).toStringAsFixed(1)}%';

    final Color barColor;
    switch (slice.sourceType) {
      case 'installment':
        barColor = theme.moneyColors.warning;
      case 'auto_posting':
        barColor = theme.moneyColors.success;
      default:
        barColor = colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  slice.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 16,
                    value: ratio,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  formatMoneyMinor(slice.amountMinor, currencyCode),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Text(
              '${slice.transactionCount} 笔 · $pct',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTrendChart extends StatelessWidget {
  const _SourceTrendChart({required this.points, required this.currencyCode});

  final List<MoneyStatisticsSourceTrendPoint> points;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    final display = points.length > 12
        ? points.sublist(points.length - 12)
        : points;
    final dateFmt = DateFormat('M月');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '月度趋势',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: display.isEmpty
              ? const AppEmptyState(title: '暂无趋势数据')
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: null,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final point = display[groupIndex];
                          final label = rodIndex == 0
                              ? '分期'
                              : rodIndex == 1
                              ? '自动记账'
                              : '其他';
                          final amount = rodIndex == 0
                              ? point.installmentMinor
                              : rodIndex == 1
                              ? point.autoPostingMinor
                              : point.otherMinor;
                          return BarTooltipItem(
                            '$label\n${formatMoneyMinor(amount.toInt(), currencyCode)}',
                            theme.textTheme.labelSmall!.copyWith(
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          );
                        },
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
                          reservedSize: 22,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= display.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              dateFmt.format(display[idx].bucketStart),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: null,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      for (var i = 0; i < display.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: display[i].installmentMinor.toDouble(),
                              color: moneyColors.warning,
                              width: 5,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2),
                              ),
                            ),
                            BarChartRodData(
                              toY: display[i].autoPostingMinor.toDouble(),
                              color: moneyColors.success,
                              width: 5,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2),
                              ),
                            ),
                            BarChartRodData(
                              toY: display[i].otherMinor.toDouble(),
                              color: colorScheme.primary.withValues(alpha: 0.6),
                              width: 5,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(2),
                                topRight: Radius.circular(2),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 300),
                ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: moneyColors.warning, label: '分期'),
            const SizedBox(width: 12),
            _LegendDot(color: moneyColors.success, label: '自动记账'),
            const SizedBox(width: 12),
            _LegendDot(
              color: colorScheme.primary.withValues(alpha: 0.6),
              label: '其他',
            ),
          ],
        ),
      ],
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

class _RefundSummaryRow extends StatelessWidget {
  const _RefundSummaryRow({required this.refund});

  final MoneyStatisticsRefundSummary refund;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final refundPct = '${(refund.refundRate * 100).toStringAsFixed(1)}%';

    return Row(
      children: [
        Icon(Icons.undo_rounded, size: 16, color: theme.moneyColors.warning),
        const SizedBox(width: 6),
        Text(
          '退款摘要',
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${refund.refundCount} 笔退款',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          formatMoneyMinor(refund.refundAmountMinor, defaultMoneyCurrencyCode),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.moneyColors.warning,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const Spacer(),
        Text(
          '退款率 $refundPct',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
