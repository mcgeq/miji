import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/home/presentation/home_page.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:miji/features/home/presentation/home_overview_card.dart';

/// 首页在没有登录会话 / 没有任何数据时也必须能渲染，
/// 并且走「首次使用」引导而不是一屏 0。
void main() {
  testWidgets('renders the onboarding view when there is no data', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );

    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('欢迎使用米记 👋'), findsOneWidget);
    expect(find.text('创建第一个账户'), findsOneWidget);
    expect(find.text('设置本月预算'), findsOneWidget);
    expect(find.text('记下第一笔支出'), findsOneWidget);
  });

  testWidgets('compact dashboard does not overflow on a phone-sized surface', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.utc(2026, 7, 18, 8);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        currentUserVisibleAccountsProvider.overrideWith(
          (ref) => Stream.value([_cashAccount(now)]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );

    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(tester.takeException(), isNull);
    // 单列布局下两个 bento 磁贴并排。
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('今日行动'), findsOneWidget);
  });

  testWidgets('renders the dashboard branch once an account exists', (
    tester,
  ) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final now = DateTime.utc(2026, 7, 18, 8);
    await database
        .into(database.users)
        .insert(
          UsersCompanion.insert(
            id: 'user_1',
            username: 'user_1',
            email: 'user_1@example.com',
            displayName: '小明',
            createdAt: now,
            updatedAt: now,
          ),
        );

    // 桌面宽度：走 8/4 双栏分支。
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        // 有一个账户即代表「不是首次使用」，从而进入 dashboard 分支；
        // 其余数据保持为空，顺带覆盖各区块的空状态。
        currentUserVisibleAccountsProvider.overrideWith(
          (ref) => Stream.value([_cashAccount(now)]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(authSessionControllerProvider.notifier).unlock('user_1');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );

    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 150));
    }

    expect(tester.takeException(), isNull);
    // 无预算 -> Hero 退化为「本月结余」。
    expect(find.text('本月结余'), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget);
    expect(find.text('最近账单'), findsOneWidget);
    expect(find.text('本月分类'), findsOneWidget);
    // 双栏右侧栏。
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('今日行动'), findsOneWidget);
    // 空数据提示。
    expect(find.text('这个月还没有账单'), findsOneWidget);
  });
  testWidgets('手机端把预算/趋势/日历合成一张卡，并且趋势不用滚动就能看到', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.utc(2026, 7, 18, 8);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        currentUserVisibleAccountsProvider.overrideWith(
          (ref) => Stream.value([_cashAccount(now)]),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomePage()),
        ),
      ),
    );
    for (var index = 0; index < 12; index++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);

    // 三个视图共享一张卡：卡内只出现一次 tab 条。
    expect(find.text('本月预算'), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);

    // 合并后整卡高度（含 tab 条）应当只占一屏的三分之一左右，
    // 而不是原来 Hero + 趋势卡两张算起来 ≈580dp。
    final cardRect = tester.getRect(find.byType(HomeOverviewCard));
    expect(cardRect.height, lessThan(400), reason: '实际 ${cardRect.height}');

    // 合并的收益：切到趋势后，图表仍在首屏（844 高的手机屏）之内。
    await tester.tap(find.text('支出趋势'));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    final chartRect = tester.getRect(find.byType(BarChart));
    expect(chartRect.bottom, lessThan(844), reason: '趋势图应该在首屏内，不需要滚动');
  });
}

MoneyAccountEntity _cashAccount(DateTime now) {
  return MoneyAccountEntity(
    id: 'account_1',
    userId: 'user_1',
    name: '现金',
    type: MoneyAccountType.cash,
    balanceMinor: 100000,
    initialBalanceMinor: 100000,
    creditLimitMinor: null,
    postedDebtMinor: null,
    frozenCreditMinor: null,
    statementDay: null,
    budgetCycleStartDay: null,
    repaymentDay: null,
    autoRepaymentReminderEnabled: false,
    currencyCode: 'CNY',
    isShared: false,
    isVirtual: false,
    isActive: true,
    isDeleted: false,
    createdAt: now,
    updatedAt: now,
  );
}
