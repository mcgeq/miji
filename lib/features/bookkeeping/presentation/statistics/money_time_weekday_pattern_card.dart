import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyTimeWeekdayPatternCard extends StatelessWidget {
  const MoneyTimeWeekdayPatternCard({super.key, required this.insights});

  final MoneyStatisticsInsights insights;

  static const _weekdayLabels = <String>[
    '周一',
    '周二',
    '周三',
    '周四',
    '周五',
    '周六',
    '周日',
  ];

  @override
  Widget build(BuildContext context) {
    final hasTimeData = insights.timeSlices.any((s) => s.amountMinor > 0);
    final hasWeekdayData = insights.weekdaySlices.any((s) => s.amountMinor > 0);

    if (!hasTimeData && !hasWeekdayData) {
      return AppContentPanel(
        title: '消费时段',
        subtitle: '按时间段和星期分布',
        child: const AppEmptyState(title: '暂无消费时段数据', message: '此时间范围内没有支出记录。'),
      );
    }

    return AppContentPanel(
      title: '消费时段',
      subtitle: '按时间段和星期分布',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasTimeData) ...[
            _SectionLabel(label: '时段分布'),
            const SizedBox(height: 6),
            _TimeDistribution(
              slices: insights.timeSlices,
              currencyCode: insights.currencyCode,
            ),
          ],
          if (hasTimeData && hasWeekdayData) const SizedBox(height: 18),
          if (hasWeekdayData) ...[
            _SectionLabel(label: '星期分布'),
            const SizedBox(height: 6),
            _WeekdayDistribution(
              slices: insights.weekdaySlices,
              currencyCode: insights.currencyCode,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _TimeDistribution extends StatelessWidget {
  const _TimeDistribution({required this.slices, required this.currencyCode});

  final List<MoneyStatisticsTimeSlice> slices;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final maxAmount = slices.fold<int>(
      1,
      (m, s) => s.amountMinor > m ? s.amountMinor : m,
    );
    final sorted = List<MoneyStatisticsTimeSlice>.from(slices)
      ..sort((a, b) => a.bucket.startHour.compareTo(b.bucket.startHour));

    return Column(
      children: [
        for (final slice in sorted)
          _TimeBar(
            label: slice.bucket.label,
            amountMinor: slice.amountMinor,
            transactionCount: slice.transactionCount,
            percentage: slice.percentage,
            currencyCode: currencyCode,
            maxAmount: maxAmount,
          ),
      ],
    );
  }
}

class _TimeBar extends StatelessWidget {
  const _TimeBar({
    required this.label,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
    required this.currencyCode,
    required this.maxAmount,
  });

  final String label;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
  final String currencyCode;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = (amountMinor / maxAmount).clamp(0.04, 1.0).toDouble();
    final pct = '${(percentage * 100).toStringAsFixed(1)}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  label,
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.moneyColors.expense,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 100,
                child: Text(
                  formatMoneyMinor(amountMinor, currencyCode),
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
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              '$transactionCount 笔 · $pct',
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

class _WeekdayDistribution extends StatelessWidget {
  const _WeekdayDistribution({
    required this.slices,
    required this.currencyCode,
  });

  final List<MoneyStatisticsWeekdaySlice> slices;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final maxAmount = slices.fold<int>(
      1,
      (m, s) => s.amountMinor > m ? s.amountMinor : m,
    );

    return Column(
      children: [
        for (var i = 0; i < slices.length; i++)
          _WeekdayBar(
            label: MoneyTimeWeekdayPatternCard._weekdayLabels[i],
            amountMinor: slices[i].amountMinor,
            transactionCount: slices[i].transactionCount,
            percentage: slices[i].percentage,
            isWeekend: slices[i].isWeekend,
            currencyCode: currencyCode,
            maxAmount: maxAmount,
          ),
      ],
    );
  }
}

class _WeekdayBar extends StatelessWidget {
  const _WeekdayBar({
    required this.label,
    required this.amountMinor,
    required this.transactionCount,
    required this.percentage,
    required this.isWeekend,
    required this.currencyCode,
    required this.maxAmount,
  });

  final String label;
  final int amountMinor;
  final int transactionCount;
  final double percentage;
  final bool isWeekend;
  final String currencyCode;
  final int maxAmount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ratio = (amountMinor / maxAmount).clamp(0.04, 1.0).toDouble();
    final pct = '${(percentage * 100).toStringAsFixed(1)}%';
    final barColor = isWeekend
        ? theme.moneyColors.warning
        : colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isWeekend
                        ? theme.moneyColors.warning
                        : colorScheme.onSurface,
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
                  formatMoneyMinor(amountMinor, currencyCode),
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
            padding: const EdgeInsets.only(left: 52),
            child: Text(
              '$transactionCount 笔 · $pct',
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
