import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/application/money_report_period.dart';
import 'package:miji/features/bookkeeping/domain/money_analysis_report_entity.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_report_settings_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/money_text.dart';

class MoneyReportCard extends ConsumerWidget {
  const MoneyReportCard({
    super.key,
    required this.latestReport,
    required this.isGenerating,
    required this.period,
    required this.onPeriodChanged,
    required this.onGenerate,
    this.ledgerId,
  });

  final MoneyAnalysisReportEntity? latestReport;
  final bool isGenerating;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onGenerate;
  final String? ledgerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final failed = latestReport?.status == 'failed';
    final option = MoneyReportPeriodOption.fromValue(period);
    return AppContentPanel(
      title: '分析报表',
      subtitle: '${option.label}收支报告',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSlidingSegmentedControl<String>(
            minSegmentWidth: 64,
            value: period,
            onChanged: (value) => onPeriodChanged(value),
            segments: [
              for (final item in MoneyReportPeriodOption.values)
                AppSlidingSegment<String>(value: item.value, label: item.label),
            ],
          ),
          const SizedBox(height: 12),
          if (failed) ...[
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '上次生成失败，请重试'
                    '${_failureSuffix(latestReport)}。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ] else if (latestReport != null) ...[
            _ReportSummary(report: latestReport!),
            const SizedBox(height: 14),
          ] else ...[
            AppEmptyState(
              title: '暂无报告',
              message: '生成${option.label}后，这里会显示收支摘要。',
            ),
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
              label: Text(
                failed
                    ? '重新生成${option.label}'
                    : isGenerating
                    ? '生成中...'
                    : '生成${option.label}',
              ),
            ),
          ),
          if (ledgerId != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showAppResponsiveDialog<bool>(
                  context: context,
                  builder: (context) =>
                      MoneyReportSettingsDialog(ledgerId: ledgerId!),
                ),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('自动生成设置'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _failureSuffix(MoneyAnalysisReportEntity? report) {
    final message = report?.errorMessage?.trim();
    if (message == null || message.isEmpty) {
      return '';
    }
    const maxLength = 60;
    final singleLine = message.replaceAll('\n', ' ');
    final snippet = singleLine.length > maxLength
        ? '${singleLine.substring(0, maxLength)}…'
        : singleLine;
    return '（$snippet）';
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
                value: maskedMoneyOr(
                  formatMoneyMinor(snapshot.incomeMinor, snapshot.currencyCode),
                  MoneyPrivacy.of(context),
                ),
                color: moneyColors.income,
              ),
              const SizedBox(width: 10),
              _MetricChip(
                label: '支出',
                value: maskedMoneyOr(
                  formatMoneyMinor(
                    snapshot.expenseMinor,
                    snapshot.currencyCode,
                  ),
                  MoneyPrivacy.of(context),
                ),
                color: moneyColors.expense,
              ),
              const SizedBox(width: 10),
              _MetricChip(
                label: '净额',
                value: maskedMoneyOr(
                  formatMoneyMinor(snapshot.netMinor, snapshot.currencyCode),
                  MoneyPrivacy.of(context),
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
                      maskedMoneyOr(
                        formatMoneyMinor(
                          cat.amountMinor,
                          snapshot.currencyCode,
                        ),
                        MoneyPrivacy.of(context),
                      ),
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
