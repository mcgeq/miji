import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/money_report_period.dart';

void main() {
  group('resolveMoneyReportPeriodRange', () {
    test('monthly covers the calendar month', () {
      final range = resolveMoneyReportPeriodRange(
        'monthly',
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.endExclusive, DateTime(2026, 8, 1));
    });

    test('weekly starts on Monday', () {
      // 2026-07-15 is a Wednesday.
      final range = resolveMoneyReportPeriodRange(
        'weekly',
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 7, 13));
      expect(range.endExclusive, DateTime(2026, 7, 20));
    });

    test('quarterly covers three months', () {
      final range = resolveMoneyReportPeriodRange(
        'quarterly',
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.endExclusive, DateTime(2026, 10, 1));
    });

    test('yearly covers the calendar year', () {
      final range = resolveMoneyReportPeriodRange(
        'yearly',
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 1, 1));
      expect(range.endExclusive, DateTime(2027, 1, 1));
    });

    test('unknown period falls back to monthly', () {
      final range = resolveMoneyReportPeriodRange(
        'unknown',
        DateTime(2026, 7, 15),
      );
      expect(range.start, DateTime(2026, 7, 1));
      expect(range.endExclusive, DateTime(2026, 8, 1));
    });
  });

  test('MoneyReportPeriodOption.fromValue falls back to monthly', () {
    expect(MoneyReportPeriodOption.fromValue('weekly').label, '周报');
    expect(MoneyReportPeriodOption.fromValue('nope').value, 'monthly');
  });
}
