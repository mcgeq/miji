import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 全局金额遮罩：开关打开后，任何走 [MoneyText] / [maskedMoneyOr] 的金额
/// 都应变成占位符（之前只覆盖首页与账户页，统计/预算/分期/提醒全是明文）。
void main() {
  Widget host({required bool masked, required Widget child}) {
    return ProviderScope(
      overrides: [
        currentUserPreferencesProvider.overrideWith(
          (ref) async => _preferences(maskMoneyAmounts: masked),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: MoneyPrivacyScope(child: child)),
      ),
    );
  }

  testWidgets('masks every MoneyText below the scope', (tester) async {
    await tester.pumpWidget(
      host(
        masked: true,
        child: const Column(
          children: [
            MoneyText(amountMinor: 414000, currencyCode: 'CNY'),
            MoneyText(amountMinor: 5234000, currencyCode: 'CNY'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsNWidgets(2));
    expect(find.textContaining('4,140'), findsNothing);
  });

  testWidgets('shows amounts when the switch is off', (tester) async {
    await tester.pumpWidget(
      host(
        masked: false,
        child: const MoneyText(amountMinor: 414000, currencyCode: 'CNY'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥4,140.00'), findsOneWidget);
    expect(find.text('••••'), findsNothing);
  });

  testWidgets('flipping the scope re-masks the subtree', (tester) async {
    // 直接验证 InheritedWidget 的通知机制：作用域变化时子树重建。
    Widget scope(bool masked) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: MoneyPrivacy(
          masked: masked,
          child: const MoneyText(amountMinor: 414000, currencyCode: 'CNY'),
        ),
      ),
    );

    await tester.pumpWidget(scope(false));
    await tester.pumpAndSettle();
    expect(find.text('¥4,140.00'), findsOneWidget);

    await tester.pumpWidget(scope(true));
    await tester.pumpAndSettle();
    expect(find.text('••••'), findsOneWidget);
    expect(find.text('¥4,140.00'), findsNothing);
  });

  testWidgets('maskedMoneyOr hides embedded amount strings', (tester) async {
    await tester.pumpWidget(
      host(
        masked: true,
        child: Builder(
          builder: (context) =>
              Text(maskedMoneyOr('支出 ¥1,240.00', MoneyPrivacy.of(context))),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsOneWidget);
  });
}

UserPreferencesEntity _preferences({required bool maskMoneyAmounts}) {
  final now = DateTime(2026, 1, 1);
  return UserPreferencesEntity(
    userId: 'user-1',
    themeMode: AppThemeModePreference.system,
    sensitiveAccessTtl: SensitiveAccessTtlOption.defaultOption,
    currencyCode: 'CNY',
    maskMoneyAmounts: maskMoneyAmounts,
    createdAt: now,
    updatedAt: now,
  );
}
