import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/shell/presentation/app_shell_page.dart';

/// 二级路由的入口有两态，规则在 `AppShellPage._openModule`：
///
/// - **不在模块里** → 直接进，并回到上次停留的面板（1 拍）；
/// - **已经在该模块根上** → 弹出面板选择器（iOS「点当前 tab」的惯例）。
///
/// 这两态一旦退化成「每次都弹层」，从首页 / 打卡切回记账就从 1 拍变成
/// 「1 拍 + 一次打断 + 1 拍」——本文件就是钉住它。
void main() {
  testWidgets('不在模块里点底栏「记账」：直接进，落到默认面板', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    await tester.tap(_bottomNav('记账'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/app/bookkeeping');
    expect(router.state.uri.queryParameters['section'], 'transactions');
    expect(find.byKey(const ValueKey('module-section-picker')), findsNothing);
  });

  testWidgets('已经在该模块根上再点它：弹出面板选择器，地址不动', (tester) async {
    final router = _router(
      initialLocation: '/app/bookkeeping?section=accounts',
    );
    addTearDown(router.dispose);
    await _pump(tester, router);

    await tester.tap(_bottomNav('记账'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('module-section-picker')), findsOneWidget);
    // 弹层不是跳转：原地不动，取消掉什么都不会变。
    expect(router.state.uri.queryParameters['section'], 'accounts');

    await tester.tap(find.byKey(const ValueKey('module-section-item-budgets')));
    await tester.pumpAndSettle();

    expect(router.state.uri.queryParameters['section'], 'budgets');
    expect(find.byKey(const ValueKey('module-section-picker')), findsNothing);
  });

  testWidgets('切走再切回来：回到上次停留的面板', (tester) async {
    final router = _router(
      initialLocation: '/app/bookkeeping?section=accounts',
    );
    addTearDown(router.dispose);
    await _pump(tester, router);

    await tester.tap(_bottomNav('打卡'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/app/gtd');
    expect(router.state.uri.queryParameters['section'], 'today');

    await tester.tap(_bottomNav('记账'));
    await tester.pumpAndSettle();

    // 没有这层记忆，底栏只能给模块根地址，面板会被重置回流水。
    expect(router.state.uri.queryParameters['section'], 'accounts');
  });

  testWidgets('宽屏没有底栏，由侧栏承担同一套两态', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router, width: 1280);

    expect(find.byType(BottomAppBar), findsNothing);

    await tester.tap(find.byIcon(Icons.payments_outlined));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/app/bookkeeping');

    // 选中后图标换成实心版；再点一次就是「换面板」。
    await tester.tap(find.byIcon(Icons.payments_rounded));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('module-section-picker')), findsOneWidget);
  });

  testWidgets('打卡面板也走同一套入口与记忆', (tester) async {
    final router = _router(initialLocation: '/app/gtd?section=habits');
    addTearDown(router.dispose);
    await _pump(tester, router);

    await tester.tap(_bottomNav('健康'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/app/health');
    expect(router.state.uri.queryParameters['section'], 'today');

    await tester.tap(_bottomNav('打卡'));
    await tester.pumpAndSettle();
    expect(router.state.uri.queryParameters['section'], 'habits');
  });
}

/// 底栏里的某个一级模块按钮。
///
/// 限定在 `BottomAppBar` 里找：全局 FAB 上也有 Tooltip，直接按 tooltip 找会撞。
Finder _bottomNav(String label) => find.descendant(
  of: find.byType(BottomAppBar),
  matching: find.byTooltip(label),
);

GoRouter _router({String initialLocation = '/app/home'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShellPage(child: child),
        routes: [
          GoRoute(
            path: '/app/home',
            builder: (_, _) => const _StubPage('首页占位'),
          ),
          GoRoute(path: '/app/gtd', builder: (_, _) => const _StubPage('打卡占位')),
          GoRoute(
            path: '/app/bookkeeping',
            builder: (_, _) => const _StubPage('记账占位'),
          ),
          GoRoute(
            path: '/app/health',
            builder: (_, _) => const _StubPage('健康占位'),
          ),
        ],
      ),
    ],
  );
}

class _StubPage extends StatelessWidget {
  const _StubPage(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

final _ledger = MoneyLedgerEntity(
  id: 'ledger-1',
  userId: 'user-1',
  name: '日常',
  ledgerType: 'personal',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}

Future<void> _pump(
  WidgetTester tester,
  GoRouter router, {
  double width = 390,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);

  tester.view.physicalSize = Size(width * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authSessionControllerProvider.overrideWith(_UnlockedSession.new),
        // 顶栏 / 工具行上的账本选择器在加载中会画不确定进度条，永远动 =>
        // `pumpAndSettle` 等不到静止。给一个假账本让它落到静态形态。
        currentUserMoneyLedgersProvider.overrideWith(
          (ref) => Stream.value([_ledger]),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
