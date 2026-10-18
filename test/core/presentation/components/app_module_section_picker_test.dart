import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/presentation/components/app_module_section_picker.dart';
import 'package:miji/core/router/app_module_nav.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 面板选择器是三个模块共用的二级路由入口：窄屏底部升出、宽屏居中弹窗，
/// 内容与选中态是同一套。
void main() {
  testWidgets('窄屏从底部升出，一次给出全部面板且当前项高亮', (tester) async {
    await _pumpHost(
      tester,
      width: 390,
      spec: bookkeepingModuleNav,
      currentSectionId: 'budgets',
      onResult: (_) {},
    );

    // 窄屏不是 Dialog，而是底部面板。
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const ValueKey('module-section-picker')), findsOneWidget);

    for (final label in ['流水', '账户', '预算', '统计', '分类', '分期', '自动记账', '提醒']) {
      expect(_itemText(label), findsOneWidget, reason: '选择器里缺少 $label');
    }

    // 当前面板加重字重，其余不加——「我在哪」必须一眼看出来。
    expect(_labelWeightOf(tester, 'budgets'), FontWeight.w800);
    expect(_labelWeightOf(tester, 'accounts'), FontWeight.w600);
  });

  testWidgets('宽屏换成居中弹窗，选中项原样返回', (tester) async {
    String? picked;
    await _pumpHost(
      tester,
      width: 1280,
      spec: bookkeepingModuleNav,
      currentSectionId: 'transactions',
      onResult: (value) => picked = value,
    );

    expect(find.byType(Dialog), findsOneWidget);
    expect(_labelWeightOf(tester, 'transactions'), FontWeight.w800);

    await tester.tap(
      find.byKey(const ValueKey('module-section-item-accounts')),
    );
    await tester.pumpAndSettle();

    expect(picked, 'accounts');
    expect(find.byKey(const ValueKey('module-section-picker')), findsNothing);
  });

  testWidgets('关掉选择器不改变面板', (tester) async {
    var closed = false;
    String? picked;
    await _pumpHost(
      tester,
      width: 390,
      spec: healthModuleNav,
      currentSectionId: 'trends',
      onResult: (value) {
        closed = true;
        picked = value;
      },
    );

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(picked, isNull);
  });

  testWidgets('提醒的待处理数挂在图标上，不动面板名', (tester) async {
    await _pumpHost(
      tester,
      width: 390,
      spec: bookkeepingModuleNav,
      currentSectionId: 'transactions',
      badges: const {'reminders': '3'},
      onResult: (_) {},
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('module-section-item-reminders')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    // 角标挂在图标上而不是文字上：面板名不能被挤成省略号。
    expect(_itemText('提醒'), findsOneWidget);
  });

  testWidgets('打卡与健康的面板也走同一套选择器', (tester) async {
    await _pumpHost(
      tester,
      width: 390,
      spec: gtdModuleNav,
      currentSectionId: 'habits',
      onResult: (_) {},
    );
    expect(find.text('打卡'), findsOneWidget);
    for (final label in ['今日', '任务', '习惯', '日历', '统计']) {
      expect(_itemText(label), findsOneWidget, reason: '打卡缺少 $label');
    }

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await _pumpHost(
      tester,
      width: 1280,
      spec: healthModuleNav,
      currentSectionId: 'calendar',
      onResult: (_) {},
    );
    expect(find.text('健康'), findsOneWidget);
    for (final label in ['今日', '日历', '趋势', '设置']) {
      expect(_itemText(label), findsOneWidget, reason: '健康缺少 $label');
    }
  });
}

/// 面板名文本（限定在选择器里找，避免撞上页面里的同名文本）。
Finder _itemText(String label) => find.descendant(
  of: find.byKey(const ValueKey('module-section-picker')),
  matching: find.text(label),
);

FontWeight? _labelWeightOf(WidgetTester tester, String sectionId) {
  return tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(ValueKey('module-section-item-$sectionId')),
          matching: find.byType(Text),
        ),
      )
      .style
      ?.fontWeight;
}

Future<void> _pumpHost(
  WidgetTester tester, {
  required double width,
  required AppModuleNavSpec spec,
  required String currentSectionId,
  required ValueChanged<String?> onResult,
  Map<String, String> badges = const <String, String>{},
}) async {
  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                onResult(
                  await showAppModuleSectionPicker(
                    context,
                    spec: spec,
                    currentSectionId: currentSectionId,
                    badges: badges,
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
