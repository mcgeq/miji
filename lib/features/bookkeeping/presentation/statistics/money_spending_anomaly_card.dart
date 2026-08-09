import 'package:flutter/material.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';

class MoneySpendingAnomalyCard extends StatelessWidget {
  const MoneySpendingAnomalyCard({
    super.key,
    required this.analysis,
    required this.minimumAmountMinor,
    required this.minimumGrowthPercent,
    required this.onThresholdChanged,
  });

  final MoneySpendingAnalysis analysis;
  final int minimumAmountMinor;
  final double minimumGrowthPercent;
  final void Function(int amountMinor, double growthPercent) onThresholdChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expenseColor = theme.moneyColors.expense;

    return AppContentPanel(
      title: '消费变化',
      subtitle: _comparisonLabel(analysis),
      leadingIcon: Icons.query_stats_rounded,
      leadingColor: expenseColor,
      trailing: TextButton.icon(
        onPressed: () => _openThresholdDialog(context),
        icon: const Icon(Icons.tune_rounded, size: 16),
        label: const Text('阈值'),
      ),
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
              message: '所选周期内没有达到展示阈值的分类、子分类或商家。',
            ),
    );
  }

  void _openThresholdDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _ThresholdDialog(
        minimumAmountMinor: minimumAmountMinor,
        minimumGrowthPercent: minimumGrowthPercent,
        onApply: onThresholdChanged,
      ),
    );
  }

  String _comparisonLabel(MoneySpendingAnalysis analysis) {
    final window = analysis.windowMonthCount;
    final baseline = analysis.baselineMonthCount;
    final percentText = minimumGrowthPercent.toStringAsFixed(0);
    final amountText = formatMoneyMinor(
      minimumAmountMinor,
      analysis.currencyCode,
    );
    if (window <= 1) {
      return '当前月较前三个月均值增长超过 $percentText% 且金额不低于 $amountText';
    }
    return '近 $window 个月较此前 $baseline 个月均值增长超过 $percentText% 且金额不低于 $amountText';
  }
}

class _ThresholdDialog extends StatefulWidget {
  const _ThresholdDialog({
    required this.minimumAmountMinor,
    required this.minimumGrowthPercent,
    required this.onApply,
  });

  final int minimumAmountMinor;
  final double minimumGrowthPercent;
  final void Function(int amountMinor, double growthPercent) onApply;

  @override
  State<_ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<_ThresholdDialog> {
  late int _amountMinor;
  late double _growthPercent;

  @override
  void initState() {
    super.initState();
    _amountMinor = widget.minimumAmountMinor;
    _growthPercent = widget.minimumGrowthPercent;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppDialogScaffold(
      title: '消费变化阈值',
      maxWidth: 380,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '最低金额 ${formatMoneyMinor(_amountMinor, 'CNY')}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            Slider(
              value: _amountMinor.toDouble().clamp(500, 100000),
              min: 500,
              max: 100000,
              divisions: 199,
              label: formatMoneyMinor(_amountMinor, 'CNY'),
              onChanged: (value) {
                setState(() => _amountMinor = (value / 500).round() * 500);
              },
            ),
            const SizedBox(height: 12),
            Text(
              '增长阈值 ${_growthPercent.toStringAsFixed(0)}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            Slider(
              value: _growthPercent.clamp(5, 200),
              min: 5,
              max: 200,
              divisions: 39,
              label: '${_growthPercent.toStringAsFixed(0)}%',
              onChanged: (value) {
                setState(() => _growthPercent = value.roundToDouble());
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_amountMinor, _growthPercent);
            Navigator.of(context).pop();
          },
          child: const Text('应用'),
        ),
      ],
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
