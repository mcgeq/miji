import 'package:miji/features/todo/domain/todo_models.dart';

/// 行动项的展示标题。
///
/// 两类行动项各存各的实体（待办是 `TodoTask`、打卡是 `PlanProgress`），但这一屏
/// 的 HUD、已完成行、批量提示都要读标题 —— 与其在每处写一遍 `is` 分支，不如
/// 在派生层统一给一个读法。
extension TodayActionItemTitle on TodayActionItem {
  String get displayTitle {
    final it = this;
    return switch (it) {
      TodayTodoActionItem(:final task) => task.title,
      TodayHabitActionItem(:final progress) => progress.plan.name,
    };
  }
}

/// 「今日」视图的**分段**模型（界面层派生，不落库）。
///
/// 与 [TodayActionView] 的关系：后者是首页看板 / 状态条在用的扁平聚合，保持原样；
/// 这里是「今日」tab 自己的组织方式 —— 把同一批行动项按一天的时间轴归组。
///
/// 段的顺序固定为「逾期 → 随时 → 上午 → 下午 → 晚上 → 打卡 → 已完成」。
/// 「随时」紧跟在逾期之后是刻意决策：先清掉没有时间约束的杂事，再进入有时间
/// 约束的日程；打卡单独成段是因为它的完成方式是计数 / 计时 / 拍照，与勾选不同，
/// 混进时间分段会让右槽控件在一段里换三种形态。
enum TodaySectionKind {
  overdue,
  anytime,
  morning,
  afternoon,
  evening,
  habit,
  completed;

  String get title {
    return switch (this) {
      TodaySectionKind.overdue => '逾期',
      TodaySectionKind.anytime => '随时',
      TodaySectionKind.morning => '上午',
      TodaySectionKind.afternoon => '下午',
      TodaySectionKind.evening => '晚上',
      TodaySectionKind.habit => '今日打卡',
      TodaySectionKind.completed => '已完成',
    };
  }

  /// 段标题右侧的时间范围提示。只有时间分段才有，其余段不写。
  String? get timeRangeHint {
    return switch (this) {
      TodaySectionKind.morning => '06–12',
      TodaySectionKind.afternoon => '12–18',
      TodaySectionKind.evening => '18–06',
      _ => null,
    };
  }

  bool get isCompleted => this == TodaySectionKind.completed;
}

class TodaySection {
  const TodaySection({required this.kind, required this.items});

  final TodaySectionKind kind;
  final List<TodayActionItem> items;
}

/// 一条「今天最该先做哪件」的提示。
class TodayFocus {
  const TodayFocus({required this.item, required this.isOverdue});

  final TodayActionItem item;
  final bool isOverdue;

  String get title {
    final it = item;
    if (it is TodayTodoActionItem) return it.task.title;
    if (it is TodayHabitActionItem) return it.progress.plan.name;
    return '';
  }
}

class TodayBoard {
  const TodayBoard({
    required this.sections,
    required this.totalCount,
    required this.completedCount,
    this.focus,
  });

  final List<TodaySection> sections;

  final int totalCount;
  final int completedCount;
  final TodayFocus? focus;

  /// 还剩几件。HUD 的环内就显示这个数 —— 用户看「今日」是要知道
  /// 还要做多少，不是已经做了百分之多少。
  int get remainingCount =>
      (totalCount - completedCount) < 0 ? 0 : totalCount - completedCount;

  bool get isEmpty => totalCount == 0;
  bool get isAllDone => totalCount > 0 && remainingCount == 0;

  /// 过滤掉空段的显示顺序（构建时已按固定顺序排好，这里只做过滤）。
  Iterable<TodaySection> get visibleSections =>
      sections.where((section) => section.items.isNotEmpty);

  TodaySection? sectionOf(TodaySectionKind kind) {
    for (final section in sections) {
      if (section.kind == kind) return section;
    }
    return null;
  }
}

/// 把扁平的今日行动项按时间轴归组。
///
/// 纯函数（只依赖 [now]），便于单测：归组规则是这一屏的核心，不该只能在
/// widget 测试里验证。
TodayBoard buildTodayBoard({
  required List<TodayActionItem> items,
  required DateTime now,
}) {
  final buckets = <TodaySectionKind, List<TodayActionItem>>{
    for (final kind in TodaySectionKind.values) kind: <TodayActionItem>[],
  };

  for (final item in items) {
    buckets[_bucketFor(item, now)]!.add(item);
  }

  final sections = <TodaySection>[];
  for (final kind in TodaySectionKind.values) {
    final bucket = buckets[kind]!;
    bucket.sort((a, b) => _compareWithinSection(a, b, kind, now));
    sections.add(TodaySection(kind: kind, items: List.unmodifiable(bucket)));
  }

  final completed = buckets[TodaySectionKind.completed]!.length;

  return TodayBoard(
    sections: List.unmodifiable(sections),
    totalCount: items.length,
    completedCount: completed,
    focus: _focusOf(sections),
  );
}

