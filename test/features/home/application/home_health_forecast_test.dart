import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/home/application/home_health_forecast_providers.dart';
import 'package:miji/features/home/presentation/home_health_forecast_card.dart';

HealthCyclePrediction prediction() => HealthCyclePrediction.cycleDay(
  basis: HealthPredictionBasis.history,
  mainStatus: '',
  currentCycleDay: 26,
  daysUntilNextPeriod: 2,
  nextPeriodStart: DateTime.utc(2026, 10, 14),
  nextPeriodEnd: DateTime.utc(2026, 10, 15),
  fertileWindowStart: DateTime.utc(2026, 10, 16),
  fertileWindowEnd: DateTime.utc(2026, 10, 17),
  pmsStart: DateTime.utc(2026, 10, 18),
  pmsEnd: DateTime.utc(2026, 10, 19),
);

Future<void> pumpCard(WidgetTester tester, HomeHealthForecast forecast) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: HomeHealthForecastCard(forecast: forecast, onOpenHealth: () {}),
      ),
    ),
  );
}

void main() {
  test('classifies period / fertile / pms days', () {
    final forecast = buildHomeHealthForecast(
      prediction: prediction(),
      activePeriod: null,
      startDate: DateTime.utc(2026, 10, 12),
      days: 7,
    );
    expect(forecast.days.length, 7);
    expect(forecast.days[0].kind, HomeForecastKind.normal); // 10-12
    expect(forecast.days[2].kind, HomeForecastKind.period); // 10-14
    expect(forecast.days[4].kind, HomeForecastKind.fertile); // 10-16
    expect(forecast.days[6].kind, HomeForecastKind.pms); // 10-18
  });

  test('active period wins over normal days', () {
    final forecast = buildHomeHealthForecast(
      prediction: HealthCyclePrediction.noHistory(mainStatus: ''),
      activePeriod: HealthPeriodRecordModel(
        id: 'p1',
        startDate: DateTime.utc(2026, 10, 11),
        endDate: DateTime.utc(2026, 10, 13),
        notes: null,
      ),
      startDate: DateTime.utc(2026, 10, 12),
      days: 3,
    );
    expect(forecast.days[0].kind, HomeForecastKind.period);
    expect(forecast.days[1].kind, HomeForecastKind.period);
    expect(forecast.days[2].kind, HomeForecastKind.normal);
  });

  testWidgets('状态画在日期格上，摘要按连续区间合并', (tester) async {
    final forecast = buildHomeHealthForecast(
      prediction: prediction(),
      activePeriod: null,
      startDate: DateTime.utc(2026, 10, 12),
      days: 7,
    );
    await pumpCard(tester, forecast);

    expect(find.text('📅 未来 7 天'), findsOneWidget);
    // 今天是第一格，且只出现一次。
    expect(find.text('今天'), findsOneWidget);

    // 7 个日期格各自带自己的日号（日期下面不再有任何色块）。
    for (final day in [12, 13, 14, 15, 16, 17, 18]) {
      expect(find.text('$day'), findsOneWidget);
    }

    // 摘要：连续同状态合并，且只列这 7 天里真的存在的状态。
    expect(find.text('经期 10/14–15'), findsOneWidget);
    expect(find.text('易孕 10/16–17'), findsOneWidget);
    expect(find.text('PMS 10/18'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨月的连续预测合并成一段并补上月份', (tester) async {
    final forecast = buildHomeHealthForecast(
      prediction: HealthCyclePrediction.cycleDay(
        basis: HealthPredictionBasis.history,
        mainStatus: '',
        currentCycleDay: 2,
        daysUntilNextPeriod: 2,
        nextPeriodStart: DateTime.utc(2026, 10, 30),
        nextPeriodEnd: DateTime.utc(2026, 11, 2),
        fertileWindowStart: DateTime.utc(2026, 11, 10),
        fertileWindowEnd: DateTime.utc(2026, 11, 12),
        pmsStart: DateTime.utc(2026, 11, 20),
        pmsEnd: DateTime.utc(2026, 11, 21),
      ),
      activePeriod: null,
      startDate: DateTime.utc(2026, 10, 28),
      days: 7,
    );
    await pumpCard(tester, forecast);

    expect(find.text('经期 10/30–11/2'), findsOneWidget);
    // 易孕期 / PMS 都不在这 7 天里，不该出现在摘要里。
    expect(find.textContaining('易孕'), findsNothing);
    expect(find.textContaining('PMS'), findsNothing);
  });

  testWidgets('这 7 天没有任何预测时给兜底文案', (tester) async {
    final forecast = buildHomeHealthForecast(
      prediction: HealthCyclePrediction.noHistory(mainStatus: ''),
      activePeriod: null,
      startDate: DateTime.utc(2026, 10, 12),
      days: 7,
    );
    await pumpCard(tester, forecast);

    expect(find.text('未来 7 天暂无经期 / 易孕期预测'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });
}
