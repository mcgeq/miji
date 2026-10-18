import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 设计稿第五节那一组数字：税前 20,000 · 北京 · 个人 22.5% · 专项扣除 2,000。
///
/// 这些数不是随便挑的：1 月到手 15,245、5 月 14,790、6 月起 14,650、年税
/// 7,680、年到手 178,320（74.3%）。它们出现在设计稿、文档和界面文案里，
/// 改任何一处算式都必须保证这里仍然对得上。
///
/// 注意示例**带 2,000 专项附加扣除**：20,000 − 5,000 − 4,500 − 2,000 = 8,500
/// 才是每月累计应纳税所得额。不带扣除算出来是 10,500，整条链都会偏。
final _sample = SocialInsuranceConfig.defaults.copyWith(
  specialDeductionMinor: 200000,
);

/// 不带专项附加扣除的同一份档案（用来对比「扣除到底省了多少税」）。
const _plain = SocialInsuranceConfig.defaults;

AnnualPayroll _plan({
  int grossMinor = 2000000,
  SocialInsuranceConfig? config,
  int bonusMinor = 0,
}) {
  return PayrollCalculator(
    config: config ?? _sample,
    bonusMinor: bonusMinor,
  ).annual(
    year: 2026,
    inputs: List.generate(12, (_) => PayrollMonthInput.gross(grossMinor)),
  );
}

