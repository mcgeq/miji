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

  testWidgets('renders seven cells and a legend', (tester) async {
    final forecast = buildHomeHealthForecast(
      prediction: prediction(),
      activePeriod: null,
      startDate: DateTime.utc(2026, 10, 12),
      days: 7,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeHealthForecastCard(
            forecast: forecast,
            onOpenHealth: () {},
          ),
        ),
      ),
    );
    expect(find.text('📅 未来 7 天'), findsOneWidget);
    expect(find.text('经期'), findsOneWidget);
    expect(find.text('易孕'), findsOneWidget);
    expect(find.text('PMS'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
