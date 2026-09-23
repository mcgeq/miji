import 'package:flutter/material.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

/// 骨架屏基础块：带轻微脉冲动画的占位块。
///
/// 用骨架屏替代整页转圈：转圈会让页面「白一下」，骨架屏先给出结构，
/// 感知加载时间明显更短（首页早就这么做了，这里抽成共享组件）。
class AppSkeletonBox extends StatefulWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 16,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<AppSkeletonBox> createState() => _AppSkeletonBoxState();
}

class _AppSkeletonBoxState extends State<AppSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.45 + 0.35 * _controller.value,
            ),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// 列表骨架：图标 + 两行文字 + 金额，匹配记账模块的列表项结构。
class AppSkeletonList extends StatelessWidget {
  const AppSkeletonList({
    super.key,
    this.rows = 5,
    this.showLeading = true,
    this.showTrailing = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final int rows;
  final bool showLeading;
  final bool showTrailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Row(
        children: [
          if (showLeading) ...[
            const AppSkeletonBox(width: 40, height: 40, radius: 13),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeletonBox(
                  height: 13,
                  width: index.isEven ? 132 : 104,
                  radius: 6,
                ),
                const SizedBox(height: 8),
                AppSkeletonBox(
                  height: 11,
                  width: index.isEven ? 196 : 160,
                  radius: 6,
                ),
              ],
            ),
          ),
          if (showTrailing) ...[
            const SizedBox(width: 12),
            const AppSkeletonBox(width: 72, height: 15, radius: 6),
          ],
        ],
      ),
    );
  }
}

/// 面板骨架：标题条 + N 行内容（统计类卡片用）。
class AppSkeletonPanel extends StatelessWidget {
  const AppSkeletonPanel({
    super.key,
    this.lines = 3,
    this.height,
    this.showHeader = true,
  });

  final int lines;
  final double? height;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radiusTokens.card),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showHeader) ...[
            const AppSkeletonBox(height: 15, width: 108, radius: 6),
            const SizedBox(height: 6),
            const AppSkeletonBox(height: 11, width: 168, radius: 6),
            const SizedBox(height: 14),
          ],
          for (var index = 0; index < lines; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            AppSkeletonBox(
              height: 12,
              width: index == 0 ? null : (index.isEven ? 180 : 140),
              radius: 6,
            ),
          ],
        ],
      ),
    );
  }
}

/// 图表骨架：坐标轴 + 高低不一的柱块。
class AppSkeletonChart extends StatelessWidget {
  const AppSkeletonChart({super.key, this.height = 132});

  final double height;

  static const _heights = <double>[0.42, 0.66, 0.3, 0.82, 0.5, 0.6, 0.24];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final ratio in _heights)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AppSkeletonBox(height: height * ratio, radius: 8),
              ),
            ),
        ],
      ),
    );
  }
}
