import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';
import 'package:miji/features/gtd/domain/plan_color.dart';
import 'package:miji/features/gtd/presentation/plans/plan_style_picker.dart';

/// 选择器的两条行为：点 emoji 会回传、点颜色会回传；「自定义」会展开输入框。
void main() {
  Future<void> pump(
    WidgetTester tester, {
    CheckinPlanCategory category = CheckinPlanCategory.exercise,
    String emoji = '🚶',
    PlanColor? color,
    bool customized = false,
    ValueChanged<String>? onEmoji,
    ValueChanged<PlanColor>? onColor,
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
              color: color ?? PlanColor.rgb(0xEF4444),
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
    PlanColor? picked;
    await pump(tester, onColor: (value) => picked = value);

    // 8 个快捷色都在，另有一枚自定义入口。
    for (final preset in checkinPlanColors) {
      expect(
        find.byKey(ValueKey('plan-color-${preset.hex}')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('plan-color-custom')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan-color-#10B981')));
    await tester.pumpAndSettle();
    expect(picked?.hex, '#10B981');
    expect(tester.takeException(), isNull);
  });

  testWidgets('自定义颜色：三根滑杆可调，点「用这个颜色」回传', (tester) async {
    PlanColor? picked;
    await pump(
      tester,
      color: PlanColor.rgb(0x0EA5E9),
      onColor: (value) => picked = value,
    );

    await tester.tap(find.byKey(const ValueKey('plan-color-custom')));
    await tester.pumpAndSettle();

    // 调色板打开：三根滑杆 + 当前值。
    expect(find.text('自定义颜色'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-color-hue')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-color-saturation')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan-color-value')), findsOneWidget);

    // 拖动色相滑杆，值应该变。
    await tester.drag(
      find.byKey(const ValueKey('plan-color-hue')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('用这个颜色'));
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.hex, startsWith('#'));
    expect(picked!.hex.length, 7);
    // 色相变了，颜色就不该还是原来那个。
    expect(picked, isNot(PlanColor.rgb(0x0EA5E9)));
    expect(tester.takeException(), isNull);
  });
}
