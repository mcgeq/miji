import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_bill_view.dart';
import 'package:miji/features/bookkeeping/domain/money_credit_card_statement_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_net_worth_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/money_accounts_section.dart';
import 'package:miji/core/auth/domain/sensitive_access_ttl_option.dart';
import 'package:miji/core/preferences/domain/user_preferences_entity.dart';
import 'package:miji/core/preferences/providers/preferences_providers.dart';
import 'package:miji/core/presentation/components/money_text.dart';

void main() {
  testWidgets('switches display groups and shows credit usage details', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserVisibleAccountsProvider.overrideWith((ref) async* {
            yield [_assetAccount, _creditAccount, _inactiveAccount];
          }),
          currentUserAccountMonthlySummariesProvider.overrideWith((ref) async {
            return const <String, MoneyAccountMonthlySummary>{};
          }),
          currentUserNetWorthSummaryProvider.overrideWith((ref) async {
            return const MoneyNetWorthSummary(
              currencyCode: 'CNY',
              assetMinor: 200000,
              liabilityMinor: 100000,
            );
          }),
          currentUserCreditCardBillViewProvider(
            _creditAccount.id,
          ).overrideWith((ref) async => _bill),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MoneyAccountsSection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 分组 chips 并排展示（只带数量，金额只在净资产卡里出现一次）。
    expect(find.text('资产'), findsOneWidget);
    expect(find.text('信用负债'), findsOneWidget);
    expect(find.text('停用'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(3));

    // 净资产 Hero 取代了原来只有「资产合计」的一行摘要。
    expect(find.text('净资产'), findsOneWidget);
    expect(find.text('总资产'), findsOneWidget);
    expect(find.text('负债'), findsOneWidget);
    // 净资产 = 2000 - 1000，金额只在 Hero 里出现；chips 只带数量不重复金额。
    expect(find.text('¥1,000.00'), findsWidgets);
    expect(find.text('¥2,000.00'), findsOneWidget);

    // 默认「资产」分组：只看到储蓄卡。
    expect(find.text('储蓄卡'), findsOneWidget);
    expect(find.text('信用卡'), findsNothing);

    await tester.tap(find.text('信用负债'));
    await tester.pumpAndSettle();

    // 切到信用分组后只剩信用卡，且额度与还款信息可见。
    expect(find.text('信用卡'), findsOneWidget);
    expect(find.text('储蓄卡'), findsNothing);
    expect(find.text('旧账户'), findsNothing);
    expect(find.text('本期应还'), findsOneWidget);
    expect(find.text('¥1,200.00'), findsOneWidget);
    expect(find.textContaining('8月10日还款'), findsOneWidget);
    // 额度进度条替代了原来那行 11px 小字。
    expect(find.text('可用额度'), findsOneWidget);
    expect(find.textContaining('已用 ¥1,000.00'), findsOneWidget);
    expect(find.textContaining('额度 ¥10,000.00'), findsOneWidget);

    // 每张卡片都有可见的操作入口（左滑不再是唯一方式）。
    expect(find.byIcon(Icons.more_horiz_rounded), findsWidgets);
  });

  testWidgets('opens the account actions menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserVisibleAccountsProvider.overrideWith((ref) async* {
            yield [_assetAccount];
          }),
          currentUserAccountMonthlySummariesProvider.overrideWith((ref) async {
            return const <String, MoneyAccountMonthlySummary>{};
          }),
          currentUserNetWorthSummaryProvider.overrideWith((ref) async {
            return const MoneyNetWorthSummary(
              currencyCode: 'CNY',
              assetMinor: 123456,
              liabilityMinor: 0,
            );
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: MoneyAccountsSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('编辑账户'), findsOneWidget);
    expect(find.text('停用账户'), findsOneWidget);
    expect(find.text('删除账户'), findsOneWidget);
  });

  group('全局金额遮罩', () {
    testWidgets('masks net worth and account balances when enabled', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_maskedHarness(masked: true));
      await tester.pumpAndSettle();

      // 净资产 Hero 与账户余额都遮住。
      expect(find.text('¥2,000.00'), findsNothing);
      expect(find.text('••••'), findsWidgets);
    });

    /// 回归：全局开关用的是 ref.read，已挂载的账户面板不会重建，
    /// 导致「在设置里打开遮罩 → 回到账户页金额依旧明文」。
    testWidgets('applies immediately when the global switch flips', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var masked = false;
      final container = ProviderContainer(
        overrides: [
          currentUserVisibleAccountsProvider.overrideWith(
            (ref) => Stream.value([_assetAccount]),
          ),
          currentUserAccountMonthlySummariesProvider.overrideWith(
            (ref) async => const <String, MoneyAccountMonthlySummary>{},
          ),
          currentUserNetWorthSummaryProvider.overrideWith(
            (ref) async => const MoneyNetWorthSummary(
              currencyCode: 'CNY',
              assetMinor: 200000,
              liabilityMinor: 100000,
            ),
          ),
          currentUserPreferencesProvider.overrideWith(
            (ref) async => _preferences(maskMoneyAmounts: masked),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: MoneyPrivacyScope(child: MoneyAccountsSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('¥2,000.00'), findsOneWidget);

      // 模拟「在设置页打开隐藏金额」。
      masked = true;
      container.invalidate(currentUserPreferencesProvider);
      await tester.pumpAndSettle();

      expect(find.text('¥2,000.00'), findsNothing);
      expect(find.text('••••'), findsWidgets);
    });

    /// 回归：全局遮罩打开时，逐账户菜单必须仍然可用
    /// （原来金额是隐藏的，但菜单却显示「隐藏金额」，点了没反应）。
    testWidgets('per-account menu can reveal a single account', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_maskedHarness(masked: true));
      await tester.pumpAndSettle();
      expect(find.text('¥2,000.00'), findsNothing);

      // 打开第一个账户的 ⋯ 菜单：应该提供「显示金额」。
      await tester.tap(find.byTooltip('更多操作').first);
      await tester.pumpAndSettle();
      expect(find.text('显示金额'), findsOneWidget);

      await tester.tap(find.text('显示金额'));
      await tester.pumpAndSettle();

      // 该账户的金额恢复展示（净资产 Hero 仍按生效状态遮住）。
      expect(find.text('¥2,000.00'), findsOneWidget);
    });
  });
}

