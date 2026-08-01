import 'package:miji/features/gtd/domain/checkin_models.dart';

/// 打卡模块 Repository 接口
abstract class CheckinRepository {
  // ---------------------------------------------------------------------------
  // 计划管理
  // ---------------------------------------------------------------------------

  /// 获取用户所有未归档的计划（按 sort_order 排序）
  Future<List<CheckinPlan>> getActivePlans(String userId);

  /// 获取用户所有计划（包含归档）
  Future<List<CheckinPlan>> getAllPlans(String userId);

  /// 获取单个计划
  Future<CheckinPlan?> getPlan(String planId);

  /// 创建计划
  Future<CheckinPlan> createPlan(CheckinPlanDraft draft, String userId);

  /// 更新计划
  Future<CheckinPlan> updatePlan(CheckinPlan plan);

  /// 归档/取消归档计划
  Future<void> archivePlan(String planId, bool archived);

  /// 删除计划（软删除）
  Future<void> deletePlan(String planId);

  /// 调整排序
  Future<void> reorderPlans(List<String> planIdsInOrder);

  /// 按分类获取模板计划（seed 数据用的接口）
  Future<List<CheckinPlan>> getPlansByCategory(String userId, String category);

  // ---------------------------------------------------------------------------
  // 打卡记录
  // ---------------------------------------------------------------------------

  /// 获取某一天的所有打卡记录（含关联的计划和照片）
  Future<List<CheckinRecord>> getRecordsByDate(String userId, DateTime date);

  /// 获取某个计划在某一天的所有打卡记录（详细模式可能有多条）
  Future<List<CheckinRecord>> getRecordsByPlanAndDate(
    String planId,
    DateTime date,
  );

  /// 获取某个计划某个日期范围内的打卡记录
  Future<List<CheckinRecord>> getRecordsByPlanAndDateRange(
    String planId,
    DateTime startDate,
    DateTime endDate,
  );

  /// 创建或更新打卡记录（合并模式下 upsert）
  Future<CheckinRecord> upsertRecord(CheckinRecordDraft draft, String userId);

  /// 创建新的打卡记录（详细模式）
  Future<CheckinRecord> createRecord(CheckinRecordDraft draft, String userId);

  /// 更新打卡记录
  Future<CheckinRecord> updateRecord(CheckinRecord record);

  /// 删除打卡记录（软删除）
  Future<void> deleteRecord(String recordId);

  /// 获取今日所有计划的进度
  Future<List<PlanProgress>> getTodayProgress(String userId, DateTime date);

  // ---------------------------------------------------------------------------
  // 照片
  // ---------------------------------------------------------------------------

  /// 添加照片
  Future<CheckinPhoto> addPhoto({
    required String recordId,
    required String userId,
    required String localPath,
    DateTime? takenAt,
    String? gpsJson,
  });

  /// 删除照片
  Future<void> deletePhoto(String photoId);

  // ---------------------------------------------------------------------------
  // 统计
  // ---------------------------------------------------------------------------

  /// 获取连续打卡天数
  Future<CheckinStreak> getStreak(String userId, DateTime upTo);

  /// 获取日期范围的每日摘要
  Future<List<DailyCheckinSummary>> getDailySummaries(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// 获取某个计划的趋势数据点
  Future<List<Map<String, dynamic>>> getPlanTrend(
    String planId,
    DateTime startDate,
    DateTime endDate,
  );

  /// 按分类统计打卡次数
  Future<Map<String, int>> getCategoryStats(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );

  /// 导出所有数据为 JSON 字符串。
  Future<String> exportAllJson(String userId);

  /// 获取心情分布（1-5）。
  Future<Map<int, int>> getMoodDistribution(
    String userId,
    DateTime startDate,
    DateTime endDate,
  );
}
