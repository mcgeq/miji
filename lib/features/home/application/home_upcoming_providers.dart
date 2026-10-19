import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

/// 「接下来」往前看几天。
///
/// 7 天是刻意选的：短于 7 天装不下一周里的账单与还款，长于 7 天就变成「日程表」
/// 而不是「接下来」——首页这块只回答「这几天要面对什么」。
const int homeUpcomingWindowDays = 7;

/// 「接下来」的窗口：**明天**起 [homeUpcomingWindowDays] 天。
///
/// 不含今天，这是与「需要关注」的分界线（见 `isReminderDueNow`）：今天与逾期的
/// 归「需要关注」并且可以就地处理；明天起的归「接下来」，只做预览。两边不重叠，
/// 同一件事不会在首页出现两次。
final homeUpcomingWindowProvider = Provider<TimelineWindow>((ref) {
  final now = DateTime.now();
  final today = DateTime.utc(now.year, now.month, now.day);
  return TimelineWindow(
    start: DateTime.utc(today.year, today.month, today.day + 1),
    end: DateTime.utc(
      today.year,
      today.month,
      today.day + homeUpcomingWindowDays,
    ),
  );
});

/// 首页「接下来」：与 `timelineProvider` 同一套读取器，只是窗口换成未来 7 天。
///
/// 不复用 `timelineProvider` 是因为它的窗口由用户在时间线页选的周决定——
/// 首页的卡片不该跟着用户在别处的翻页跳来跳去。
final homeUpcomingProvider = FutureProvider.autoDispose<TimelineResult>((
  ref,
) async {
  final window = ref.watch(homeUpcomingWindowProvider);
  return loadTimeline(ref, window);
});

/// 「接下来」一天的一组事件。
class HomeUpcomingGroup {
  const HomeUpcomingGroup({required this.day, required this.events});

  /// 这一天的零点（UTC date-key）。
  final DateTime day;

  final List<TimelineEvent> events;

  int get count => events.length;
}

/// 「接下来」的编排结果。
class HomeUpcoming {
  const HomeUpcoming({required this.groups, required this.totalCount});

  static const empty = HomeUpcoming(groups: [], totalCount: 0);

  final List<HomeUpcomingGroup> groups;

  /// 窗口内**所有**待发生事件的条数（截断前）。
  ///
  /// 界面靠它说「还有 N 项」，而不是让多出来的部分无声消失。
  final int totalCount;

  bool get isEmpty => groups.isEmpty;

  int get shownCount => groups.fold(0, (sum, group) => sum + group.count);
}

/// 从时间线结果里挑出「接下来」。
///
/// 三条筛选，每条都有来由：
/// 1. **只要还没发生的**（`commitment` / `prediction`）：`fact` 是已经发生的事，
///    它属于「回顾」，不属于「接下来」。
/// 2. **只要明天起的**：今天与逾期已经交给「需要关注」了。
/// 3. **每天内承诺在预测前**：承诺一定会发生，预测可能不成立，别让虚的压过实的。
HomeUpcoming buildHomeUpcoming({
  required Timeline timeline,
  required DateTime today,
  int maxDays = 4,
  int maxItems = 6,
}) {
  final cutoff = DateTime.utc(today.year, today.month, today.day);

  // 先数清窗口里一共有多少条，再决定给界面看多少条——不然「还有 N 项」
  // 会因为截断而算错。
  final pending = <TimelineDay>[];
  var totalCount = 0;
  for (final day in timeline.days) {
    if (!day.day.isAfter(cutoff)) {
      continue;
    }
    if (day.commitments.isEmpty && day.predictions.isEmpty) {
      continue;
    }
    totalCount += day.commitments.length + day.predictions.length;
    pending.add(day);
  }

  final groups = <HomeUpcomingGroup>[];
  var shown = 0;
  for (final day in pending) {
    if (groups.length >= maxDays || shown >= maxItems) {
      break;
    }
    final events = <TimelineEvent>[...day.commitments, ...day.predictions];
    final kept = events.take(maxItems - shown).toList(growable: false);
    if (kept.isEmpty) {
      continue;
    }
    shown += kept.length;
    groups.add(HomeUpcomingGroup(day: day.day, events: kept));
  }

  return HomeUpcoming(
    groups: List.unmodifiable(groups),
    totalCount: totalCount,
  );
}

/// 日期小标题：先说相对，再说星期，最后才落到日期。
///
/// 「明天」比「10/21」有用；超过两天就补星期（`周四 10/22`），因为跨周的安排
/// 光看数字反应不过来是哪天。
String homeUpcomingDayLabel(DateTime day, DateTime today) {
  final base = DateTime.utc(today.year, today.month, today.day);
  final diff = day.difference(base).inDays;
  final date = '${day.month}/${day.day}';
  if (diff == 1) {
    return '明天 · $date';
  }
  if (diff == 2) {
    return '后天 · $date';
  }
  const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
  return '周${weekdays[day.weekday - 1]} · $date';
}
