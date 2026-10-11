import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';

enum HomeHealthHintKind { period, pregnancy }

/// 首页健康窄条的展示内容。健康是独立 Tab，首页只给一行提示。
class HomeHealthHint {
  const HomeHealthHint({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final HomeHealthHintKind kind;
  final String title;
  final String detail;
}

/// 未开启经期追踪、或没有足够历史时返回 null，首页不渲染窄条。
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

  switch (prediction.statusKind) {
    case HealthTodayStatusKind.pregnancy:
      final week = prediction.pregnancyWeek;
      if (week == null) {
        return null;
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.pregnancy,
        title: '孕期第 $week 周',
        detail: hasDailyLogToday ? '今天已记录' : '今天还没记录',
      );

    case HealthTodayStatusKind.periodDay:
      final day = prediction.currentPeriodDay;
      if (day == null) {
        return null;
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '经期第 $day 天',
        detail: hasDailyLogToday ? '今天已记录' : '今天还没记录',
      );

    case HealthTodayStatusKind.cycleDay:
      final nextStart = prediction.nextPeriodStart;
      if (nextStart == null) {
        return null;
      }
      final daysUntil = _dateOnly(nextStart).difference(today).inDays;
      final nextLabel = '${nextStart.month}月${nextStart.day}日预计开始';
      if (daysUntil < 0) {
        return HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '经期已推迟 ${daysUntil.abs()} 天',
          detail: nextLabel,
        );
      }
      if (daysUntil == 0) {
        return HomeHealthHint(
          kind: HomeHealthHintKind.period,
          title: '预计今天来经期',
          detail: hasDailyLogToday ? '今天已记录' : '今天还没记录',
        );
      }
      return HomeHealthHint(
        kind: HomeHealthHintKind.period,
        title: '距下次经期还有 $daysUntil 天',
        detail: hasDailyLogToday ? '$nextLabel · 今天已记录' : '$nextLabel · 今天还没记录',
      );

    case HealthTodayStatusKind.noPeriodHistory:
      return null;
  }
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
