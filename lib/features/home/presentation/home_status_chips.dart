import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 首页 L0 状态胶囊：问候语下方一行最多 3 颗「一眼可见的状态」，点哪颗进哪个模块。
///
/// 数据全部来自首页本来就在取的 provider（连续记账 / 健康提示 / 今日待办），
/// 不新增查库。没有任何状态可显示时整行消失，不留空白。
///
/// 三颗胶囊刻意与下方的三宫格同源但不同粒度：胶囊给结论（`经期第 3 天`），
/// 宫格给口径与明细（主值 + 口径 + 今日支出）。
class HomeStatusChips extends ConsumerWidget {
  const HomeStatusChips({
    super.key,
    required this.onOpenMoney,
    required this.onOpenHealth,
    required this.onOpenAction,
  });

  final VoidCallback onOpenMoney;
  final VoidCallback onOpenHealth;
  final VoidCallback onOpenAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final streak = ref.watch(homeStreakProvider).asData?.value;
    final healthHint = ref.watch(homeHealthHintProvider).asData?.value;
    final action = ref.watch(todayActionItemsProvider).asData?.value;

    final chips = <Widget>[
      if (streak != null && streak.days > 0)
        _StatusChip(
          emoji: '🔥',
          // 写「连续记账」而不是「连续」：行动模块的习惯打卡也有「连续 N 天」，
          // 两颗胶囊同时出现时只说「连续」会分不清在说哪一件。
          label: streak.hasRecordedToday
              ? '连续记账 ${streak.days}${streak.isCapped ? '+' : ''} 天'
              : '今天还没记账',
          color: theme.moneyColors.warning,
          tooltip: streak.hasRecordedToday ? '连续记账天数' : '记一笔即可延续连续记录',
          onTap: onOpenMoney,
        ),
      if (healthHint != null)
        _StatusChip(
          emoji: healthHint.kind == HomeHealthHintKind.pregnancy ? '🤰' : '🩸',
          label: healthHint.title,
          color: theme.colorScheme.tertiary,
          onTap: onOpenHealth,
        ),
      if (action != null && action.totalCount > 0)
        _StatusChip(
          emoji: '✅',
          label: '今日 ${action.completedCount}/${action.totalCount}',
          color: theme.colorScheme.primary,
          onTap: onOpenAction,
        ),
    ];

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    // 上间距放在这里而不是调用方：整行没有内容时不应该留下空隙。
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(spacing: 7, runSpacing: 7, children: chips),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(999);

    Widget chip = Material(
      color: color.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12, height: 1.2)),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
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

    final message = tooltip;
    if (message != null) {
      chip = Tooltip(message: message, child: chip);
    }
    return chip;
  }
}
