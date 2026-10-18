import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/plan_checkin_progress.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

// ---------------------------------------------------------------------------
// 今日打卡的写操作。
//
// 之前这些逻辑散在「习惯」tab 的 `_QuickAddButton` / `_TimerButton` 里，而
// 「今日」tab 压根没有打卡入口 —— 同一件事只有一处实现，另一处就只能进详情页。
// 抽到这里之后两个页面调同一套函数，「今日」点一下和「习惯」点一下写进去的
// 记录完全一致。
// ---------------------------------------------------------------------------

/// 打卡一次，前进一个步长（[planQuickStep]）。
///
/// [currentValue] 是今天的累计值：已经达标的计划不再加，避免出现「9 / 8 杯」
/// 这种越打越多的数字。返回值表示这次是否真的写入了记录。
Future<bool> checkInPlanOnce(
  WidgetRef ref,
  CheckinPlan plan, {
  required double currentValue,
}) async {
  final remaining = planRemainingToTarget(plan, currentValue);
  if (remaining <= 0) return false;

  final step = math.min(planQuickStep(plan), remaining);
  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) return false;

  final now = DateTime.now();
  await ref
      .read(checkinRepositoryProvider)
      .upsertRecord(
        CheckinRecordDraft(
          planId: plan.id,
          recordDate: now,
          completedAt: now,
          count: 1,
          numericValue: step,
        ),
        userId,
      );
  // 「今日」混排行直接查 repository，不 watch 打卡自己的 provider。
  invalidateTodayActionData(ref);
  return true;
}

/// 今天一次做满：把还差的部分一次写进去。
///
/// 用在长按菜单里（「今天全部完成」）—— 30 分钟阅读读了 25 分钟，剩 5 分钟
/// 不该逼用户点一次。
Future<bool> completePlanToday(
  WidgetRef ref,
  CheckinPlan plan, {
  required double currentValue,
}) async {
  final remaining = planRemainingToTarget(plan, currentValue);
  if (remaining <= 0) return false;

  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) return false;

  final now = DateTime.now();
  await ref
      .read(checkinRepositoryProvider)
      .upsertRecord(
        CheckinRecordDraft(
          planId: plan.id,
          recordDate: now,
          completedAt: now,
          count: 1,
          numericValue: remaining,
        ),
        userId,
      );
  invalidateTodayActionData(ref);
  return true;
}

/// 撤销最近一次打卡。
///
/// 「每次独立」的计划直接删掉最后那条记录；「每日合并」的计划按一个步长往回
/// 减，减到零就删记录 —— 合并模式下我们只知道今天总共多少，不知道每一次分别
/// 加了多少，所以撤销只能近似成「回退一步」。
///
/// 计时器落下的记录（带 `durationSeconds`）整条删除：它的分钟数来自一段真实
/// 时间，往回减一个步长会留下「7.5 分钟」这种谁也解释不了的数字。
Future<bool> undoPlanCheckIn(WidgetRef ref, CheckinPlan plan) async {
  final repo = ref.read(checkinRepositoryProvider);
  final records = await repo.getRecordsByPlanAndDate(plan.id, DateTime.now());
  if (records.isEmpty) return false;

  final last = records.reduce(
    (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
  );

  final isSessionRecord = (last.durationSeconds ?? 0) > 0;
  if (plan.recordGranularity == CheckinRecordGranularity.detailed ||
      isSessionRecord) {
    await repo.deleteRecord(last.id);
    invalidateTodayActionData(ref);
    return true;
  }

  final step = planQuickStep(plan);
  final remainingValue = math.max((last.numericValue ?? 0) - step, 0.0);
  final remainingCount = math.max(last.count - 1, 0);

  if (remainingValue <= 0 && remainingCount <= 0) {
    await repo.deleteRecord(last.id);
  } else {
    await repo.updateRecord(
      last.copyWith(count: remainingCount, numericValue: remainingValue),
    );
  }
  invalidateTodayActionData(ref);
  return true;
}

/// 计时器结束时落一条记录。
///
/// 「分钟」为单位的计划要同时把分钟数写进 `numericValue`：今日进度是按
/// `numericValue` 累加的，只写 `durationSeconds` 的话，计完 30 分钟进度条
/// 纹丝不动 —— 之前就是这样，计时型计划永远到不了目标。
Future<bool> recordPlanTimer(
  WidgetRef ref,
  CheckinPlan plan, {
  required int seconds,
}) async {
  if (seconds <= 0) return false;

  final userId = ref.read(authSessionControllerProvider).userId;
  if (userId == null) return false;

  final now = DateTime.now();
  await ref
      .read(checkinRepositoryProvider)
      .upsertRecord(
        CheckinRecordDraft(
          planId: plan.id,
          recordDate: now,
          completedAt: now,
          count: 1,
          numericValue: plan.targetUnit == '分钟' ? seconds / 60 : null,
          durationSeconds: seconds,
        ),
        userId,
      );
  invalidateTodayActionData(ref);
  return true;
}
