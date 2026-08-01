import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';

class MoneyReportCard extends StatelessWidget {
  const MoneyReportCard({
    super.key,
    required this.latestReport,
    required this.isGenerating,
    required this.onGenerate,
  });

  final MoneyAnalysisReportEntity? latestReport;
  final bool isGenerating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return AppContentPanel(
      title: '分析报表',
      subtitle: '月度收支报告',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latestReport != null) ...[
            _ReportSummary(report: latestReport!),
            const SizedBox(height: 14),
          ] else ...[
            AppEmptyState(title: '暂无报告', message: '生成月度报表后，这里会显示收支摘要。'),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isGenerating ? null : onGenerate,
              icon: isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(isGenerating ? '生成中...' : '生成本月报表'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportSummary extends StatelessWidget {
  const _ReportSummary({required this.report});

  final MoneyAnalysisReportEntity report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;

    MoneyAnalysisReportSnapshot? snapshot;
    try {
      final json = jsonDecode(report.reportDataJson) as Map<String, dynamic>;
      snapshot = MoneyAnalysisReportSnapshot.fromJson(json);
    } catch (_) {
      // JSON parse failed — show minimal info
    }

    final dateFmt = DateFormat('M月d日');
    final periodLabel =
        '${dateFmt.format(report.periodStart)} ~ ${dateFmt.format(report.periodEnd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '最新报告',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              periodLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        if (snapshot != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              _MetricChip(
                label: '收入',
                value: formatMoneyMinor(
                  snapshot.incomeMinor,
                  snapshot.currencyCode,
                ),
                color: moneyColors.income,
              ),
              const SizedBox(width: 10),
              _MetricChip(
                label: '支出',
                value: formatMoneyMinor(
                  snapshot.expenseMinor,
                  snapshot.currencyCode,
                ),
                color: moneyColors.expense,
              ),
              const SizedBox(width: 10),
              _MetricChip(
                label: '净额',
                value: formatMoneyMinor(
                  snapshot.netMinor,
                  snapshot.currencyCode,
                ),
                color: snapshot.netMinor >= 0
                    ? moneyColors.success
                    : moneyColors.expense,
              ),
            ],
          ),
          if (snapshot.expenseByCategory.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '支出前 3 分类',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            for (final cat in snapshot.expenseByCategory.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        cat.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Text(
                      formatMoneyMinor(cat.amountMinor, snapshot.currencyCode),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '预算执行率 ${(snapshot.budgetUsageRate * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: snapshot.budgetUsageRate >= 1.0
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              if (snapshot.overspentBudgetCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '${snapshot.overspentBudgetCount} 项超支',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
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
