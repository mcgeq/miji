import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/data/drift_todo_repository.dart';
import 'package:miji/features/todo/domain/today_board.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/domain/todo_repository.dart';
import 'package:miji/core/sync/delta_sync/delta_sync_providers.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final todoRepositoryProvider = Provider<TodoRepository>((ref) {
  return DriftTodoRepository(
    database: ref.watch(appDatabaseProvider),
    syncChangeLogger: ref.watch(syncChangeLoggerProvider),
  );
});

// ---------------------------------------------------------------------------
// 今日 Todo 任务
// ---------------------------------------------------------------------------

final todayTodoTasksProvider = FutureProvider.autoDispose<List<TodoTask>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  return repo.getTodayTasks(userId, DateTime.now());
});

// ---------------------------------------------------------------------------
// 任务列表（可按筛选条件）
// ---------------------------------------------------------------------------

final todoTaskListProvider = FutureProvider.autoDispose
    .family<List<TodoTask>, TodoTaskFilter>((ref, filter) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];

      final repo = ref.watch(todoRepositoryProvider);
      return repo.getTasks(userId, filter);
    });

// ---------------------------------------------------------------------------
// 全部待办任务（顶层，不含已完成/已取消）
// ---------------------------------------------------------------------------

final allTodoTasksProvider = FutureProvider.autoDispose<List<TodoTask>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  return repo.getTasks(
    userId,
    const TodoTaskFilter(statuses: [TodoTaskStatus.todo]),
  );
});

// ---------------------------------------------------------------------------
// 已完成任务
// ---------------------------------------------------------------------------

final completedTodoTasksProvider = FutureProvider.autoDispose<List<TodoTask>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  return repo.getTasks(
    userId,
    const TodoTaskFilter(statuses: [TodoTaskStatus.completed]),
  );
});

// ---------------------------------------------------------------------------
// 任务详情
// ---------------------------------------------------------------------------

final todoTaskDetailProvider = FutureProvider.autoDispose
    .family<TodoTask?, String>((ref, taskId) async {
      final repo = ref.watch(todoRepositoryProvider);
      return repo.getTask(taskId);
    });

// ---------------------------------------------------------------------------
// 分类列表
// ---------------------------------------------------------------------------

final todoCategoriesProvider = FutureProvider.autoDispose<List<TodoCategory>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  return repo.getCategories(userId);
});

// ---------------------------------------------------------------------------
// V1.1: 标签列表
// ---------------------------------------------------------------------------

final todoTagsProvider = FutureProvider.autoDispose<List<TodoTag>>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  return repo.getTags(userId);
});

// ---------------------------------------------------------------------------
// V1.1: 重复规则列表
// ---------------------------------------------------------------------------

final todoRecurrenceRulesProvider =
    FutureProvider.autoDispose<List<TodoRecurrenceRule>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];

      final repo = ref.watch(todoRepositoryProvider);
      return repo.getRecurrenceRules(userId);
    });

// ---------------------------------------------------------------------------
// V1.1: 搜索
// ---------------------------------------------------------------------------

final todoSearchProvider = FutureProvider.autoDispose
    .family<List<TodoTask>, String>((ref, query) async {
      if (query.trim().isEmpty) return [];
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];

      final repo = ref.watch(todoRepositoryProvider);
      return repo.searchTasks(userId, query);
    });

// ---------------------------------------------------------------------------
// V1.1: 按日期查询任务（日历用）
// ---------------------------------------------------------------------------

final todoTasksByDateProvider = FutureProvider.autoDispose
    .family<List<TodoTask>, DateTime>((ref, date) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];

      final repo = ref.watch(todoRepositoryProvider);
      return repo.getTasksByDate(userId, date);
    });

// ---------------------------------------------------------------------------
// 今日行动聚合（Todo + 习惯打卡）
// ---------------------------------------------------------------------------

/// 今日行动视图模型（界面层聚合，不落库）
class TodayActionView {
  const TodayActionView({
    required this.items,
    required this.completedCount,
    required this.totalCount,
  });

  final List<TodayActionItem> items;
  final int completedCount;
  final int totalCount;

  double get completionRate =>
      totalCount > 0 ? completedCount / totalCount : 0.0;
}

final todayActionItemsProvider = FutureProvider.autoDispose<TodayActionView>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) {
    return const TodayActionView(items: [], completedCount: 0, totalCount: 0);
  }

  final items = await loadTodayActionItems(ref, userId);
  final completed = items.where((item) => item.isCompleted).length;

  return TodayActionView(
    items: items,
    completedCount: completed,
    totalCount: items.length,
  );
});

