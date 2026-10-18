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
import 'package:miji/features/health/presentation/health_page.dart';
import 'package:miji/features/health/presentation/health_today_tab.dart';
import 'package:miji/features/health/presentation/health_trends_tab.dart';

/// 健康页的面板以前只活在 State 里（地址永远是 `/app/health`）：首页的预测卡
/// 只能落到「今日」，底栏切走再切回也回不到趋势页。这里钉住 `?section=`。
///
/// 只走「今日 ↔ 趋势」：日历面板会开一批长生命周期的 drift 流，测试结束时
/// `database.close()` 等它们取消会一直不返回（与本次改动无关的既有现象）。
void main() {
  testWidgets('页内没有面板切换控件：tab 栏和面板 chip 都不该回来', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    // 回归：这里曾是一枚 4 段分段控件，后来换成工具行左端的 chip，两者都已移除。
    expect(find.byType(AppSlidingSegmentedControl), findsNothing);
    expect(
      find.byKey(const ValueKey('module-section-chip-health')),
      findsNothing,
    );
  });

  testWidgets('深链直接落到指定面板', (tester) async {
    final router = _router(initialLocation: '/app/health?section=trends');
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(find.byType(HealthTrendsTab), findsOneWidget);
    expect(find.byType(HealthTodayTab), findsNothing);
  });

  testWidgets('换面板写回 ?section=', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(find.byType(HealthTodayTab), findsOneWidget);
    expect(router.state.uri.queryParameters['section'], isNull);

    await _switchPanel(tester, 'trends', router);

    expect(router.state.uri.queryParameters['section'], 'trends');
    expect(find.byType(HealthTrendsTab), findsOneWidget);

    await _switchPanel(tester, 'today', router);

    expect(router.state.uri.queryParameters['section'], 'today');
    expect(find.byType(HealthTodayTab), findsOneWidget);
  });

  testWidgets('非法的 section 退到「今日」，不白屏', (tester) async {
    final router = _router(initialLocation: '/app/health?section=nope');
    addTearDown(router.dispose);
    await _pump(tester, router);

    expect(find.byType(HealthTodayTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// 换面板：直接改地址（页内已没有切换控件）。
///
/// 真实用户路径是底栏 / 侧栏点当前模块再点一次，那条由
/// `test/features/shell/app_shell_navigation_test.dart` 覆盖。
Future<void> _switchPanel(
  WidgetTester tester,
  String sectionId,
  GoRouter router,
) async {
  router.go('/app/health?section=$sectionId');
  await tester.pumpAndSettle();
}

GoRouter _router({String initialLocation = '/app/health'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/app/health',
        builder: (context, state) => Scaffold(
          body: HealthPage(
            initialSection: state.uri.queryParameters['section'],
          ),
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
