import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_history.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 档案：月到手 12,000 · 22 天 · 8 小时 · 通勤 70 分 · 常规加班 12h · 开销 1,700。
///
/// 这一组数在 P0 里就是「¥48.2 / 小时」，改动前后面都能对上。
WorkProfile _profile() => const WorkProfile(
  userId: 'user-1',
  payAmountMinor: 1200000,
  payCycle: LifeEnergyPayCycle.month,
  workDaysPerMonth: 22,
  workMinutesPerDay: 480,
  commuteMinutesPerDay: 70,
  overtimeMinutesPerMonth: 720,
  costTransportMinor: 50000,
  costMealMinor: 30000,
  costClothingMinor: 20000,
  costChildcareMinor: 40000,
  costDecompressMinor: 20000,
  costOtherMinor: 30000,
);

SalarySegment _segment({
  required String id,
  required int year,
  required int month,
  required int amountMinor,
  String? employer,
  int? commute,
  int? overtime,
  int? workCost,
}) {
  return SalarySegment(
    id: id,
    userId: 'user-1',
    employer: employer,
    effectiveYear: year,
    effectiveMonth: month,
    amountMinor: amountMinor,
    commuteMinutesPerDay: commute,
    overtimeMinutesPerMonth: overtime,
    workCostMonthlyMinor: workCost,
    createdAt: DateTime(year, month),
    updatedAt: DateTime(year, month),
  );
}

