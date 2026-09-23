import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_category_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/presentation/home_overview_card.dart';

/// 首页日历视图：一个月内每天的 支出 / 收入 / 净额。
///
/// 存在的意义是回答「钱是哪天花掉的」，而周柱状图只能回答「这周比上周多还是少」。
/// 与趋势视图共用同一份按月聚合（[homeMonthDailySpendingProvider]），
/// 翻月时走的是同一个数据入口：命中选中月就复用已加载的月交易，其它月份按需查库。
///
/// 遮罩一律走 [MoneyText] / `MoneyPrivacy`，所以全局「隐藏金额」开关自动生效，
/// 不需要上层再往里传一个 masked 参数。
class HomeSpendingCalendar extends ConsumerStatefulWidget {
  const HomeSpendingCalendar({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.onOpenTransactions,
    this.onAddTransaction,
  });

  /// 当前展示的月份（月初）。
  final DateTime month;

  /// 翻月：-1 上个月，0 回到本月，1 下个月。与顶栏月份选择器是同一个状态。
  final ValueChanged<int> onMonthChanged;

  /// 「查看全部」→ 跳流水页。
  final VoidCallback onOpenTransactions;

  /// 空日「补记一笔」。
  final VoidCallback? onAddTransaction;

  @override
  ConsumerState<HomeSpendingCalendar> createState() =>
      _HomeSpendingCalendarState();
}

class _HomeSpendingCalendarState extends ConsumerState<HomeSpendingCalendar> {
  int? _selectedDay;

