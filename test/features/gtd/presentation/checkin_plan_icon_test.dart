import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/presentation/plans/checkin_plan_icon.dart';

/// 计划图标：旧默认值「📌」不再原样画出来。
void main() {
  CheckinPlan plan({
    String icon = '📌',
    CheckinPlanCategory category = CheckinPlanCategory.exercise,
  }) {
    final now = DateTime.utc(2026, 10, 18);
    return CheckinPlan(
      id: 'plan-1',
      userId: 'user-1',
      name: '散步',
      icon: icon,
      category: category,
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> pump(WidgetTester tester, CheckinPlan value) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: CheckinPlanIcon.forPlan(value))),
      ),
    );
  }

  testWidgets('旧默认图钉 → 换成该分类的默认 emoji', (tester) async {
    await pump(tester, plan(icon: '📌', category: CheckinPlanCategory.exercise));

    expect(find.text('📌'), findsNothing, reason: '图钉不该出现在列表里');
    // 运动分类的第一个内置 emoji 是散步。
    expect(find.text('🚶'), findsOneWidget);
  });

  testWidgets('用户自己挑的 emoji 保留，但只有 14px 上下', (tester) async {
    await pump(tester, plan(icon: '🏃', category: CheckinPlanCategory.exercise));

    final text = tester.widget<Text>(find.text('🏃'));
    expect(text.style?.fontSize, closeTo(26 * 0.55, 0.1));
  });

  testWidgets('分类不同给的默认 emoji 不同', (tester) async {
    await pump(tester, plan(category: CheckinPlanCategory.study));
    expect(find.text('📖'), findsOneWidget);

    await pump(tester, plan(category: CheckinPlanCategory.anniversary));
    expect(find.text('🎂'), findsOneWidget);
  });
}
