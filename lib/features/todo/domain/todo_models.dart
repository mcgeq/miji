import 'package:miji/features/gtd/domain/checkin_models.dart';

/// Todo 任务状态
enum TodoTaskStatus {
  todo('todo'),
  completed('completed'),
  cancelled('cancelled');

  const TodoTaskStatus(this.value);
  final String value;

  static TodoTaskStatus fromValue(String value) {
    return TodoTaskStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TodoTaskStatus.todo,
    );
  }

  bool get isTodo => this == TodoTaskStatus.todo;
  bool get isCompleted => this == TodoTaskStatus.completed;
  bool get isCancelled => this == TodoTaskStatus.cancelled;
}

/// Todo 任务优先级
enum TodoTaskPriority {
  none('none'),
  low('low'),
  medium('medium'),
  high('high');

  const TodoTaskPriority(this.value);
  final String value;

  static TodoTaskPriority fromValue(String value) {
    return TodoTaskPriority.values.firstWhere(
      (p) => p.value == value,
      orElse: () => TodoTaskPriority.none,
    );
  }

  int get sortWeight {
    return switch (this) {
      TodoTaskPriority.high => 3,
      TodoTaskPriority.medium => 2,
      TodoTaskPriority.low => 1,
      TodoTaskPriority.none => 0,
    };
  }
}

// ---------------------------------------------------------------------------
// V1.1: 重复频率类型
// ---------------------------------------------------------------------------

enum RecurrenceFrequencyType {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  yearly('yearly');

  const RecurrenceFrequencyType(this.value);
  final String value;

  static RecurrenceFrequencyType fromValue(String value) {
    return RecurrenceFrequencyType.values.firstWhere(
      (f) => f.value == value,
      orElse: () => RecurrenceFrequencyType.daily,
    );
  }

  String get label {
    return switch (this) {
      RecurrenceFrequencyType.daily => '每天',
      RecurrenceFrequencyType.weekly => '每周',
      RecurrenceFrequencyType.monthly => '每月',
      RecurrenceFrequencyType.yearly => '每年',
    };
  }
}

// ---------------------------------------------------------------------------
// Todo 任务实体
// ---------------------------------------------------------------------------

class TodoTask {
  const TodoTask({
    required this.id,
    required this.userId,
    required this.title,
    this.notes,
    required this.status,
    required this.priority,
    this.scheduledDate,
    this.dueAt,
    this.categoryId,
    this.parentTaskId,
    this.sortOrder = 0,
    this.completedAt,
    this.cancelledAt,
    // V1.1 新增
    this.isRecurrenceTemplate = false,
    this.recurrenceRuleId,
    this.occurrenceDate,
    this.reminderAt,
    // V1.2+ Markdown 正文
    this.markdownBody,
    // 同步字段
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    // 导航字段
    this.subTasks = const [],
    this.category,
    this.tags = const [],
    this.recurrenceRule,
  });

  final String id;
  final String userId;
  final String title;
  final String? notes;
  final TodoTaskStatus status;
  final TodoTaskPriority priority;
  final DateTime? scheduledDate;
  final DateTime? dueAt;
  final String? categoryId;
  final String? parentTaskId;
  final int sortOrder;
  final DateTime? completedAt;
  final DateTime? cancelledAt;

  // V1.1 新增
  final bool isRecurrenceTemplate;
  final String? recurrenceRuleId;
  final DateTime? occurrenceDate;
  final DateTime? reminderAt;

  // V1.2+ Markdown 正文
  final String? markdownBody;

  // 同步字段
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // 导航字段
  final List<TodoTask> subTasks;
  final TodoCategory? category;
  final List<TodoTag> tags;
  final TodoRecurrenceRule? recurrenceRule;

  // ---------------------------------------------------------------------------
  // 派生属性
  // ---------------------------------------------------------------------------

