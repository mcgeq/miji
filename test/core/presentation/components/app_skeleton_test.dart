import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/theme/app_theme.dart';

void main() {
  testWidgets('list skeleton renders the requested rows', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSkeletonList(rows: 4)),
      ),
    );
    // 首帧即可见（不需要 settle：脉冲动画是无限重复的）。
    await tester.pump();

    expect(find.byType(AppSkeletonBox), findsWidgets);
    // 4 行 × (图标 + 2 行文字 + 金额) = 16 个占位块。
    expect(find.byType(AppSkeletonBox).evaluate().length, 4 * 4);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel skeleton shows a header plus the requested lines', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSkeletonPanel(lines: 3)),
      ),
    );
    await tester.pump();

    // 标题 + 副标题 + 3 行。
    expect(find.byType(AppSkeletonBox).evaluate().length, 5);
  });

  testWidgets('skeleton pulses without errors and disposes cleanly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: AppSkeletonChart()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);

    // 换掉整棵树，确认动画控制器被正确释放（否则会报 timer/controller 泄漏）。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
