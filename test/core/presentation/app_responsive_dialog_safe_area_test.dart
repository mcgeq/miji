import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 「记录加班 / 记一件想买的东西」这类整屏弹层曾按
/// `View.physicalSize − MediaQuery.padding` 自己算高度，只要有一处把 padding
/// 吃掉，面板就顶进状态栏，标题被挖孔摄像头盖住。现在高度交给 SafeArea。
///
/// 这里把状态栏设成 44、手势条设成 34，然后量面板标题和操作按钮的位置。
Future<void> _pumpHarness(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showAppResponsiveDialog<void>(
                context: context,
                expandCompactSheet: true,
                builder: (context) => AppDialogScaffold(
                  title: '记录加班',
                  body: const SizedBox(height: 400, child: Text('body')),
                  actions: appDialogIconActions(
                    onCancel: () => Navigator.of(context).pop(),
                    onConfirm: () {},
                    confirmTooltip: '记录',
                  ),
                ),
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('整屏弹层整体落在安全区内：顶部不压状态栏、底部不压手势条', (tester) async {
    await _pumpHarness(tester);

    final titleTop = tester.getTopLeft(find.text('记录加班')).dy;
    expect(titleTop, greaterThanOrEqualTo(44), reason: '标题必须落在状态栏（44）之下');

    // 操作行在底部，底部安全区 34 —— 图标按钮的下沿不能压进手势条。
    final confirm = find.byTooltip('记录');
    expect(confirm, findsOneWidget);
    final confirmBottom = tester.getRect(confirm).bottom;
    expect(confirmBottom, lessThanOrEqualTo(844 - 34), reason: '保存按钮要给手势条让位');

    expect(tester.takeException(), isNull);
  });

  testWidgets('取消与确认都是图标按钮，不是文字按钮', (tester) async {
    await _pumpHarness(tester);

    expect(find.text('取消'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
