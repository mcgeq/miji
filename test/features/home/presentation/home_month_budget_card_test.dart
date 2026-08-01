import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/presentation/home_month_budget_card.dart';

void main() {
  testWidgets('renders progress bar layout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeMonthBudgetCard(
            summary: const HomeMonthBudgetSummary(
              hasBudget: true,
              currencyCode: 'CNY',
              budgetId: 'budget-1',
              budgetName: '日常支出预算',
              totalMinor: 400000,
              usedMinor: 232000,
              remainingMinor: 168000,
              progress: 0.58,
              periodProgress: 0.61,
              paceRatio: 0.95,
              paceLabel: '节奏正常',
              remainingDays: 12,
            ),
            isLoading: false,
            onCreateBudget: () {},
          ),
        ),
      ),
    );

    expect(find.text('节奏正常'), findsOneWidget);
    expect(find.text('周期 61%'), findsOneWidget);
    expect(find.text('还可花'), findsOneWidget);
    expect(find.text('日均可花'), findsOneWidget);
    expect(find.text('剩余 12 天'), findsOneWidget);
  });
}
