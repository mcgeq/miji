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
/// 1. 顶部**不再有 tab 栏**：原先那枚 5 段的分段控件换成了工具行左端的 chip
///    （形态与记账页一致），底栏「打卡」两态唤出的也是同一张选择器；
/// 2. 页级动作（新建任务 / 新建计划 / 管理计划）必须真的能用；
/// 3. 面板要进地址（`?section=`）——以前只活在 State 里，深链、底栏切回、
///    系统返回键全都拿不到「我在哪个面板」。
void main() {
  testWidgets('顶部不再有 tab 栏，改成工具行 chip（选择器一次列全 5 个面板）', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    // 回归：这里曾是一枚横跨整行的 5 段分段控件（今日 / 任务 / 习惯 / 日历 / 统计）。
    expect(find.byType(AppSlidingSegmentedControl), findsNothing);

    final chip = find.byKey(const ValueKey('module-section-chip-gtd'));
    expect(chip, findsOneWidget);
    expect(
      find.descendant(of: chip, matching: find.text('今日')),
      findsOneWidget,
      reason: 'chip 上要常驻当前面板名，否则用户不知道自己在哪',
    );

    await tester.tap(chip);
    await tester.pumpAndSettle();

    // 面板之间没有横向通路（只有底栏 / chip 两个入口），选择器必须一次列全，
    // 否则删掉 tab 行会留下死胡同。
    final picker = find.byKey(const ValueKey('module-section-picker'));
    expect(picker, findsOneWidget);
    for (final label in ['今日', '任务', '习惯', '日历', '统计']) {
      expect(
        find.descendant(of: picker, matching: find.text(label)),
        findsOneWidget,
        reason: '选择器里缺少 $label',
      );
    }

    // 选完必须收起：它取代 tab 栏，绝不能又变成压在内容上的浮层。
    await tester.tap(find.byKey(const ValueKey('module-section-item-tasks')));
    await tester.pumpAndSettle();
    expect(picker, findsNothing);
    expect(
      find.descendant(of: chip, matching: find.text('任务')),
      findsOneWidget,
    );
    expect(router.state.uri.queryParameters['section'], 'tasks');
  });

  testWidgets('「新建任务」打开快速创建任务面板', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await _pump(tester, router);

    await _switchPanel(tester, 'tasks');

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
      await _switchPanel(tester, section);
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

    await _switchPanel(tester, 'habits');

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

    await _switchPanel(tester, 'statistics');

    expect(router.state.uri.queryParameters['section'], 'statistics');
  });
}

/// 换面板：点工具行 chip 唤起选择器，再点目标面板。
///
/// 顶部 tab 栏删掉之后，这是页内唯一的换面板通路，测试也照真实路径走——
/// 直接 tap 分段图标的日子过去了（想走底栏那条，见
/// `test/features/shell/app_shell_navigation_test.dart`）。
Future<void> _switchPanel(WidgetTester tester, String sectionId) async {
  await tester.tap(find.byKey(const ValueKey('module-section-chip-gtd')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('module-section-item-$sectionId')));
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
