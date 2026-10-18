import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_health_brief_providers.dart';
import 'package:miji/features/home/presentation/home_health_cycle_card.dart';
import 'package:miji/features/home/presentation/home_health_today_card.dart';

HomeHealthBrief brief({bool tracking = true}) => HomeHealthBrief(
  trackingEnabled: tracking,
  isPregnancy: false,
  headline: '经期第 3 天',
  subline: '本次经期进行中',
  phaseLabel: '经期',
  ringRatio: 0.1,
  ringDay: 3,
  ringTotal: 28,
  todayMetrics: const [
    HomeHealthMetric(
      kind: HomeHealthMetricKind.mood,
      emoji: '🙂',
      label: '心情',
      value: '+',
      logged: false,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.sleep,
      emoji: '😴',
      label: '睡眠',
      value: '7h20m',
      logged: true,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.water,
      emoji: '💧',
      label: '饮水',
      value: '+',
      logged: false,
    ),
    HomeHealthMetric(
      kind: HomeHealthMetricKind.weight,
      emoji: '⚖️',
      label: '体重',
      value: '+',
      logged: false,
    ),
  ],
);

void main() {
  testWidgets('cycle card shows headline and opens today', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthCycleCard(
            brief: brief(),
            onOpenHealth: () => opened = true,
          ),
        ),
      ),
    );
    expect(find.text('经期第 3 天'), findsOneWidget);
    await tester.tap(find.byType(HomeHealthCycleCard));
    expect(opened, isTrue);
  });

  testWidgets('cycle card shows enable guide when tracking off', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthCycleCard(
            brief: brief(tracking: false),
            onOpenHealth: () {},
          ),
        ),
      ),
    );
    expect(find.text('开启健康追踪'), findsOneWidget);
  });

  testWidgets('today card emits tapped metric', (tester) async {
    HomeHealthMetricKind? tapped;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthTodayCard(
            metrics: brief().todayMetrics,
            onTapMetric: (kind) => tapped = kind,
          ),
        ),
      ),
    );
    await tester.tap(find.text('睡眠'));
    expect(tapped, HomeHealthMetricKind.sleep);
  });
}
