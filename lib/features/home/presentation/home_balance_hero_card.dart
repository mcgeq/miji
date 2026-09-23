import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// 首页主角卡片：回答「这个月我还能花多少」。
///
/// - 有预算：展示剩余可花 + 预算环形进度 + 时间/花费双轨进度条
/// - 无预算：退化为「本月结余」，并给出设置预算入口
class HomeBalanceHeroCard extends StatelessWidget {
  const HomeBalanceHeroCard({
    super.key,
    required this.budget,
    required this.today,
    required this.categoryBudgets,
    required this.isLoading,
    required this.masked,
    this.onTapBudget,
  });

  final HomeMonthBudgetSummary? budget;
  final HomeTodaySpendingSummary? today;
  final HomeCategoryBudgetSummary? categoryBudgets;
  final bool isLoading;
  final bool masked;
  final VoidCallback? onTapBudget;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = budget;
    final spending = today ?? const HomeTodaySpendingSummary.empty();
    final hasBudget = summary?.hasBudget ?? false;
    final exceeded = hasBudget && (summary!.progress >= 1);
    final gradient = _heroGradient(theme, exceeded: exceeded);
    final onHero = Colors.white;

    return Semantics(
      label: hasBudget ? '本月预算概览' : '本月概览',
      container: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
          gradient: gradient.linear,
          boxShadow: [
            BoxShadow(
              color: gradient.shadow.withValues(alpha: 0.32),
              blurRadius: 28,
              offset: const Offset(0, 14),
              spreadRadius: -16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
          child: Stack(
            children: [
              Positioned(
                right: -60,
                top: -80,
                child: _Glow(size: 200, opacity: 0.13),
              ),
              Positioned(
                right: 40,
                bottom: -100,
                child: _Glow(size: 160, opacity: 0.08),
              ),
              Padding(
                padding: EdgeInsets.all(theme.spacingTokens.cardPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      hasBudget: hasBudget,
                      paceLabel: summary?.paceLabel,
                      exceeded: exceeded,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 14),
                    _MainRow(
                      hasBudget: hasBudget,
                      exceeded: exceeded,
                      summary: summary,
                      spending: spending,
                      masked: masked,
                      progress: summary?.progress ?? 0,
                    ),
                    const SizedBox(height: 16),
                    _Pills(
                      hasBudget: hasBudget,
                      spending: spending,
                      budget: summary,
                      masked: masked,
                    ),
                    if (hasBudget) ...[
                      if (categoryBudgets != null &&
                          !categoryBudgets!.isEmpty) ...[
                        const SizedBox(height: 14),
                        _CategoryBudgetBlock(
                          summary: categoryBudgets!,
                          masked: masked,
                        ),
                      ],
                      const SizedBox(height: 14),
                      _DualProgress(
                        spendProgress: summary!.progress,
                        periodProgress: summary.periodProgress,
                        exceeded: exceeded,
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onTapBudget,
                          style: TextButton.styleFrom(
                            foregroundColor: onHero,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.flag_rounded, size: 16),
                          label: const Text('设置本月预算'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 渐变改由主题提供（`AppHeroGradients`），超支时切到 danger。
  /// 原来这里每次 build 都用 colorScheme 现算三档停靠点，颜色无法复用，
  /// 也没法在主题层统一校准对比度。
  static AppHeroGradient _heroGradient(
    ThemeData theme, {
    required bool exceeded,
  }) {
    final gradients = theme.heroGradients;
    return exceeded ? gradients.danger : gradients.brand;
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.hasBudget,
    required this.paceLabel,
    required this.exceeded,
    required this.isLoading,
  });

  final bool hasBudget;
  final String? paceLabel;
  final bool exceeded;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    // 「本月预算」这个胶囊已经去掉了：它现在就是卡上方 tab 的名字，
    // 卡内再写一遍是同一句话说两次（设计稿里两个胶囊本来是并排靠左的）。
    // 左槽留给节奏状态，右侧只在加载时出现进度条。
    final pace = hasBudget && !exceeded ? (paceLabel ?? '') : '';

    return Row(
      children: [
        if (pace.isNotEmpty) _HeroChip(text: pace, dot: true),
        const Spacer(),
        if (isLoading)
          const SizedBox(
            width: 56,
            height: 3,
            child: LinearProgressIndicator(
              minHeight: 3,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          ),
        // 超支时正文已经有「本月已超支」，这里不再重复一遍。
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.text, this.dot = false});

  final String text;
  final bool? dot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot == true) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF9BF5D4),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainRow extends StatelessWidget {
  const _MainRow({
    required this.hasBudget,
    required this.exceeded,
    required this.summary,
    required this.spending,
    required this.masked,
    required this.progress,
  });

  final bool hasBudget;
  final bool exceeded;
  final HomeMonthBudgetSummary? summary;
  final HomeTodaySpendingSummary spending;
  final bool masked;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = this.summary;
    final currencyCode = summary?.currencyCode ?? spending.currencyCode;

    final String label;
    final int amountMinor;
    // 预算 / 已用 / 日均可花这类「标签 + 金额」明细，逐行展示。
    final List<(String, String)> breakdown;

    if (hasBudget && summary != null) {
      final remaining = summary.remainingMinor;
      if (exceeded) {
        label = '本月已超支';
        amountMinor = -remaining;
      } else {
        label = '本月还可花';
        amountMinor = remaining;
      }
      breakdown = [
        ('预算', formatMoneyMinor(summary.totalMinor, currencyCode)),
        ('已用', formatMoneyMinor(summary.usedMinor, currencyCode)),
        ('日均可花', formatMoneyMinor(summary.dailyAllowanceMinor, currencyCode)),
      ];
    } else {
      label = '本月结余';
      amountMinor = spending.monthNetMinor;
      breakdown = [
        ('本月支出', formatMoneyMinor(spending.monthExpenseMinor, currencyCode)),
        ('本月收入', formatMoneyMinor(spending.monthIncomeMinor, currencyCode)),
      ];
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              _HeroAmount(
                key: const ValueKey('home-hero-amount'),
                amountMinor: amountMinor,
                currencyCode: currencyCode,
                masked: masked,
              ),
              const SizedBox(height: 8),
              _AmountBreakdown(
                rows: masked ? const [] : breakdown,
                masked: masked,
              ),
            ],
          ),
        ),
        if (hasBudget) ...[
          const SizedBox(width: 16),
          _BudgetRing(progress: progress, exceeded: exceeded),
        ],
      ],
    );
  }
}

/// 一行一项的金额明细。
///
/// 挤成「预算 A · 已用 B · 日均可花 C」一行时，数字之间只能靠分隔符去猜，
/// 窄屏还会折行；改为逐行「标签 + 金额」，扫读更快。
class _AmountBreakdown extends StatelessWidget {
  const _AmountBreakdown({required this.rows, required this.masked});

  final List<(String, String)> rows;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (masked || rows.isEmpty) {
      return Text(
        '金额已隐藏',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.82),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text(
                  row.$1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    row.$2,
                    maxLines: 1,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 大号金额：整数部分大、小数部分小，藏在金额里的排版细节。
class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    super.key,
    required this.amountMinor,
    required this.currencyCode,
    required this.masked,
  });

  final int amountMinor;
  final String currencyCode;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.displaySmall?.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
      height: 1.05,
    );

    if (masked) {
      return Text('••••', style: baseStyle);
    }

    final text = formatMoneyMinor(amountMinor, currencyCode);
    final dotIndex = text.lastIndexOf('.');
    if (dotIndex < 0 || dotIndex < text.length - 3) {
      return Text(text, maxLines: 1, style: baseStyle, semanticsLabel: text);
    }

    // 样式必须挂在根 TextSpan 上：只给子 span 设置样式的话，整数部分会
    // 回退到默认 bodyMedium（14px），主角数字会缩成小字。
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: text.substring(0, dotIndex)),
          TextSpan(
            text: text.substring(dotIndex),
            style: baseStyle?.copyWith(
              fontSize: (baseStyle.fontSize ?? 36) * 0.56,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
      maxLines: 1,
      semanticsLabel: text,
    );
  }
}

class _BudgetRing extends StatelessWidget {
  const _BudgetRing({required this.progress, required this.exceeded});

