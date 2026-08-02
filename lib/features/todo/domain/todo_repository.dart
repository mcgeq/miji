import 'package:miji/features/todo/domain/todo_models.dart';

/// Todo 模块 Repository 接口
abstract class TodoRepository {
  // ---------------------------------------------------------------------------
  // 任务查询
  // ---------------------------------------------------------------------------

  Future<List<TodoTask>> getTodayTasks(String userId, DateTime today);
  Future<List<TodoTask>> getTasks(String userId, TodoTaskFilter filter);
  Future<TodoTask?> getTask(String id);
  Future<List<TodoTask>> getSubTasks(String parentTaskId);

  /// 获取某日期的任务（含 occurrenceDate 匹配）
  Future<List<TodoTask>> getTasksByDate(String userId, DateTime date);

  /// V1.1: 全文搜索
  Future<List<TodoTask>> searchTasks(String userId, String query);

  // ---------------------------------------------------------------------------
  // 任务 CRUD
  // ---------------------------------------------------------------------------

  Future<TodoTask> createTask(TodoTaskDraft draft, String userId);
  Future<TodoTask> updateTask(TodoTask task);
  Future<void> completeTask(String id);
  Future<void> reopenTask(String id);
  Future<void> cancelTask(String id);
  Future<void> softDeleteTask(String id);
  Future<void> restoreTask(String id);
  Future<void> permanentlyDeleteTask(String id);

  // ---------------------------------------------------------------------------
  // 标签 (V1.1)
  // ---------------------------------------------------------------------------

  Future<List<TodoTag>> getTags(String userId);
  Future<TodoTag> createTag(String name, String color, String userId);
  Future<TodoTag> updateTag(TodoTag tag);
  Future<void> deleteTag(String id);

  /// 获取任务的标签
  Future<List<TodoTag>> getTaskTags(String taskId);

  /// 设置任务的标签（替换全部关联）
  Future<void> setTaskTags(String taskId, List<String> tagIds);

  /// 获取指定标签名下的任务数
  Future<int> getTagTaskCount(String tagId);

  // ---------------------------------------------------------------------------
  // 重复规则 (V1.1)
  // ---------------------------------------------------------------------------

  /// 获取用户的重复规则
  Future<List<TodoRecurrenceRule>> getRecurrenceRules(String userId);

  /// 获取单个规则
  Future<TodoRecurrenceRule?> getRecurrenceRule(String id);

  /// 创建重复规则（同时创建模板任务和预生成实例）
  Future<TodoRecurrenceRule> createRecurrenceRule(
    TodoTaskDraft templateDraft,
    TodoRecurrenceRule rule,
    String userId,
  );

  /// 更新重复规则（同时更新模板任务）
  Future<TodoRecurrenceRule> updateRecurrenceRule(
    TodoRecurrenceRule rule,
    TodoTask updatedTemplate,
  );

  /// 删除重复规则（停止生成并软删除未来实例）
  Future<void> deleteRecurrenceRule(String id);

  /// 预生成未来 30 天实例（补足缺口）
  Future<void> generateRecurrenceInstances(
    String userId,
    TodoRecurrenceRule rule,
    TodoTask template,
  );

  // ---------------------------------------------------------------------------
  // 分类
  // ---------------------------------------------------------------------------

  Future<List<TodoCategory>> getCategories(String userId);
  Future<TodoCategory> createCategory(String name, String userId);
  Future<TodoCategory> updateCategory(TodoCategory category);
  Future<void> deleteCategory(String id);

  // ---------------------------------------------------------------------------
  // 排序
  // ---------------------------------------------------------------------------

  Future<void> reorderTasks(List<String> taskIdsInOrder);

  // ---------------------------------------------------------------------------
  // V1.2: 统计
  // ---------------------------------------------------------------------------

  Future<TodoStatsSummary> getStatsSummary(
    String userId,
    TodoStatsRangeInfo range,
  );
  Future<List<TodoDailyTrend>> getCompletionTrend(
    String userId,
    TodoStatsRangeInfo range,
  );
  Future<List<TodoDistribution>> getCategoryDistribution(
    String userId,
    TodoStatsRangeInfo range,
  );
  Future<List<TodoDistribution>> getTagDistribution(
    String userId,
    TodoStatsRangeInfo range,
  );
  Future<List<TodoDistribution>> getPriorityDistribution(
    String userId,
    TodoStatsRangeInfo range,
  );
  Future<List<TodoReviewTip>> getReviewTips(
    String userId,
    TodoStatsRangeInfo range,
  );

  // ---------------------------------------------------------------------------
  // V1.2: CSV 导出
  // ---------------------------------------------------------------------------

  Future<String> exportTasksCsv(String userId, TodoStatsRangeInfo range);
}
