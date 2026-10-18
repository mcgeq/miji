import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/presentation/gtd_page.dart';

/// 打卡页的三件事：
///
/// 1. 页内**没有任何面板切换控件**（既没有 tab 栏，也没有面板 chip）：换面板
///    只走底栏 / 侧栏「点当前模块再点一次」那条路；
/// 2. 页级动作（新建任务 / 新建计划 / 管理计划）必须真的能用；
/// 3. 面板要进地址（`?section=`）——以前只活在 State 里，深链、底栏切回、
///    系统返回键全都拿不到「我在哪个面板」。
void main() {
  testWidgets('页内没有面板切换控件：tab 栏和面板 chip 都不该回来', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    // 回归：这里曾是一枚横跨整行的 5 段分段控件，后来又换成工具行左端的 chip。
    // 两者都已按要求移除，换面板只走底栏 / 侧栏的两态唤出。
    expect(find.byType(AppSlidingSegmentedControl), findsNothing);
    expect(
      find.byKey(const ValueKey('module-section-chip-gtd')),
      findsNothing,
    );

    // 面板仍然要能切：地址是唯一入口。
    router.go('/app/gtd?section=tasks');
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'tasks');
  });

  testWidgets('「新建任务」打开快速创建任务面板', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    await _switchPanel(tester, 'tasks', router);

    await tester.tap(find.byTooltip('新建任务'));
    await tester.pumpAndSettle();

    expect(find.text('输入任务标题'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建任务'), findsOneWidget);
  });

  testWidgets('每个面板的页级动作在手机宽度下都能渲染且不溢出', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    for (final section in ['tasks', 'habits', 'calendar', 'statistics']) {
      await _switchPanel(tester, section, router);
      expect(tester.takeException(), isNull, reason: '切到 $section 时抛异常');
      // 「习惯」有两个动作，最宽；至少保证有动作入口渲染出来。
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    }
  });

  testWidgets('深链选面板，换面板写回 ?section=', (tester) async {
    final router = _router(initialLocation: '/app/gtd?section=tasks');
    addTearDown(router.dispose);
    await _pump(tester, router);

    // 落在「任务」：页级动作跟着面板走，这是最省事的「我在哪」判据。
    expect(find.byTooltip('新建任务'), findsOneWidget);
    expect(find.byTooltip('管理计划'), findsNothing);

    await _switchPanel(tester, 'habits', router);

    expect(router.state.uri.queryParameters['section'], 'habits');
    expect(find.byTooltip('管理计划'), findsOneWidget);
    expect(find.byTooltip('新建任务'), findsNothing);
  });

  testWidgets('非法的 section 退到「今日」，不白屏', (tester) async {
    final router = _router(initialLocation: '/app/gtd?section=nope');
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(find.byTooltip('新建计划'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('切面板会写回地址', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(router.state.uri.queryParameters['section'], isNull);

    await _switchPanel(tester, 'statistics', router);

    expect(router.state.uri.queryParameters['section'], 'statistics');
  });
}

/// 换面板：直接改地址（页内已经没有切换控件）。
///
/// 真正的用户路径是底栏 / 侧栏点当前模块再点一次，那条路径由
/// `test/features/shell/app_shell_navigation_test.dart` 覆盖；这里只关心
/// 「面板按 section 渲染」，所以走最短的等价路径。
Future<void> _switchPanel(
  WidgetTester tester,
  String sectionId,
  GoRouter router,
) async {
  router.go('/app/gtd?section=$sectionId');
  await tester.pumpAndSettle();
}

GoRouter _router({String initialLocation = '/app/gtd'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/gtd',
        builder: (context, state) => Scaffold(
          body: GtdPage(initialSection: state.uri.queryParameters['section']),
        ),
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester, GoRouter router) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
