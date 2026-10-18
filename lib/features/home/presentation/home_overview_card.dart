import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

/// 首页第一张卡的三个视图。
enum HomeOverviewTab { budget, trend, calendar }

/// 「本月预算 / 支出趋势 / 日历」三视图卡片。
///
/// 为什么合并：原来 Hero（≈290dp）和趋势卡（≈280dp）各占一张卡，
/// 中间还隔着快捷动作、洞察条、提醒条、bento 双卡、健康条 —— 想看趋势要滚一屏半。
/// 合并后整卡取三者较高者，**净省约 250dp**，趋势变成「第一张卡的第 2 个视图」。
///
/// 两个实现要点：
/// 1. **Tab 条放在卡外**（页面背景上）。卡内 Hero 是品牌渐变、趋势/日历是浅底，
///    把图表塞进渐变里对比度会塌；放在外面则两种视图都能用自己合适的底色。
/// 2. 三个视图都用 [Offstage] 常驻：不重复取数、切换瞬时、状态（如日历选中的那天）
///    都保留；但**不占布局空间** —— 卡片高度等于当前视图的自然高度，
///    所以卡底不会出现「锁到最高视图」留下的空白。切 tab 时高度变化由
///    [AnimatedSize] 平滑处理。
class HomeOverviewCard extends StatefulWidget {
  const HomeOverviewCard({
    super.key,
    required this.budgetView,
    required this.trendView,
    required this.calendarView,
  });

  /// 本月预算（渐变 Hero）。
  final Widget budgetView;

  /// 支出趋势（周窗口柱状图）。
  final Widget trendView;

  /// 日历（月视图）。
  final Widget calendarView;

  @override
  State<HomeOverviewCard> createState() => _HomeOverviewCardState();
}

class _HomeOverviewCardState extends State<HomeOverviewCard> {
  HomeOverviewTab _tab = HomeOverviewTab.budget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSlidingSegmentedControl<HomeOverviewTab>(
          value: _tab,
          minSegmentWidth: 84,
          onChanged: (value) => setState(() => _tab = value),
          segments: const [
            AppSlidingSegment(
              value: HomeOverviewTab.budget,
              label: '本月预算',
              icon: Icons.savings_rounded,
            ),
            AppSlidingSegment(
              value: HomeOverviewTab.trend,
              label: '支出趋势',
              icon: Icons.bar_chart_rounded,
            ),
            AppSlidingSegment(
              value: HomeOverviewTab.calendar,
              label: '日历',
              icon: Icons.calendar_month_rounded,
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          // 用 Offstage 而不是 IndexedStack：
          // IndexedStack 会把整卡高度**锁在最高的那个视图**上（日历 338dp），
          // 于是本月预算页底部空出 50dp、遮罩后空出 70dp —— 看起来就是
          // 「卡片离下面的内容间距太大」。
          // Offstage 子节点照常 build/保持状态（不重复取数、不丢选中日），
          // 但不占布局空间 → 卡片高度跟着当前视图走，没有空白。
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, view) in [
                widget.budgetView,
                widget.trendView,
                widget.calendarView,
              ].indexed)
                Offstage(offstage: index != _tab.index, child: view),
            ],
          ),
        ),
      ],
    );
  }
}

/// 视图外壳：让三个视图共用同一套圆角/内边距/阴影。
///
/// Hero 自带渐变背景，所以它用自己的装饰；趋势/日历用这个浅色面板，
/// 两者圆角与阴影一致，切 tab 时读起来仍是「同一张卡」。
class HomeOverviewPanel extends StatelessWidget {
  const HomeOverviewPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
            spreadRadius: -12,
          ),
        ],
      ),
      padding: padding ?? EdgeInsets.all(theme.spacingTokens.cardPadding),
      child: child,
    );
  }
}
