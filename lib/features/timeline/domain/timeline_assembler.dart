import 'package:miji/features/bookkeeping/domain/money_budget_commitment_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 把各模块的领域对象折成 [TimelineEvent]。
///
/// 全是纯函数：输入是仓库已经返回的对象，不查库、不读 provider。这样「哪条事件
/// 属于哪天、属于哪一类」可以单独钉测试，而不用起一个数据库。
///
/// 三条贯穿全文件的规则：
/// 1. **日粒度不编时刻**：打卡、经期、待办的 `scheduledDate` 都只有「哪天」。
/// 2. **预测不冒充事实**：经期预测、PMS、易孕窗全部标 `prediction`。
/// 3. **身份稳定**：`module:table:id`，同一件事不会在两个窗口里出现两次。

/// 每天的展示上限（超过则截断，由界面给出「还有 N 条」）。
const int timelineEventsPerDayLimit = 12;

/// 一天的编排结果。
class TimelineDay {
  TimelineDay({
    required this.day,
    required List<TimelineEvent> commitments,
    required List<TimelineEvent> facts,
    required List<TimelineEvent> predictions,
    required this.hiddenCount,
  }) : commitments = List.unmodifiable(commitments),
       facts = List.unmodifiable(facts),
       predictions = List.unmodifiable(predictions);

  /// 这一天的零点（UTC date-key）。
  final DateTime day;

  /// 待发生（含预测——预测也是「还没发生」，但界面用虚线区分）。
  final List<TimelineEvent> commitments;

  /// 预测单独一列，避免混进承诺的计数里。
  final List<TimelineEvent> predictions;

  /// 已发生。
  final List<TimelineEvent> facts;

  /// 被上限截掉的条数。
  final int hiddenCount;

  bool get isEmpty =>
      commitments.isEmpty && facts.isEmpty && predictions.isEmpty;

  int get total => commitments.length + predictions.length + facts.length;
}

/// 整条时间线。
class Timeline {
  const Timeline({required this.window, required this.days});

  final TimelineWindow window;

  /// 升序，只包含窗口内、且至少有一条事件的日子。
  final List<TimelineDay> days;

  bool get isEmpty => days.isEmpty;

  int get totalEvents =>
      days.fold(0, (sum, day) => sum + day.total + day.hiddenCount);
}

/// 组装：按日分桶 → 截断 → 排序。
///
/// 排序规则（有意为之）：
/// - 待发生里**没有时刻的排前面**（「全天」的事通常更重要，比如还款）；
/// - 同时刻按标题稳定排序，避免每次重建时顺序抖动；
/// - 已发生按时刻倒序（刚发生的在上）。
Timeline assembleTimeline({
  required TimelineWindow window,
  required Iterable<List<TimelineEvent>> eventGroups,
  int perDayLimit = timelineEventsPerDayLimit,
}) {
  final buckets = <DateTime, List<TimelineEvent>>{};
  final seen = <String>{};
  for (final group in eventGroups) {
    for (final event in group) {
      if (!window.contains(event.occurredOn)) {
        continue;
      }
      // 同一身份只留一条（跨越多个来源时也不会重复）。
      if (!seen.add(event.id)) {
        continue;
      }
      buckets.putIfAbsent(event.dayKey, () => <TimelineEvent>[]).add(event);
    }
  }

  final days = <TimelineDay>[];
  for (final day in window.days) {
    final events = buckets[day];
    if (events == null || events.isEmpty) {
      continue;
    }
    final commitments = <TimelineEvent>[];
    final predictions = <TimelineEvent>[];
    final facts = <TimelineEvent>[];
    for (final event in events) {
      switch (event.nature) {
        case TimelineNature.commitment:
          commitments.add(event);
        case TimelineNature.prediction:
          predictions.add(event);
        case TimelineNature.fact:
          facts.add(event);
        case TimelineNature.container:
          // 容器不进行列表：它们是顶部区间带，由界面单独渲染。
          break;
      }
    }

    commitments.sort(_compareUpcoming);
    predictions.sort(_compareUpcoming);
    facts.sort(_comparePast);

    // 截断：先保住「待发生」，再保住刚发生的。被截掉的计数交给界面，
    // 不让它静默消失。
    final kept = <TimelineEvent>[];
    final ordered = [...commitments, ...predictions, ...facts];
    for (final event in ordered) {
      if (kept.length >= perDayLimit) {
        break;
      }
      kept.add(event);
    }
    final keptIds = kept.map((event) => event.id).toSet();

    days.add(
      TimelineDay(
        day: day,
        commitments: commitments
            .where((event) => keptIds.contains(event.id))
            .toList(growable: false),
        predictions: predictions
            .where((event) => keptIds.contains(event.id))
            .toList(growable: false),
        facts: facts
            .where((event) => keptIds.contains(event.id))
            .toList(growable: false),
        hiddenCount: events.length - kept.length,
      ),
    );
  }

  return Timeline(window: window, days: days);
}

