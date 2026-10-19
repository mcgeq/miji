import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// 占用（已用 + 已预留）到多少算「快满了」。
///
/// 环、双轨进度条、胶囊圆点**共用这一个判据**：以前环按 80% 变琥珀，进度条
/// 却只在**超支**时才变，于是「占用 96%」的卡上环是黄的、条还是白的，两个
/// 信号互相拆台；胶囊圆点更是恒为薄荷绿。三处各自算一次，就必然走散。
const _nearLimitProgress = 0.8;

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
    // 判一次、传下去：环 / 进度条 / 圆点必须同时变色。
    final nearLimit =
        hasBudget && (summary?.occupiedProgress ?? 0) >= _nearLimitProgress;
    final gradient = _heroGradient(theme, exceeded: exceeded);
    // 这张卡只用品牌（石墨）与超支（深红）两套渐变，都是深卡，所以 A 下正文是白字。
    // 仍从 token 取而不是写死 `Colors.white`：换方向/换渐变时不用再回来逐个改。
    final onHero = gradient.onColor;

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
                      onHero: onHero,
                      nearLimit: nearLimit,
                    ),
                    const SizedBox(height: 14),
                    _MainRow(
                      hasBudget: hasBudget,
                      exceeded: exceeded,
                      summary: summary,
                      spending: spending,
                      masked: masked,
                      usedProgress: summary?.progress ?? 0,
                      occupiedProgress: summary?.occupiedProgress ?? 0,
                      nearLimit: nearLimit,
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
                        usedProgress: summary!.progress,
                        occupiedProgress: summary.occupiedProgress,
                        periodProgress: summary.periodProgress,
                        exceeded: exceeded,
                        nearLimit: nearLimit,
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
    required this.onHero,
    required this.nearLimit,
  });

  final bool hasBudget;
  final String? paceLabel;
  final bool exceeded;
  final bool isLoading;

  /// 卡片的正文色（`AppHeroGradient.onColor`）。
  final Color onHero;

  /// 占用已过 [_nearLimitProgress]。与环、进度条共用同一个判据。
  final bool nearLimit;

  /// 圆点跟着状态一起变。
  ///
  /// 原来恒为薄荷绿：卡片已经「花费偏快」甚至「额度被预留占满」了，旁边
  /// 仍是一颗表示平安的绿点，等于把告警抵掉一半。占用过线时哪怕文案还是
  /// 「节奏正常」（过去确实花得不快），也该转告警色 —— 环已经黄了。
  Color _dotColor(ThemeData theme) {
    if (nearLimit) {
      return theme.heroGradients.amber;
    }
    final label = paceLabel ?? '';
    if (label.contains('超支') || label.contains('预留') || label.contains('偏快')) {
      return theme.heroGradients.amber;
    }
    if (label.contains('偏慢')) {
      // 偏慢不是告警，但也不该沿用「一切正常」的薄荷绿。
      return onHero.withValues(alpha: 0.62);
    }
    return const Color(0xFF9BF5D4);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 「本月预算」这个胶囊已经去掉了：它现在就是卡上方 tab 的名字，
    // 卡内再写一遍是同一句话说两次（设计稿里两个胶囊本来是并排靠左的）。
    // 左槽留给节奏状态，右侧只在加载时出现进度条。
    final pace = hasBudget && !exceeded ? (paceLabel ?? '') : '';

    return Row(
      children: [
        if (pace.isNotEmpty)
          _HeroChip(text: pace, dotColor: _dotColor(theme), onHero: onHero),
        // 超支时把节奏胶囊换成实心的告警胶囊。
        //
        // 以前这里直接留空（理由是「正文已经写了本月已超支，不再重复」），
        // 结果整张卡只剩「底色变红」这一个信号 —— 而 brand（深石墨
        // #1D252D→#30363E）与 danger（暗紫红 #800E50→#921921）的明度几乎
        // 相同，两张卡不并排放一起根本分不出「正常」和「超支」。
        if (exceeded)
          _HeroChip(
            text: '已超支',
            icon: Icons.error_rounded,
            onHero: theme.heroGradients.danger.colors[1],
            background: Colors.white,
          ),
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
  const _HeroChip({
    required this.text,
    required this.onHero,
    this.dotColor,
    this.icon,
    this.background,
  });

  final String text;

  /// 圆点颜色；为 null 且不传 [icon] 时不画前置标记。
  final Color? dotColor;

  /// 前置图标；优先于 [dotColor]。
  final IconData? icon;

  /// 胶囊底色。默认半透明白；告警胶囊传纯白，把整颗胶囊变成高对比块。
  final Color? background;

  /// 胶囊上的文字色（深卡上是白，白底告警胶囊上是深红）。
  final Color onHero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: onHero),
            const SizedBox(width: 5),
          ] else if (dotColor != null) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onHero,
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
    required this.usedProgress,
    required this.occupiedProgress,
    required this.nearLimit,
  });

  final bool hasBudget;
  final bool exceeded;
  final HomeMonthBudgetSummary? summary;
  final HomeTodaySpendingSummary spending;
  final bool masked;

  /// 已用 / 预算。
  final double usedProgress;

  /// (已用 + 已预留) / 预算；环与进度条按这个口径画。
  final double occupiedProgress;

  /// 占用已过 [_nearLimitProgress]，环与进度条一起转告警色。
  final bool nearLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = this.summary;
    final currencyCode = summary?.currencyCode ?? spending.currencyCode;

    final String label;
    final int amountMinor;
    // 预算 / 已用 / 日均可花这类「标签 + 金额」明细，逐行展示。
    final List<(String, String, bool)> breakdown;

    if (hasBudget && summary != null) {
      final remaining = summary.remainingMinor;
      final committed = summary.committedMinor;
      if (exceeded) {
        label = '本月已超支';
        amountMinor = -remaining;
      } else {
        // 已预留的钱不算「已经花掉」，但它已经不是你能花的了。
        label = '本月还可花';
        amountMinor = summary.availableMinor < 0 ? 0 : summary.availableMinor;
      }
      breakdown = [
        ('预算', formatMoneyMinor(summary.totalMinor, currencyCode), false),
        ('已用', formatMoneyMinor(summary.usedMinor, currencyCode), false),
        if (committed > 0)
          ('已预留', formatMoneyMinor(committed, currencyCode), false),
        // 超支后「日均可花」恒为 0（`availableMinor <= 0` 时按 0 算），
        // 留着它等于在告警卡上写一句没有信息量的话。换成「超出」，把
        // 预算 / 已用 / 超出 串成一条能对账的链。行数保持不变，卡片高度
        // 不会在跨过 100% 那一刻跳一下。
        if (exceeded)
          ('超出', formatMoneyMinor(-remaining, currencyCode), false)
        else
          (
            '日均可花',
            formatMoneyMinor(summary.dailyAllowanceMinor, currencyCode),
            false,
          ),
      ];
    } else {
      label = '本月结余';
      amountMinor = spending.monthNetMinor;
      breakdown = [
        (
          '本月支出',
          formatMoneyMinor(spending.monthExpenseMinor, currencyCode),
          false,
        ),
        (
          '本月收入',
          formatMoneyMinor(spending.monthIncomeMinor, currencyCode),
          true,
        ),
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
              // 遮罩时也要把同样的明细行传下去（只把金额换成圆点），
              // 否则 Hero 会矮一截、卡片高度跟着变 —— 就是「点隐藏金额
              // 间距被拉开」的来源。
              _AmountBreakdown(rows: breakdown, masked: masked),
            ],
          ),
        ),
        if (hasBudget) ...[
          const SizedBox(width: 16),
          _BudgetRing(
            usedProgress: usedProgress,
            occupiedProgress: occupiedProgress,
            exceeded: exceeded,
            nearLimit: nearLimit,
          ),
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

  final List<(String, String, bool)> rows;
  final bool masked;

  /// 单行金额：收入行看 [IncomePrivacy]（`****`）并可点按，
  /// 其余行沿用全局 `masked`（`••••`）且不加点击语义。
  Widget _rowValue(
    BuildContext context,
    ThemeData theme,
    (String, String, bool) row,
  ) {
    final text = Text(
      row.$3
          ? (IncomePrivacy.of(context) ? '****' : row.$2)
          : (masked ? '••••' : row.$2),
      maxLines: 1,
      textAlign: TextAlign.right,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.labelMedium?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
    return row.$3 ? IncomeAmountTap(child: text) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    // 遮罩时**仍然保留同样的行数与行高**，只把金额换成圆点。
    // 原来是塌成一行「金额已隐藏」：Hero 因此矮 20dp，而整卡高度
    // 又被锁在最高的视图上 → 一点「隐藏金额」，卡片下方的空白就变大，
    // 看起来像间距被拉开了。这里保持结构不变，顺带也更清楚地告诉
    // 用户「哪个指标被隐藏了」。

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
                Expanded(child: _rowValue(context, theme, row)),
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

/// 预算环形进度。
///
/// 画的是**占用**（已用 + 已预留），不是只画已用：只按已用画的话，
/// 「未来义务把额度占满」时环还是空着一半，和旁边「本月还可花 ¥0」直接打架。
///
/// 两段弧形区分来源：实色是已用，半透明是被预留占住的部分。合并成一个数
/// 会让预留看起来像已经花掉，用户也就没法对账了。
///
/// 环还会按状态换色（见 [_arcColor]）：整环恒为白色的话，占用 30% 与
/// 占用 95% 长一样，只有卡片底色会变 —— 而底色只在**已经超支**的那一刻才切，
/// 也就是说「快超了」这个真正需要提醒的状态，界面上完全没有信号。
class _BudgetRing extends StatelessWidget {
  const _BudgetRing({
    required this.usedProgress,
    required this.occupiedProgress,
    required this.exceeded,
    required this.nearLimit,
  });

  final double usedProgress;

  /// 已用 + 已预留，恒 ≥ [usedProgress]。
  final double occupiedProgress;

  /// 已用 ≥ 预算。此时整卡切到 danger 深红，卡片本身已经在喊了。
  final bool exceeded;

  /// 占用已过 [_nearLimitProgress]（与进度条、胶囊圆点同一判据）。
  final bool nearLimit;

  static const _size = 84.0;
  static const _stroke = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = usedProgress.clamp(0.0, 1.0).toDouble();
    final occupied = occupiedProgress.clamp(0.0, 1.0).toDouble();
    final hasCommitted = occupied - used > 0.0001;
    // 超支时卡片已经是深红，环再上琥珀会「红底压橙」，两个告警互相打架，
    // 所以只在**还没超支但快到顶**时上琥珀。
    final arc = nearLimit && !exceeded
        ? theme.heroGradients.amber
        : Colors.white;

    return SizedBox.square(
      dimension: _size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // 底环：整圈预算。用 border 画固定底环，避免每个
              // CircularProgressIndicator 都自带一条底环、叠加后颜色变深。
              // 底环**恒为中性白**，不跟弧一起变色：底色也跟着变的话，
              // 琥珀弧在琥珀底环上就分不出「用掉多少 / 还剩多少」了。
              SizedBox.square(
                dimension: _size,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                      width: _stroke,
                    ),
                  ),
                ),
              ),
              // 预留段（浅）：先画到「占用」的位置。
              if (hasCommitted)
                SizedBox.square(
                  dimension: _size,
                  child: CircularProgressIndicator(
                    value: occupied * t,
                    strokeWidth: _stroke,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(
                      arc.withValues(alpha: 0.52),
                    ),
                  ),
                ),
              // 已用段（实）：与预留段同起点，叠在上面。
              SizedBox.square(
                dimension: _size,
                child: CircularProgressIndicator(
                  value: used * t,
                  strokeWidth: _stroke,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(arc),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    // 不 clamp 到 100%：超支时环画满，但中心仍要读出「超了多少」。
                    // clamp 掉的话 104% 与「刚好用满」长得一模一样。
                    '${(occupiedProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: exceeded
                          ? theme.heroGradients.amber
                          : Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  // 环的百分比不再是「已用占比」，标出来免得被误读；
                  // 超支时直接把这句话换成状态。
                  Text(
                    exceeded ? '已超支' : '已占用',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: exceeded
                          ? theme.heroGradients.amber
                          : Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                      height: 1.1,
                      letterSpacing: 0,
                    ),
                  ),
                ],
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
            _PillData(
              '本月收入',
              spending.monthIncomeMinor,
              currencyCode,
              isIncome: true,
            ),
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
              isIncome: true,
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
    this.isIncome = false,
  });

  final String label;
  final int amountMinor;
  final String currencyCode;
  final bool showSign;
  final bool isIncome;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.data, required this.masked});

  final _PillData data;
  final bool masked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maskedAmount = data.isIncome ? IncomePrivacy.of(context) : masked;
    final placeholder = data.isIncome ? '****' : '••••';
    final text = maskedAmount
        ? placeholder
        : '${data.showSign && data.amountMinor > 0 ? '+' : ''}'
              '${formatMoneyMinor(data.amountMinor, data.currencyCode)}';
    final amountText = Text(
      text,
      maxLines: 1,
      style: theme.textTheme.titleSmall?.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
    );

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
            child: data.isIncome
                ? IncomeAmountTap(child: amountText)
                : amountText,
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
                // 超支是终态，不能被「接近上限」这句话含过去：
                // 以前两者共用 nearLimitCount，真正已经超了的那条和
                // 80% 的那条在卡片上是同一种说法、同一种颜色。
                summary.exceededCount > 0
                    ? '${summary.exceededCount} 项已超支'
                    : summary.nearLimitCount > 0
                    ? '${summary.nearLimitCount} 项接近上限'
                    : '共 ${summary.totalCount} 项',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: summary.exceededCount > 0
                      ? theme.heroGradients.amber
                      : Colors.white.withValues(alpha: 0.8),
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
    final over = item.isExceeded;
    final alertColor = theme.heroGradients.amber;
    // 超支时整行转琥珀（名称 + 条 + 金额），「接近上限」只有条转琥珀。
    // 两者以前长得完全一样：条都是满格琥珀，用户只能靠自己除一下两个数。
    final rowColor = over ? alertColor : Colors.white.withValues(alpha: 0.9);

    return Row(
      children: [
        SizedBox(
          width: 46,
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: rowColor,
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
                warn ? alertColor : Colors.white,
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
                      ' / ${formatMoneyMinor(item.amountMinor, item.currencyCode)}'
                      '${over ? ' 超' : ''}',
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: over ? alertColor : Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

/// 时间进度 vs 额度占用的双轨进度条。
///
/// 三档白度区分来源：白 0.38 是已过去的时间，白 0.62 是被预留占住的部分，
/// 纯白是真花掉的钱。先前的版本只画「已用」，于是「预留把额度占满」时
/// 进度条看着还很空，和同一张卡上的「本月还可花 ¥0」矛盾。
class _DualProgress extends StatelessWidget {
  const _DualProgress({
    required this.usedProgress,
    required this.occupiedProgress,
    required this.periodProgress,
    required this.exceeded,
    required this.nearLimit,
  });

  /// 已用 / 预算。
  final double usedProgress;

  /// (已用 + 已预留) / 预算，恒 ≥ [usedProgress]。
  final double occupiedProgress;
  final double periodProgress;
  final bool exceeded;

  /// 占用已过 [_nearLimitProgress]。与环、胶囊圆点共用同一判据 ——
  /// 以前这里只在 `exceeded` 时变黄，而环是 80% 就变，于是同一张卡上
  /// 「环已黄、条还白」。超支时卡片整体已经是深红，条也保持琥珀。
  final bool nearLimit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = usedProgress.clamp(0.0, 1.0).toDouble();
    final occupied = occupiedProgress.clamp(0.0, 1.0).toDouble();
    final period = periodProgress.clamp(0.0, 1.0).toDouble();
    final committed = (occupied - used).clamp(0.0, 1.0).toDouble();
    final hasCommitted = committed > 0.0001;
    final alert = nearLimit || exceeded;

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
                        color: Colors.white.withValues(alpha: 0.18),
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
                        color: Colors.white.withValues(alpha: 0.38),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  // 预留段：紧接在已用之后。告警时跟环一样用 52% 琥珀 ——
                  // 只把已用段染黄的话，「已用 40% + 预留 56%」的条读起来
                  // 仍是「灰掉大半」，而环那边整圈都已经是琥珀。
                  if (hasCommitted)
                    Positioned(
                      left: width * used,
                      top: 4,
                      child: Container(
                        key: const ValueKey('home-budget-committed-bar'),
                        width: width * committed,
                        height: 8,
                        decoration: BoxDecoration(
                          color: alert
                              ? theme.heroGradients.amber.withValues(
                                  alpha: 0.52,
                                )
                              : Colors.white.withValues(alpha: 0.62),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    top: 4,
                    child: Container(
                      key: const ValueKey('home-budget-used-bar'),
                      width: width * used,
                      height: 8,
                      decoration: BoxDecoration(
                        color: alert ? theme.heroGradients.amber : Colors.white,
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
              // 有预留时把两段都写出来，用户才知道进度条里那段浅色是什么。
              // 超支时这行转琥珀：条已经画满（clamp 到 100%），只有这个数字
              // 还在说「到底超了多少」。
              hasCommitted
                  ? '已用+预留 ${(occupiedProgress * 100).clamp(0, 999).toStringAsFixed(0)}%'
                  : '花费进度 ${(occupiedProgress * 100).clamp(0, 999).toStringAsFixed(0)}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: exceeded
                    ? theme.heroGradients.amber
                    : Colors.white.withValues(alpha: 0.86),
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