  bool isDueToday(DateTime today) {
    if (status != TodoTaskStatus.todo) return false;
    if (isDeleted) return false;

    final todayDate = DateTime.utc(today.year, today.month, today.day);
    if (scheduledDate != null) {
      final sd = DateTime.utc(
        scheduledDate!.year,
        scheduledDate!.month,
        scheduledDate!.day,
      );
      if (sd == todayDate) return true;
    }
    if (occurrenceDate != null) {
      final od = DateTime.utc(
        occurrenceDate!.year,
        occurrenceDate!.month,
        occurrenceDate!.day,
      );
      if (od == todayDate) return true;
    }
    if (dueAt != null) {
      final dd = DateTime.utc(dueAt!.year, dueAt!.month, dueAt!.day);
      if (dd == todayDate) return true;
      if (dd.isBefore(todayDate)) return true;
    }
    return false;
  }

  bool get isOverdue {
    if (status != TodoTaskStatus.todo) return false;
    if (dueAt == null) return false;
    final now = DateTime.now();
    return dueAt!.isBefore(now);
  }

  double get subTaskProgress {
    if (subTasks.isEmpty) return 1.0;
    final completed = subTasks
        .where((s) => s.status == TodoTaskStatus.completed)
        .length;
    return completed / subTasks.length;
  }

  TodoTask copyWith({
    String? id,
    String? userId,
    String? title,
    String? notes,
    TodoTaskStatus? status,
    TodoTaskPriority? priority,
    DateTime? scheduledDate,
    DateTime? dueAt,
    String? categoryId,
    String? parentTaskId,
    int? sortOrder,
    DateTime? completedAt,
    DateTime? cancelledAt,
    bool? isRecurrenceTemplate,
    String? recurrenceRuleId,
    DateTime? occurrenceDate,
    DateTime? reminderAt,
    String? markdownBody,
    String? deviceId,
    int? version,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<TodoTask>? subTasks,
    TodoCategory? category,
    List<TodoTag>? tags,
    TodoRecurrenceRule? recurrenceRule,
  }) {
    return TodoTask(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      dueAt: dueAt ?? this.dueAt,
      categoryId: categoryId ?? this.categoryId,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      sortOrder: sortOrder ?? this.sortOrder,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      isRecurrenceTemplate: isRecurrenceTemplate ?? this.isRecurrenceTemplate,
      recurrenceRuleId: recurrenceRuleId ?? this.recurrenceRuleId,
      occurrenceDate: occurrenceDate ?? this.occurrenceDate,
      reminderAt: reminderAt ?? this.reminderAt,
      markdownBody: markdownBody ?? this.markdownBody,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subTasks: subTasks ?? this.subTasks,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
    );
  }
}

/// 创建任务时的草稿
class TodoTaskDraft {
  const TodoTaskDraft({
    required this.title,
    this.notes,
    this.priority = TodoTaskPriority.none,
    this.scheduledDate,
    this.dueAt,
    this.categoryId,
    this.parentTaskId,
    // V1.1
    this.isRecurrenceTemplate = false,
    this.recurrenceRuleId,
    this.occurrenceDate,
    this.reminderAt,
    this.tagIds,
    // V1.2+
    this.markdownBody,
  });

  final String title;
  final String? notes;
  final TodoTaskPriority priority;
  final DateTime? scheduledDate;
  final DateTime? dueAt;
  final String? categoryId;
  final String? parentTaskId;
  final bool isRecurrenceTemplate;
  final String? recurrenceRuleId;
  final DateTime? occurrenceDate;
  final DateTime? reminderAt;
  final List<String>? tagIds;

  // V1.2+
  final String? markdownBody;

