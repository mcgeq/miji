import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
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
  GoRouter router,
) async {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
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
