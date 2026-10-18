import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/auth/domain/auth_session.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/gtd/presentation/plans/plan_form_page.dart';

/// 表单上的联动规则：换分类时默认图标跟着换；用户手动选过之后不再覆盖。
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionControllerProvider.overrideWith(() => _Unlocked()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const PlanFormPage()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('新建时默认图标是「其他」的第一枚，且不显示自定义输入框', (tester) async {
    await pump(tester);

    expect(find.text('其他 默认'), findsOneWidget);
    expect(find.byType(TextField).evaluate().length, lessThan(3));
    // 名称 + 自定义 emoji 文本框，新建时后者不该存在
    expect(find.text('自定义 emoji'), findsNothing);
  });
}

class _Unlocked extends AuthSessionController {
  @override
  AuthSession build() =>
      const AuthSession(userId: 'user-1', isUnlocked: true, unlockedAt: null);
}
