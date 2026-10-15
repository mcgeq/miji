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
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/presentation/gtd_page.dart';
import 'package:miji/features/gtd/presentation/plans/plan_form_page.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 计划的写操作之后，凡是依赖「今日混排」的界面必须立刻看到新数据。
///
/// 回归：新建/编辑计划页保存后只调了 `invalidateCheckinData`，它的覆盖范围只有
/// 打卡自己的 provider。「今日」tab 与首页今日看板的数据源是
/// `todayActionItemsProvider` —— 它自己直接查 repository、不 watch 任何打卡
/// provider，于是写完库 UI 纹丝不动，非得杀掉应用重启才看得到新计划。
void main() {
  testWidgets('新建计划后回到「今日」tab 立即显示该计划', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    _usePhoneSize(tester);

    final router = _buildRouter();

    await tester.pumpWidget(_buildHost(database: database, router: router));
    await tester.pumpAndSettle();

    expect(find.text('今日没有待办事项'), findsOneWidget);

    await tester.tap(find.byTooltip('新建计划'));
    await tester.pumpAndSettle();

    // 表单里第一个输入框就是「计划名称」。
    await tester.enterText(find.byType(TextField).first, '每日阅读');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '创建计划'));
    await tester.pumpAndSettle();

    // pop 回第一页后不应再留在表单上。
    expect(find.widgetWithText(FilledButton, '创建计划'), findsNothing);
    expect(find.text('每日阅读'), findsOneWidget);
  });

  testWidgets('编辑计划改名后「今日」tab 立即跟着改名', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    _usePhoneSize(tester);

    final seed = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      ],
    );
    addTearDown(seed.dispose);
    final created = await seed
        .read(checkinRepositoryProvider)
        .createPlan(_draft('旧名字'), 'user-1');

    final router = _buildRouter();
    await tester.pumpWidget(_buildHost(database: database, router: router));
    await tester.pumpAndSettle();

    expect(find.text('旧名字'), findsOneWidget);

    router.push('/app/gtd/plans/create?edit=${created.id}');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '新名字');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '保存修改'));
    await tester.pumpAndSettle();

    expect(find.text('新名字'), findsOneWidget);
  });

  test('首页今日看板的「计划」格跟着今日混排一起更新', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        authSessionControllerProvider.overrideWith(_UnlockedSession.new),
      ],
    );
    addTearDown(container.dispose);

    String actionValue() => container
        .read(homeTodayBoardProvider)
        .cells
        .firstWhere((cell) => cell.id == HomeBlockId.boardAction)
        .value;

    expect(actionValue(), '—');

    await container
        .read(checkinRepositoryProvider)
        .createPlan(_draft('每日阅读'), 'user-1');
    // 写库本身不该让任何 UI 数据变化。
    expect(actionValue(), '—');

    // 只刷打卡自己的计划列表救不了这条链：
    // `todayActionItemsProvider` 不 watch 它，首页拿到的还是旧快照。
    container.invalidate(activePlansProvider);
    container.invalidate(todayProgressProvider);
    await container.read(todayProgressProvider.future);
    expect(actionValue(), '—');

    // 这正是 `invalidateTodayActionData` 比 `invalidateCheckinData` 多出来的那一步。
    container.invalidate(todayActionItemsProvider);
    await container.read(todayActionItemsProvider.future);
    expect(actionValue(), '0 / 1');
  });
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Widget _buildHost({required AppDatabase database, required GoRouter router}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      authSessionControllerProvider.overrideWith(_UnlockedSession.new),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  );
}

/// 用真 GoRouter 才能覆盖 `context.pop()` 返回到上一层导航的真实路径。
///
/// 路径必须照搬 `AppRoutes`（`/app/gtd/plans/create`）：页面里的 push 写的是
/// 绝对路径，测试路由少了 `/app` 这层的话，点了「新建计划」会静默跳不过去。
GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/app/gtd',
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        routes: [
          GoRoute(
            path: '/app/gtd',
            builder: (_, _) => const Scaffold(body: GtdPage()),
            routes: [
              GoRoute(
                path: 'plans/create',
                builder: (_, state) =>
                    PlanFormPage(editPlanId: state.uri.queryParameters['edit']),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CheckinPlanDraft _draft(String name) => CheckinPlanDraft(
  name: name,
  icon: '📌',
  category: '其他',
  planType: CheckinPlanType.cyclic,
  frequencyType: CheckinFrequencyType.daily,
  targetValue: 1,
  targetUnit: '次',
  triggerMode: CheckinTriggerMode.button,
  recordGranularity: CheckinRecordGranularity.merged,
  reminderEnabled: false,
);

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
