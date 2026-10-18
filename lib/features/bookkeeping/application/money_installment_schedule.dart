import 'dart:math' as math;

import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';

class MoneyInstallmentScheduleEntry {
  const MoneyInstallmentScheduleEntry({
    required this.principalMinor,
    required this.interestMinor,
  });

  final int principalMinor;
  final int interestMinor;

  int get amountMinor => principalMinor + interestMinor;
}

/// 生成每期的本金 / 利息安排。
///
/// - flat（等额平摊）：本金与总利息分别平均分摊，余数分配到前几期；
/// - equalInstallment（等额本息）：每期还款额相同，利息按剩余本金计算；
/// - equalPrincipal（等额本金）：每期本金相同，利息按剩余本金计算。
///
/// 所有结果以「分」为单位，且本金之和严格等于 [principalMinor]。
List<MoneyInstallmentScheduleEntry> buildInstallmentSchedule({
  required int principalMinor,
  required int totalPeriods,
  required MoneyInstallmentCalcMethod calcMethod,
  int interestRateBasisPoints = 0,
  int totalInterestMinor = 0,
}) {
  if (principalMinor <= 0 || totalPeriods <= 0) {
    return const <MoneyInstallmentScheduleEntry>[];
  }
  switch (calcMethod) {
    case MoneyInstallmentCalcMethod.flat:
      final principals = _splitEven(principalMinor, totalPeriods);
      final interests = _splitEven(totalInterestMinor, totalPeriods);
      return [
        for (var index = 0; index < totalPeriods; index++)
          MoneyInstallmentScheduleEntry(
            principalMinor: principals[index],
            interestMinor: interests[index],
          ),
      ];
    case MoneyInstallmentCalcMethod.equalInstallment:
      return _equalInstallmentSchedule(
        principalMinor: principalMinor,
        totalPeriods: totalPeriods,
        interestRateBasisPoints: interestRateBasisPoints,
      );
    case MoneyInstallmentCalcMethod.equalPrincipal:
      return _equalPrincipalSchedule(
        principalMinor: principalMinor,
        totalPeriods: totalPeriods,
        interestRateBasisPoints: interestRateBasisPoints,
      );
  }
}

List<int> _splitEven(int total, int parts) {
  final base = total ~/ parts;
  final remainder = total % parts;
  return List<int>.generate(
    parts,
    (index) => base + (index < remainder ? 1 : 0),
  );
}

double _monthlyRate(int interestRateBasisPoints) {
  return interestRateBasisPoints / 10000 / 12;
}

List<MoneyInstallmentScheduleEntry> _equalInstallmentSchedule({
  required int principalMinor,
  required int totalPeriods,
  required int interestRateBasisPoints,
}) {
  final rate = _monthlyRate(interestRateBasisPoints);
  if (rate <= 0) {
    final principals = _splitEven(principalMinor, totalPeriods);
    return [
      for (var index = 0; index < totalPeriods; index++)
        MoneyInstallmentScheduleEntry(
          principalMinor: principals[index],
          interestMinor: 0,
        ),
    ];
  }
  final factor = math.pow(1 + rate, totalPeriods).toDouble();
  final payment = principalMinor * rate * factor / (factor - 1);
  final entries = <MoneyInstallmentScheduleEntry>[];
  var remaining = principalMinor;
  for (var index = 0; index < totalPeriods; index++) {
    if (index == totalPeriods - 1) {
      final interest = (remaining * rate).round();
      entries.add(
        MoneyInstallmentScheduleEntry(
          principalMinor: remaining,
          interestMinor: interest,
        ),
      );
      break;
    }
    final interest = (remaining * rate).round();
    var principal = payment.round() - interest;
    if (principal < 0) {
      principal = 0;
    }
    if (principal > remaining) {
      principal = remaining;
    }
    entries.add(
      MoneyInstallmentScheduleEntry(
        principalMinor: principal,
        interestMinor: interest,
      ),
    );
    remaining -= principal;
  }
  return entries;
}

List<MoneyInstallmentScheduleEntry> _equalPrincipalSchedule({
  required int principalMinor,
  required int totalPeriods,
  required int interestRateBasisPoints,
}) {
  final rate = _monthlyRate(interestRateBasisPoints);
  final principals = _splitEven(principalMinor, totalPeriods);
  final entries = <MoneyInstallmentScheduleEntry>[];
  var remaining = principalMinor;
  for (var index = 0; index < totalPeriods; index++) {
    final principal = principals[index];
    final interest = (remaining * rate).round();
    entries.add(
      MoneyInstallmentScheduleEntry(
        principalMinor: principal,
        interestMinor: interest,
      ),
    );
    remaining -= principal;
  }
  return entries;
}
