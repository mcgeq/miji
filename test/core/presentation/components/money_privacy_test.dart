import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/preferences_repository.dart';
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

  group('MoneyPrivacyTap', () {
    // 流水汇总栏的「支出 / 净」两格靠它点按切换：点一处，另一处同步显隐。
    Future<ProviderContainer> pumpTaps(
      WidgetTester tester, {
      required bool masked,
    }) async {
      var prefs = _preferences(maskMoneyAmounts: masked);
      final container = ProviderContainer(
        overrides: [
          currentUserPreferencesProvider.overrideWith((ref) async => prefs),
          preferencesRepositoryProvider.overrideWithValue(
            _RecordingPreferencesRepository((value) {
              prefs = _preferences(maskMoneyAmounts: value);
            }),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MoneyPrivacyScope(
                child: Builder(
                  builder: (context) => Column(
                    children: [
                      MoneyPrivacyTap(
                        child: Text(
                          maskedMoneyOr(
                            '支出 ¥1,240.00',
                            MoneyPrivacy.of(context),
                          ),
                        ),
                      ),
                      MoneyPrivacyTap(
                        child: Text(
                          maskedMoneyOr('净 -¥560.00', MoneyPrivacy.of(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('点一支出金额，支出与净一起遮罩，再点还原', (tester) async {
      await pumpTaps(tester, masked: false);
      expect(find.text('支出 ¥1,240.00'), findsOneWidget);
      expect(find.text('净 -¥560.00'), findsOneWidget);

      await tester.tap(find.text('支出 ¥1,240.00'));
      await tester.pumpAndSettle();
      expect(find.text('••••'), findsNWidgets(2));
      expect(find.text('支出 ¥1,240.00'), findsNothing);

      await tester.tap(find.text('••••').first);
      await tester.pumpAndSettle();
      expect(find.text('支出 ¥1,240.00'), findsOneWidget);
      expect(find.text('净 -¥560.00'), findsOneWidget);
    });

    testWidgets('全局开启时点按可临时显示', (tester) async {
      await pumpTaps(tester, masked: true);
      expect(find.text('••••'), findsNWidgets(2));

      await tester.tap(find.text('••••').last);
      await tester.pumpAndSettle();
      expect(find.text('支出 ¥1,240.00'), findsOneWidget);
      expect(find.text('净 -¥560.00'), findsOneWidget);
    });
  });
}

/// 只关心「隐藏金额」这一路的写库：其余接口在本测试里用不到。
class _RecordingPreferencesRepository implements PreferencesRepository {
  _RecordingPreferencesRepository(this._onMaskChanged);

  final void Function(bool mask) _onMaskChanged;

  @override
  Future<void> updateMaskMoneyAmounts(String userId, bool mask) async {
    _onMaskChanged(mask);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
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
