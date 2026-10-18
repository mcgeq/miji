import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
// Drift 生成的表模型与领域模型同名，这里只用领域那一份。
import 'package:miji/core/database/app_database.dart'
    hide CheckinPlan, CheckinRecord;
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/presentation/gtd_page.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 「今日」里的习惯行必须能当场打卡。
///
/// 回归：这一行以前整块只接了「进详情页」，没有完成按钮 —— 想在今日打卡得先
/// 切到「习惯」tab 或者回首页。完成之后也没有任何视觉（只把一条 4px 的进度
/// 条藏起来），于是「做了」和「没做」在界面上几乎一样。
void main() {
  late AppDatabase database;
  late GoRouter router;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    router.dispose();
  });

  Future<CheckinPlan> createPlan({
    String name = '喝水',
    double targetValue = 8,
    String targetUnit = '杯',
    CheckinTriggerMode triggerMode = CheckinTriggerMode.button,
  }) async {
    final container = _container(database);
    addTearDown(container.dispose);
    return container
        .read(checkinRepositoryProvider)
        .createPlan(
          CheckinPlanDraft(
            name: name,
            icon: '💧',
            category: CheckinPlanCategory.healthHabit,
            targetValue: targetValue,
            targetUnit: targetUnit,
            triggerMode: triggerMode,
            recordGranularity: CheckinRecordGranularity.merged,
          ),
          'user-1',
        );
  }

  Future<void> pumpToday(WidgetTester tester) async {
    _usePhoneSize(tester);
    router = _router();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authSessionControllerProvider.overrideWith(_UnlockedSession.new),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 直接读库，确认界面上那一下真的写进去了，而不只是变了颜色。
  Future<List<CheckinRecord>> todayRecords(WidgetTester tester, String planId) {
    final container = ProviderScope.containerOf(
      tester.element(find.byType(GtdPage)),
    );
    return container
        .read(checkinRepositoryProvider)
        .getRecordsByPlanAndDate(planId, DateTime.now());
  }

  group('进度环', () {
    testWidgets('点一下就算一次打卡，数字当场变', (tester) async {
      final plan = await createPlan();
      await pumpToday(tester);

      final ring = find.byKey(ValueKey('habit-ring-${plan.id}'));
      expect(ring, findsOneWidget);
      expect(find.text('0'), findsOneWidget, reason: '今天还没喝，环里是 0');

      await tester.tap(ring);
      await tester.pumpAndSettle();

      final records = await todayRecords(tester, plan.id);
      expect(records.single.numericValue, 1);
      expect(records.single.count, 1);
      expect(find.text('1'), findsOneWidget, reason: '环里当场变成 1');
    });

    testWidgets('目标达成后画勾并进入已完成区，再点先问是否撤销', (tester) async {
      final plan = await createPlan(
        name: '吃药',
        targetValue: 1,
        targetUnit: '次',
      );
      await pumpToday(tester);

      final ring = find.byKey(ValueKey('habit-ring-${plan.id}'));
      // 目标为 1 的计划环里不写数字，达标直接画勾。
      expect(find.text('0'), findsNothing);

      await tester.tap(ring);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('今天已完成'), findsOneWidget);

      // 完成之后再点不会默默把数字加到 2：先确认要不要撤销。
      await tester.tap(find.byKey(ValueKey('habit-ring-${plan.id}')));
      await tester.pumpAndSettle();
      expect(find.text('撤销今天的打卡？'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('habit-undo-confirm')));
      await tester.pumpAndSettle();

      expect(await todayRecords(tester, plan.id), isEmpty);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('长按菜单', () {
    testWidgets('可以一次做满，也能撤销一步', (tester) async {
      final plan = await createPlan();
      await pumpToday(tester);

      await tester.longPress(find.text('喝水'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('今天全部完成'));
      await tester.pumpAndSettle();

      var records = await todayRecords(tester, plan.id);
      expect(records.single.numericValue, 8, reason: '一次补满到目标');

      await tester.longPress(find.text('喝水'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('撤销一次打卡'));
      await tester.pumpAndSettle();

      records = await todayRecords(tester, plan.id);
      expect(records.single.numericValue, 7, reason: '回退一个步长');
    });
  });

  group('触发方式', () {
    testWidgets('计时型：「开始」→ 计时中 → 暂停', (tester) async {
      final plan = await createPlan(
        name: '健身',
        targetValue: 30,
        targetUnit: '分钟',
        triggerMode: CheckinTriggerMode.timer,
      );
      await pumpToday(tester);

      expect(find.byKey(ValueKey('habit-ring-${plan.id}')), findsNothing);
      expect(find.text('开始'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('habit-timer-${plan.id}')));
      await tester.pumpAndSettle();
      expect(find.text('计时中 00:00'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('habit-timer-${plan.id}')));
      await tester.pumpAndSettle();
      expect(find.text('继续'), findsOneWidget);
    });

    testWidgets('拍照型：右侧是拍照入口', (tester) async {
      final plan = await createPlan(
        name: '每日一拍',
        targetValue: 1,
        targetUnit: '张',
        triggerMode: CheckinTriggerMode.photo,
      );
      await pumpToday(tester);

      expect(find.byKey(ValueKey('habit-photo-${plan.id}')), findsOneWidget);
      expect(find.byKey(ValueKey('habit-ring-${plan.id}')), findsNothing);
    });
  });
}

ProviderContainer _container(AppDatabase database) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      authSessionControllerProvider.overrideWith(_UnlockedSession.new),
    ],
  );
}

void _usePhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

GoRouter _router() {
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
                path: 'plans/:id',
                builder: (_, state) =>
                    Scaffold(body: Text('计划详情 ${state.pathParameters['id']}')),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