final _now = DateTime(2026, 7, 20, 12);

final _assetAccount = MoneyAccountEntity(
  id: 'asset-1',
  userId: 'user-1',
  name: '储蓄卡',
  type: MoneyAccountType.bank,
  balanceMinor: 123456,
  initialBalanceMinor: 123456,
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
  createdAt: _now,
  updatedAt: _now,
);

final _creditAccount = MoneyAccountEntity(
  id: 'credit-1',
  userId: 'user-1',
  name: '信用卡',
  type: MoneyAccountType.creditCard,
  balanceMinor: 0,
  initialBalanceMinor: 0,
  creditLimitMinor: 1000000,
  postedDebtMinor: 100000,
  frozenCreditMinor: 0,
  statementDay: 17,
  budgetCycleStartDay: 16,
  repaymentDay: 10,
  autoRepaymentReminderEnabled: true,
  currencyCode: 'CNY',
  isShared: false,
  isVirtual: false,
  isActive: true,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _inactiveAccount = MoneyAccountEntity(
  id: 'inactive-1',
  userId: 'user-1',
  name: '旧账户',
  type: MoneyAccountType.cash,
  balanceMinor: 5000,
  initialBalanceMinor: 5000,
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
  isActive: false,
  isDeleted: false,
  createdAt: _now,
  updatedAt: _now,
);

final _bill = MoneyCreditCardBillView(
  accountId: 'credit-1',
  currencyCode: 'CNY',
  source: MoneyCreditCardBillViewSource.issuedStatement,
  periodStart: DateTime(2026, 6, 16),
  periodEndExclusive: DateTime(2026, 7, 16),
  repaymentDate: DateTime(2026, 8, 10),
  purchaseAmountMinor: 150000,
  repaymentAmountMinor: 30000,
  amountDueMinor: 120000,
  availableCreditMinor: 880000,
  postedDebtMinor: 120000,
  state: MoneyCreditCardStatementState.dueSoon,
);

Widget _maskedHarness({required bool masked}) {
  return ProviderScope(
    overrides: [
      currentUserVisibleAccountsProvider.overrideWith(
        (ref) => Stream.value([_assetAccount]),
      ),
      currentUserAccountMonthlySummariesProvider.overrideWith(
        (ref) async => const <String, MoneyAccountMonthlySummary>{},
      ),
      currentUserNetWorthSummaryProvider.overrideWith(
        (ref) async => const MoneyNetWorthSummary(
          currencyCode: 'CNY',
          assetMinor: 200000,
          liabilityMinor: 100000,
        ),
      ),
      currentUserPreferencesProvider.overrideWith(
        (ref) async => _preferences(maskMoneyAmounts: masked),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: MoneyPrivacyScope(child: MoneyAccountsSection()),
      ),
    ),
  );
}

UserPreferencesEntity _preferences({required bool maskMoneyAmounts}) {
  final now = DateTime(2026, 1, 1);
  return UserPreferencesEntity(
    userId: 'user-1',
    themeMode: AppThemeModePreference.system,
    themeSeedColor: 0xFFE45F4F,
    sensitiveAccessTtl: SensitiveAccessTtlOption.defaultOption,
    currencyCode: 'CNY',
    maskMoneyAmounts: maskMoneyAmounts,
    createdAt: now,
    updatedAt: now,
  );
}
