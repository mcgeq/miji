import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/plan_checkin_progress.dart';

/// 今日打卡的算术。这些数字同时决定三处的显示：「今日」混排行、「习惯」列表
/// 和计划详情，所以每条规则都在这里钉住，避免三处各算各的。
void main() {
  CheckinPlan plan({
    String name = '喝水',
    double targetValue = 1,
    String targetUnit = '次',
    CheckinTriggerMode triggerMode = CheckinTriggerMode.button,
  }) {
    return CheckinPlan(
      id: 'plan-$name',
      userId: 'user_1',
      name: name,
      targetValue: targetValue,
      targetUnit: targetUnit,
      triggerMode: triggerMode,
      createdAt: DateTime.utc(2026, 7, 1),
      updatedAt: DateTime.utc(2026, 7, 1),
    );
  }

  group('planQuickStep', () {
    test('按单位给步长：杯/次是 1，分钟是 5，升是 0.25', () {
      expect(planQuickStep(plan(targetValue: 8, targetUnit: '杯')), 1);
      expect(planQuickStep(plan(targetUnit: '次')), 1);
      expect(planQuickStep(plan(targetValue: 30, targetUnit: '分钟')), 5);
      expect(planQuickStep(plan(targetValue: 2, targetUnit: '升')), 0.25);
    });

    test('步长不超过目标：目标 3 分钟时一次点按就能做完', () {
      expect(planQuickStep(plan(targetValue: 3, targetUnit: '分钟')), 3);
      // 0.5 升的目标按 0.25 走两步，仍然不会一次冲过目标。
      expect(planQuickStep(plan(targetValue: 0.5, targetUnit: '升')), 0.25);
    });

    test('目标为 0 或负数时退回 1，不会出现 0 步长', () {
      expect(planQuickStep(plan(targetValue: 0)), 1);
      expect(planQuickStep(plan(targetValue: -3)), 1);
    });
  });

  group('planRemainingToTarget', () {
    test('没达标时返回差额', () {
      final p = plan(targetValue: 8, targetUnit: '杯');
      expect(planRemainingToTarget(p, 3), 5);
    });

    test('达标或超了都返回 0（不给负数，调用方不必再 clamp）', () {
      final p = plan(targetValue: 8, targetUnit: '杯');
      expect(planRemainingToTarget(p, 8), 0);
      expect(planRemainingToTarget(p, 12), 0);
    });
  });

  group('planRingLabel', () {
    test('目标为 1 时不显示数字（环里只画勾或留空）', () {
      expect(planRingLabel(plan(targetUnit: '次'), 0), isNull);
      expect(planRingLabel(plan(targetUnit: '次'), 1), isNull);
    });

    test('多段计划显示今天的量，不带单位', () {
      final cups = plan(targetValue: 8, targetUnit: '杯');
      expect(planRingLabel(cups, 3), '3');
      expect(planRingLabel(cups, 0), '0');

      final minutes = plan(targetValue: 30, targetUnit: '分钟');
      expect(planRingLabel(minutes, 24), '24');
    });

    test('小数单位保留一位，但去掉多余的 .0', () {
      final liters = plan(targetValue: 2, targetUnit: '升');
      expect(planRingLabel(liters, 1.5), '1.5');
      expect(planRingLabel(liters, 2.0), '2');
    });
  });

  group('文案', () {
    test('planTargetLabel 去掉多余的 .0', () {
      expect(planTargetLabel(plan(targetValue: 8, targetUnit: '杯')), '目标 8 杯');
      expect(planTargetLabel(plan(targetValue: 2, targetUnit: '升')), '目标 2 升');
      expect(
        planTargetLabel(plan(targetValue: 0.5, targetUnit: '升')),
        '目标 0.5 升',
      );
    });

    test('planProgressLabel：单位「次」不写出来', () {
      expect(
        planProgressLabel(plan(targetValue: 8, targetUnit: '杯'), 3),
        '3 / 8 杯',
      );
      expect(
        planProgressLabel(plan(targetValue: 30, targetUnit: '分钟'), 24),
        '24 / 30 分钟',
      );
      expect(
        planProgressLabel(plan(targetValue: 3, targetUnit: '次'), 1),
        '1 / 3',
      );
    });
  });

  group('planStreakDays', () {
    final today = DateTime.utc(2026, 7, 18);
    DateTime daysAgo(int n) => today.subtract(Duration(days: n));

    test('从今天往回数连续天数', () {
      expect(
        planStreakDays(
          checkinDays: {daysAgo(0), daysAgo(1), daysAgo(2)},
          today: today,
        ),
        3,
      );
    });

    test('今天还没打卡不算断（早上打开应用不该看到 0）', () {
      expect(
        planStreakDays(checkinDays: {daysAgo(1), daysAgo(2)}, today: today),
        2,
      );
    });

    test('中间缺一天就停在那里', () {
      expect(
        planStreakDays(
          checkinDays: {daysAgo(0), daysAgo(1), daysAgo(3), daysAgo(4)},
          today: today,
        ),
        2,
      );
    });

    test('没有任何记录是 0', () {
      expect(planStreakDays(checkinDays: {}, today: today), 0);
    });

    test('带时分秒的日期按「哪一天」算，不按毫秒比', () {
      expect(
        planStreakDays(
          checkinDays: {
            DateTime.utc(2026, 7, 18, 23, 50),
            DateTime.utc(2026, 7, 17, 0, 5),
          },
          today: today,
        ),
        2,
      );
    });
  });

  group('计时器时间', () {
    test('formatTimerClock 补零，负数当 0', () {
      expect(formatTimerClock(0), '00:00');
      expect(formatTimerClock(65), '01:05');
      expect(formatTimerClock(600), '10:00');
      expect(formatTimerClock(-5), '00:00');
    });

    test('idle 状态走过 0 秒', () {
      expect(timerElapsedSeconds(const CheckinTimerIdle()), 0);
    });
  });
}
