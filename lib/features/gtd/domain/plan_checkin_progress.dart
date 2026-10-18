import 'dart:math' as math;

import 'package:miji/features/gtd/domain/checkin_models.dart';

// ---------------------------------------------------------------------------
// 今日打卡的算术：点一下前进多少、还差多少、环里写什么。
//
// 都做成纯函数，因为这几条规则同时被「今日」混排行、「习惯」列表和计划详情
// 使用，任何一处写错都会让同一天在三个地方显示不同的进度。
// ---------------------------------------------------------------------------

/// 在今日行里点一次进度环，今天应该前进多少（单位 = 计划的 `targetUnit`）。
///
/// 为什么不是固定的 +1：8 杯水点 8 次很自然，30 分钟阅读点 30 次就不像话了。
/// 按单位给一个「一次点按代表多少」，让满目标所需的点按次数落在 3～10 次之间。
/// 步长永远不超过目标值本身，否则一次点按就会冲过目标。
double planQuickStep(CheckinPlan plan) {
  final target = plan.targetValue;
  if (target <= 0) return 1;

  final base = switch (plan.targetUnit) {
    '分钟' => 5.0,
    '小时' => 0.5,
    '升' => 0.25,
    '公里' => 1.0,
    '页' => 5.0,
    _ => 1.0,
  };
  return math.min(base, target);
}

/// 今天还差多少才达标。已经达标返回 0（不会返回负数）。
double planRemainingToTarget(CheckinPlan plan, double currentValue) {
  final remaining = plan.targetValue - currentValue;
  return remaining > 0 ? remaining : 0;
}

/// 进度环里那个数字。
///
/// 目标为 1 的计划返回 null：环里写「0」或「1」没有意义，直接留空、达标时画勾。
String? planRingLabel(CheckinPlan plan, double currentValue) {
  if (plan.targetValue <= 1) return null;
  if (plan.targetUnit == '升' || plan.targetUnit == '公里') {
    // 小数点后一位才有意义，0.0 这种写法反而更难看懂。
    final text = currentValue.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }
  return currentValue.toInt().toString();
}

/// 今日目标，例如「目标 8 杯」「目标 30 分钟」。
String planTargetLabel(CheckinPlan plan) {
  final value = _trimNumber(plan.targetValue);
  return '目标 $value ${plan.targetUnit}';
}

/// 今日完成的量，例如「3 / 8 杯」「24 / 30 分钟」。
///
/// 单位是「次」时不写出来：计划列表里「1 / 3 次」不如「1 / 3」直接。
String planProgressLabel(CheckinPlan plan, double currentValue) {
  final current = _trimNumber(currentValue);
  final target = _trimNumber(plan.targetValue);
  if (plan.targetUnit == '次') return '$current / $target';
  return '$current / $target ${plan.targetUnit}';
}

/// 连续打卡天数：从今天往回数，该计划每天只要**有记录**就算一天。
///
/// 为什么以「有记录」而不是「达标」为口径：与 `getStreak`（全局连续天数）
/// 保持一致，避免同一个应用里两套「连续」定义；且 8 杯水的计划喝到第 7 杯
/// 就把连续天数清零，惩罚感太强。
///
/// 今天还没打卡不算断——早上打开应用时连续天数不该已经掉到 0。
int planStreakDays({
  required Set<DateTime> checkinDays,
  required DateTime today,
}) {
  final days = checkinDays
      .map((day) => DateTime.utc(day.year, day.month, day.day))
      .toSet();
  final todayKey = DateTime.utc(today.year, today.month, today.day);

  var cursor = days.contains(todayKey)
      ? todayKey
      : todayKey.subtract(const Duration(days: 1));
  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// 计时器时间的显示，`12:35` 这种。
String formatTimerClock(int seconds) {
  final safe = seconds < 0 ? 0 : seconds;
  final mins = safe ~/ 60;
  final secs = safe % 60;
  return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

/// 计时器当前已经走过的秒数。
int timerElapsedSeconds(CheckinTimerState state) {
  return switch (state) {
    CheckinTimerRunning(
      startedAt: final startedAt,
      pausedDurationSeconds: final paused,
    ) =>
      DateTime.now().difference(startedAt).inSeconds - paused,
    CheckinTimerPaused(
      pausedDurationSeconds: final paused,
      pausedAt: final pausedAt,
    ) =>
      paused - DateTime.now().difference(pausedAt).inSeconds,
    _ => 0,
  };
}

String _trimNumber(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  final text = value.toStringAsFixed(2);
  return text.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
}
