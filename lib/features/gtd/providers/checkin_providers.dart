import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/features/gtd/application/checkin_timer_controller.dart';
import 'package:miji/features/gtd/data/drift_checkin_repository.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/checkin_repository.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

final checkinRepositoryProvider = Provider<CheckinRepository>((ref) {
  return DriftCheckinRepository(database: ref.watch(appDatabaseProvider));
});

// ---------------------------------------------------------------------------
// 计时器
// ---------------------------------------------------------------------------

final checkinTimerProvider =
    NotifierProvider<CheckinTimerController, CheckinTimerState>(
      CheckinTimerController.new,
    );

// ---------------------------------------------------------------------------
// 计划列表
// ---------------------------------------------------------------------------

final activePlansProvider = FutureProvider<List<CheckinPlan>>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getActivePlans(userId);
});

final allPlansProvider = FutureProvider<List<CheckinPlan>>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getAllPlans(userId);
});

// ---------------------------------------------------------------------------
// 今日进度
// ---------------------------------------------------------------------------

final todayProgressProvider = FutureProvider.autoDispose<List<PlanProgress>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getTodayProgress(userId, DateTime.now());
});

// ---------------------------------------------------------------------------
// 选中日期 Notifier
// ---------------------------------------------------------------------------

class SelectedCheckinDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) => state = date;
}

// ---------------------------------------------------------------------------
// 选中日期（用于日历和今日进度）
// ---------------------------------------------------------------------------

final selectedCheckinDateProvider =
    NotifierProvider<SelectedCheckinDateNotifier, DateTime>(
      SelectedCheckinDateNotifier.new,
    );

// ---------------------------------------------------------------------------
// 指定日期的打卡记录
// ---------------------------------------------------------------------------

final recordsByDateProvider = FutureProvider.autoDispose<List<CheckinRecord>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return [];

  final date = ref.watch(selectedCheckinDateProvider);
  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getRecordsByDate(userId, date);
});

// ---------------------------------------------------------------------------
// 连续打卡
// ---------------------------------------------------------------------------

final checkinStreakProvider = FutureProvider.autoDispose<CheckinStreak>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return const CheckinStreak();

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getStreak(userId, DateTime.now());
});

// ---------------------------------------------------------------------------
// 每日摘要（日历热力图数据）
// ---------------------------------------------------------------------------

final dailySummariesProvider =
    FutureProvider.autoDispose<List<DailyCheckinSummary>>((ref) async {
      final session = ref.watch(authSessionControllerProvider);
      final userId = session.userId;
      if (userId == null) return [];

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 90));

      final repo = ref.watch(checkinRepositoryProvider);
      return repo.getDailySummaries(userId, startDate, endDate);
    });

// ---------------------------------------------------------------------------
// 指定计划的趋势数据
// ---------------------------------------------------------------------------

final planTrendProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, planId) async {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final repo = ref.watch(checkinRepositoryProvider);
      return repo.getPlanTrend(planId, startDate, endDate);
    });

// ---------------------------------------------------------------------------
// 分类统计
// ---------------------------------------------------------------------------

final categoryStatsProvider = FutureProvider.autoDispose<Map<String, int>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return {};

  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 30));

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getCategoryStats(userId, startDate, endDate);
});

// ---------------------------------------------------------------------------
// 心情分布
// ---------------------------------------------------------------------------

final moodDistributionProvider = FutureProvider.autoDispose<Map<int, int>>((
  ref,
) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (userId == null) return {};

  final endDate = DateTime.now();
  final startDate = endDate.subtract(const Duration(days: 30));

  final repo = ref.watch(checkinRepositoryProvider);
  return repo.getMoodDistribution(userId, startDate, endDate);
});
