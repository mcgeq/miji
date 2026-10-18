import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';

/// 档案页里的「一组字段」卡片。
///
/// 抽出来是因为税前模式会多出三组（五险一金 / 专项附加 / 到手明细入口），
/// 而档案页本身已经有收入、时间、开销三组 —— 六组长得像才能看出它们是
/// 同一个表单的不同部分，而不是六个各自独立的小界面。
class LifeEnergyGroupCard extends StatelessWidget {
  const LifeEnergyGroupCard({
    super.key,
    required this.title,
    required this.hint,
    required this.children,
  });

  final String title;

  /// 这一组是干什么的。
  ///
  /// 为什么这组必须有小字：五险一金、专项附加这些词对大多数人只有一个模糊
  /// 的概念，不给口径说明他们只会猜一个数填进去 —— 而猜错一个比例，整条
  /// 扣缴链上的每一个数都会错得很具体。
  final String hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spacing = theme.spacingTokens;
    return Container(
      padding: EdgeInsets.all(spacing.cardPadding),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(theme.radiusTokens.card),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
