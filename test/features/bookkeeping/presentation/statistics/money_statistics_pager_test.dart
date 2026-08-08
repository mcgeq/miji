import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_split_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';
import 'package:miji/features/bookkeeping/presentation/statistics/money_statistics_section.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

void main() {
  testWidgets('statistics pager shows dots and the first page content', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSection());
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('statistics-dot-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('statistics-dot-4')), findsOneWidget);
    expect(find.text('总览'), findsNothing);
    expect(find.text('收支趋势'), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);
  });

  testWidgets('swiping left moves to the next page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSection());
    await tester.pumpAndSettle();

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('支出分类'), findsOneWidget);
    expect(find.text('收支趋势'), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('支付渠道'), findsOneWidget);
  });

  testWidgets('tapping the last dot jumps to the last page', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildSection());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('statistics-dot-4')));
    await tester.pumpAndSettle();

    expect(find.text('账户分布'), findsOneWidget);
    expect(find.text('总览'), findsNothing);
  });
}

final _now = DateTime(2026, 7, 20, 12);

final _ledger = MoneyLedgerEntity(
  id: 'ledger-1',
  userId: 'user-1',
  name: '家庭账本',
  ledgerType: 'family',
  status: 'active',
  baseCurrencyCode: 'CNY',
  createdAt: _now,
  updatedAt: _now,
);

final _context = MoneyStatisticsContext(
  userId: 'user-1',
  ledger: _ledger,
  accounts: const <MoneyAccountEntity>[],
);

Widget _buildSection() {
  return ProviderScope(
    overrides: [
      moneyStatisticsContextProvider.overrideWith((ref) async => _context),
      moneyStatisticsProvider.overrideWith(
        (ref, request) async => const MoneyStatisticsSummary.empty(),
      ),
      moneyStatisticsInsightsProvider.overrideWith(
        (ref, request) async => const MoneyStatisticsInsights.empty(),
      ),
      moneySpendingAnalysisProvider.overrideWith(
        (ref, request) async => const MoneySpendingAnalysis.empty(),
      ),
      moneyBudgetHistoryTrendProvider.overrideWith(
        (ref, ledgerId) async => const <MoneyBudgetHistoryTrendPoint>[],
      ),
      currentUserBillRemindersProvider.overrideWith((ref) async* {
        yield const <MoneyBillReminderEntity>[];
      }),
      moneyUpcomingCashFlowProvider.overrideWith(
        (ref, ledgerId) async => const MoneyUpcomingCashFlowSummary.empty(),
      ),
      currentUserLatestReportProvider.overrideWith((ref, arg) async => null),
      currentUserBudgetsProvider.overrideWith((ref) async* {
        yield const <MoneyBudgetEntity>[];
      }),
      currentUserNetWorthTrendProvider.overrideWith(
        (ref, arg) async => const <MoneyNetWorthTrendPoint>[],
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: MoneyStatisticsSection()),
    ),
  );
}
