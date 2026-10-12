import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_health_hint_providers.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/presentation/home_status_chips.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

void main() {
  // Riverpod 3 的 flutter 层没有导出 `Override` 类型名，这里用局部 final
  // 让推断接管，避免把内部类型写进测试签名。
  final streakStub = homeStreakProvider.overrideWith(
    (ref) async =>
        const HomeStreak(days: 7, hasRecordedToday: true, cappedAt: 120),
  );
  final streakNotLoggedStub = homeStreakProvider.overrideWith(
    (ref) async =>
        const HomeStreak(days: 7, hasRecordedToday: false, cappedAt: 120),
  );
  final streakEmptyStub = homeStreakProvider.overrideWith(
    (ref) async => const HomeStreak.empty(),
  );
  final healthStub = homeHealthHintProvider.overrideWith(
    (ref) async => const HomeHealthHint(
      kind: HomeHealthHintKind.period,
      title: '经期第 3 天',
      detail: '今天已记录',
      digest: (value: '第 3 天', label: '经期', note: '今天已记录'),
    ),
  );
  final healthLongStub = homeHealthHintProvider.overrideWith(
    (ref) async => const HomeHealthHint(
      kind: HomeHealthHintKind.period,
      title: '距下次经期还有 16 天',
      detail: '今天还没记录',
      digest: (value: '16 天', label: '距下次经期', note: '今天还没记录'),
    ),
  );
  final healthNullStub = homeHealthHintProvider.overrideWith(
    (ref) async => null,
  );
  final actionStub = todayActionItemsProvider.overrideWith(
    (ref) async =>
        const TodayActionView(items: [], completedCount: 2, totalCount: 5),
  );
  final actionEmptyStub = todayActionItemsProvider.overrideWith(
    (ref) async =>
        const TodayActionView(items: [], completedCount: 0, totalCount: 0),
  );

  Widget app({
    VoidCallback? onOpenMoney,
    VoidCallback? onOpenHealth,
    VoidCallback? onOpenAction,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: HomeStatusChips(
          onOpenMoney: onOpenMoney ?? () {},
          onOpenHealth: onOpenHealth ?? () {},
          onOpenAction: onOpenAction ?? () {},
        ),
      ),
    );
  }

  testWidgets('renders the three status chips', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [streakStub, healthStub, actionStub],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('连续记账 7 天'), findsOneWidget);
    expect(find.text('经期第 3 天'), findsOneWidget);
    expect(find.text('今日 2/5'), findsOneWidget);
  });

  testWidgets('each chip opens its own module', (tester) async {
    var money = 0;
    var health = 0;
    var action = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [streakStub, healthStub, actionStub],
        child: app(
          onOpenMoney: () => money++,
          onOpenHealth: () => health++,
          onOpenAction: () => action++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('连续记账 7 天'));
    await tester.tap(find.text('经期第 3 天'));
    await tester.tap(find.text('今日 2/5'));

    expect(money, 1);
    expect(health, 1);
    expect(action, 1);
  });

  testWidgets('有连续天数但今天还没记账时改成提醒文案', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [streakNotLoggedStub, healthStub, actionStub],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('今天还没记账'), findsOneWidget);
    expect(find.text('连续记账 7 天'), findsNothing);
  });

  testWidgets('没有任何状态时整行消失', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [streakEmptyStub, healthNullStub, actionEmptyStub],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('三个胶囊在手机宽度下不会溢出', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [streakStub, healthLongStub, actionStub],
        child: app(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