/// 今日行动项（待办 + 打卡），排好序返回。
///
/// 抽成函数是因为 [todayBoardProvider] 要的是**同一批数据、同一套排序**，但它
/// 不能用 `ref.watch(todayActionItemsProvider.future)` 去拿 —— 见那边的注释。
Future<List<TodayActionItem>> loadTodayActionItems(
  Ref ref,
  String userId,
) async {
  final todoRepo = ref.watch(todoRepositoryProvider);
  final checkinRepo = ref.watch(checkinRepositoryProvider);

  final today = DateTime.now();

  // 并行获取 Todo 和习惯数据
  final results = await Future.wait([
    todoRepo.getTodayTasks(userId, today),
    checkinRepo.getTodayProgress(userId, today),
  ]);

  final todoTasks = results[0] as List<TodoTask>;
  final habitProgress = results[1] as List<PlanProgress>;

  // 构建 Todo 行动项
  final todoItems = todoTasks.map((task) {
    return TodayTodoActionItem(task: task);
  }).toList();

  // 构建习惯行动项（TodayHabitActionItem 定义在 todo_models.dart 中引用）
  // 注意：TodayHabitActionItem 需要 PlanProgress，它在 checkin_models.dart 中
  final habitItems = habitProgress.map((progress) {
    return TodayHabitActionItem(progress: progress);
  }).toList();

  // 排序
  final allItems = <TodayActionItem>[...todoItems, ...habitItems];
  allItems.sort(_compareActionItems);

  return allItems;
}

int _compareActionItems(TodayActionItem a, TodayActionItem b) {
  // 逾期 Todo 优先
  final aOverdue = a is TodayTodoActionItem && a.task.isOverdue;
  final bOverdue = b is TodayTodoActionItem && b.task.isOverdue;
  if (aOverdue && !bOverdue) return -1;
  if (!aOverdue && bOverdue) return 1;

  // 高优先级在前
  int priorityWeight(TodayActionItem item) {
    if (item is TodayTodoActionItem) return item.task.priority.sortWeight;
    return 0;
  }

  final pw = priorityWeight(b).compareTo(priorityWeight(a));
  if (pw != 0) return pw;

  // 已完成的排后面
  if (a.isCompleted != b.isCompleted) {
    return a.isCompleted ? 1 : -1;
  }

  // 按时间排序
  final aTime = a.sortTime;
  final bTime = b.sortTime;
  if (aTime != null && bTime != null) return aTime.compareTo(bTime);
  if (aTime != null) return -1;
  if (bTime != null) return 1;

  return 0;
}

// ---------------------------------------------------------------------------
// 今日分段视图（「今日」tab 用）
// ---------------------------------------------------------------------------

/// 「今日」tab 的分段视图：把同一批行动项按一天的时间轴归组。
///
/// **刻意不去** `ref.watch(todayActionItemsProvider.future)`，而是像它一样直接
/// 查 repository。原因是 Riverpod 的暂停 / 恢复机制：`ConsumerStatefulWidget`
/// 的 element 会按 `TickerMode` 暂停订阅（被路由盖住时），回来时 `resume()` 会
/// **同步** flush 依赖链 —— 若这条链上有别的异步 provider（`X 依赖 Y.future`），
/// Y 在暂停期间被 invalidate 过后重算，X 就会 `invalidateSelf` 并立刻
/// `scheduleRefresh`，而那一刻框架正在 build 另一个 widget，直接抛
/// `setState() called during build`。自己查库就没有这条链。
///
/// 代价：它不会被 `todayActionItemsProvider` 的失效带着走，所以
/// `invalidateTodoData` 里必须显式 invalidate 它（已经加上了）。
final todayBoardProvider = FutureProvider.autoDispose<TodayBoard>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  final now = DateTime.now();
  if (userId == null) {
    return buildTodayBoard(items: const [], now: now);
  }

  final items = await loadTodayActionItems(ref, userId);
  final completedTodos = await loadCompletedTodayTodos(ref, userId, now);

  return buildTodayBoard(
    items: <TodayActionItem>[
      ...items,
      ...completedTodos.map((task) => TodayTodoActionItem(task: task)),
    ],
    now: now,
  );
});

/// 今天之内完成的待办。
///
/// `getTodayTasks` 只查 `status = todo`，所以「今日」页上原本**看不到**今天已经
/// 做完的任务 —— 勾完就消失，连「我今天做了 5 件」的痕迹都没有。这里从已完成
/// 列表里按 `completedAt` 捞回今天那批，补进「已完成」段。
Future<List<TodoTask>> loadCompletedTodayTodos(
  Ref ref,
  String userId,
  DateTime now,
) async {
  final repo = ref.watch(todoRepositoryProvider);
  final all = await repo.getTasks(
    userId,
    const TodoTaskFilter(statuses: [TodoTaskStatus.completed]),
  );

  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 1));

  return all
      .where((task) {
        final at = task.completedAt;
        if (at == null) return false;
        return !at.isBefore(start) && at.isBefore(end);
      })
      .toList(growable: false);
}

