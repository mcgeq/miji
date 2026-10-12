import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/providers/health_providers.dart';

enum HomeForecastKind { period, fertile, pms, normal }

class HomeForecastDay {
  const HomeForecastDay({required this.date, required this.kind});

  final DateTime date;
  final HomeForecastKind kind;
}

class HomeHealthForecast {
  const HomeHealthForecast({required this.days});

  final List<HomeForecastDay> days;
}

final homeHealthForecastProvider = FutureProvider<HomeHealthForecast?>((
  ref,
) async {
  final snapshot = await ref.watch(
    currentUserHealthTodaySnapshotProvider.future,
  );
  if (snapshot == null || !snapshot.settings.periodTrackingEnabled) {
    return null;
  }
  return buildHomeHealthForecast(
    prediction: snapshot.prediction,
    activePeriod: snapshot.activePeriod,
    startDate: snapshot.date,
    days: 7,
  );
});

HomeHealthForecast buildHomeHealthForecast({
  required HealthCyclePrediction prediction,
  required HealthPeriodRecordModel? activePeriod,
  required DateTime startDate,
  int days = 7,
}) {
  final start = _dateOnly(startDate);
  return HomeHealthForecast(
    days: [
      for (var i = 0; i < days; i++)
        HomeForecastDay(
          date: start.add(Duration(days: i)),
          kind: _kindFor(start.add(Duration(days: i)), prediction, activePeriod),
        ),
    ],
  );
}

HomeForecastKind _kindFor(
  DateTime date,
  HealthCyclePrediction prediction,
  HealthPeriodRecordModel? activePeriod,
) {
  if (activePeriod != null && activePeriod.containsDate(date)) {
    return HomeForecastKind.period;
  }
  if (_inRange(date, prediction.nextPeriodStart, prediction.nextPeriodEnd)) {
    return HomeForecastKind.period;
  }
  if (_inRange(
    date,
    prediction.fertileWindowStart,
    prediction.fertileWindowEnd,
  )) {
    return HomeForecastKind.fertile;
  }
  if (_inRange(date, prediction.pmsStart, prediction.pmsEnd)) {
    return HomeForecastKind.pms;
  }
  return HomeForecastKind.normal;
}

bool _inRange(DateTime date, DateTime? start, DateTime? end) {
  if (start == null || end == null) {
    return false;
  }
  final day = _dateOnly(date);
  return !day.isBefore(_dateOnly(start)) && !day.isAfter(_dateOnly(end));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
