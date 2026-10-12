import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/home/presentation/home_action_habit_card.dart';

HomeHabitEntry habit() {
  final plan = CheckinPlan(
    id: 'p1',
    userId: 'u1',
    name: '阅读',
    icon: '📖',
    targetValue: 30,
    targetUnit: '页',
    createdAt: DateTime.utc(2026, 10, 1),
    updatedAt: DateTime.utc(2026, 10, 1),
  );
  return HomeHabitEntry(
    progress: PlanProgress(plan: plan, currentCount: 1, currentValue: 20, streak: 12),
  );
}

Widget host(HomeActionHabitCard card) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: card),
);

void main() {
  testWidgets('empty state renders', (tester) async {
    await tester.pumpWidget(
      host(
        HomeActionHabitCard(habits: const [], onTapHabit: (_) {}),
      ),
    );
    expect(find.text('还没有打卡计划'), findsOneWidget);
  });

  testWidgets('habit tile shows progress and emits tap', (tester) async {
    HomeHabitEntry? tapped;
    await tester.pumpWidget(
      host(
        HomeActionHabitCard(habits: [habit()], onTapHabit: (h) => tapped = h),
      ),
    );
    expect(find.text('阅读'), findsOneWidget);
    expect(find.textContaining('20/30 页'), findsOneWidget);
    await tester.tap(find.text('打卡'));
    expect(tapped?.name, '阅读');
  });
}