  TodoTaskDraft copyWith({
    String? title,
    Object? notes = _sentinel,
    TodoTaskPriority? priority,
    Object? scheduledDate = _sentinel,
    Object? dueAt = _sentinel,
    Object? categoryId = _sentinel,
    Object? parentTaskId = _sentinel,
    bool? isRecurrenceTemplate,
    Object? recurrenceRuleId = _sentinel,
    Object? occurrenceDate = _sentinel,
    Object? reminderAt = _sentinel,
    Object? tagIds = _sentinel,
    Object? markdownBody = _sentinel,
  }) {
    return TodoTaskDraft(
      title: title ?? this.title,
      notes: notes == _sentinel ? this.notes : notes as String?,
      priority: priority ?? this.priority,
      scheduledDate: scheduledDate == _sentinel
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      dueAt: dueAt == _sentinel ? this.dueAt : dueAt as DateTime?,
      categoryId: categoryId == _sentinel
          ? this.categoryId
          : categoryId as String?,
      parentTaskId: parentTaskId == _sentinel
          ? this.parentTaskId
          : parentTaskId as String?,
      isRecurrenceTemplate: isRecurrenceTemplate ?? this.isRecurrenceTemplate,
      recurrenceRuleId: recurrenceRuleId == _sentinel
          ? this.recurrenceRuleId
          : recurrenceRuleId as String?,
      occurrenceDate: occurrenceDate == _sentinel
          ? this.occurrenceDate
          : occurrenceDate as DateTime?,
      reminderAt: reminderAt == _sentinel
          ? this.reminderAt
          : reminderAt as DateTime?,
      tagIds: tagIds == _sentinel ? this.tagIds : tagIds as List<String>?,
      markdownBody: markdownBody == _sentinel
          ? this.markdownBody
          : markdownBody as String?,
    );
  }
}

const _sentinel = Object();