int _compareUpcoming(TimelineEvent a, TimelineEvent b) {
  if (a.isTimed != b.isTimed) {
    // 没有时刻的（全天）排前面。
    return a.isTimed ? 1 : -1;
  }
  if (a.isTimed && b.isTimed) {
    final byTime = a.at!.compareTo(b.at!);
    if (byTime != 0) {
      return byTime;
    }
  }
  return a.title.compareTo(b.title);
}

int _comparePast(TimelineEvent a, TimelineEvent b) {
  if (a.isTimed && b.isTimed) {
    final byTime = b.at!.compareTo(a.at!);
    if (byTime != 0) {
      return byTime;
    }
  } else if (a.isTimed != b.isTimed) {
    return a.isTimed ? -1 : 1;
  }
  return a.title.compareTo(b.title);
}

// ───────────────────────── 记账 ─────────────────────────

/// 流水 = 事实；未来义务 = 承诺。
List<TimelineEvent> moneyEvents({
  Iterable<MoneyTransactionEntity> transactions = const [],
  Iterable<MoneyBudgetCommitmentItem> commitments = const [],
}) {
  return [
    for (final transaction in transactions) _transactionEvent(transaction),
    for (final commitment in commitments) _commitmentEvent(commitment),
  ];
}

TimelineEvent _transactionEvent(MoneyTransactionEntity transaction) {
  final signed = transaction.type == MoneyTransactionType.income
      ? transaction.amountMinor
      : -transaction.amountMinor;
  return TimelineEvent(
    id: 'money:transaction:${transaction.id}',
    occurredOn: transaction.transactionAt.toUtc(),
    at: transaction.transactionAt.toUtc(),
    precision: TimelinePrecision.minute,
    module: TimelineModule.money,
    nature: TimelineNature.fact,
    kind: 'transaction',
    title: transaction.description,
    subtitle: _transactionSubtitle(transaction),
    amountMinor: signed,
    currencyCode: transaction.currencyCode,
  );
}

