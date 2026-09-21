import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/home/application/home_money_dashboard_models.dart';
import 'package:miji/features/home/application/home_money_dashboard_providers.dart';
import 'package:miji/features/home/presentation/home_weekly_trend_card.dart';

/// 以 [start] 为首日的 7 天，金额递增。
List<HomeDailySpendingPoint> _week(DateTime start) {
  return List.generate(7, (index) {
    return HomeDailySpendingPoint(
      date: DateTime(start.year, start.month, start.day + index),
      expenseMinor: (index + 1) * 1000,
      incomeMinor: 0,
      transactionCount: 1,
      isInMonth: true,
    );
  });
}

/// 以今天为中心、今天落在第 4 根柱子上的窗口。
HomeTrendWindow _rollingWindow({int offset = 0, int blockCount = 3}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return HomeTrendWindow(
    start: DateTime(
      today.year,
      today.month,
      today.day - homeTrendTodayIndex - offset * 7,
    ),
    blockCount: blockCount,
    offset: offset,
    rolling: true,
  );
}

HomeTrendWindow _calendarWindow({int offset = 0, int blockCount = 4}) {
  return HomeTrendWindow(
    start: DateTime(2024, 10, 14 + offset * 7),
    blockCount: blockCount,
    offset: offset,
    rolling: false,
  );
}

Widget _host(Widget child, {double width = 360}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  );
}

Widget _card(
  HomeTrendWindow window, {
  bool masked = false,
  ValueChanged<int>? onWeekChanged,
}) {
  return HomeWeeklyTrendCard(
    points: _week(window.start),
    window: window,
    selectedMonth: DateTime(window.start.year, window.start.month),
    dailyAverageMinor: 1500,
    currencyCode: 'CNY',
    isLoading: false,
    masked: masked,
    onWeekChanged: onWeekChanged ?? (_) {},
  );
}

void main() {
  testWidgets('renders the chart and the rolling week chips', (tester) async {
    await tester.pumpWidget(_host(_card(_rollingWindow())));
    await tester.pumpAndSettle();

    expect(find.byType(BarChart), findsOneWidget);
    expect(find.text('支出趋势'), findsOneWidget);
    expect(find.text('本周'), findsOneWidget);
    expect(find.text('上周'), findsOneWidget);
    expect(find.text('2 周前'), findsOneWidget);
    expect(find.text('日均线'), findsOneWidget);
    expect(find.textContaining('本周合计'), findsOneWidget);
  });

  testWidgets('puts the date range on the title line, right aligned', (
    tester,
  ) async {
    final window = _rollingWindow();
    await tester.pumpWidget(_host(_card(window)));
    await tester.pumpAndSettle();

    final start = window.start;
    final end = window.lastDay;
    final rangeLabel = '${start.month}/${start.day} - ${end.month}/${end.day}';
    final range = find.text(rangeLabel);
    expect(range, findsOneWidget);

    final titleRect = tester.getRect(find.text('支出趋势'));
    final rangeRect = tester.getRect(range);
    expect(
      (titleRect.center.dy - rangeRect.center.dy).abs(),
      lessThan(10),
      reason: '日期区间应与标题在同一行',
    );
    expect(rangeRect.left, greaterThan(titleRect.right));

    final titleSize = tester.widget<Text>(find.text('支出趋势')).style?.fontSize;
    final rangeSize = tester.widget<Text>(range).style?.fontSize;
    expect(rangeSize, isNotNull);
    expect(titleSize, isNotNull);
    expect(rangeSize!, lessThanOrEqualTo(titleSize! * 0.8));
  });

  testWidgets('today sits in the middle of the chart', (tester) async {
    await tester.pumpWidget(_host(_card(_rollingWindow())));
    await tester.pumpAndSettle();

    final today = find.text('今天');
    expect(today, findsOneWidget, reason: '当前窗口必须包含今天');

    final chartRect = tester.getRect(find.byType(BarChart));
    final todayRect = tester.getRect(today);
    // 「今天」位于第 4 根柱子（0 基索引 3），即 7 根柱子的正中间。
    expect(
      (todayRect.center.dx - chartRect.center.dx).abs(),
      lessThan(12),
      reason:
          '今天应位于图表中央，实际偏差 ${(todayRect.center.dx - chartRect.center.dx).abs()}',
    );
  });

  testWidgets('week chips report the tapped offset', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(_card(_rollingWindow(), onWeekChanged: tapped.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('2 周前'));
    await tester.pumpAndSettle();

    expect(tapped, [2]);
  });

  testWidgets('keeps the chip row for single-block months hidden', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_card(_rollingWindow(blockCount: 1))));
    await tester.pumpAndSettle();

    expect(find.text('本周'), findsNothing);
    expect(find.byType(BarChart), findsOneWidget);
  });

  testWidgets('uses calendar-week labels for a past month', (tester) async {
    await tester.pumpWidget(_host(_card(_calendarWindow(blockCount: 4))));
    await tester.pumpAndSettle();

    expect(find.text('第 1 周'), findsOneWidget);
    expect(find.text('第 4 周'), findsOneWidget);
    expect(find.text('本周'), findsNothing);
    // 历史月份的窗口不含今天。
    expect(find.text('今天'), findsNothing);
  });

  testWidgets('masks the weekly total when privacy mode is on', (tester) async {
    await tester.pumpWidget(_host(_card(_rollingWindow(), masked: true)));
    await tester.pumpAndSettle();

    expect(find.text('本周合计 ••••'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow surface with large amounts', (
    tester,
  ) async {
    final window = _rollingWindow(blockCount: 5);
    await tester.pumpWidget(
      _host(
        HomeWeeklyTrendCard(
          points: [
            for (var index = 0; index < 7; index++)
              HomeDailySpendingPoint(
                date: DateTime(
                  window.start.year,
                  window.start.month,
                  window.start.day + index,
                ),
                expenseMinor: 987654321,
                incomeMinor: 0,
                transactionCount: 12,
                isInMonth: true,
              ),
          ],
          window: window,
          selectedMonth: DateTime(window.start.year, window.start.month),
          dailyAverageMinor: 12345678,
          currencyCode: 'CNY',
          isLoading: false,
          masked: false,
          onWeekChanged: (_) {},
        ),
        width: 320,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