/// Todo 分类实体
class TodoCategory {
  const TodoCategory({
    required this.id,
    required this.userId,
    required this.name,
    this.color = '#6366F1',
    this.icon = '📋',
    this.sortOrder = 0,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String color;
  final String icon;
  final int sortOrder;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoCategory copyWith({
    String? id,
    String? userId,
    String? name,
    String? color,
    String? icon,
    int? sortOrder,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoCategory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// V1.1: Todo 标签
// ---------------------------------------------------------------------------

class TodoTag {
  const TodoTag({
    required this.id,
    required this.userId,
    required this.name,
    this.color = '#6366F1',
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String color;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoTag copyWith({
    String? id,
    String? userId,
    String? name,
    String? color,
    String? deviceId,
    int? version,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoTag(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      color: color ?? this.color,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// V1.1: 重复任务规则
// ---------------------------------------------------------------------------

class TodoRecurrenceRule {
  const TodoRecurrenceRule({
    required this.id,
    required this.userId,
    required this.templateTaskId,
    required this.frequencyType,
    this.interval_ = 1,
    this.daysOfWeek,
    this.dayOfMonth,
    this.monthOfYear,
    this.dayOfYear,
    this.endsAt,
    this.reminderMode = 'none',
    this.reminderConfigJson,
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String templateTaskId;
  final RecurrenceFrequencyType frequencyType;
  final int interval_;
  final List<int>? daysOfWeek;
  final int? dayOfMonth;
  final int? monthOfYear;
  final int? dayOfYear;
  final DateTime? endsAt;
  final String reminderMode;
  final String? reminderConfigJson;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  TodoRecurrenceRule copyWith({
    String? id,
    String? userId,
    String? templateTaskId,
    RecurrenceFrequencyType? frequencyType,
    int? interval_,
    List<int>? daysOfWeek,
    int? dayOfMonth,
    int? monthOfYear,
    int? dayOfYear,
    DateTime? endsAt,
    String? reminderMode,
    String? reminderConfigJson,
    String? deviceId,
    int? version,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TodoRecurrenceRule(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      templateTaskId: templateTaskId ?? this.templateTaskId,
      frequencyType: frequencyType ?? this.frequencyType,
      interval_: interval_ ?? this.interval_,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      monthOfYear: monthOfYear ?? this.monthOfYear,
      dayOfYear: dayOfYear ?? this.dayOfYear,
      endsAt: endsAt ?? this.endsAt,
      reminderMode: reminderMode ?? this.reminderMode,
      reminderConfigJson: reminderConfigJson ?? this.reminderConfigJson,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ---------------------------------------------------------------------------
// 任务列表筛选条件
// ---------------------------------------------------------------------------

class TodoTaskFilter {
  const TodoTaskFilter({
    this.statuses = const [TodoTaskStatus.todo],
    this.priorities,
    this.categoryId,
    this.scheduledDate,
    this.dueDate,
    this.parentTaskId,
    this.tagId,
    this.searchQuery,
    this.includeDeleted = false,
    this.excludeRecurrenceTemplates = true,
    this.limit,
    this.offset,
  });

  final List<TodoTaskStatus> statuses;
  final List<TodoTaskPriority>? priorities;
  final String? categoryId;
  final DateTime? scheduledDate;
  final DateTime? dueDate;
  final String? parentTaskId;
  final String? tagId;
  final String? searchQuery;
  final bool includeDeleted;
  final bool excludeRecurrenceTemplates;
  final int? limit;
  final int? offset;
}

// ---------------------------------------------------------------------------
// V1.2: 统计模型
// ---------------------------------------------------------------------------

enum TodoStatsRange { last7Days, last30Days, thisMonth }

class TodoStatsRangeInfo {
  const TodoStatsRangeInfo(this.range, this.start, this.end);
  final TodoStatsRange range;
  final DateTime start;
  final DateTime end;

  String get label {
    return switch (range) {
      TodoStatsRange.last7Days => '近 7 天',
      TodoStatsRange.last30Days => '近 30 天',
      TodoStatsRange.thisMonth => '本月',
    };
  }

  static TodoStatsRangeInfo forRange(TodoStatsRange range) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (range) {
      TodoStatsRange.last7Days => TodoStatsRangeInfo(
        range,
        today.subtract(const Duration(days: 6)),
        today.add(const Duration(days: 1)),
      ),
      TodoStatsRange.last30Days => TodoStatsRangeInfo(
        range,
        today.subtract(const Duration(days: 29)),
        today.add(const Duration(days: 1)),
      ),
      TodoStatsRange.thisMonth => TodoStatsRangeInfo(
        range,
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 1),
      ),
    };
  }
}

class TodoStatsSummary {
  const TodoStatsSummary({
    this.plannedCount = 0,
    this.completedPlannedCount = 0,
    this.completionRate,
    this.totalCompleted = 0,
    this.overdueCount = 0,
    this.cancelledCount = 0,
  });
  final int plannedCount;
  final int completedPlannedCount;
  final double? completionRate;
  final int totalCompleted;
  final int overdueCount;
  final int cancelledCount;

  String get completionRateText {
    if (plannedCount == 0) return '--';
    return '${((completedPlannedCount / plannedCount) * 100).round()}%';
  }
}

class TodoDailyTrend {
  const TodoDailyTrend({required this.date, required this.count});
  final DateTime date;
  final int count;
}

class TodoDistribution {
  const TodoDistribution({
    required this.key,
    required this.count,
    this.label,
    this.color,
  });
  final String key;
  final int count;
  final String? label;
  final String? color;
}

class TodoReviewTip {
  const TodoReviewTip({required this.message, required this.type});
  final String message;
  final TodoReviewTipType type;
  int get colorValue {
    return switch (type) {
      TodoReviewTipType.warning => 0xFFF59E0B,
      TodoReviewTipType.danger => 0xFFEF4444,
      TodoReviewTipType.success => 0xFF22C55E,
    };
  }
}

enum TodoReviewTipType { warning, danger, success }

// ---------------------------------------------------------------------------
// 今日行动视图的聚合模型（界面层，不落库）
// ---------------------------------------------------------------------------

sealed class TodayActionItem {
  const TodayActionItem();

  String get id;
  DateTime? get sortTime;
  bool get isCompleted;
}

class TodayTodoActionItem extends TodayActionItem {
  const TodayTodoActionItem({required this.task});

  final TodoTask task;

  @override
  String get id => task.id;

  @override
  DateTime? get sortTime => task.dueAt ?? task.scheduledDate;

  @override
  bool get isCompleted => task.status == TodoTaskStatus.completed;
}

class TodayHabitActionItem extends TodayActionItem {
  const TodayHabitActionItem({required this.progress});

  final PlanProgress progress;

  @override
  String get id => progress.plan.id;

  @override
  DateTime? get sortTime => progress.lastCheckinAt;

  @override
  bool get isCompleted => progress.completionRate >= 1.0;
}
