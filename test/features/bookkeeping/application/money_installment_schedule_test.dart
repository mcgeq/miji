import 'package:flutter_test/flutter_test.dart';
import 'package:miji/features/bookkeeping/application/money_installment_schedule.dart';
import 'package:miji/features/bookkeeping/domain/money_installment_entity.dart';

void main() {
  int totalPrincipal(List<MoneyInstallmentScheduleEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.principalMinor);
  int totalInterest(List<MoneyInstallmentScheduleEntry> entries) =>
      entries.fold(0, (sum, entry) => sum + entry.interestMinor);

  group('flat（等额平摊）', () {
    test('本金与总利息平均分摊，余数分配到前几期', () {
      final entries = buildInstallmentSchedule(
        principalMinor: 100000,
        totalPeriods: 3,
        calcMethod: MoneyInstallmentCalcMethod.flat,
        totalInterestMinor: 3000,
      );

      expect(entries.length, 3);
      expect(entries.map((e) => e.principalMinor).toList(), [
        33334,
        33333,
        33333,
      ]);
      expect(entries.map((e) => e.interestMinor).toList(), [1000, 1000, 1000]);
      expect(totalPrincipal(entries), 100000);
      expect(totalInterest(entries), 3000);
    });

    test('本金之和严格等于本金', () {
      final entries = buildInstallmentSchedule(
        principalMinor: 100000,
        totalPeriods: 7,
        calcMethod: MoneyInstallmentCalcMethod.flat,
      );
      expect(totalPrincipal(entries), 100000);
    });
  });

  group('equalInstallment（等额本息）', () {
    test('零利率时退化为本金均摊', () {
      final entries = buildInstallmentSchedule(
        principalMinor: 120000,
        totalPeriods: 12,
        calcMethod: MoneyInstallmentCalcMethod.equalInstallment,
        interestRateBasisPoints: 0,
      );
      expect(entries.every((e) => e.interestMinor == 0), isTrue);
      expect(totalPrincipal(entries), 120000);
    });

    test('有息时每期还款额相同，本金之和守恒', () {
      final entries = buildInstallmentSchedule(
        principalMinor: 120000,
        totalPeriods: 12,
        calcMethod: MoneyInstallmentCalcMethod.equalInstallment,
        interestRateBasisPoints: 1200,
      );

      expect(entries.length, 12);
      expect(totalPrincipal(entries), 120000);
      expect(totalInterest(entries), greaterThan(0));
      // 前 n-1 期金额相同（最后一期吸收舍入差）。
      final firstAmounts = entries.take(11).map((e) => e.amountMinor).toSet();
      expect(firstAmounts.length, 1);
      // 利息逐期递减（余额在减少）。
      expect(
        entries.first.interestMinor,
        greaterThan(entries[5].interestMinor),
      );
    });
  });

  group('equalPrincipal（等额本金）', () {
    test('本金均摊、利息逐期递减，本金之和守恒', () {
      final entries = buildInstallmentSchedule(
        principalMinor: 120000,
        totalPeriods: 12,
        calcMethod: MoneyInstallmentCalcMethod.equalPrincipal,
        interestRateBasisPoints: 1200,
      );

      expect(entries.length, 12);
      expect(entries.every((e) => e.principalMinor == 10000), isTrue);
      expect(totalPrincipal(entries), 120000);
      expect(
        entries.first.interestMinor,
        greaterThan(entries.last.interestMinor),
      );
      expect(entries.last.interestMinor, greaterThanOrEqualTo(0));
      // 每期金额逐期递减。
      for (var i = 1; i < entries.length; i++) {
        expect(
          entries[i].amountMinor,
          lessThanOrEqualTo(entries[i - 1].amountMinor),
        );
      }
    });
  });

  test('非法输入返回空列表', () {
    expect(
      buildInstallmentSchedule(
        principalMinor: 0,
        totalPeriods: 12,
        calcMethod: MoneyInstallmentCalcMethod.flat,
      ),
      isEmpty,
    );
  });
}
