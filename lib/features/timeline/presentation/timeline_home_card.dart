import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

/// 首页概览页的紧凑时间线：最多 4 条 + 「查看全部」。
///
/// 为什么不是完整列表：首页已经有 4 页 12 块，再铺一屏「本周」会把它变成
/// 另一个模块。这里只回答「接下来还有什么」——点进去才是全景。
class TimelineHomeCard extends ConsumerWidget {
  const TimelineHomeCard({super.key, this.maxItems = 4});

  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(timelineProvider).asData?.value;
    final upcoming = <TimelineEvent>[
      if (data != null)
        for (final day in data.timeline.days) ...day.commitments,
    ]..sort((a, b) => a.occurredOn.compareTo(b.occurredOn));
    final shown = upcoming.take(maxItems).toList(growable: false);

    return AppSurface(
      onTap: () => context.push(AppRoutes.timeline),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              const Spacer(),
              Text(
                shown.isEmpty ? '看时间线' : '查看全部',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (shown.isEmpty)
            Text(
              '这几天没有安排。待办、账单、打卡都会在这里出现。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
                height: 1.4,
              ),
            )
          else
            for (final event in shown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        _dayLabel(event.occurredOn),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
          if (data != null && data.hasFailures) ...[
            const SizedBox(height: 4),
            Text(
              '有模块读取失败，点开可以单独重试',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 「今天 / 明天 / 10/21」：人读日期先说相对，再说绝对。
  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => '今天',
      1 => '明天',
      _ => '${day.month}/${day.day}',
    };
  }
}