/// 收集箱里那些既没排期、也没截止日的未完成任务。
///
/// 空态只说「去创建任务」是不够的：多数时候人不是没任务，是有一堆没归到某一天
/// 的任务。这个 provider 让人不必切页就能把今天填满。上限 6 条 —— 建议一旦变成
/// 一张长清单，就退化成第二个「全部任务」页了。
final todayUnscheduledProvider = FutureProvider.autoDispose<List<TodoTask>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(todoRepositoryProvider);
  final all = await repo.getTasks(
    userId,
    const TodoTaskFilter(statuses: [TodoTaskStatus.todo]),
  );

  final candidates = all.where(isUnscheduledTodo).toList();
  candidates.sort((a, b) {
    final pw = b.priority.sortWeight.compareTo(a.priority.sortWeight);
    if (pw != 0) return pw;
    // 同等优先级时新的在前：刚想到的通常比陈年旧账更该先做。
    return b.createdAt.compareTo(a.createdAt);
  });

  return candidates.take(6).toList(growable: false);
});

// ---------------------------------------------------------------------------
// V1.2: 统计范围
// ---------------------------------------------------------------------------

final todoStatsRangeProvider =
    NotifierProvider<TodoStatsRangeNotifier, TodoStatsRange>(
      TodoStatsRangeNotifier.new,
    );

class TodoStatsRangeNotifier extends Notifier<TodoStatsRange> {
  @override
  TodoStatsRange build() => TodoStatsRange.last7Days;
  void set(TodoStatsRange range) => state = range;
}

// ---------------------------------------------------------------------------
// V1.2: 统计 Providers
// ---------------------------------------------------------------------------

final todoStatsSummaryProvider = FutureProvider.autoDispose<TodoStatsSummary>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return const TodoStatsSummary();
  final range = TodoStatsRangeInfo.forRange(ref.watch(todoStatsRangeProvider));
  final repo = ref.watch(todoRepositoryProvider);
  return repo.getStatsSummary(userId, range);
});

final todoCompletionTrendProvider =
    FutureProvider.autoDispose<List<TodoDailyTrend>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];
      final range = TodoStatsRangeInfo.forRange(
        ref.watch(todoStatsRangeProvider),
      );
      final repo = ref.watch(todoRepositoryProvider);
      return repo.getCompletionTrend(userId, range);
    });

final todoCategoryDistributionProvider =
    FutureProvider.autoDispose<List<TodoDistribution>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];
      final range = TodoStatsRangeInfo.forRange(
        ref.watch(todoStatsRangeProvider),
      );
      final repo = ref.watch(todoRepositoryProvider);
      return repo.getCategoryDistribution(userId, range);
    });

final todoTagDistributionProvider =
    FutureProvider.autoDispose<List<TodoDistribution>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];
      final range = TodoStatsRangeInfo.forRange(
        ref.watch(todoStatsRangeProvider),
      );
      final repo = ref.watch(todoRepositoryProvider);
      return repo.getTagDistribution(userId, range);
    });

final todoPriorityDistributionProvider =
    FutureProvider.autoDispose<List<TodoDistribution>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];
      final range = TodoStatsRangeInfo.forRange(
        ref.watch(todoStatsRangeProvider),
      );
      final repo = ref.watch(todoRepositoryProvider);
      return repo.getPriorityDistribution(userId, range);
    });

final todoReviewTipsProvider = FutureProvider.autoDispose<List<TodoReviewTip>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];
  final range = TodoStatsRangeInfo.forRange(ref.watch(todoStatsRangeProvider));
  final repo = ref.watch(todoRepositoryProvider);
  return repo.getReviewTips(userId, range);
});

// ---------------------------------------------------------------------------
// V1.2: CSV 导出
// ---------------------------------------------------------------------------

final todoExportCsvProvider = FutureProvider.autoDispose
    .family<String, TodoStatsRange>((ref, range) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return '';
      final rangeInfo = TodoStatsRangeInfo.forRange(range);
      final repo = ref.watch(todoRepositoryProvider);
      return repo.exportTasksCsv(userId, rangeInfo);
    });

// ---------------------------------------------------------------------------
// 刷新辅助
// ---------------------------------------------------------------------------

/// 刷新所有 Todo 相关数据
void invalidateTodoData(WidgetRef ref) {
  ref.invalidate(todayTodoTasksProvider);
  ref.invalidate(todayActionItemsProvider);
  ref.invalidate(todayBoardProvider);
  ref.invalidate(todayUnscheduledProvider);
  ref.invalidate(todoTaskListProvider);
  ref.invalidate(allTodoTasksProvider);
  ref.invalidate(completedTodoTasksProvider);
  ref.invalidate(todoTagsProvider);
  ref.invalidate(todoRecurrenceRulesProvider);
  ref.invalidate(todoSearchProvider);
  ref.invalidate(todoTasksByDateProvider);
}

/// 刷新 Todo + 打卡的全部今日数据
void invalidateTodayActionData(WidgetRef ref) {
  invalidateTodoData(ref);
  invalidateCheckinData(ref);
}
