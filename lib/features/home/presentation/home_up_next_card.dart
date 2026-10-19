import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/features/home/application/home_upcoming_providers.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/timeline/presentation/timeline_style.dart';

/// 首页概览页的「接下来」：**明天起**的日程预览，按天分组。
///
/// 与「需要关注」的分工（详见 `isReminderDueNow`）：
/// - 需要关注 = 今天 + 逾期，四类统一、可以就地处理；
/// - 接下来 = 明天起，只读预览，不催你动手。
///
/// 这样切是为了不让同一件事在首页出现两次。旧版这张卡直接铺时间线窗口内的
/// 全部承诺，于是「今天到期的待办」既在这里、又在「需要关注」里，一边能勾选、
/// 一边只能看。
///
/// 为什么按天分组而不平铺：平铺时每条都是「10/21 + 标题」，看不出哪几条是同一天
/// 的，也看不出是账单还是待办。分组 + 来源图标后，一眼是「明天有两笔账单」。
class HomeUpNextCard extends ConsumerWidget {
  const HomeUpNextCard({super.key, this.maxDays = 3, this.maxItems = 5});

  final int maxDays;
  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = ref.watch(homeUpcomingProvider).asData?.value;

    final upcoming = result == null
        ? HomeUpcoming.empty
        : buildHomeUpcoming(
            timeline: result.timeline,
            today: DateTime.now(),
            maxDays: maxDays,
            maxItems: maxItems,
          );
    final hiddenCount = upcoming.totalCount - upcoming.shownCount;

    return AppSurface(
      onTap: () => context.push(AppRoutes.timeline),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '接下来',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '未来 $homeUpcomingWindowDays 天',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              Text(
                upcoming.isEmpty ? '看时间线' : '查看全部',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          if (upcoming.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              result == null
                  ? '正在读取未来安排…'
                  : '未来 $homeUpcomingWindowDays 天没有安排。账单、待办、打卡都会在这里提前出现。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
                height: 1.4,
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),
            for (var index = 0; index < upcoming.groups.length; index++) ...[
              if (index > 0) const SizedBox(height: 2),
              _UpNextDayGroup(
                group: upcoming.groups[index],
                today: DateTime.now(),
              ),
            ],
            if (hiddenCount > 0) ...[
              const SizedBox(height: 2),
              Text(
                '还有 $hiddenCount 项',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
            ],
          ],
          if (result?.hasFailures ?? false) ...[
            const SizedBox(height: 4),
            Text(
              '有模块读取失败，点开可以单独重试',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 一天的小组：日期小标题 + 当天的事件行。
class _UpNextDayGroup extends StatelessWidget {
  const _UpNextDayGroup({required this.group, required this.today});

  final HomeUpcomingGroup group;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Text(
            homeUpcomingDayLabel(group.day, today),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ),
        for (final event in group.events) _UpNextEventRow(event: event),
      ],
    );
  }
}

class _UpNextEventRow extends StatelessWidget {
  const _UpNextEventRow({required this.event});

  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = timelineModuleColor(theme, event.module);
    // 预测按历史推算，可能不成立——降一层不透明度，形态上和「一定会发生」的
    // 承诺区分开，而不是靠一行小字去解释。
    final predicted = event.nature.isPrediction;

    return Opacity(
      opacity: predicted ? 0.72 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(timelineEventIcon(event), size: 14, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  if (event.subtitle != null &&
                      event.subtitle!.trim().isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      event.subtitle!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (event.amountMinor != null) ...[
              const SizedBox(width: 8),
              MoneyText(
                amountMinor: event.amountMinor!,
                currencyCode: event.currencyCode ?? 'CNY',
                tone: event.amountMinor! < 0
                    ? MoneyAmountTone.expense
                    : MoneyAmountTone.income,
                textStyle: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ] else if (event.emphasis == TimelineEmphasis.attention)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: colorScheme.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