  final double progress;
  final bool exceeded;

  static const _size = 84.0;
  static const _stroke = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = progress.clamp(0.0, 1.0).toDouble();

    return SizedBox.square(
      dimension: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.square(
                dimension: _size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: _stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.24),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
              Text(
                '${(progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Pills extends StatelessWidget {
  const _Pills({
    required this.hasBudget,
    required this.spending,
    required this.budget,
    required this.masked,
  });

  final bool hasBudget;
  final HomeTodaySpendingSummary spending;
  final HomeMonthBudgetSummary? budget;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final currencyCode = budget?.currencyCode ?? spending.currencyCode;

    final entries = hasBudget
        ? <_PillData>[
            _PillData('今日支出', spending.todayExpenseMinor, currencyCode),
            _PillData('本月收入', spending.monthIncomeMinor, currencyCode),
            _PillData(
              '日均支出',
              spending.dailyAverageExpenseMinor,
              currencyCode,
              showSign: false,
            ),
          ]
        : <_PillData>[
            _PillData('本月支出', spending.monthExpenseMinor, currencyCode),
            _PillData(
              '本月收入',
              spending.monthIncomeMinor,
              currencyCode,
              showSign: true,
            ),
            _PillData('今日支出', spending.todayExpenseMinor, currencyCode),
          ];

    return Row(
      children: [
        for (var index = 0; index < entries.length; index++) ...[
          Expanded(
            child: _Pill(data: entries[index], masked: masked),
          ),
          if (index != entries.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _PillData {
  const _PillData(
    this.label,
    this.amountMinor,
    this.currencyCode, {
    this.showSign = false,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final bool showSign;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.data, required this.masked});

  final _PillData data;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = masked
        ? '••••'
        : '${data.showSign && data.amountMinor > 0 ? '+' : ''}'
              '${formatMoneyMinor(data.amountMinor, data.currencyCode)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetBlock extends StatelessWidget {
  const _CategoryBudgetBlock({required this.summary, required this.masked});

  final HomeCategoryBudgetSummary summary;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '分类预算',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                summary.nearLimitCount > 0
                    ? '${summary.nearLimitCount} 项接近上限'
                    : '共 ${summary.totalCount} 项',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          for (final item in summary.items) ...[
            const SizedBox(height: 9),
            _CategoryBudgetRow(item: item, masked: masked),
          ],
        ],
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({required this.item, required this.masked});

  final HomeCategoryBudgetProgress item;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final warn = item.isNearLimit;

    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: item.progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: AlwaysStoppedAnimation(
                warn ? const Color(0xFFFFD9A0) : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
          width: 92,
          child: Text(
            masked
                ? '••••'
                : '${formatMoneyMinor(item.usedMinor, item.currencyCode)}'
                      ' / ${formatMoneyMinor(item.amountMinor, item.currencyCode)}',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

/// 时间进度 vs 花费进度的双轨进度条。
class _DualProgress extends StatelessWidget {
  const _DualProgress({
    required this.spendProgress,
    required this.periodProgress,
    required this.exceeded,
  });

  final double spendProgress;
  final double periodProgress;
  final bool exceeded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spend = spendProgress.clamp(0.0, 1.0).toDouble();
    final period = periodProgress.clamp(0.0, 1.0).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return SizedBox(
              height: 16,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 4,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Container(
                      width: width * period,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Container(
                      width: width * spend,
                      height: 8,
                      decoration: BoxDecoration(
                        color: exceeded
                            ? const Color(0xFFFFD9A0)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * period - 1).clamp(0.0, width - 2),
                    top: 0,
                    child: Container(
                      width: 2,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '时间进度 ${(periodProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            Text(
              '花费进度 ${(spendProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.86),
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
