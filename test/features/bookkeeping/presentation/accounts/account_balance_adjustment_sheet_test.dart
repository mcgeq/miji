import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/presentation/accounts/account_balance_adjustment_sheet.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

/// 余额对账：账期明细 + 差额。
void main() {
  Widget host({
    MoneyAccountPeriodFlows flows = const MoneyAccountPeriodFlows(
      incomeMinor: 50000,
      expenseMinor: 3000,
    ),
  }) {
    return ProviderScope(
      overrides: [
        currentUserAccountPeriodFlowsProvider.overrideWith(
          (ref, key) async => flows,
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAccountBalanceAdjustmentSheet(
                context: context,
                account: _account,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('shows the period breakdown summing back to the balance', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('余额对账'), findsOneWidget);
    // 账面 1000.00 − (收入 500.00 − 支出 30.00) = 期初 530.00。
    expect(find.text('期初余额'), findsOneWidget);
    expect(find.text('¥530.00'), findsOneWidget);
    expect(find.text('期内收入'), findsOneWidget);
    expect(find.text('+¥500.00'), findsOneWidget);
    expect(find.text('期内支出'), findsOneWidget);
    expect(find.text('-¥30.00'), findsOneWidget);
    expect(find.text('应有余额'), findsOneWidget);
    // 期初 + 收入 − 支出 === 账面余额。
    expect(find.text('¥1,000.00'), findsWidgets);
  });

  testWidgets('shows the difference between entered and book balance', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1234.56');
    await tester.pumpAndSettle();

    expect(find.text('需补记'), findsOneWidget);
    expect(find.text('+¥234.56'), findsOneWidget);
  });

  testWidgets('switches the period and keeps the balance consistent', (
    tester,
  ) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('上月'));
    await tester.pumpAndSettle();

    // 换账期只换明细，账面余额不变。
    expect(find.text('¥1,000.00'), findsWidgets);
    expect(find.text('期初余额'), findsOneWidget);
  });
}

final _account = MoneyAccountEntity(
  id: 'asset-1',
  userId: 'user-1',
  name: '储蓄卡',
  type: MoneyAccountType.bank,
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
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);
