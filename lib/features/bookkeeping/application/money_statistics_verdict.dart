import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

/// 一句话结论。
///
/// 统计页原来是「两张大数字卡 + 趋势图」，用户得自己算「比上期多了还是少了」。
/// 这里把统计结果压成一句人话，放在首屏最上方（首页的洞察条是同一个思路）。
class StatisticsVerdict {
  const StatisticsVerdict({required this.text, required this.tone});

  final String text;

  /// positive = 比上期好（花得更少 / 赚得更多）；negative = 变差；neutral = 持平或没有基准。
  final StatisticsTone tone;
}

enum StatisticsTone { positive, negative, neutral }

/// 生成结论；数据不足时返回 null（调用方不渲染结论条）。
StatisticsVerdict? buildStatisticsVerdict({
  required MoneyStatisticsSummary summary,
  required MoneyStatisticsTypeFocus typeFocus,
  int anomalyCount = 0,
  bool masked = false,
}) {
  if (summary.isEmpty) {
    return null;
  }

  final isIncomeFocus = typeFocus == MoneyStatisticsTypeFocus.income;
  final currentMinor = isIncomeFocus
      ? summary.totalIncomeMinor
      : summary.totalExpenseMinor;
  if (currentMinor <= 0 && anomalyCount == 0) {
    return null;
  }

  final label = isIncomeFocus ? '收入' : '支出';
  final money = masked
      ? '••••'
      : formatMoneyMinor(currentMinor, summary.currencyCode);
  final parts = <String>['$label $money'];

  final baselineMinor = isIncomeFocus
      ? summary.previousPeriod.incomeMinor
      : summary.previousPeriod.expenseMinor;
  final tone = _toneFor(
    currentMinor: currentMinor,
    baselineMinor: baselineMinor,
    isIncomeFocus: isIncomeFocus,
  );

  if (baselineMinor > 0) {
    final delta = currentMinor - baselineMinor;
    if (delta == 0) {
      parts.add('与上期持平');
    } else {
      final percent = (delta.abs() / baselineMinor * 100).round();
      final arrow = delta > 0 ? '↑' : '↓';
      // 支出下降 / 收入上升是「好消息」，措辞上先说方向再说幅度。
      parts.add('较上期 $arrow$percent%');
    }
  }

  if (!isIncomeFocus) {
    final top = _topCategory(summary);
    if (top != null) {
      parts.add(
        '最大头是 ${top.categoryName}（${masked ? '••••' : formatMoneyMinor(top.amountMinor, summary.currencyCode)}'
        '，${(top.percentage * 100).toStringAsFixed(0)}%）',
      );
    }
  }

  if (anomalyCount > 0) {
    parts.add('$anomalyCount 项异常波动');
  }

  return StatisticsVerdict(text: parts.join(' · '), tone: tone);
}

MoneyStatisticsCategorySlice? _topCategory(MoneyStatisticsSummary summary) {
  if (summary.expenseCategories.isEmpty) {
    return null;
  }
  var top = summary.expenseCategories.first;
  for (final slice in summary.expenseCategories) {
    if (slice.amountMinor > top.amountMinor) {
      top = slice;
    }
  }
  return top;
}

StatisticsTone _toneFor({
  required int currentMinor,
  required int baselineMinor,
  required bool isIncomeFocus,
}) {
  if (baselineMinor <= 0 || currentMinor == baselineMinor) {
    return StatisticsTone.neutral;
  }
  final increased = currentMinor > baselineMinor;
  if (isIncomeFocus) {
    return increased ? StatisticsTone.positive : StatisticsTone.negative;
  }
  // 支出：变少是好事。
  return increased ? StatisticsTone.negative : StatisticsTone.positive;
}
