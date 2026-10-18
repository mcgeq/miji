import 'package:flutter/foundation.dart';

import 'package:miji/features/timeline/domain/timeline_assembler.dart';

/// 一天的回顾摘要。
@immutable
class TimelineHistoryDay {
  const TimelineHistoryDay({
    required this.day,
    required this.expenseMinor,
    required this.checkinCount,
    required this.taskCompletedCount,
    this.hasPeriod = false,
  });

  final DateTime day;

  /// 当天支出合计（分，正数）。
  final int expenseMinor;

  /// 当天打卡次数（聚合行里的条数之和）。
  final int checkinCount;

  /// 当天完成的待办数。
  final int taskCompletedCount;

  /// 当天有经期记录。回顾里只说「有」，不展示细节。
  final bool hasPeriod;

  bool get isEmpty =>
      expenseMinor == 0 && checkinCount == 0 && taskCompletedCount == 0;

  /// 「支出 ¥120 · 打卡 3 次 · 任务 1」——只写有内容的那几项。
  String get summary {
    final parts = <String>[
      if (checkinCount > 0) '打卡 $checkinCount 次',
      if (taskCompletedCount > 0) '任务 $taskCompletedCount',
      if (hasPeriod) '经期',
    ];
    return parts.join(' · ');
  }
}

/// 一个月的回顾。
///
/// **只含事实**：预测不进来（回顾是「发生过什么」），未发生的承诺也不进来
/// （否则「上个月」会混进明天的账单）。
@immutable
class TimelineHistory {
  const TimelineHistory({
    required this.monthStart,
    required this.days,
    required this.totalExpenseMinor,
    required this.totalCheckinCount,
    required this.totalTaskCompletedCount,
  });

  final DateTime monthStart;

  /// 倒序（最近的在上），只包含有内容的日子。
  final List<TimelineHistoryDay> days;

  final int totalExpenseMinor;
  final int totalCheckinCount;
  final int totalTaskCompletedCount;

  bool get isEmpty => days.isEmpty;
}

/// 从组装好的时间线里折出回顾。
///
/// 复用同一份 [Timeline]：不另查一遍数据，也就不可能和日程页对不上。
TimelineHistory buildHistory(Timeline timeline) {
  final days = <TimelineHistoryDay>[];
  var totalExpense = 0;
  var totalCheckins = 0;
  var totalTasks = 0;

  for (final day in timeline.days) {
    var expense = 0;
    var checkins = 0;
    var tasks = 0;
    var hasPeriod = false;
    for (final event in day.facts) {
      switch (event.kind) {
        case 'transaction':
          final amount = event.amountMinor ?? 0;
          if (amount < 0) {
            expense += -amount;
          }
        case 'checkinDay':
          checkins += event.count ?? 1;
        case 'todoCompleted':
          tasks += 1;
        case 'health.actualPeriod':
          hasPeriod = true;
      }
    }
    if (expense == 0 && checkins == 0 && tasks == 0 && !hasPeriod) {
      continue;
    }
    totalExpense += expense;
    totalCheckins += checkins;
    totalTasks += tasks;
    days.add(
      TimelineHistoryDay(
        day: day.day,
        expenseMinor: expense,
        checkinCount: checkins,
        taskCompletedCount: tasks,
        hasPeriod: hasPeriod,
      ),
    );
  }

  days.sort((a, b) => b.day.compareTo(a.day));
  return TimelineHistory(
    monthStart: timeline.window.start,
    days: days,
    totalExpenseMinor: totalExpense,
    totalCheckinCount: totalCheckins,
    totalTaskCompletedCount: totalTasks,
  );
}
