import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';

class MoneySpendingAnomalyCard extends StatelessWidget {
  const MoneySpendingAnomalyCard({super.key, required this.analysis});

  final MoneySpendingAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseColor = theme.moneyColors.expense;

    return AppContentPanel(
      title: '消费变化',
      subtitle: '当前月较前三个月均值增长超过 20%',
      leadingIcon: Icons.query_stats_rounded,
      leadingColor: expenseColor,
      child: analysis.hasAnomalies
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final anomaly in analysis.anomalies.take(5))
                  _AnomalyRow(
                    anomaly: anomaly,
                    currencyCode: analysis.currencyCode,
                  ),
              ],
            )
          : const AppEmptyState(
              title: '暂无明显消费变化',
              message: '当前月没有达到展示阈值的分类、子分类或商家。',
            ),
    );
  }
}

class _AnomalyRow extends StatelessWidget {
  const _AnomalyRow({required this.anomaly, required this.currencyCode});

  final MoneySpendingAnomaly anomaly;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final expenseColor = theme.moneyColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _iconFor(anomaly.dimension),
              size: 17,
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  anomaly.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_dimensionLabel(anomaly.dimension)} · 均值 ${formatMoneyMinor(anomaly.baselineAverageMinor, currencyCode)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMoneyMinor(anomaly.currentAmountMinor, currencyCode),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '+${anomaly.growthPercent.toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: expenseColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _iconFor(MoneySpendingAnalysisDimension dimension) {
    return switch (dimension) {
      MoneySpendingAnalysisDimension.category => Icons.category_rounded,
      MoneySpendingAnalysisDimension.subCategory => Icons.account_tree_rounded,
      MoneySpendingAnalysisDimension.merchant => Icons.storefront_rounded,
    };
  }

  String _dimensionLabel(MoneySpendingAnalysisDimension dimension) {
    return switch (dimension) {
      MoneySpendingAnalysisDimension.category => '分类',
      MoneySpendingAnalysisDimension.subCategory => '子分类',
      MoneySpendingAnalysisDimension.merchant => '商家',
    };
  }
}