void main() {
  group('段解析', () {
    test('没有段时，任何月份都用档案本身', () {
      final history = SalaryHistory(profile: _profile(), segments: const []);
      expect(history.hasHistory, isFalse);
      expect(
        history.profileAt(DateTime(2024, 3)).hourlyWageMinor,
        closeTo(_profile().hourlyWageMinor, 0.001),
      );
    });

    test('单段：金额、公司名、条件都从段上取', () {
      final history = SalaryHistory(
        profile: _profile(),
        segments: [
          _segment(
            id: 'a',
            year: 2026,
            month: 7,
            amountMinor: 1600000,
            employer: '云图科技',
            commute: 30,
            workCost: 120000,
          ),
        ],
      );

      final resolved = history.profileAt(DateTime(2026, 10));
      expect(resolved.employer, '云图科技');
      expect(resolved.payAmountMinor, 1600000);
      expect(resolved.commuteMinutesPerDay, 30);
      // 段上只存合计，直接顶掉档案的六项之和。
      expect(resolved.monthlyWorkCostMinor, 120000);
      // 没有覆盖的项仍然继承档案。
      expect(resolved.workMinutesPerDay, 480);
      expect(resolved.workDaysPerMonth, 22);
    });

    test('早于第一段的月份归到第一段，而不是返回 null', () {
      final history = SalaryHistory(
        profile: _profile(),
        segments: [
          _segment(id: 'a', year: 2025, month: 1, amountMinor: 1600000),
          _segment(id: 'b', year: 2026, month: 7, amountMinor: 2000000),
        ],
      );

      final resolved = history.profileAt(DateTime(2020, 5));
      expect(resolved.payAmountMinor, 1600000);
    });

    test('跨年边界：次年 1 月用新段，12 月用旧段', () {
      final history = SalaryHistory(
        profile: _profile(),
        segments: [
          _segment(id: 'a', year: 2025, month: 1, amountMinor: 1600000),
          _segment(id: 'b', year: 2026, month: 1, amountMinor: 2500000),
        ],
      );

      expect(history.profileAt(DateTime(2025, 12)).payAmountMinor, 1600000);
      expect(history.profileAt(DateTime(2026, 1)).payAmountMinor, 2500000);
      expect(history.profileAt(DateTime(2026, 1, 1)).payAmountMinor, 2500000);
    });

    test('段上的 company 为空时，不会染上档案的当前公司名', () {
      final history = SalaryHistory(
        profile: _profile().copyWith(employer: '云图科技'),
        segments: [
          _segment(id: 'a', year: 2025, month: 1, amountMinor: 1600000),
        ],
      );

      expect(history.profileAt(DateTime(2025, 6)).employer, isNull);
    });
  });

  group('涨薪与跳槽', () {
    SalaryHistory build({String? firstEmployer, String? secondEmployer}) {
      return SalaryHistory(
        profile: _profile(),
        segments: [
          _segment(
            id: 'a',
            year: 2025,
            month: 1,
            amountMinor: 1600000,
            employer: firstEmployer,
            commute: 30,
            workCost: 120000,
          ),
          _segment(
            id: 'b',
            year: 2026,
            month: 7,
            amountMinor: 2000000,
            employer: secondEmployer,
            commute: 70,
            workCost: 170000,
          ),
        ],
      );
    }

    test('两段都填了公司名且不同，才算跳槽', () {
      expect(
        build(
          firstEmployer: '星野科技',
          secondEmployer: '云图科技',
        ).views(DateTime(2026, 10)).first.isJobChange,
        isTrue,
      );
      expect(
        build(
          firstEmployer: '云图科技',
          secondEmployer: '云图科技',
        ).views(DateTime(2026, 10)).first.isJobChange,
        isFalse,
      );
    });

    test('一段空一段有时不判跳槽：补填第一条不该改写过去', () {
      expect(
        build(
          secondEmployer: '云图科技',
        ).views(DateTime(2026, 10)).first.isJobChange,
        isFalse,
      );
      expect(
        build(
          firstEmployer: '星野科技',
        ).views(DateTime(2026, 10)).first.isJobChange,
        isFalse,
      );
    });

    test('每一段用自己那段的条件，末期的时薪才对', () {
      final history = build(firstEmployer: '星野科技', secondEmployer: '云图科技');
      final views = history.views(DateTime(2026, 10));

      // 现段：20,000 − 1,700，213.67 小时 → 85.6 元（8,564 分）
      expect(views.first.profile.hourlyWageMinor, closeTo(8564.7, 5));

      // 旧段：16,000 − 1,200，199 小时（通勤 30 分）→ 74.4 元（7,437 分）
      expect(views.last.profile.hourlyWageMinor, closeTo(7437.2, 5));
    });

    test('如果拿现在的通勤倒推旧段，会得出更低的数（这正是要防的错）', () {
      final history = build(firstEmployer: '星野科技', secondEmployer: '云图科技');
      final oldSegmentProfile = history.views(DateTime(2026, 10)).last.profile;
      final wrongProfile = _profile().copyWith(
        payAmountMinor: 1600000,
        costTransportMinor: 120000,
        costMealMinor: 0,
        costClothingMinor: 0,
        costChildcareMinor: 0,
        costDecompressMinor: 0,
        costOtherMinor: 0,
      );

      // 7,437（按当时 30 分钟）vs 6,927（今天 70 分钟倒推）—— 差 7%。
      expect(oldSegmentProfile.hourlyWageMinor, greaterThan(7000));
      expect(wrongProfile.hourlyWageMinor, lessThan(7000));
    });

    test('金额涨幅折算到月，时薪涨幅单独算', () {
      final views = build(
        firstEmployer: '星野科技',
        secondEmployer: '云图科技',
      ).views(DateTime(2026, 10));

      // 16,000 → 20,000 = +25%
      expect(views.first.amountChangePercent, closeTo(0.25, 0.0001));
      // 74.37 → 85.60 = +15.1%
      expect(views.first.hourlyChangePercent, closeTo(0.151, 0.002));
      // 最早一段没有可比对象
      expect(views.last.amountChangePercent, isNull);
      expect(views.last.hourlyChangePercent, isNull);
    });

    test('没有公司名时用「未填写工作单位」兜底', () {
      final views = build().views(DateTime(2026, 10));
      expect(views.first.employerLabel, '未填写工作单位');
    });
  });

  group('税前推算', () {
    /// 税前 2 万 · 北京口径 · 专项扣除 2,000（设计稿第五节那组数）。
    WorkProfile grossProfile() => _profile().copyWith(
      compensationMode: LifeEnergyCompensationMode.gross,
      grossMonthlyMinor: 2000000,
      payroll: SocialInsuranceConfig.defaults.copyWith(
        specialDeductionMinor: 200000,
      ),
    );

    SalarySegment grossSegment({
      required String id,
      required int year,
      required int month,
      required int netMinor,
      int? grossMinor,
      String? employer,
      int? commute,
      int? workCost,
    }) {
      return SalarySegment(
        id: id,
        userId: 'user-1',
        employer: employer,
        effectiveYear: year,
        effectiveMonth: month,
        amountMinor: netMinor,
        grossAmountMinor: grossMinor,
        commuteMinutesPerDay: commute,
        workCostMonthlyMinor: workCost,
        createdAt: DateTime(year, month),
        updatedAt: DateTime(year, month),
      );
    }

    test('段上存了税前：到手由累计预扣算出，不再用段上那个数', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [
          grossSegment(
            id: 'a',
            year: 2026,
            month: 1,
            // 段上的到手不管写多少都会被推算结果覆盖。
            netMinor: 9999999,
            grossMinor: 2000000,
          ),
        ],
      );

      expect(history.profileAt(DateTime(2026, 1)).payAmountMinor, 1524500);
      expect(history.profileAt(DateTime(2026, 5)).payAmountMinor, 1479000);
      expect(history.profileAt(DateTime(2026, 10)).payAmountMinor, 1465000);
    });

    test('段上没有税前（net 时代记的旧段）：用段上记的到手，不参与累计', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [
          grossSegment(
            id: 'a',
            year: 2025,
            month: 1,
            netMinor: 1200000,
            grossMinor: null,
          ),
          grossSegment(
            id: 'b',
            year: 2026,
            month: 1,
            netMinor: 0,
            grossMinor: 2000000,
          ),
        ],
      );

      // 切到税前不应该改写历史：2025 年那段没有税前数字，就只能用它记的到手。
      expect(history.profileAt(DateTime(2025, 6)).payAmountMinor, 1200000);
      expect(
        history.profileAt(DateTime(2025, 6)).isGrossMode,
        isFalse,
        reason: '没有税前可算，这一段仍然是「直接填到手」',
      );
    });

    test('年中涨薪：累计从 1 月起算，不会按新工资的档位一次性补齐', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [
          grossSegment(
            id: 'a',
            year: 2026,
            month: 1,
            netMinor: 0,
            grossMinor: 2000000,
          ),
          grossSegment(
            id: 'b',
            year: 2026,
            month: 7,
            netMinor: 0,
            grossMinor: 4000000,
          ),
        ],
      );

      final july = history.profileAt(DateTime(2026, 7)).payAmountMinor;
      // 整年都按 4 万的话，7 月会落在 20% 档，税 5,200，到手 25,800。
      final wholeYearAt40k = PayrollCalculator(config: grossProfile().payroll)
          .annual(
            year: 2026,
            inputs: List.generate(12, (_) => PayrollMonthInput.gross(4000000)),
          );

      expect(july, greaterThan(wholeYearAt40k.month(7)!.netMinor));
      // 4 万已经超过北京基数上限 35,811，个人五险一金按封顶数扣（不是 9,000）。
      expect(
        history.profileAt(DateTime(2026, 7)).payroll.baseFor(4000000),
        3581100,
      );
      // 4,000,000 − 805,748（封顶基数 × 22.5%）− 249,425（本月补的税）
      expect(july, 4000000 - 805748 - 249425);
    });

    test('税前口径下历史页拿得到税前月薪', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [
          grossSegment(
            id: 'a',
            year: 2026,
            month: 7,
            netMinor: 1793750,
            grossMinor: 2500000,
            employer: '云图科技',
          ),
        ],
      );

      final view = history.views(DateTime(2026, 10)).first;
      expect(view.profile.grossMonthlyMinor, 2500000);
      // 到手是算出来的，不是段上那个占位值。
      expect(view.profile.payAmountMinor, isNot(1793750));
    });
  });

  group('换城市 / 参数调整', () {
    /// 税前 2 万 · 档案默认（北京）口径 · 专项扣除 2,000。
    WorkProfile grossProfile() => _profile().copyWith(
      compensationMode: LifeEnergyCompensationMode.gross,
      grossMonthlyMinor: 2000000,
      payroll: SocialInsuranceConfig.defaults.copyWith(
        specialDeductionMinor: 200000,
      ),
    );

    /// 深圳口径：基数下限 3,523、公积金 5%、个人合计 15.3%。
    /// 与北京的 22.5% 差 7.2 个点 —— 拿今天的比例重算去年，时薪会凭空涨一截。
    SocialInsuranceConfig shenzhen() => SocialInsuranceConfig.defaults.copyWith(
      baseFloorMinor: 352300,
      baseCeilingMinor: 2642100,
      unemploymentBp: 30,
      housingFundBp: 500,
      medicalErBp: 600,
      unemploymentErBp: 70,
      injuryErBp: 14,
      housingFundErBp: 500,
    );

    test('段上冻了参数：改档案的比例不会改写这一段的到手', () {
      final segment = SalarySegment(
        id: 'a',
        userId: 'user-1',
        effectiveYear: 2025,
        effectiveMonth: 1,
        amountMinor: 0,
        grossAmountMinor: 2000000,
        payroll: shenzhen(),
        createdAt: DateTime(2025, 1),
        updatedAt: DateTime(2025, 1),
      );

      SalaryHistory build(SocialInsuranceConfig profileConfig) => SalaryHistory(
        profile: grossProfile().copyWith(payroll: profileConfig),
        segments: [segment],
      );

      // 用户现在人在北京：把档案改回北京口径（公积金 12%）。
      final afterMove = build(SocialInsuranceConfig.defaults);
      // 没动档案的那份。
      final untouched = build(shenzhen());

      expect(
        afterMove.profileAt(DateTime(2025, 6)).payAmountMinor,
        untouched.profileAt(DateTime(2025, 6)).payAmountMinor,
        reason: '2025 年那一段按当时的深圳口径算，不该被今天的档案改写',
      );
      // 确实是深圳那套：20,000 × 15.3% = 3,060。
      final january = afterMove.profileAt(DateTime(2025, 1));
      expect(january.payroll.individualRateBp, 1530);
      expect(
        afterMove.annualPayrollFor(2025).month(1)!.individual.totalMinor,
        306000,
      );
    });

    test('年中换城市：1–6 月按旧参数、7 月起按新参数，累计不串味', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [
          SalarySegment(
            id: 'a',
            userId: 'user-1',
            effectiveYear: 2026,
            effectiveMonth: 1,
            amountMinor: 0,
            grossAmountMinor: 2000000,
            createdAt: DateTime(2026, 1),
            updatedAt: DateTime(2026, 1),
          ),
          SalarySegment(
            id: 'b',
            userId: 'user-1',
            effectiveYear: 2026,
            effectiveMonth: 7,
            amountMinor: 0,
            grossAmountMinor: 2000000,
            payroll: shenzhen(),
            createdAt: DateTime(2026, 7),
            updatedAt: DateTime(2026, 7),
          ),
        ],
      );

      final plan = history.annualPayrollFor(2026);
      expect(plan.month(1)!.individual.totalMinor, 450000, reason: '北京 22.5%');
      expect(plan.month(6)!.individual.totalMinor, 450000);
      expect(plan.month(7)!.individual.totalMinor, 306000, reason: '深圳 15.3%');

      // 整年只按北京那份跑（旧行为）会得出另一个数：换城市那天起扣得少了，
      // 累计应纳税所得额也跟着变，全年个税不是一个数能代表的。
      final wholeYearBeijing = PayrollCalculator(config: grossProfile().payroll)
          .annual(
            year: 2026,
            inputs: List.generate(12, (_) => PayrollMonthInput.gross(2000000)),
          );
      expect(plan.taxMinor, isNot(wholeYearBeijing.taxMinor));
      expect(plan.netMinor, greaterThan(wholeYearBeijing.netMinor));
    });

    test('金额没变、只有参数变：标成「参数调整」而不是涨薪', () {
      SalarySegment segment(
        String id,
        int month, {
        int gross = 2000000,
        SocialInsuranceConfig? payroll,
      }) => SalarySegment(
        id: id,
        userId: 'user-1',
        effectiveYear: 2026,
        effectiveMonth: month,
        amountMinor: 0,
        grossAmountMinor: gross,
        payroll: payroll,
        createdAt: DateTime(2026, month),
        updatedAt: DateTime(2026, month),
      );

      final paramOnly = SalaryHistory(
        profile: grossProfile(),
        segments: [
          segment('a', 1),
          segment('b', 7, payroll: shenzhen()),
        ],
      );
      expect(
        paramOnly.views(DateTime(2026, 10)).first.isParameterAdjustment,
        isTrue,
      );

      // 金额也涨了：那是涨薪，不是参数调整。
      final raised = SalaryHistory(
        profile: grossProfile(),
        segments: [
          segment('a', 1),
          segment('b', 7, gross: 2500000, payroll: shenzhen()),
        ],
      );
      expect(
        raised.views(DateTime(2026, 10)).first.isParameterAdjustment,
        isFalse,
      );
    });
  });

  group('年终奖按年度', () {
    WorkProfile grossProfile() => _profile().copyWith(
      compensationMode: LifeEnergyCompensationMode.gross,
      grossMonthlyMinor: 2000000,
      payroll: SocialInsuranceConfig.defaults.copyWith(
        specialDeductionMinor: 200000,
      ),
    );

    BonusPayment bonus(int year, int amountMinor, {String? source}) =>
        BonusPayment(
          id: 'bonus-$year',
          userId: 'user-1',
          taxYear: year,
          amountMinor: amountMinor,
          sourceLabel: source,
          createdAt: DateTime(year),
          updatedAt: DateTime(year),
        );

    SalarySegment single() => SalarySegment(
      id: 'a',
      userId: 'user-1',
      effectiveYear: 2024,
      effectiveMonth: 1,
      amountMinor: 0,
      grossAmountMinor: 2000000,
      createdAt: DateTime(2024, 1),
      updatedAt: DateTime(2024, 1),
    );

    test('每一年只认自己那一条：2025 的奖进 2025 的账，不进 2026', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [single()],
        bonuses: [
          bonus(2025, 6000000, source: '星野科技'),
          bonus(2026, 4000000, source: '云图科技'),
        ],
      );

      expect(history.annualPayrollFor(2025).bonusMinor, 6000000);
      expect(history.annualPayrollFor(2026).bonusMinor, 4000000);
      expect(history.annualPayrollFor(2027).bonusMinor, 0);
    });

    test('单独计税只作用于那一年，不摊进月度累计预扣', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [single()],
        bonuses: [bonus(2026, 3600000)],
      );

      final withBonus = history.annualPayrollFor(2026);
      final withoutBonus = SalaryHistory(
        profile: grossProfile(),
        segments: [single()],
      ).annualPayrollFor(2026);

      // 12 个月的税一分不差：奖金走单独计税，不进累计。
      expect(withBonus.taxMinor, withoutBonus.taxMinor);
      // 36,000 ÷ 12 = 3,000 → 3% → 税 1,080。
      expect(withBonus.bonusTaxMinor, 108000);
      expect(withBonus.bonusNetMinor, 3492000);
      expect(
        withBonus.totalNetMinor - withoutBonus.totalNetMinor,
        3492000,
        reason: '全年到手只多出奖金净额',
      );
    });

    test('未指定年度（0）的记录不进任何一年的账', () {
      final history = SalaryHistory(
        profile: grossProfile(),
        segments: [single()],
        bonuses: [bonus(BonusPayment.unspecifiedYear, 3600000)],
      );

      expect(history.bonusForYear(2026), 0);
      expect(history.bonusForYear(2025), 0);
      expect(history.annualPayrollFor(2026).bonusMinor, 0);
    });
  });
}
