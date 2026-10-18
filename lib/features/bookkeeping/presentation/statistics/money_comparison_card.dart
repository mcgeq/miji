import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_content_panel.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

/// 独立的环比 / 同比对比卡。
///
/// 原来「比上月多花多少」只以两个小 chip 的形式挂在收支总览里，而且是
/// 净额口径——用户真正想问的「哪个分类涨得最快」没有地方看。这里把它做成
/// 一张独立卡：三个总量指标 + 分类维度的涨跌榜，每行可点进对应流水。
class MoneyComparisonCard extends StatelessWidget {
  const MoneyComparisonCard({
    super.key,
    required this.summary,
    required this.previousSummary,
    required this.typeFocus,
    required this.periodLabel,
    this.onCategoryTap,
  });

  final MoneyStatisticsSummary summary;
  final MoneyStatisticsSummary? previousSummary;

  /// 决定分类榜取支出还是收入。
  final MoneyStatisticsTypeFocus typeFocus;
  final String periodLabel;

  /// 点击分类时回调，参数为分类 id 与名称。
  final void Function(String categoryId, String categoryName)? onCategoryTap;

  bool get _isIncome => typeFocus == MoneyStatisticsTypeFocus.income;

  List<MoneyStatisticsCategorySlice> _categoriesOf(
    MoneyStatisticsSummary value,
  ) {
    return _isIncome ? value.incomeCategories : value.expenseCategories;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previous = previousSummary;
    final previousTotals = previous == null
        ? null
        : (previous.totalIncomeMinor, previous.totalExpenseMinor);

    final rows = <_MetricRow>[
      _MetricRow(
        label: '收入',
        currentMinor: summary.totalIncomeMinor,
        previousMinor: previousTotals?.$1,
        sameYearMinor: summary.samePeriodLastYear.incomeMinor,
        // 收入涨是好事。
        higherIsBetter: true,
      ),
      _MetricRow(
        label: '支出',
        currentMinor: summary.totalExpenseMinor,
        previousMinor: previousTotals?.$2,
        sameYearMinor: summary.samePeriodLastYear.expenseMinor,
        // 支出涨是坏事。
        higherIsBetter: false,
      ),
      _MetricRow(
        label: '净额',
        currentMinor: summary.netMinor,
        previousMinor: previous?.netMinor,
        sameYearMinor: summary.samePeriodLastYear.netMinor,
        higherIsBetter: true,
      ),
    ];

    final deltas = _categoryDeltas();
    final categoryTap = onCategoryTap;

    return AppContentPanel(
      title: '环比对比',
      subtitle: '$periodLabel · 对比上一个周期',
      leadingIcon: Icons.compare_arrows_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
              const SizedBox(height: 10),
            ],
            _MetricLine(row: rows[i], currencyCode: summary.currencyCode),
          ],
          if (deltas.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Text(
              _isIncome ? '收入分类变化' : '支出分类变化',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            for (final delta in deltas)
              _CategoryDeltaRow(
                delta: delta,
                currencyCode: summary.currencyCode,
                onTap: categoryTap == null
                    ? null
                    : () => categoryTap(delta.categoryId, delta.categoryName),
              ),
          ] else if (previous != null) ...[
            const SizedBox(height: 12),
            Text(
              '上一个周期没有可对比的分类数据',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 涨跌榜：涨得最多的 3 个 + 降得最多的 3 个（降序排列）。
  ///
  /// 只统计本期或上期出现过的分类，两边都是 0 的不会出现。
  List<_CategoryDelta> _categoryDeltas() {
    final previous = previousSummary;
    if (previous == null) {
      return const <_CategoryDelta>[];
    }
    final currentSlices = _categoriesOf(summary);
    final previousSlices = _categoriesOf(previous);
    final previousByCategory = <String, int>{
      for (final slice in previousSlices) slice.categoryId: slice.amountMinor,
    };

    final deltas = <_CategoryDelta>[];
    final seen = <String>{};
    for (final slice in currentSlices) {
      final before = previousByCategory[slice.categoryId] ?? 0;
      seen.add(slice.categoryId);
      final delta = slice.amountMinor - before;
      if (delta == 0) {
        continue;
      }
      deltas.add(
        _CategoryDelta(
          categoryId: slice.categoryId,
          categoryName: slice.categoryName,
          currentMinor: slice.amountMinor,
          deltaMinor: delta,
        ),
      );
    }
    // 上期有、本期归零的分类也要出现在"降得最多"里。
    for (final slice in previousSlices) {
      if (seen.contains(slice.categoryId)) {
        continue;
      }
      if (slice.amountMinor == 0) {
        continue;
      }
      deltas.add(
        _CategoryDelta(
          categoryId: slice.categoryId,
          categoryName: slice.categoryName,
          currentMinor: 0,
          deltaMinor: -slice.amountMinor,
        ),
      );
    }
    if (deltas.isEmpty) {
      return const <_CategoryDelta>[];
    }

    deltas.sort((a, b) => b.deltaMinor.abs().compareTo(a.deltaMinor.abs()));
    final rising = deltas
        .where((delta) => delta.deltaMinor > 0)
        .take(3)
        .toList();
    final falling = deltas
        .where((delta) => delta.deltaMinor < 0)
        .take(3)
        .toList();
    return <_CategoryDelta>[...rising, ...falling];
  }
}

class _MetricRow {
  const _MetricRow({
    required this.label,
    required this.currentMinor,
    required this.sameYearMinor,
    required this.higherIsBetter,
    this.previousMinor,
  });

  final String label;
  final int currentMinor;
  final int? previousMinor;
  final int sameYearMinor;
  final bool higherIsBetter;
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.row, required this.currencyCode});

  final _MetricRow row;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final previousMinor = row.previousMinor;

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            row.label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        Expanded(
          child: Text(
            maskedMoneyOr(
              formatMoneyMinor(row.currentMinor, currencyCode),
              MoneyPrivacy.of(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _DeltaChip(
          label: '上期',
          deltaMinor: previousMinor == null
              ? null
              : row.currentMinor - previousMinor,
          baselineMinor: previousMinor,
          higherIsBetter: row.higherIsBetter,
        ),
        const SizedBox(width: 6),
        _DeltaChip(
          label: '同比',
          deltaMinor: row.currentMinor - row.sameYearMinor,
          baselineMinor: row.sameYearMinor,
          higherIsBetter: row.higherIsBetter,
        ),
      ],
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.label,
    required this.deltaMinor,
    required this.baselineMinor,
    required this.higherIsBetter,
  });

  final String label;
  final int? deltaMinor;
  final int? baselineMinor;
  final bool higherIsBetter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;

    final delta = deltaMinor;
    final baseline = baselineMinor;
    String text;
    Color color;
    if (delta == null || baseline == null) {
      return const SizedBox.shrink();
    }
    if (baseline == 0) {
      text = delta == 0 ? '$label 持平' : '$label 新增';
      color = moneyColors.income;
    } else if (delta == 0) {
      text = '$label 持平';
      color = theme.colorScheme.onSurfaceVariant;
    } else {
      final percent = delta.abs() / baseline.abs() * 100;
      final precision = percent >= 10 ? 0 : 1;
      final arrow = delta > 0 ? '↑' : '↓';
      text = '$arrow${percent.toStringAsFixed(precision)}%';
      // 涨了是好事还是坏事，取决于这是收入还是支出。
      final isGood = delta > 0 ? higherIsBetter : !higherIsBetter;
      color = isGood ? moneyColors.income : moneyColors.expense;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $text',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CategoryDelta {
  const _CategoryDelta({
    required this.categoryId,
    required this.categoryName,
    required this.currentMinor,
    required this.deltaMinor,
  });

  final String categoryId;
  final String categoryName;
  final int currentMinor;
  final int deltaMinor;
}

class _CategoryDeltaRow extends StatelessWidget {
  const _CategoryDeltaRow({
    required this.delta,
    required this.currencyCode,
    this.onTap,
  });

  final _CategoryDelta delta;
  final String currencyCode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moneyColors = theme.moneyColors;
    final isUp = delta.deltaMinor > 0;
    // 这个卡固定按支出口径解读涨跌：花得多标红（花销色），花得少标绿。
    final color = isUp ? moneyColors.expense : moneyColors.income;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
          child: Row(
            children: [
              Icon(
                isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  delta.categoryName,
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
                maskedMoneyOr(
                  formatMoneyMinor(delta.currentMinor, currencyCode),
                  MoneyPrivacy.of(context),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                maskedMoneyOr(
                  '${isUp ? '+' : '-'}${formatMoneyMinor(delta.deltaMinor.abs(), currencyCode)}',
                  MoneyPrivacy.of(context),
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
