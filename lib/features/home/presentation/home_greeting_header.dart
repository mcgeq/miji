import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';

/// 首页问候头：左侧问候 + 日期，右侧连续记账天数。
///
/// 原来的随机理财金句已移到页面底部（见 [HomeQuoteFooter]），
/// 避免每次重建都在跳动。
class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({
    super.key,
    this.userDisplayName,
    this.streak,
    this.now,
  });

  final String? userDisplayName;
  final HomeStreak? streak;
  final DateTime? now;

  static const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final current = now ?? DateTime.now();
    final name = userDisplayName?.trim();
    final greeting = _greeting(current.hour);
    final greetingText = (name != null && name.isNotEmpty)
        ? '$greeting，$name'
        : greeting;

    final streak = this.streak;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greetingText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateString(current),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (streak != null && streak.days > 0) ...[
            const SizedBox(width: 8),
            _StreakChip(streak: streak),
          ],
          const SizedBox(width: 4),
          const HomeMaskToggle(),
        ],
      ),
    );
  }

  String _greeting(int hour) {
    if (hour >= 5 && hour < 12) return '早上好';
    if (hour >= 12 && hour < 18) return '下午好';
    return '晚上好';
  }

  String _dateString(DateTime value) {
    return '${value.year}年${value.month}月${value.day}日 '
        '${_weekdays[value.weekday - 1]}';
  }
}

/// 首页金额隐私开关。
///
/// 放在问候行而不是顶栏：桌面端首页没有顶栏，放在内容区两种布局都能用。
class HomeMaskToggle extends ConsumerWidget {
  const HomeMaskToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final masked = ref.watch(moneyAmountsMaskedProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: masked ? '显示金额' : '隐藏金额',
      child: IconButton(
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: masked
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
          foregroundColor: masked
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
        ),
        onPressed: () => _toggle(context, ref, masked),
        icon: Icon(
          masked ? Icons.visibility_off_rounded : Icons.visibility_outlined,
          size: 18,
        ),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool masked) async {
    final userId = ref
        .read(currentUserPreferencesProvider)
        .asData
        ?.value
        ?.userId;
    if (userId == null) {
      return;
    }

    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .updateMaskMoneyAmounts(userId, !masked);
      ref.invalidate(currentUserPreferencesProvider);
    } catch (_) {
      messenger?.showSnackBar(const SnackBar(content: Text('切换失败，请重试')));
    }
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final HomeStreak streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.moneyColors.warning;
    final label = streak.hasRecordedToday
        ? '连续 ${streak.days}${streak.isCapped ? '+' : ''} 天'
        : '今天还没记账';

    return Tooltip(
      message: streak.hasRecordedToday ? '连续记账天数' : '记一笔即可延续连续记录',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              streak.hasRecordedToday
                  ? Icons.local_fire_department_rounded
                  : Icons.edit_calendar_outlined,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
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
    );
  }
}

/// 页面底部的理财金句。按日期取模选择，保证同一天内不会变化。
class HomeQuoteFooter extends StatelessWidget {
  const HomeQuoteFooter({super.key, this.now});

  final DateTime? now;

  static const quotes = [
    '时间就是金钱。',
    '你不理财，财不理你。',
    '由俭入奢易，由奢入俭难。',
    '不要把所有的鸡蛋放在同一个篮子里。',
    '省一分钱就是赚一分钱。',
    '一寸光阴一寸金，寸金难买寸光阴。',
    '不要为钱工作，让钱为你工作。',
    '积少成多，聚沙成塔。',
    '钱是个好仆人，却是个坏主人。',
    '早知三日事，富贵一千年。',
    '致富的秘诀：支出少于收入。',
    '理财就是理生活。',
    '财富是智慧的产物。',
    '区分需要和想要，减少冲动消费。',
    '机会成本才是真正的成本。',
    '记录每一笔收支，才能更好地规划未来。',
    '急用钱储备建议覆盖 3-6 个月开支。',
    '定期回顾账单，发现消费盲区。',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = now ?? DateTime.now();
    final dayOfYear = current.difference(DateTime(current.year)).inDays;
    final quote = quotes[dayOfYear % quotes.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        '「$quote」',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
          height: 1.6,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
