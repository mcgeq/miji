import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/presentation/plans/plan_detail_page.dart';

/// 习惯计划能从详情页删掉。
///
/// 回归：删除入口原先只挂在「计划管理」列表的溢出菜单上，而从「今日 / 习惯」
/// 列表点进去的是这个详情页——右上角空空如也，习惯计划因此删不掉。
/// 「任务」那边一直有删除按钮，这里的断言就是照它对齐的。
void main() {
  testWidgets('详情页能删除计划：软删 + 退回上一页', (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    await _insertUser(database);
    await _insertPlan(database, id: 'plan-1', name: '喝水');

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          authSessionControllerProvider.overrideWith(_UnlockedSession.new),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlanDetailPage(planId: 'plan-1'),
                    ),
                  ),
                  child: const Text('打开计划'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开计划'));
    await tester.pumpAndSettle();

    // 入口在右上角，与「任务详情」页同一个位置、同一个图标。
    await tester.tap(find.byTooltip('删除计划'));
    await tester.pumpAndSettle();
    expect(find.textContaining('喝水'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();

    final row = await (database.select(
      database.checkinPlans,
    )..where((r) => r.id.equals('plan-1'))).getSingle();
    expect(row.isDeleted, isTrue, reason: '删除应该是软删，历史记录仍留在库里');
    // 删完退回上一页，别停在一个已经不存在的计划上。
    expect(find.text('打开计划'), findsOneWidget);

    // 「计划已删除」提示背后是 FToast 的 2 秒定时器：测试结束前要让它跑完，
    // 否则框架会报 "A Timer is still pending even after the widget tree was
    // disposed"。
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}

Future<void> _insertUser(AppDatabase database) async {
  final now = DateTime.utc(2026, 10, 14, 12);
  await database
      .into(database.users)
      .insert(
        UsersCompanion.insert(
          id: 'user-1',
          username: 'user-1',
          email: 'user-1@example.com',
          displayName: 'User One',
          createdAt: now,
          updatedAt: now,
        ),
      );
}

Future<void> _insertPlan(
  AppDatabase database, {
  required String id,
  required String name,
}) async {
  final now = DateTime.utc(2026, 10, 14, 12);
  await database
      .into(database.checkinPlans)
      .insert(
        CheckinPlansCompanion.insert(
          id: id,
          userId: 'user-1',
          name: name,
          createdAt: now,
          updatedAt: now,
        ),
      );
}
