import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

class MoneyCreditUtilizationCard extends StatelessWidget {
  const MoneyCreditUtilizationCard({super.key, required this.insights});

  final MoneyStatisticsInsights insights;

  static const _warningThreshold = 0.9;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (insights.creditUtilization.isEmpty) {
      return AppContentPanel(
        title: '信用使用率',
        subtitle: '信用账户额度与已用',
        child: const AppEmptyState(
          title: '暂无信用账户',
          message: '添加信用卡、花呗等信用账户后，这里会显示使用率。',
        ),
      );
    }

    final totalLimitMinor = insights.creditUtilization.fold<int>(
      0,
      (sum, slice) => sum + slice.creditLimitMinor,
    );
    final totalUsedMinor = insights.creditUtilization.fold<int>(
      0,
      (sum, slice) => sum + slice.usedMinor,
    );
    final totalAvailableMinor = totalLimitMinor - totalUsedMinor;
    final overallUtilization = totalLimitMinor <= 0
        ? 0.0
        : totalUsedMinor / totalLimitMinor;
    final isWarning = overallUtilization >= _warningThreshold;
    final utilizationPct = '${(overallUtilization * 100).toStringAsFixed(1)}%';

    final currencyCode = insights.creditUtilization.first.currencyCode;

    return AppContentPanel(
      title: '信用使用率',
      subtitle: '信用账户额度与已用',
      leadingWidget: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (isWarning ? colorScheme.error : colorScheme.primary)
              .withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.credit_card_rounded,
          size: 16,
          color: isWarning ? colorScheme.error : colorScheme.primary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SummaryMetric(
            label: '总额度',
            value: formatMoneyMinor(totalLimitMinor, currencyCode),
            color: colorScheme.primary,
          ),
          _SummaryMetric(
            label: '已用',
            value: formatMoneyMinor(totalUsedMinor, currencyCode),
            color: theme.moneyColors.expense,
          ),
          _SummaryMetric(
            label: '可用',
            value: formatMoneyMinor(totalAvailableMinor, currencyCode),
            color: isWarning ? colorScheme.error : theme.moneyColors.success,
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 24,
              value: overallUtilization.clamp(0.0, 1.0),
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                isWarning ? colorScheme.error : colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '综合使用率 $utilizationPct',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isWarning
                  ? colorScheme.error
                  : colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          if (insights.creditUtilization.length > 1) ...[
            const SizedBox(height: 18),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 10),
            for (var i = 0; i < insights.creditUtilization.length; i++)
              _AccountRow(
                slice: insights.creditUtilization[i],
                showDivider: i < insights.creditUtilization.length - 1,
              ),
          ],
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.slice, required this.showDivider});

  final MoneyStatisticsCreditUtilizationSlice slice;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWarning =
        slice.utilization >= MoneyCreditUtilizationCard._warningThreshold;
    final pct = '${(slice.utilization * 100).toStringAsFixed(1)}%';

    return Column(
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
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMoneyMinor(slice.usedMinor, slice.currencyCode),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isWarning ? colorScheme.error : colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            Text(
              ' / ${formatMoneyMinor(slice.creditLimitMinor, slice.currencyCode)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: slice.utilization.clamp(0.0, 1.0),
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              isWarning ? colorScheme.error : colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '可用 ${formatMoneyMinor(slice.availableMinor, slice.currencyCode)} · $pct',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
