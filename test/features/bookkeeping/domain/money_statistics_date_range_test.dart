import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_statistics_entity.dart';

void main() {
  group('MoneyStatisticsDateRange.resolve weekly presets', () {
    test('thisWeek spans the current Monday to next Monday', () {
      // 2026-08-09 is a Sunday.
      final range = MoneyStatisticsDateRange.resolve(
        MoneyStatisticsPeriodPreset.thisWeek,
        DateTime(2026, 8, 9),
      );

      expect(range.start, DateTime(2026, 8, 3));
      expect(range.endExclusive, DateTime(2026, 8, 10));
      expect(range.groupBy, MoneyStatisticsGroupBy.day);
    });

    test('lastWeek spans the previous Monday to the current Monday', () {
      // 2026-08-06 is a Thursday.
      final range = MoneyStatisticsDateRange.resolve(
        MoneyStatisticsPeriodPreset.lastWeek,
        DateTime(2026, 8, 6),
      );

      expect(range.start, DateTime(2026, 7, 27));
      expect(range.endExclusive, DateTime(2026, 8, 3));
      expect(range.groupBy, MoneyStatisticsGroupBy.day);
    });

    test('Monday anchor keeps the week itself', () {
      final range = MoneyStatisticsDateRange.resolve(
        MoneyStatisticsPeriodPreset.thisWeek,
        DateTime(2026, 8, 3),
      );

      expect(range.start, DateTime(2026, 8, 3));
      expect(range.endExclusive, DateTime(2026, 8, 10));
    });
  });
}
