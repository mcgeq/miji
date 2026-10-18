import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

enum HomeReminderSource { money, todo, habit, health }

enum HomeReminderSeverity { overdue, dueToday, dueSoon, normal }

sealed class HomeReminderAction {
  const HomeReminderAction();
}

class OpenMoneyRemindersAction extends HomeReminderAction {
  const OpenMoneyRemindersAction();
}

class CompleteTodoAction extends HomeReminderAction {
  const CompleteTodoAction(this.task);
  final TodoTask task;
}

class CheckInHabitAction extends HomeReminderAction {
  const CheckInHabitAction(this.progress);
  final PlanProgress progress;
}

class OpenHealthAction extends HomeReminderAction {
  const OpenHealthAction();
}

/// 统一提醒条目：四类来源合成一种模型，界面只按 [source] / [severity] 渲染。
class HomeReminderItem {
  const HomeReminderItem({
    required this.source,
    required this.severity,
    required this.title,
    required this.subtitle,
    required this.action,
    this.dueDate,
    this.amountMinor,
    this.currencyCode,
    this.isIncome = false,
  });

  final HomeReminderSource source;
  final HomeReminderSeverity severity;
  final String title;
  final String subtitle;
  final HomeReminderAction action;
  final DateTime? dueDate;
  final int? amountMinor;
  final String? currencyCode;
  final bool isIncome;
}

class HomeUnifiedReminders {
  const HomeUnifiedReminders({required this.items});

  static const empty = HomeUnifiedReminders(items: []);

  final List<HomeReminderItem> items;
}

final homeUnifiedRemindersProvider = Provider<HomeUnifiedReminders>((ref) {
  final session = ref.watch(authSessionControllerProvider);
  if (session.userId == null) {
    return HomeUnifiedReminders.empty;
  }

  final money =
      ref.watch(currentUserPendingReminderCenterItemsProvider).asData?.value ??
      const <MoneyReminderCenterItem>[];
  final budgets =
      ref.watch(currentUserBudgetsProvider).asData?.value ??
      const <MoneyBudgetEntity>[];
  final todos =
      ref.watch(allTodoTasksProvider).asData?.value ?? const <TodoTask>[];
  final habits =
      ref.watch(todayProgressProvider).asData?.value ?? const <PlanProgress>[];
  final health = ref
      .watch(currentUserHealthTodaySnapshotProvider)
      .asData
      ?.value;

  return buildHomeUnifiedReminders(
    money: money,
    budgets: budgets,
    todos: todos,
    habits: habits,
    health: health,
    now: DateTime.now(),
  );
});

HomeUnifiedReminders buildHomeUnifiedReminders({
  required List<MoneyReminderCenterItem> money,
  required List<MoneyBudgetEntity> budgets,
  required List<TodoTask> todos,
  required List<PlanProgress> habits,
  required HealthTodaySnapshot? health,
  required DateTime now,
}) {
  final items = <HomeReminderItem>[
    ...buildMoneyReminders(money, budgets, now),
    ...buildTodoReminders(todos, now),
    ...buildHabitReminders(habits),
    ...buildHealthReminders(health, now),
  ];
  items.sort(_compareReminders);
  return HomeUnifiedReminders(items: List.unmodifiable(items));
}

List<HomeReminderItem> buildMoneyReminders(
  List<MoneyReminderCenterItem> items,
  List<MoneyBudgetEntity> budgets,
  DateTime now,
) {
  return [
    for (final item in items)
      HomeReminderItem(
        source: HomeReminderSource.money,
        severity: _moneySeverity(item, now),
        title: item.title,
        subtitle: item.isBudgetExceeded
            ? '预算超支'
            : '${DateFormat('MM-dd').format(item.dueDate)} 到期',
        dueDate: item.dueDate,
        amountMinor: item.amountMinor,
        currencyCode: item.currencyCode,
        isIncome: item.isIncomeAmount(budgets),
        action: const OpenMoneyRemindersAction(),
      ),
  ];
}

List<HomeReminderItem> buildTodoReminders(List<TodoTask> tasks, DateTime now) {
  final today = _dateOnly(now);
  final out = <HomeReminderItem>[];
  for (final task in tasks) {
    if (task.status != TodoTaskStatus.todo || task.isDeleted) {
      continue;
    }
    final due = task.dueAt ?? task.scheduledDate;
    if (due == null) {
      continue;
    }
    final dueDay = _dateOnly(due);
    final diff = dueDay.difference(today).inDays;
    if (diff > 0) {
      continue;
    }
    out.add(
      HomeReminderItem(
        source: HomeReminderSource.todo,
        severity: diff < 0
            ? HomeReminderSeverity.overdue
            : HomeReminderSeverity.dueToday,
        title: task.title,
        subtitle: diff < 0 ? '逾期 ${-diff} 天' : '今天到期',
        dueDate: due,
        action: CompleteTodoAction(task),
      ),
    );
  }
  return out;
}