void main() {
  group('累计预扣', () {
    test('税前 2 万：1–4 月 15,245 · 5 月 14,790 · 6 月起 14,650', () {
      final plan = _plan();

      for (final month in [1, 2, 3, 4]) {
        expect(plan.month(month)!.netMinor, 1524500, reason: '$month 月');
      }
      expect(plan.month(5)!.netMinor, 1479000);
      for (final month in [6, 7, 8, 9, 10, 11, 12]) {
        expect(plan.month(month)!.netMinor, 1465000, reason: '$month 月');
      }
    });

    test('税率逐月爬档：前四个月 3%，5 月跨进 10%', () {
      final plan = _plan();

      expect(plan.month(1)!.taxMinor, 25500);
      expect(plan.month(4)!.taxMinor, 25500);
      // 跨档那个月要把前面少扣的补回来，所以 5 月不是 850。
      expect(plan.month(5)!.taxMinor, 71000);
      expect(plan.month(6)!.taxMinor, 85000);
      expect(plan.month(12)!.taxMinor, 85000);
      expect(plan.month(1)!.rateBp, 300);
      expect(plan.month(5)!.rateBp, 1000);
    });

    test('年税 7,680 = 12 月累计，不是「每月 850 × 12」', () {
      final plan = _plan();
      // 850 × 12 = 10,200；累计预扣法下全年只交 7,680。这两个数的差就是
      // 「全年 ÷12」会系统性偏低的原因。
      expect(plan.taxMinor, 768000);
      expect(plan.month(12)!.cumulativeTaxableMinor, 10200000);
    });

    test('年到手 178,320，占应发 74.3%', () {
      final plan = _plan();
      expect(plan.grossMinor, 24000000);
      expect(plan.netMinor, 17832000);
      expect(plan.netRatio, closeTo(0.743, 0.0005));
    });

    test('个人五险一金 54,000（公积金 28,800 · 养老 19,200 · 其余 6,000）', () {
      final plan = _plan();
      expect(plan.individual.totalMinor, 5400000);
      expect(plan.month(1)!.individual.totalMinor, 450000);
      expect(plan.month(1)!.cumulativeTaxableMinor, 850000);
      expect(plan.individual.housingFundMinor, 2880000);
      expect(plan.individual.pensionMinor, 1920000);
      // 医疗 4,800 + 失业 1,200。失业是 0.5% × 2 万 × 12 = 1,200，不是 600。
      expect(plan.individual.medicalMinor, 480000);
      expect(plan.individual.unemploymentMinor, 120000);
      expect(plan.individual.othersMinor, 600000);
    });

    test('单位另付 92,160，用工成本 332,160', () {
      final plan = _plan();
      expect(plan.employerTotalMinor, 9216000);
      expect(plan.employmentCostMinor, 33216000);
      // 公积金双边 57,600 都是你的钱，但不进时薪。
      expect(plan.housingFundBothSidesMinor, 5760000);
    });

    test('低薪月：累计应纳税所得额可以是负数，税额为 0 且不退税', () {
      final plan = _plan(grossMinor: 300000);
      expect(plan.taxMinor, 0);
      expect(plan.month(12)!.cumulativeTaxableMinor, lessThan(0));
      // 到手 = 应发 − 个人五险一金（基数被下限抬高了，所以扣得比 22.5% 多）
      expect(plan.month(1)!.netMinor, lessThan(300000));
    });
  });

  group('缴费基数', () {
    test('auto 模式夹在北京 6,821 ~ 35,811 之间', () {
      expect(_sample.baseFor(500000), 682100);
      expect(_sample.baseFor(8000000), 3581100);
      expect(_sample.baseFor(2000000), 2000000);
    });

    test('manual 模式用填的那个数，不再 clamp', () {
      final config = _sample.copyWith(
        baseMode: SocialBaseMode.manual,
        baseOverrideMinor: 2000000,
      );
      expect(config.baseFor(500000), 2000000);
    });

    test('上下限填反了不抛异常（手填时可能写错）', () {
      final config = _sample.copyWith(
        baseFloorMinor: 9000000,
        baseCeilingMinor: 1000000,
      );
      expect(config.baseFor(5000000), 5000000);
    });

    test('月薪低于下限时，扣得比 22.5% 更多 —— 基数不是月薪', () {
      final plan = _plan(grossMinor: 500000);
      // 5,000 × 22.5% 是 1,125，但按 6,821 的基数要扣 1,535。
      expect(plan.month(1)!.individual.totalMinor, greaterThan(112500));
    });
  });

  group('参数快照（职业段用）', () {
    test('JSON 往返一点不差', () {
      final config = _sample.copyWith(
        baseMode: SocialBaseMode.manual,
        baseOverrideMinor: 1800000,
        baseFloorMinor: 352300,
        baseCeilingMinor: 2642100,
        pensionBp: 800,
        medicalBp: 200,
        unemploymentBp: 30,
        housingFundBp: 500,
        pensionErBp: 1500,
        medicalErBp: 600,
        unemploymentErBp: 70,
        injuryErBp: 14,
        housingFundErBp: 500,
        medicalFixedMinor: 300,
        specialDeductionMinor: 200000,
      );

      expect(SocialInsuranceConfig.fromJson(config.toJson()), config);
    });

    test('缺键 / 类型不对 / 多出来的键都不炸，缺的走默认值', () {
      final parsed = SocialInsuranceConfig.fromJson({
        'housingFundBp': 500,
        'baseFloorMinor': '352300', // 类型不对 → 默认值，不是崩
        'someFutureKey': true,
      });

      expect(parsed.housingFundBp, 500);
      expect(
        parsed.baseFloorMinor,
        SocialInsuranceConfig.defaults.baseFloorMinor,
      );
      expect(parsed.pensionBp, SocialInsuranceConfig.defaults.pensionBp);
    });
  });

  group('年终奖', () {
    test('单独计税：÷12 找档，再用全额算税', () {
      // 36,000 ÷ 12 = 3,000 → 3% → 1,080
      expect(bonusTaxMinorFor(3600000), 108000);
      // 36,001 ÷ 12 = 3,000.08 → 10% → 36,001 × 10% − 210 = 3,390.10
      // 多拿 1 元，多交 2,310。这个盲区只说明，不替用户规划。
      expect(bonusTaxMinorFor(3600100), closeTo(339000, 20));
    });

    test('年终奖不进 12 个月的累计预扣', () {
      final without = _plan();
      final withBonus = _plan(bonusMinor: 3600000);

      expect(without.taxMinor, 768000);
      expect(withBonus.taxMinor, 768000, reason: '月薪那 12 个月的税不该变');
      expect(withBonus.bonusTaxMinor, 108000);
      expect(withBonus.totalNetMinor, without.netMinor + 3600000 - 108000);
    });
  });

  group('专项附加扣除', () {
    test('减的是计税基数：每月 2,000 在 10% 档一年只省 2,400 元税', () {
      // 不带扣除：每月应纳税所得额 10,500，全年累计 126,000 → 12,600 − 2,520。
      final without = _plan(config: _plain);
      final withDeduction = _plan();

      expect(without.taxMinor, 1008000);
      final saved = without.taxMinor - withDeduction.taxMinor;
      // 12 × 2,000 × 10% = 2,400。不是 2,000 × 12 = 24,000 —— 写成后者
      // 会让人以为能退一大笔。
      expect(saved, 240000);
    });
  });

  group('到手 → 时薪', () {
    test('10 月：14,650 − 1,700 开销 ÷ 213.67 小时 = ¥60.6', () {
      final plan = _plan();
      final profile = WorkProfile(
        userId: 'user-1',
        // 税前口径下这个字段是算出来的当月到手，写回去之后时薪算式不用改。
        payAmountMinor: plan.month(10)!.netMinor,
        payCycle: LifeEnergyPayCycle.month,
        compensationMode: LifeEnergyCompensationMode.gross,
        grossMonthlyMinor: 2000000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 50000,
        costMealMinor: 30000,
        costClothingMinor: 20000,
        costChildcareMinor: 40000,
        costDecompressMinor: 20000,
        costOtherMinor: 10000,
      );

      // 六项合计 1,700 元，与设计稿同口径。
      expect(profile.monthlyWorkCostMinor, 170000);
      expect(profile.monthlyWorkHours, closeTo(213.667, 0.01));
      expect(profile.dailyHours, closeTo(9.71, 0.01));
      expect(profile.hourlyWageMinor, closeTo(6060.9, 1));
    });

    test('1 月的时薪比年末高 4.6%，全年平均那行要能解释它', () {
      final plan = _plan();
      final profile = WorkProfile(
        userId: 'user-1',
        payAmountMinor: plan.month(1)!.netMinor,
        payCycle: LifeEnergyPayCycle.month,
        compensationMode: LifeEnergyCompensationMode.gross,
        grossMonthlyMinor: 2000000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
        overtimeMinutesPerMonth: 720,
        costTransportMinor: 170000,
      );

      final january = profile.hourlyWageMinor;
      final steady = profile
          .withResolvedNet(plan.month(12)!.netMinor)
          .hourlyWageMinor;

      // 时薪的差（4.6%）比到手的差（3.9%）更大：固定的 1,700 元开销被摊在
      // 同一个分母上，分子差 595 元会放大成 278 元的时薪差。
      expect(january / steady, closeTo(1.046, 0.002));
      // 「全年平均」用 12 个月的净额平均算，落在 1 月和年末之间。
      expect(
        profile.averageHourlyWageMinor,
        lessThan(january),
        reason: '全年平均必须低于 1 月，否则参照就没有意义',
      );
      expect(profile.averageHourlyWageMinor, greaterThan(steady));
    });
  });
}