String? _transactionSubtitle(MoneyTransactionEntity transaction) {
  final parts = <String>[];
  if (transaction.notes != null && transaction.notes!.trim().isNotEmpty) {
    parts.add(transaction.notes!.trim());
  }
  if (transaction.status == MoneyTransactionStatus.pending) {
    parts.add('待确认');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

TimelineEvent _commitmentEvent(MoneyBudgetCommitmentItem item) {
  return TimelineEvent(
    id:
        'money:commitment:${item.source.storageValue}:${item.sourceId}:'
        '${item.date.millisecondsSinceEpoch}',
    occurredOn: item.date.toUtc(),
    module: TimelineModule.money,
    // 四种来源（自动记账 / 分期 / 账单 / 待确认）都是「还没发生但会发生」。
    nature: TimelineNature.commitment,
    kind: 'commitment.${item.source.storageValue}',
    title: item.title,
    subtitle: item.detail,
    amountMinor: -item.amountMinor,
    currencyCode: item.currencyCode,
  );
}

// ───────────────────────── 待办 ─────────────────────────

/// 待办的 `scheduledDate` / `dueAt` = 承诺，`completedAt` = 事实。
List<TimelineEvent> todoEvents(Iterable<TodoTask> tasks) {
  final events = <TimelineEvent>[];
  for (final task in tasks) {
    final completedAt = task.completedAt;
    if (completedAt != null) {
      events.add(
        TimelineEvent(
          id: 'action:todo:${task.id}',
          occurredOn: completedAt.toUtc(),
          at: completedAt.toUtc(),
          precision: TimelinePrecision.minute,
          module: TimelineModule.action,
          nature: TimelineNature.fact,
          kind: 'todoCompleted',
          title: task.title,
          subtitle: '完成 · 待办',
          target: TimelineTarget(
            route: '/app/gtd/tasks/${task.id}',
            label: '看待办',
          ),
        ),
      );
      continue;
    }

    // 未完成：落在哪一天？优先 dueAt（有时刻），否则 scheduledDate（日期）。
    final dueAt = task.dueAt?.toUtc();
    final scheduled = task.scheduledDate?.toUtc();
    final day = dueAt ?? scheduled;
    if (day == null) {
      continue;
    }
    events.add(
      TimelineEvent(
        id: 'action:todo:${task.id}',
        occurredOn: day,
        at: dueAt,
        precision: dueAt == null
            ? TimelinePrecision.day
            : TimelinePrecision.minute,
        module: TimelineModule.action,
        nature: TimelineNature.commitment,
        kind: 'todoDue',
        title: task.title,
        subtitle: task.dueAt == null ? '待办' : '截止 · 待办',
        emphasis: task.priority == TodoTaskPriority.high
            ? TimelineEmphasis.attention
            : TimelineEmphasis.normal,
        ruleId: task.recurrenceRuleId,
        target: TimelineTarget(
          route: '/app/gtd/tasks/${task.id}',
          label: '看待办',
          askRuleScope: task.recurrenceRuleId != null,
        ),
      ),
    );
  }
  return events;
}

// ───────────────────────── 打卡 ─────────────────────────

/// 打卡记录 = 事实，但**一天聚合成一条**。
///
/// 一天可能打十几次卡（喝水、站立、吃药），逐条列出来会把其它事件挤掉。
/// 聚合成「打卡 4 次：喝水、站立、吃药」既保住信息，也不淹没时间线。
List<TimelineEvent> habitEvents({
  Iterable<CheckinRecord> records = const [],
  Iterable<CheckinPlan> plans = const [],
  int titleLimit = 3,
}) {
  final planNames = <String, String>{
    for (final plan in plans) plan.id: plan.name,
  };
  final byDay = <DateTime, List<CheckinRecord>>{};
  for (final record in records) {
    if (record.isDeleted) {
      continue;
    }
    final day = DateTime.utc(
      record.recordDate.year,
      record.recordDate.month,
      record.recordDate.day,
    );
    byDay.putIfAbsent(day, () => <CheckinRecord>[]).add(record);
  }

  return [
    for (final entry in byDay.entries)
      _habitDayEvent(entry.key, entry.value, planNames, titleLimit),
  ];
}

TimelineEvent _habitDayEvent(
  DateTime day,
  List<CheckinRecord> records,
  Map<String, String> planNames,
  int titleLimit,
) {
  final names = <String>[];
  for (final record in records) {
    final name = record.plan?.name ?? planNames[record.planId];
    if (name != null && !names.contains(name)) {
      names.add(name);
    }
  }
  final shown = names.take(titleLimit).join('、');
  final rest = names.length - titleLimit;
  final subtitle = names.isEmpty
      ? '打卡记录'
      : rest > 0
      ? '$shown 等 ${names.length} 项'
      : shown;
  // 用当天最后一次完成时刻排序：聚合行也有一个「什么时候做完的」。
  final lastAt = records
      .map((record) => record.completedAt.toUtc())
      .reduce((a, b) => a.isAfter(b) ? a : b);
  return TimelineEvent(
    id: 'action:habit:$day',
    occurredOn: day,
    at: lastAt,
    precision: TimelinePrecision.minute,
    module: TimelineModule.action,
    nature: TimelineNature.fact,
    kind: 'checkinDay',
    title: '打卡 ${records.length} 次',
    subtitle: subtitle,
    target: const TimelineTarget(route: '/app/gtd', label: '看打卡'),
  );
}

// ───────────────────────── 健康 ─────────────────────────

/// 经期 / 用药 / 记录 = 事实；预测 / PMS / 易孕窗 = 推断。
List<TimelineEvent> healthEvents(Iterable<HealthCalendarMarker> markers) {
  return [for (final marker in markers) _healthMarkerEvent(marker)];
}

TimelineEvent _healthMarkerEvent(HealthCalendarMarker marker) {
  final predicted = switch (marker.kind) {
    HealthCalendarMarkerKind.predictedPeriod ||
    HealthCalendarMarkerKind.pms ||
    HealthCalendarMarkerKind.fertileWindow => true,
    _ => false,
  };
  final day = DateTime.utc(
    marker.date.year,
    marker.date.month,
    marker.date.day,
  );
  return TimelineEvent(
    id: 'health:${marker.kind.name}:$day',
    occurredOn: day,
    module: TimelineModule.health,
    nature: predicted ? TimelineNature.prediction : TimelineNature.fact,
    kind: 'health.${marker.kind.name}',
    title: marker.label,
    subtitle: predicted ? '按历史周期推算' : null,
    target: const TimelineTarget(route: '/app/health', label: '看健康'),
    // 经期与相关的身体数据需要二次验证后才显示细节。
    sensitive: true,
  );
}

/// 健康类事件在未解锁时的占位标题。
///
/// 连「经期」两个字都不能给：它本身就是信息。
const String timelineLockedHealthTitle = '健康 · 需解锁';