List<HomeReminderItem> buildHabitReminders(List<PlanProgress> habits) {
  return [
    for (final progress in habits)
      if (progress.plan.reminderEnabled && progress.completionRate < 1.0)
        HomeReminderItem(
          source: HomeReminderSource.habit,
          severity: HomeReminderSeverity.dueToday,
          title: progress.plan.name,
          subtitle: '今天还没打卡',
          action: CheckInHabitAction(progress),
        ),
  ];
}

List<HomeReminderItem> buildHealthReminders(
  HealthTodaySnapshot? snapshot,
  DateTime now,
) {
  if (snapshot == null) {
    return const [];
  }
  final settings = snapshot.settings;
  if (!settings.periodTrackingEnabled) {
    return const [];
  }
  final prediction = snapshot.prediction;
  final today = _dateOnly(now);
  final reminderDays = settings.reminderDays;
  final out = <HomeReminderItem>[];

  if (settings.periodReminderEnabled && prediction.nextPeriodStart != null) {
    final days = _dateOnly(
      prediction.nextPeriodStart!,
    ).difference(today).inDays;
    if (days < 0) {
      out.add(
        HomeReminderItem(
          source: HomeReminderSource.health,
          severity: HomeReminderSeverity.overdue,
          title: '经期已推迟 ${-days} 天',
          subtitle: '可更新周期记录',
          action: const OpenHealthAction(),
        ),
      );
    } else if (days == 0) {
      out.add(
        const HomeReminderItem(
          source: HomeReminderSource.health,
          severity: HomeReminderSeverity.dueToday,
          title: '预计今天来经期',
          subtitle: '记得记录',
          action: OpenHealthAction(),
        ),
      );
    } else if (days <= reminderDays) {
      out.add(
        HomeReminderItem(
          source: HomeReminderSource.health,
          severity: HomeReminderSeverity.dueSoon,
          title: '经期预计 $days 天后开始',
          subtitle: '提前准备',
          action: const OpenHealthAction(),
        ),
      );
    }
  }

  if (settings.ovulationReminderEnabled &&
      prediction.fertileWindowStart != null) {
    final days = _dateOnly(
      prediction.fertileWindowStart!,
    ).difference(today).inDays;
    if (days >= 0 && days <= reminderDays) {
      out.add(
        HomeReminderItem(
          source: HomeReminderSource.health,
          severity: HomeReminderSeverity.dueSoon,
          title: days == 0 ? '今天是易孕期第一天' : '易孕期预计 $days 天后开始',
          subtitle: '可提前安排',
          action: const OpenHealthAction(),
        ),
      );
    }
  }

  if (settings.pmsReminderEnabled && prediction.pmsStart != null) {
    final days = _dateOnly(prediction.pmsStart!).difference(today).inDays;
    if (days >= 0 && days <= reminderDays) {
      out.add(
        HomeReminderItem(
          source: HomeReminderSource.health,
          severity: HomeReminderSeverity.normal,
          title: days == 0 ? '今天可能进入经前期' : '经前期预计 $days 天后开始',
          subtitle: '注意休息',
          action: const OpenHealthAction(),
        ),
      );
    }
  }

  return out;
}

HomeReminderSeverity _moneySeverity(
  MoneyReminderCenterItem item,
  DateTime now,
) {
  switch (item.priority(today: now)) {
    case MoneyReminderCenterPriority.overdue:
      return HomeReminderSeverity.overdue;
    case MoneyReminderCenterPriority.dueWithinThreeDays:
      return _dateOnly(item.dueDate) == _dateOnly(now)
          ? HomeReminderSeverity.dueToday
          : HomeReminderSeverity.dueSoon;
    case MoneyReminderCenterPriority.budgetExceeded:
      return HomeReminderSeverity.dueSoon;
    case MoneyReminderCenterPriority.normal:
      return HomeReminderSeverity.normal;
  }
}

int _compareReminders(HomeReminderItem a, HomeReminderItem b) {
  final bySeverity = _severityRank(
    a.severity,
  ).compareTo(_severityRank(b.severity));
  if (bySeverity != 0) {
    return bySeverity;
  }
  final aDue = a.dueDate;
  final bDue = b.dueDate;
  if (aDue != null && bDue != null) {
    return aDue.compareTo(bDue);
  }
  if (aDue != null) {
    return -1;
  }
  if (bDue != null) {
    return 1;
  }
  return 0;
}

int _severityRank(HomeReminderSeverity severity) => switch (severity) {
  HomeReminderSeverity.overdue => 0,
  HomeReminderSeverity.dueToday => 1,
  HomeReminderSeverity.dueSoon => 2,
  HomeReminderSeverity.normal => 3,
};

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
