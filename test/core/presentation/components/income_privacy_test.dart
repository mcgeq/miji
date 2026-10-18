import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_theme.dart';

/// 收入金额独立显隐：默认 `****`、点按切换、与全局「隐藏金额」正交。
void main() {
  Widget scopeHost(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: IncomePrivacyScope(child: child)),
      ),
    );
  }

  testWidgets('作用域默认遮罩（state 初始 true）', (tester) async {
    bool? read;
    await tester.pumpWidget(
      scopeHost(
        Builder(
          builder: (context) {
            read = IncomePrivacy.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(read, isTrue);
  });

  testWidgets('作用域外兜底为 true（失败安全）', (tester) async {
    bool? read;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                read = IncomePrivacy.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(read, isTrue);
  });

  testWidgets('后代可读到 toggle 并切换状态，状态被依赖方重建', (tester) async {
    await tester.pumpWidget(
      scopeHost(
        Column(
          children: [
            Builder(
              builder: (context) => Text(
                'masked=${IncomePrivacy.of(context)}',
                key: const ValueKey('state'),
              ),
            ),
            Builder(
              builder: (context) => TextButton(
                onPressed: () => IncomePrivacy.toggleOf(context)!(),
                child: const Text('toggle'),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('state')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('state'))).data,
      'masked=true',
    );

    await tester.tap(find.text('toggle'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('state'))).data,
      'masked=false',
    );
  });

  group('MoneyText 收入分支', () {
    Widget host({required Widget child, bool globalMasked = false}) {
      return ProviderScope(
        overrides: [
          currentUserPreferencesProvider.overrideWith(
            (ref) async => _preferences(maskMoneyAmounts: globalMasked),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // 两套作用域都要在：MoneyPrivacy 管支出/中性，IncomePrivacy 管收入。
          home: Scaffold(
            body: MoneyPrivacyScope(child: IncomePrivacyScope(child: child)),
          ),
        ),
      );
    }

    const income = MoneyText(
      amountMinor: 414000,
      currencyCode: 'CNY',
      tone: MoneyAmountTone.income,
    );
    const expense = MoneyText(amountMinor: 5234000, currencyCode: 'CNY');

    testWidgets('收入默认 ****，支出默认明文（全局开关关闭时）', (tester) async {
      await tester.pumpWidget(
        host(child: const Column(children: [income, expense])),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
      expect(find.text('¥52,340.00'), findsOneWidget);
    });

    testWidgets('点击收入金额显示，再点隐藏', (tester) async {
      await tester.pumpWidget(host(child: const Column(children: [income])));
      await tester.pumpAndSettle();
      expect(find.text('****'), findsOneWidget);

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget);

      await tester.tap(find.text('¥4,140.00'));
      await tester.pumpAndSettle();
      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
    });

    testWidgets('点一处，另一处收入同步切换', (tester) async {
      await tester.pumpWidget(
        host(
          child: const Column(
            children: [
              income,
              MoneyText(
                amountMinor: 9900,
                currencyCode: 'CNY',
                tone: MoneyAmountTone.income,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('****'), findsNWidgets(2));

      await tester.tap(find.text('****').first);
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget);
      expect(find.text('¥99.00'), findsOneWidget);
      expect(find.text('****'), findsNothing);
    });

    testWidgets('全局开：支出 ••••、收入 ****；点收入后收入明文、支出仍 ••••', (tester) async {
      await tester.pumpWidget(
        host(
          globalMasked: true,
          child: const Column(children: [income, expense]),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('••••'), findsOneWidget);
      expect(find.text('****'), findsOneWidget);

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();
      expect(find.text('¥4,140.00'), findsOneWidget); // 收入独立，仍可见
      expect(find.text('••••'), findsOneWidget); // 支出不受收入点击影响
    });

    testWidgets('作用域外的收入金额显示 ****（兜底）', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserPreferencesProvider.overrideWith(
              (ref) async => _preferences(maskMoneyAmounts: false),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: income),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
      expect(find.text('¥4,140.00'), findsNothing);
    });

    testWidgets('点收入金额不触发外层行的 onTap', (tester) async {
      var rowTapped = false;
      await tester.pumpWidget(
        host(
          child: InkWell(
            onTap: () => rowTapped = true,
            child: const Padding(padding: EdgeInsets.all(8), child: income),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('****'));
      await tester.pumpAndSettle();

      expect(rowTapped, isFalse);
      expect(find.text('¥4,140.00'), findsOneWidget);
    });
  });

  group('拼接文案 helper', () {
    testWidgets('maskedIncomeOr：遮罩时返回 ****，且随点按切换', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => Text(
                        maskedIncomeOr('收入 ¥800.00', context),
                        key: const ValueKey('income-str'),
                      ),
                    ),
                    const MoneyText(
                      amountMinor: 100,
                      currencyCode: 'CNY',
                      tone: MoneyAmountTone.income,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('income-str')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('income-str'))).data,
        '****',
      );

      await tester.tap(find.text('****').last); // 点 MoneyText 那处
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('income-str'))).data,
        '收入 ¥800.00',
      );
    });

    testWidgets('maskedMoneyValue：isIncome 选收入遮罩，否则选全局遮罩', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MoneyPrivacyScope(
                child: IncomePrivacyScope(
                  child: Builder(
                    builder: (context) => Column(
                      children: [
                        Text(
                          maskedMoneyValue(
                            '¥1,000.00',
                            isIncome: true,
                            context: context,
                          ),
                          key: const ValueKey('v-income'),
                        ),
                        Text(
                          maskedMoneyValue(
                            '¥2,000.00',
                            isIncome: false,
                            context: context,
                          ),
                          key: const ValueKey('v-expense'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('v-income'))).data,
        '****',
      );
      // 全局开关默认关闭 → 支出侧保持明文
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('v-expense'))).data,
        '¥2,000.00',
      );
    });

    testWidgets('maskedMoneyOr 支持自定义占位符', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Builder(
                  builder: (context) => Text(
                    maskedMoneyOr('¥3,000.00', true, placeholder: '****'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('****'), findsOneWidget);
    });

    testWidgets('IncomeAmountTap 包住的文案可点按切换', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: IncomePrivacyScope(
                child: Column(
                  children: [
                    Builder(
                      builder: (context) => IncomeAmountTap(
                        child: Text(
                          maskedIncomeOr('收入 ¥800.00', context),
                          key: const ValueKey('tappable'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tappable'))).data,
        '****',
      );

      await tester.tap(find.byKey(const ValueKey('tappable')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('tappable'))).data,
        '收入 ¥800.00',
      );
    });
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
