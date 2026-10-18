import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/timeline/domain/timeline_history.dart';

/// 回顾只回答「发生过什么」：预测和未发生的承诺都不许混进来。
void main() {
  final month = TimelineWindow.monthOf(DateTime.utc(2026, 10, 18));

  TimelineEvent event({
    required String id,
    required String kind,
    required DateTime day,
    int? amountMinor,
    int? count,
    TimelineNature nature = TimelineNature.fact,
  }) {
    return TimelineEvent(
      id: id,
      occurredOn: day,
      module: TimelineModule.money,
      nature: nature,
      kind: kind,
      title: '事件',
      amountMinor: amountMinor,
      count: count,
    );
  }

  TimelineHistory build(List<TimelineEvent> events) {
    return buildHistory(
      assembleTimeline(window: month, eventGroups: [events]),
    );
  }

  test('按天汇总：支出合计、打卡次数、完成任务数', () {
    final history = build([
      event(
        id: 't1',
        kind: 'transaction',
        day: DateTime.utc(2026, 10, 18),
        amountMinor: -12000,
      ),
      event(
        id: 't2',
        kind: 'transaction',
        day: DateTime.utc(2026, 10, 18),
        amountMinor: -3800,
      ),
      event(
        id: 'h1',
        kind: 'checkinDay',
        day: DateTime.utc(2026, 10, 18),
        count: 3,
      ),
      event(
        id: 'a1',
        kind: 'todoCompleted',
        day: DateTime.utc(2026, 10, 17),
      ),
    ]);

    expect(history.days, hasLength(2));
    // 倒序：18 号在上。
    final today = history.days.first;
    expect(today.expenseMinor, 15800);
    expect(today.checkinCount, 3);
    expect(today.taskCompletedCount, 0);
    expect(history.totalExpenseMinor, 15800);
    expect(history.totalCheckinCount, 3);
    expect(history.totalTaskCompletedCount, 1);
  });

  test('收入不算支出：负数才计入', () {
    final history = build([
      event(
        id: 'in',
        kind: 'transaction',
        day: DateTime.utc(2026, 10, 18),
        amountMinor: 1200000,
      ),
    ]);
    expect(history.isEmpty, isTrue);
  });

  test('预测与承诺不进回顾', () {
    final history = build([
      event(
        id: 'predicted',
        kind: 'health.predictedPeriod',
        day: DateTime.utc(2026, 10, 20),
        nature: TimelineNature.prediction,
      ),
      event(
        id: 'due',
        kind: 'commitment.auto_posting',
        day: DateTime.utc(2026, 10, 25),
        amountMinor: -800000,
        nature: TimelineNature.commitment,
      ),
    ]);
    expect(history.isEmpty, isTrue, reason: '回顾是过去，不是计划');
  });

  test('经期只记「有」，不带细节', () {
    final history = build([
      event(
        id: 'period',
        kind: 'health.actualPeriod',
        day: DateTime.utc(2026, 10, 3),
      ),
    ]);
    expect(history.days.single.hasPeriod, isTrue);
    expect(history.days.single.summary, contains('经期'));
  });

  test('一天只有收入或只有预测时不出现在列表里', () {
    final history = build([
      event(
        id: 't',
        kind: 'transaction',
        day: DateTime.utc(2026, 10, 18),
        amountMinor: 500000,
      ),
      event(
        id: 'p',
        kind: 'health.pms',
        day: DateTime.utc(2026, 10, 19),
        nature: TimelineNature.prediction,
      ),
    ]);
    expect(history.days, isEmpty);
  });
}
