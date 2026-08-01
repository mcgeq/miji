import 'package:miji/features/bookkeeping/domain/money_account_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_transaction_entity.dart';

enum MoneySpendingAnalysisDimension {
  category,
  subCategory,
  merchant;

  String get storageValue {
    return switch (this) {
      MoneySpendingAnalysisDimension.category => 'category',
      MoneySpendingAnalysisDimension.subCategory => 'sub_category',
      MoneySpendingAnalysisDimension.merchant => 'merchant',
    };
  }
}

class MoneySpendingAnalysisQuery {
  const MoneySpendingAnalysisQuery({
    required this.currentMonth,
    required this.ledgerId,
    this.accountId,
    this.accountType,
    this.paymentMethod,
    this.baselineMonthCount = 3,
  });

  final DateTime currentMonth;
  final String ledgerId;
  final String? accountId;
  final MoneyAccountType? accountType;
  final MoneyPaymentMethod? paymentMethod;
  final int baselineMonthCount;

  DateTime get dateStart {
    return DateTime(currentMonth.year, currentMonth.month - baselineMonthCount);
  }

  DateTime get dateEndExclusive {
    return DateTime(currentMonth.year, currentMonth.month + 1);
  }
}

class MoneySpendingAnalysisSample {
  const MoneySpendingAnalysisSample({
    required this.dimension,
    required this.id,
    required this.name,
    required this.month,
    required this.amountMinor,
    required this.transactionCount,
  });

  final String dimension;
  final String id;
  final String name;
  final DateTime month;
  final int amountMinor;
  final int transactionCount;
}

class MoneySpendingAnomaly {
  const MoneySpendingAnomaly({
    required this.dimension,
    required this.id,
    required this.name,
    required this.currentAmountMinor,
    required this.baselineAverageMinor,
    required this.growthPercent,
    required this.transactionCount,
  });

  final MoneySpendingAnalysisDimension dimension;
  final String id;
  final String name;
  final int currentAmountMinor;
  final int baselineAverageMinor;
  final double growthPercent;
  final int transactionCount;
}

class MoneySpendingAnalysis {
  const MoneySpendingAnalysis({
    required this.currencyCode,
    required this.currentMonth,
    required this.baselineMonthCount,
    required this.minimumAmountMinor,
    required this.minimumGrowthPercent,
    required this.anomalies,
  });

  const MoneySpendingAnalysis.empty()
    : currencyCode = 'CNY',
      currentMonth = null,
      baselineMonthCount = 0,
      minimumAmountMinor = 0,
      minimumGrowthPercent = 0,
      anomalies = const <MoneySpendingAnomaly>[];

  final String currencyCode;
  final DateTime? currentMonth;
  final int baselineMonthCount;
  final int minimumAmountMinor;
  final double minimumGrowthPercent;
  final List<MoneySpendingAnomaly> anomalies;

  bool get hasAnomalies => anomalies.isNotEmpty;

  static MoneySpendingAnalysis fromSamples({
    required String currencyCode,
    required DateTime currentMonth,
    required Iterable<MoneySpendingAnalysisSample> samples,
    int baselineMonthCount = 3,
    int minimumAmountMinor = 5000,
    double minimumGrowthPercent = 20,
  }) {
    final normalizedCurrentMonth = _monthOnly(currentMonth);
    final buckets = <String, _SpendingBucket>{};

    for (final sample in samples) {
      final dimension = _dimensionFromStorageValue(sample.dimension);
      if (dimension == null) {
        continue;
      }
      final key = '${dimension.storageValue}|${sample.id}';
      final bucket = buckets.putIfAbsent(
        key,
        () => _SpendingBucket(
          dimension: dimension,
          id: sample.id,
          name: sample.name,
        ),
      );
      final month = _monthOnly(sample.month);
      bucket.amountByMonth[month] =
          (bucket.amountByMonth[month] ?? 0) + sample.amountMinor;
      bucket.transactionCountByMonth[month] =
          (bucket.transactionCountByMonth[month] ?? 0) +
          sample.transactionCount;
    }

    final anomalies = <MoneySpendingAnomaly>[];
    for (final bucket in buckets.values) {
      final currentAmountMinor =
          bucket.amountByMonth[normalizedCurrentMonth] ?? 0;
      if (currentAmountMinor < minimumAmountMinor) {
        continue;
      }

      var baselineTotalMinor = 0;
      for (var index = 1; index <= baselineMonthCount; index++) {
        final month = DateTime(
          normalizedCurrentMonth.year,
          normalizedCurrentMonth.month - index,
        );
        baselineTotalMinor += bucket.amountByMonth[month] ?? 0;
      }
      if (baselineTotalMinor <= 0 || baselineMonthCount <= 0) {
        continue;
      }

      final baselineAverageMinor = baselineTotalMinor ~/ baselineMonthCount;
      if (baselineAverageMinor <= 0) {
        continue;
      }
      final growthPercent =
          (currentAmountMinor - baselineAverageMinor) /
          baselineAverageMinor *
          100;
      if (growthPercent <= minimumGrowthPercent) {
        continue;
      }

      anomalies.add(
        MoneySpendingAnomaly(
          dimension: bucket.dimension,
          id: bucket.id,
          name: bucket.name,
          currentAmountMinor: currentAmountMinor,
          baselineAverageMinor: baselineAverageMinor,
          growthPercent: growthPercent,
          transactionCount:
              bucket.transactionCountByMonth[normalizedCurrentMonth] ?? 0,
        ),
      );
    }

    anomalies.sort((left, right) {
      final growthCompare = right.growthPercent.compareTo(left.growthPercent);
      if (growthCompare != 0) {
        return growthCompare;
      }
      return right.currentAmountMinor.compareTo(left.currentAmountMinor);
    });

    return MoneySpendingAnalysis(
      currencyCode: currencyCode,
      currentMonth: normalizedCurrentMonth,
      baselineMonthCount: baselineMonthCount,
      minimumAmountMinor: minimumAmountMinor,
      minimumGrowthPercent: minimumGrowthPercent,
      anomalies: anomalies.take(20).toList(growable: false),
    );
  }

  static MoneySpendingAnalysisDimension? _dimensionFromStorageValue(
    String value,
  ) {
    return switch (value) {
      'category' => MoneySpendingAnalysisDimension.category,
      'sub_category' => MoneySpendingAnalysisDimension.subCategory,
      'merchant' => MoneySpendingAnalysisDimension.merchant,
      _ => null,
    };
  }

  static DateTime _monthOnly(DateTime date) {
    final local = date.toLocal();
    return DateTime(local.year, local.month);
  }
}

class _SpendingBucket {
  _SpendingBucket({
    required this.dimension,
    required this.id,
    required this.name,
  });

  final MoneySpendingAnalysisDimension dimension;
  final String id;
  final String name;
  final Map<DateTime, int> amountByMonth = {};
  final Map<DateTime, int> transactionCountByMonth = {};
}
