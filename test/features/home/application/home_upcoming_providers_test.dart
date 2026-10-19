import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/home/application/home_upcoming_providers.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

final DateTime today = DateTime.utc(2026, 10, 20);

DateTime at(int offset) =>
    DateTime.utc(today.year, today.month, today.day + offset);

TimelineEvent event(
  String id,
  DateTime day, {
  TimelineNature nature = TimelineNature.commitment,
  TimelineModule module = TimelineModule.money,
}) => TimelineEvent(
  id: id,
  occurredOn: day,
  module: module,
  nature: nature,
  kind: 'todoDue',
  title: id,
);

TimelineDay dayGroup(
  DateTime when, {
  List<TimelineEvent> commitments = const [],
  List<TimelineEvent> predictions = const [],
  List<TimelineEvent> facts = const [],
}) => TimelineDay(
  day: when,
  commitments: commitments,
  facts: facts,
  predictions: predictions,
  hiddenCount: 0,
);

Timeline timeline(List<TimelineDay> days) => Timeline(
  window: TimelineWindow(start: at(1), end: at(7)),
  days: days,
);

void main() {
  group('buildHomeUpcoming', () {
    test('只要明天起的', () {
      final upcoming = buildHomeUpcoming(
        timeline: timeline([
          dayGroup(
            today,
            commitments: [event('今天', today)],
            facts: [event('已发生', today)],
          ),
          dayGroup(at(-1), commitments: [event('昨天', at(-1))]),
          dayGroup(at(1), commitments: [event('明天', at(1))]),
        ]),
        today: today,
      );

      expect(upcoming.groups.length, 1);
      expect(upcoming.groups.single.day, at(1));
    });

    test('已发生的事实不属于「接下来」', () {
      final upcoming = buildHomeUpcoming(
        timeline: timeline([
          dayGroup(at(1), facts: [event('流水', at(1))]),
        ]),
        today: today,
      );
      expect(upcoming.isEmpty, isTrue);
    });

    test('同一天里承诺排在预测前', () {
      final upcoming = buildHomeUpcoming(
        timeline: timeline([
          dayGroup(
            at(1),
            predictions: [
              event('经期预测', at(1), nature: TimelineNature.prediction),
            ],
            commitments: [event('房租', at(1))],
          ),
        ]),
        today: today,
      );
      expect(upcoming.groups.single.events.map((e) => e.title).toList(), [
        '房租',
        '经期预测',
      ]);
    });

    test('截断后 totalCount 仍是完整条数', () {
      final upcoming = buildHomeUpcoming(
        timeline: timeline([
          dayGroup(
            at(1),
            commitments: [
              event('a', at(1)),
              event('b', at(1)),
              event('c', at(1)),
              event('d', at(1)),
            ],
          ),
          dayGroup(at(2), commitments: [event('e', at(2))]),
        ]),
        today: today,
        maxDays: 1,
        maxItems: 2,
      );

      expect(upcoming.shownCount, 2);
      // 「还有 N 项」要报的是窗口里真实的剩余量，不是被截断后剩下的。
      expect(upcoming.totalCount, 5);
    });

    test('maxDays 限制分组数', () {
      final upcoming = buildHomeUpcoming(
        timeline: timeline([
          dayGroup(at(1), commitments: [event('a', at(1))]),
          dayGroup(at(2), commitments: [event('b', at(2))]),
          dayGroup(at(3), commitments: [event('c', at(3))]),
        ]),
        today: today,
        maxDays: 2,
      );
      expect(upcoming.groups.map((g) => g.day).toList(), [at(1), at(2)]);
      expect(upcoming.totalCount, 3);
    });
  });

  group('homeUpcomingDayLabel', () {
    test('先说相对，超过两天补星期', () {
      expect(homeUpcomingDayLabel(at(1), today), '明天 · 10/21');
      expect(homeUpcomingDayLabel(at(2), today), '后天 · 10/22');
      // 2026-10-23 是周五。
      expect(homeUpcomingDayLabel(at(3), today), '周五 · 10/23');
    });
  });
}
