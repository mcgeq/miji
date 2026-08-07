import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_today_spending_card.dart';

void main() {
  Widget buildCard({
    required HomeTodaySpendingSummary summary,
    required List<HomeDailySpendingPoint> points,
    DateTime? selectedMonth,
  }) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeTodaySpendingCard(
            selectedMonth: selectedMonth ?? DateTime.now(),
            weeklyPoints: points,
            summary: summary,
            isLoading: false,
            weekOffset: 0,
            totalWeeks: 5,
            onWeekChanged: (_) {},
          ),
        ),
      ),
    );
  }

  testWidgets('renders footer metrics in tile rows', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final points = List.generate(7, (i) {
      final date = today.add(Duration(days: 3 - i));
      return HomeDailySpendingPoint(
        date: date,
        expenseMinor: (i + 1) * 10000,
        incomeMinor: (i + 1) * 5000,
        transactionCount: 2,
        isInMonth: true,
      );
    });

    await tester.pumpWidget(
      buildCard(
        summary: const HomeTodaySpendingSummary(
          currencyCode: 'CNY',
          todayExpenseMinor: 8000,
          todayIncomeMinor: 3000,
          weekExpenseMinor: 280000,
          monthExpenseMinor: 1200000,
          monthIncomeMinor: 800000,
          monthExpenseTransactionCount: 42,
          todayTransactionCount: 5,
          dailyAverageExpenseMinor: 40000,
        ),
        points: points,
      ),
    );

    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('本月收入'), findsOneWidget);
    expect(find.text('结余'), findsOneWidget);
    expect(find.text('周支出'), findsOneWidget);
    expect(find.text('周收入'), findsOneWidget);
    expect(find.text('今日收入'), findsOneWidget);
    expect(find.text('14 笔'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('huge amounts do not overflow on a narrow surface', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final points = List.generate(7, (i) {
      return HomeDailySpendingPoint(
        date: today.subtract(Duration(days: 6 - i)),
        expenseMinor: 8800000000 + i * 1000000,
        incomeMinor: 6600000000 + i * 1000000,
        transactionCount: 3,
        isInMonth: true,
      );
    });

    await tester.pumpWidget(
      buildCard(
        summary: const HomeTodaySpendingSummary(
          currencyCode: 'CNY',
          todayExpenseMinor: 8800000000,
          todayIncomeMinor: 6600000000,
          weekExpenseMinor: 60000000000,
          monthExpenseMinor: 260000000000,
          monthIncomeMinor: 190000000000,
          monthExpenseTransactionCount: 300,
          todayTransactionCount: 21,
          dailyAverageExpenseMinor: 9000000000,
        ),
        points: points,
      ),
    );

    // Compact formatter keeps values readable; FittedBox scales them down
    // instead of overflowing.
    expect(find.text('本月支出'), findsOneWidget);
    expect(find.text('周支出'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
