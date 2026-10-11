import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/database/app_database.dart';
import 'package:miji/core/database/database_providers.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/presentation/gtd_page.dart';

/// 「任务」面板的新建入口必须真的打开快速创建面板。
///
/// 回归：这个按钮的 `onPressed` 里曾经只有一句 `// TODO`，点了完全没反应。
void main() {
  testWidgets('「新建任务」打开快速创建任务面板', (tester) async {
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
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: GtdPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 切到「任务」面板（页签只有图标，没有文字）。
    await tester.tap(find.byIcon(Icons.task_alt_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('新建任务'));
    await tester.pumpAndSettle();

    expect(find.text('输入任务标题'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '创建任务'), findsOneWidget);
  });

  testWidgets('每个面板的页级动作在手机宽度下都能渲染且不溢出', (tester) async {
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
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: GtdPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final icon in [
      Icons.task_alt_rounded,
      Icons.checklist_rounded,
      Icons.calendar_month_rounded,
      Icons.insights_rounded,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '切到 $icon 时抛异常');
      // 「习惯」有两个动作，最宽；至少保证有动作入口渲染出来。
      expect(find.byIcon(Icons.add_rounded), findsWidgets);
    }
  });
}

class _UnlockedSession extends AuthSessionController {
  @override
  AuthSession build() => const AuthSession(userId: 'user-1', isUnlocked: true);
}
