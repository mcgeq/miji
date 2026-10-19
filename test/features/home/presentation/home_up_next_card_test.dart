import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_upcoming_providers.dart';
import 'package:miji/features/home/presentation/home_up_next_card.dart';
import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';

/// 卡片内部的「今天」取 `DateTime.now()`，所以这里的日期必须相对它算，
/// 否则跨零点跑测试就会全绿变全红。
DateTime get today {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

DateTime daysFromToday(int days) =>
    DateTime.utc(today.year, today.month, today.day + days);

TimelineEvent event(
  String id,
  DateTime day, {
  TimelineNature nature = TimelineNature.commitment,
  TimelineModule module = TimelineModule.money,
  int? amountMinor,
}) => TimelineEvent(
  id: id,
  occurredOn: day,
  module: module,
  nature: nature,
  kind: 'commitment.billReminder',
  title: id,
  subtitle: '副标题',
  amountMinor: amountMinor,
  currencyCode: 'CNY',
);

TimelineDay day(
  DateTime when,
  List<TimelineEvent> commitments, {
  List<TimelineEvent> predictions = const [],
  List<TimelineEvent> facts = const [],
}) => TimelineDay(
  day: when,
  commitments: commitments,
  facts: facts,
  predictions: predictions,
  hiddenCount: 0,
);

TimelineResult result(List<TimelineDay> days) => TimelineResult(
  timeline: Timeline(
    window: TimelineWindow(start: daysFromToday(1), end: daysFromToday(7)),
    days: days,
  ),
  failures: const [],
);

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: child),
);

Future<void> pumpCard(WidgetTester tester, TimelineResult data) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [homeUpcomingProvider.overrideWith((ref) async => data)],
      child: host(const HomeUpNextCard()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('按天分组，日期小标题用相对说法', (tester) async {
    await pumpCard(
      tester,
      result([
        day(daysFromToday(1), [event('房租', daysFromToday(1))]),
        day(daysFromToday(2), [event('电费', daysFromToday(2))]),
      ]),
    );

    expect(find.text('接下来'), findsOneWidget);
    expect(find.textContaining('明天'), findsOneWidget);
    expect(find.textContaining('后天'), findsOneWidget);
    expect(find.text('房租'), findsOneWidget);
    expect(find.text('电费'), findsOneWidget);
  });

  testWidgets('今天与过去的安排不出现（它们归「需要关注」）', (tester) async {
    await pumpCard(
      tester,
      result([
        day(today, [event('今天的待办', today)]),
        day(daysFromToday(-1), [event('昨天的待办', daysFromToday(-1))]),
        day(daysFromToday(1), [event('明天的账单', daysFromToday(1))]),
      ]),
    );

    expect(find.text('今天的待办'), findsNothing);
    expect(find.text('昨天的待办'), findsNothing);
    expect(find.text('明天的账单'), findsOneWidget);
  });

  testWidgets('没有安排时空态提示', (tester) async {
    await pumpCard(tester, result([]));
    expect(find.textContaining('没有安排'), findsOneWidget);
  });
}
