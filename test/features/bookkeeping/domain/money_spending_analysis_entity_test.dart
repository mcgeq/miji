import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/domain/money_spending_analysis_entity.dart';

void main() {
  test(
    'finds category and merchant increases above the configured baseline',
    () {
      final analysis = MoneySpendingAnalysis.fromSamples(
        currencyCode: 'CNY',
        currentMonth: DateTime(2026, 7),
        samples: [
          _sample('category', 'food', '餐饮', DateTime(2026, 4), 8000, 4),
          _sample('category', 'food', '餐饮', DateTime(2026, 5), 9000, 5),
          _sample('category', 'food', '餐饮', DateTime(2026, 6), 10000, 6),
          _sample('category', 'food', '餐饮', DateTime(2026, 7), 15000, 8),
          _sample('merchant', 'cafe', '咖啡店', DateTime(2026, 4), 4000, 2),
          _sample('merchant', 'cafe', '咖啡店', DateTime(2026, 5), 5000, 2),
          _sample('merchant', 'cafe', '咖啡店', DateTime(2026, 6), 6000, 3),
          _sample('merchant', 'cafe', '咖啡店', DateTime(2026, 7), 10000, 5),
        ],
      );

      expect(analysis.anomalies, hasLength(2));
      expect(analysis.anomalies.first.name, '咖啡店');
      expect(analysis.anomalies.first.growthPercent, closeTo(100, 0.1));
      expect(analysis.anomalies.last.name, '餐饮');
    },
  );

  test('excludes exact threshold, small amount, and zero-baseline samples', () {
    final analysis = MoneySpendingAnalysis.fromSamples(
      currencyCode: 'CNY',
      currentMonth: DateTime(2026, 7),
      samples: [
        _sample('category', 'exact', '刚好20%', DateTime(2026, 4), 10000, 1),
        _sample('category', 'exact', '刚好20%', DateTime(2026, 5), 10000, 1),
        _sample('category', 'exact', '刚好20%', DateTime(2026, 6), 10000, 1),
        _sample('category', 'exact', '刚好20%', DateTime(2026, 7), 12000, 1),
        _sample('category', 'small', '金额太小', DateTime(2026, 4), 1000, 1),
        _sample('category', 'small', '金额太小', DateTime(2026, 5), 1000, 1),
        _sample('category', 'small', '金额太小', DateTime(2026, 6), 1000, 1),
        _sample('category', 'small', '金额太小', DateTime(2026, 7), 2000, 1),
        _sample('merchant', 'new', '首次消费', DateTime(2026, 7), 10000, 1),
      ],
    );

    expect(analysis.anomalies, isEmpty);
  });
}

MoneySpendingAnalysisSample _sample(
  String dimension,
  String id,
  String name,
  DateTime month,
  int amountMinor,
  int transactionCount,
) {
  return MoneySpendingAnalysisSample(
    dimension: dimension,
    id: id,
    name: name,
    month: month,
    amountMinor: amountMinor,
    transactionCount: transactionCount,
  );
}
