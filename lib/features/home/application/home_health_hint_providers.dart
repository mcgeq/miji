import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';

enum HomeHealthHintKind { period, pregnancy }

/// 首页三宫格「健康」格用的紧凑摘要。
///
/// 宫格的列宽只有 80dp 上下，塞不下「距下次经期还有 5 天」这种整句 ——
/// 之前直接把整句当大字号主值渲染，结果「还没有周期记录」被截成
/// 「还没有周…」。这里把同一份预测拆成「短主值 + 口径标签 + 一行说明」三段，
/// 让主值永远是短文本，用户先看到数字，再看清这个数字的口径。
typedef HomeHealthDigest = ({String value, String label, String note});

/// 首页健康提示：窄条用 [title] / [detail] 两句长文案，
/// 三宫格用 [digest] 的短主值。
class HomeHealthHint {
  const HomeHealthHint({
    required this.kind,
    required this.title,
    required this.detail,
    required this.digest,
  });

  final HomeHealthHintKind kind;
  final String title;
  final String detail;

  /// 宫格视图：短主值 / 口径标签 / 一行说明。
  final HomeHealthDigest digest;
}

/// 未开启经期追踪时返回 null；已开启但还没记录时返回「还没有周期记录」。
final homeHealthHintProvider = FutureProvider<HomeHealthHint?>((ref) async {
  final session = ref.watch(authSessionControllerProvider);
  final userId = session.userId;
  if (!session.isUnlocked || userId == null || userId.isEmpty) {
    return null;
  }

  final snapshot = await ref.watch(
    currentUserHealthTodaySnapshotProvider.future,
  );
  if (snapshot == null || !snapshot.settings.periodTrackingEnabled) {
    return null;
  }

  return buildHomeHealthHint(
    prediction: snapshot.prediction,
    hasDailyLogToday: snapshot.dailyLog.visibleRecordCount > 0,
    referenceDate: snapshot.date,
  );
});

/// 纯函数版本，便于单元测试。
HomeHealthHint? buildHomeHealthHint({
  required HealthCyclePrediction prediction,
  required bool hasDailyLogToday,
  required DateTime referenceDate,
}) {
  final today = DateTime(
    referenceDate.year,
    referenceDate.month,
    referenceDate.day,
  );

  final logNote = hasDailyLogToday ? '今天已记录' : '今天还没记录';

  switch (prediction.statusKind) {
    case HealthTodayStatusKind.pregnancy:
      final week = prediction.pregnancyWeek;
      if (week == null) {
        return null;
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.pregnancy,
        title: '孕期第 $week 周',
        detail: logNote,
        digest: (value: '第 $week 周', label: '孕期', note: logNote),
      );

    case HealthTodayStatusKind.periodDay:
      final day = prediction.currentPeriodDay;
      if (day == null) {
        return null;
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '经期第 $day 天',
        detail: logNote,
        digest: (value: '第 $day 天', label: '经期', note: logNote),
      );

    case HealthTodayStatusKind.cycleDay:
      final nextStart = prediction.nextPeriodStart;
      if (nextStart == null) {
        // 周期可预测但算不出下次经期（理论上少见）：不要回退成「未开启」。
        return HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '周期记录中',
          detail: logNote,
          digest: (value: '—', label: '周期记录', note: logNote),
        );
      }
      final daysUntil = _dateOnly(nextStart).difference(today).inDays;
      final nextLabel = '${nextStart.month}月${nextStart.day}日预计开始';
      if (daysUntil < 0) {
        final lateDays = daysUntil.abs();
        return HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '经期已推迟 $lateDays 天',
          detail: nextLabel,
          digest: (value: '$lateDays 天', label: '经期已推迟', note: nextLabel),
        );
      }
      if (daysUntil == 0) {
        return HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '预计今天来经期',
          detail: logNote,
          digest: (value: '今天', label: '预计经期', note: logNote),
        );
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '距下次经期还有 $daysUntil 天',
        detail: hasDailyLogToday ? '$nextLabel · 今天已记录' : '$nextLabel · 今天还没记录',
        digest: (value: '$daysUntil 天', label: '距下次经期', note: logNote),
      );

    case HealthTodayStatusKind.noPeriodHistory:
      // 已开启追踪但还没记过一次经期。这里必须返回 hint，否则首页会把
      // 「未开启」的文案错误地套到「已开启、只是没数据」上。
      return HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '还没有周期记录',
        detail: hasDailyLogToday ? '今天已记录' : '记录一次经期即可预测',
        digest: (
          value: '—',
          label: '周期记录',
          note: hasDailyLogToday ? '今天已记录' : '记录一次即可预测',
        ),
      );
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
