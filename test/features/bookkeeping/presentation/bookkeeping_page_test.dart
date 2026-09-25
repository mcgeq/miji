import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/presentation/bookkeeping_page.dart';

/// 一级导航：原来是 8 个只有图标的横条（360dp 手机上放不下、没有文字），
/// 现在收敛成「流水 / 账户 / 预算 / 统计 + 更多」。
void main() {
  testWidgets('shows four primary tabs plus more, defaulting to accounts', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    for (final label in ['流水', '账户', '预算', '统计', '更多']) {
      expect(find.text(label), findsWidgets, reason: '缺少 $label 标签');
    }
    // Q2 的决定：默认落在账户面板。
    expect(find.text('还没有账户'), findsOneWidget);
  });

  testWidgets('switching a tab writes the section back to the URL', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    await tester.tap(find.text('预算'));
    await tester.pumpAndSettle();

    expect(find.text('还没有预算'), findsOneWidget);
    // 面板状态进 URL：系统返回键 / 深链才能正确工作。
    expect(router.state.uri.queryParameters['section'], 'budgets');

    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'transactions');
  });

  testWidgets('more tab opens the secondary grid and remembers the panel', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();

    // 四个二级面板都在「更多」里。
    expect(find.text('分类'), findsWidgets);
    expect(find.text('分期'), findsWidgets);
    expect(find.text('自动记账'), findsWidgets);
    expect(find.text('提醒'), findsWidgets);

    await tester.tap(find.text('分类').first);
    await tester.pumpAndSettle();

    expect(find.text('暂无分类'), findsOneWidget);
    expect(router.state.uri.queryParameters['section'], 'categories');
    // 二级面板激活时，「更多」标签显示当前面板名。
    expect(find.text('分类'), findsWidgets);
  });

  testWidgets('deep link opens the section from the query parameter', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router(initialLocation: '/app/bookkeeping?section=budgets');
    addTearDown(router.dispose);

    await _pump(tester, database, router);

    expect(find.text('还没有预算'), findsOneWidget);
  });

  testWidgets('type tabs are not covered by the share button on narrow phones', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    // 360dp 是主流窄屏宽度：56dp 最小段宽 * 4 = 224dp > 可用宽度，
    // 曾经溢出到分享按钮下面（既被遮住又点不到）。
    await _pump(tester, database, router, width: 360);
    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();

    final transfer = tester.getRect(find.text('转账'));
    final share = tester.getRect(find.byTooltip('导出流水'));
    expect(
      transfer.right,
      lessThanOrEqualTo(share.left),
      reason: '「转账」标签被分享按钮遮住',
    );

    final control = tester.getRect(
      find.byWidgetPredicate((widget) => widget is AppSlidingSegmentedControl),
    );
    expect(
      transfer.right,
      lessThanOrEqualTo(control.right),
      reason: '「转账」标签超出了分段控件的可视区',
    );
  });

  testWidgets('summary bar shows only amounts, labels live in semantics', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final router = _router();
    addTearDown(router.dispose);

    await _pump(tester, database, router);
    await tester.tap(find.text('流水'));
    await tester.pumpAndSettle();

    expect(find.text('共 0 笔'), findsOneWidget);

    // 三格金额只靠颜色区分方向，所以「支出 / 收入 / 净」必须留在语义标签与
    // 长按提示里，否则读屏用户与色觉缺陷用户拿不到方向信息。
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('支出 ¥0.00'), findsOneWidget);
    expect(find.bySemanticsLabel('收入 ¥0.00'), findsOneWidget);
    expect(find.bySemanticsLabel('净 +¥0.00'), findsOneWidget);
    semantics.dispose();

    expect(find.byTooltip('支出'), findsOneWidget);
    expect(find.byTooltip('收入'), findsOneWidget);
    expect(find.byTooltip('净'), findsOneWidget);

    // 汇总条本身上不再有「支出 / 收入 / 净」文案（筛选条里的类型标签不算）。
    // .first 取距「共 N 笔」最近的 Column，即汇总条自己的 Column；用搜索框
    // 反证它不是更外层的页面 Column，否则这个断言会变成假阳性。
    final bar = find
        .ancestor(of: find.text('共 0 笔'), matching: find.byType(Column))
        .first;
    expect(
      find.descendant(of: bar, matching: find.byType(TextField)),
      findsNothing,
    );
    expect(
      find.descendant(of: bar, matching: find.byTooltip('支出')),
      findsOneWidget,
    );
    for (final label in ['支出', '收入', '净']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsNothing,
        reason: '汇总条里不应再有「$label」文案',
      );
    }
  });
}

GoRouter _router({String initialLocation = '/app/bookkeeping'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/bookkeeping',
        // 真实外壳（AppShellPage）也把页面包在 Scaffold 里；测试必须提供
        // Material / Scaffold 祖先，否则 InkWell / TextField 会直接断言失败。
        builder: (context, state) => Scaffold(
          body: BookkeepingPage(
            initialSection: state.uri.queryParameters['section'],
            initialAccountId: state.uri.queryParameters['accountId'],
          ),
        ),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  AppDatabase database,
  GoRouter router, {
  double width = 390,
}) async {
  tester.view.physicalSize = Size(width * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );

  // 页面里有一个分三批 Future.delayed 的预取器（120/80/80ms），
  // 必须把时钟推过这些定时器，否则测试结束时会报「Timer is still pending」。
  for (var index = 0; index < 10; index++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
