import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';
import 'package:miji/features/gtd/presentation/plans/plan_style_picker.dart';

/// 选择器的两条行为：点 emoji 会回传、点颜色会回传；「自定义」会展开输入框。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    CheckinPlanCategory category = CheckinPlanCategory.exercise,
    String emoji = '🚶',
    String colorHex = '#EF4444',
    bool customized = false,
    ValueChanged<String>? onEmoji,
    ValueChanged<String>? onColor,
    VoidCallback? onCustom,
  }) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanStylePicker(
              category: category,
              emoji: emoji,
              colorHex: colorHex,
              customized: customized,
              customController: TextEditingController(),
              onEmojiChanged: onEmoji ?? (_) {},
              onColorChanged: onColor ?? (_) {},
              onCustomToggled: onCustom ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('内置 emoji 都在：点一个就回传它', (tester) async {
    String? picked;
    await pump(tester, onEmoji: (value) => picked = value);

    for (final emoji in checkinPlanEmojis[CheckinPlanCategory.exercise]!) {
      expect(find.text(emoji), findsWidgets, reason: emoji);
    }

    await tester.tap(find.text('🚴'));
    await tester.pumpAndSettle();
    expect(picked, '🚴');
  });

  testWidgets('没选过时显示分类默认；选过显示「自定义」并可展开输入框', (tester) async {
    await pump(tester, customized: false);
    expect(find.text('运动 默认'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await pump(tester, customized: true, emoji: '🐳');
    expect(find.textContaining('自定义'), findsWidgets);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('🐳'), findsWidgets);
  });

  testWidgets('颜色可点：回传对应色值', (tester) async {
    String? picked;
    await pump(tester, onColor: (value) => picked = value);

    // 8 个预设色都在。
    for (final hex in checkinPlanColors) {
      expect(find.byKey(ValueKey('plan-color-$hex')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('plan-color-#10B981')));
    await tester.pumpAndSettle();
    expect(picked, '#10B981');
    expect(tester.takeException(), isNull);
  });
}