  @override
  void didUpdateWidget(HomeSpendingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换月后原来的选中日不再属于当前月份。
    if (oldWidget.month.year != widget.month.year ||
        oldWidget.month.month != widget.month.month) {
      _selectedDay = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final masked = MoneyPrivacy.of(context);
    final summaryAsync = ref.watch(
      homeMonthDailySpendingProvider(widget.month),
    );
    final summary = summaryAsync.asData?.value;
    final isLoading = summaryAsync.isLoading && summary == null;

    final dayCount = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final leadingBlanks = DateTime(
      widget.month.year,
      widget.month.month,
    ).weekday;
    final leadingBlanks0 = leadingBlanks - 1;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCurrentMonth =
        today.year == widget.month.year && today.month == widget.month.month;
    final rows = ((leadingBlanks0 + dayCount) / 7).ceil();

    return HomeOverviewPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MonthHeader(
            month: widget.month,
            isCurrentMonth: isCurrentMonth,
            netMinor: summary?.netMinor ?? 0,
            isLoading: isLoading,
            onMonthChanged: widget.onMonthChanged,
          ),
          const SizedBox(height: 10),
          // 注意：加载中**不能**把整块网格换成骨架屏。
          // 骨架屏比网格矮一大截，AnimatedSize 会先把整卡压扁、数据到了再撑回来，
          // 看起来就是「翻个月卡片先缩小再恢复」。这里网格始终占位，
          // 只有格子里的数字位置显示骨架。
          // 宽屏（8/4 分栏）下主栏很宽，格子会跟着被撑成方块、
          // 整张卡被顶到 570dp 以上。这里给网格一个宽度上限，保持格子尺寸稳定。
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 396),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _WeekdayHeader(),
                  const SizedBox(height: 5),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.2,
                        ),
                    itemCount: rows * 7,
                    itemBuilder: (context, index) {
                      final day = index - leadingBlanks0 + 1;
                      if (day < 1 || day > dayCount) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime(
                        widget.month.year,
                        widget.month.month,
                        day,
                      );
                      return _DayCell(
                        day: day,
                        isLoading: isLoading,
                        point: summary?.pointForDay(day),
                        averageExpenseMinor:
                            summary?.dailyAverageExpenseMinor ?? 0,
                        isToday: isCurrentMonth && date == today,
                        isFuture: date.isAfter(today),
                        selected: _selectedDay == day,
                        masked: masked,
                        onTap: () => setState(
                          () => _selectedDay = _selectedDay == day ? null : day,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_selectedDay != null) ...[
            const SizedBox(height: 12),
            _DayDetailPanel(
              month: widget.month,
              day: _selectedDay!,
              summary: summary,
              onOpenTransactions: widget.onOpenTransactions,
              onAddTransaction: widget.onAddTransaction,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '格子里的数字是当日净额（收入为正、支出为负），点某天看明细',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 月份标题 + 左右翻月 + 「回到本月」+ 本月净额。
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.isCurrentMonth,
    required this.netMinor,
    required this.isLoading,
    required this.onMonthChanged,
  });

  final DateTime month;
  final bool isCurrentMonth;
  final int netMinor;
  final bool isLoading;
  final ValueChanged<int> onMonthChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final masked = MoneyPrivacy.of(context);

    return Row(
      children: [
        _MonthArrow(
          icon: Icons.chevron_left_rounded,
          tooltip: '上个月',
          onTap: () => onMonthChanged(-1),
        ),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
            // 不在本月时，点标题直接回到本月。
            onTap: isCurrentMonth ? null : () => onMonthChanged(0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${month.year}年${month.month}月',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  if (!isCurrentMonth) ...[
                    const SizedBox(width: 6),
                    Text(
                      '回到本月',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        _MonthArrow(
          icon: Icons.chevron_right_rounded,
          tooltip: '下个月',
          onTap: () => onMonthChanged(1),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '本月净额',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            // 用与格子同一套紧凑写法：完整格式（¥12,345.00）会把表头挤爆。
            if (isLoading)
              const AppSkeletonBox(width: 46, height: 16, radius: 6)
            else
              Text(
                masked ? '••••' : formatCompactSignedAmount(netMinor),
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  color: netMinor >= 0
                      ? moneyColors.income
                      : moneyColors.expense,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        for (final label in const ['一', '二', '三', '四', '五', '六', '日'])
          Expanded(
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 单个日期格：日号 + 当日净额，底色深浅表示支出强度。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isLoading,
    required this.point,
    required this.averageExpenseMinor,
    required this.isToday,
    required this.isFuture,
    required this.selected,
    required this.masked,
    required this.onTap,
  });

  final int day;
  final bool isLoading;
  final HomeDailySpendingPoint? point;
  final int averageExpenseMinor;
  final bool isToday;
  final bool isFuture;
  final bool selected;
  final bool masked;
  final VoidCallback onTap;

  /// 支出强度：相对本月日均，落到 1..4 档。
  int _intensityStep(int expenseMinor) {
    if (expenseMinor <= 0) {
      return 0;
    }
    final base = averageExpenseMinor > 0 ? averageExpenseMinor : expenseMinor;
    final ratio = expenseMinor / base;
    if (ratio <= 0.5) {
      return 1;
    }
    if (ratio <= 1) {
      return 2;
    }
    if (ratio <= 1.6) {
      return 3;
    }
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final point = this.point;
    final isEmpty = point == null || point.transactionCount == 0;
    final net = point?.netMinor ?? 0;
    final isIncome = !isEmpty && net > 0;

    // 支出越重底色越深（4 档）；收入日固定用收入色淡底。
    final Color background;
    if (isEmpty) {
      background = colorScheme.surfaceContainerHighest.withValues(alpha: 0.40);
    } else if (isIncome) {
      background = moneyColors.income.withValues(alpha: 0.14);
    } else {
      background = moneyColors.expense.withValues(
        alpha: switch (_intensityStep(point.expenseMinor)) {
          1 => 0.07,
          2 => 0.12,
          3 => 0.18,
          _ => 0.24,
        },
      );
    }

    final border = selected
        ? Border.all(color: colorScheme.primary, width: 1.6)
        : isToday
        ? Border.all(color: colorScheme.primary.withValues(alpha: 0.65))
        : Border.all(
            color: isFuture
                ? colorScheme.outlineVariant.withValues(alpha: 0.45)
                : Colors.transparent,
          );

    final amountColor = isEmpty
        ? colorScheme.onSurfaceVariant
        : isIncome
        ? moneyColors.income
        : moneyColors.expense;

    final amountLabel = masked
        ? '••'
        : isEmpty
        ? '—'
        : formatCompactSignedAmount(net);

    return Semantics(
      button: !isFuture,
      label: '$day 日${isEmpty ? '没有记录' : ''}${masked ? '，金额已隐藏' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: isFuture ? null : onTap,
        child: Opacity(
          opacity: isFuture ? 0.4 : 1,
          child: Container(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: border,
            ),
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
            // 格子是固定宽高比，而系统字体可以放大到 1.5 倍以上：
            // 外层 FittedBox 保证「日号 + 金额」两行永远缩得进格子，不会溢出。
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$day',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10.5,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: isToday
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 1),
                    if (isLoading)
                      // 骨架占位保持格子高度不变（翻月时不抖）。
                      const AppSkeletonBox(width: 22, height: 9, radius: 4)
                    else
                      Text(
                        amountLabel,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: amountColor,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 某一天的明细：支出 / 收入 / 净额 / 笔数 + 当日流水。
class _DayDetailPanel extends ConsumerWidget {
  const _DayDetailPanel({
    required this.month,
    required this.day,
    required this.summary,
    required this.onOpenTransactions,
    required this.onAddTransaction,
  });

  final DateTime month;
  final int day;
  final HomeMonthlyDailySpending? summary;
  final VoidCallback onOpenTransactions;
  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final point = summary?.pointForDay(day);
    final transactions =
        summary?.transactionsForDay(day) ?? const <MoneyTransactionEntity>[];
    final date = DateTime(month.year, month.month, day);

    final expenseCatalog = ref
        .watch(currentUserCategoryCatalogProvider(MoneyCategoryKind.expense))
        .asData
        ?.value;
    final incomeCatalog = ref
        .watch(currentUserCategoryCatalogProvider(MoneyCategoryKind.income))
        .asData
        ?.value;
    final netMinor = point?.netMinor ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${month.month}月$day日 · ${_weekdayLabel(date.weekday)}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                '${transactions.length} 笔',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _DayMetric(
                label: '支出',
                amountMinor: point?.expenseMinor ?? 0,
                color: moneyColors.expense,
              ),
              _DayMetric(
                label: '收入',
                amountMinor: point?.incomeMinor ?? 0,
                color: moneyColors.income,
              ),
              _DayMetric(
                label: '净额',
                amountMinor: netMinor,
                color: netMinor >= 0 ? moneyColors.income : moneyColors.expense,
                showSign: true,
              ),
            ],
          ),
          if (transactions.isEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '这天没有记账',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                if (onAddTransaction != null)
                  TextButton(
                    onPressed: onAddTransaction,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    child: const Text('补记一笔'),
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            for (final transaction in transactions.take(3))
              _DayTransactionRow(
                transaction: transaction,
                categoryName: _categoryName(
                  transaction,
                  expenseCatalog: expenseCatalog,
                  incomeCatalog: incomeCatalog,
                ),
              ),
            if (transactions.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenTransactions,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text('查看全部 ${transactions.length} 笔'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _weekdayLabel(int weekday) {
    return const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
  }

  static String _categoryName(
    MoneyTransactionEntity transaction, {
    required MoneyCategoryCatalog? expenseCatalog,
    required MoneyCategoryCatalog? incomeCatalog,
  }) {
    if (transaction.type == MoneyTransactionType.transfer) {
      return '转账';
    }
    final catalog = transaction.type == MoneyTransactionType.income
        ? incomeCatalog
        : expenseCatalog;
    return catalog?.categoryById(transaction.categoryId)?.name ??
        transaction.type.label;
  }
}

class _DayMetric extends StatelessWidget {
  const _DayMetric({
    required this.label,
    required this.amountMinor,
    required this.color,
    this.showSign = false,
  });

  final String label;
  final int amountMinor;
  final Color color;
  final bool showSign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          MoneyText(
            amountMinor: amountMinor,
            showSign: showSign,
            textStyle: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayTransactionRow extends StatelessWidget {
  const _DayTransactionRow({
    required this.transaction,
    required this.categoryName,
  });

  final MoneyTransactionEntity transaction;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final moneyColors = theme.moneyColors;
    final note = transaction.description.trim();
    final isTransfer = transaction.type == MoneyTransactionType.transfer;
    final isIncome = transaction.type == MoneyTransactionType.income;
    final color = isTransfer
        ? colorScheme.onSurfaceVariant
        : isIncome
        ? moneyColors.income
        : moneyColors.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              note.isEmpty ? categoryName : '$categoryName · $note',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          MoneyText(
            amountMinor: effectiveMoneyAmountMinor(transaction),
            showSign: !isTransfer,
            textStyle: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 日历格子里的紧凑带符号金额：整数元、千分位、万位缩写。
///
/// 390dp 屏幕上每格约 43dp 宽，放不下 `-¥1,240.50` 这种完整写法，
/// 所以格子里只用来「扫一眼」，精确金额在点开的日详情里。
String formatCompactSignedAmount(int amountMinor) {
  final yuan = amountMinor / 100;
  final sign = yuan < 0 ? '-' : '+';
  final abs = yuan.abs();
  if (abs >= 10000) {
    return '$sign${(abs / 10000).toStringAsFixed(1)}万';
  }
  final digits = abs.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[index]);
  }
  return '$sign$buffer';
}