TodaySectionKind _bucketFor(TodayActionItem item, DateTime now) {
  if (item.isCompleted) {
    return TodaySectionKind.completed;
  }
  if (item is TodayHabitActionItem) {
    return TodaySectionKind.habit;
  }

  final task = (item as TodayTodoActionItem).task;

  // 逾期永远置顶，不管它有没有具体时间。
  if (task.isOverdueAt(now)) {
    return TodaySectionKind.overdue;
  }

  final due = task.dueAt;
  if (due == null) {
    return TodaySectionKind.anytime;
  }

  final hour = due.hour;
  if (hour >= 6 && hour < 12) return TodaySectionKind.morning;
  if (hour >= 12 && hour < 18) return TodaySectionKind.afternoon;
  // 18–23 与 00–05 合并成「晚上」：标「晚上」比标「凌晨」友好，
  // 而深夜档的任务量通常个位数，单独开一段不值。
  return TodaySectionKind.evening;
}

int _compareWithinSection(
  TodayActionItem a,
  TodayActionItem b,
  TodaySectionKind kind,
  DateTime now,
) {
  switch (kind) {
    case TodaySectionKind.overdue:
      // 拖得最久的排最前：它是「最紧」的自然候选。
      final ad = _overdueDays(a, now);
      final bd = _overdueDays(b, now);
      if (ad != bd) return bd.compareTo(ad);
      return _priorityThenOrder(a, b);

    case TodaySectionKind.morning:
    case TodaySectionKind.afternoon:
    case TodaySectionKind.evening:
      // 有时间就按时间；同一时间的按优先级。
      final at = a.sortTime;
      final bt = b.sortTime;
      if (at != null && bt != null && at != bt) return at.compareTo(bt);
      return _priorityThenOrder(a, b);

    case TodaySectionKind.anytime:
      // 没有时间，优先级就是唯一的排序依据。
      return _priorityThenOrder(a, b);

    case TodaySectionKind.habit:
    case TodaySectionKind.completed:
      // 打卡保持 provider 给的顺序；已完成按完成时间倒序（最近做的在上）。
      if (kind == TodaySectionKind.completed) {
        final at = a.sortTime;
        final bt = b.sortTime;
        if (at != null && bt != null) return bt.compareTo(at);
      }
      return 0;
  }
}

int _overdueDays(TodayActionItem item, DateTime now) {
  if (item is TodayTodoActionItem) {
    return item.task.overdueDaysAt(now);
  }
  return 0;
}

int _priorityThenOrder(TodayActionItem a, TodayActionItem b) {
  int weight(TodayActionItem item) {
    if (item is TodayTodoActionItem) return item.task.priority.sortWeight;
    return 0;
  }

  final pw = weight(b).compareTo(weight(a));
  if (pw != 0) return pw;

  int order(TodayActionItem item) {
    if (item is TodayTodoActionItem) return item.task.sortOrder;
    return 0;
  }

  return order(a).compareTo(order(b));
}

/// 「最紧的一条」= 第一个非空、且不是已完成段的第一项。
///
/// 逾期段排第一，所以有逾期时它自然就是逾期里拖得最久的那条 —— 这正是 HUD
/// 上那句「最紧：交房租 · 逾期 2 天」要抓的东西。
TodayFocus? _focusOf(List<TodaySection> sections) {
  for (final section in sections) {
    if (section.kind == TodaySectionKind.completed) continue;
    if (section.items.isEmpty) continue;
    final item = section.items.first;
    return TodayFocus(
      item: item,
      isOverdue: section.kind == TodaySectionKind.overdue,
    );
  }
  return null;
}

/// 「待安排」的判定：既没有排期日、也没有截止时间、也不是重复实例。
///
/// 空态的「从待安排挑」靠它把收集箱里的东西拉进今天。重复实例带
/// `occurrenceDate`（规则自己按节奏生成），不能算「待安排」——否则一次
/// 补 30 天会把未来一个月的实例全列进来。
bool isUnscheduledTodo(TodoTask task) {
  if (task.status != TodoTaskStatus.todo) return false;
  if (task.isDeleted) return false;
  if (task.isRecurrenceTemplate) return false;
  if (task.parentTaskId != null) return false;
  if (task.scheduledDate != null) return false;
  if (task.dueAt != null) return false;
  if (task.occurrenceDate != null) return false;
  return true;
}
