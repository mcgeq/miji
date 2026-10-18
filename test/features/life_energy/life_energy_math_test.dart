import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/overtime_record.dart';
import 'package:miji/features/life_energy/domain/wishlist_entry.dart';
import 'package:miji/features/life_energy/domain/wishlist_insight.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 算式是这功能的全部——界面只是把结果排版。这里把示例档案钉住：
/// 月到手 12,000、22 天、每天 8 小时、通勤 70 分钟、工作开销 1,700。
WorkProfile _sampleProfile({
  int payAmountMinor = 1200000,
  LifeEnergyPayCycle payCycle = LifeEnergyPayCycle.month,
}) {
  return WorkProfile(
    userId: 'user-1',
    payAmountMinor: payAmountMinor,
    payCycle: payCycle,
    workDaysPerMonth: 22,
    workMinutesPerDay: 480,
    commuteMinutesPerDay: 70,
    overtimeMinutesPerMonth: 720,
    costTransportMinor: 90000,
    costMealMinor: 60000,
    costDecompressMinor: 20000,
  );
}

OvertimeRecord _record({
  String id = 'r1',
  int minutes = 660,
  OvertimeCompensation compensation = OvertimeCompensation.none,
  int payAmountMinor = 0,
  int extraCostMinor = 0,
  bool isRestDay = false,
  DateTime? workDate,
}) {
  final date = workDate ?? DateTime(2026, 10, 12);
  return OvertimeRecord(
    id: id,
    userId: 'user-1',
    workDate: date,
    minutes: minutes,
    compensation: compensation,
    payAmountMinor: payAmountMinor,
    extraCostMinor: extraCostMinor,
    isRestDay: isRestDay,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('真实时薪', () {
    test('示例档案：¥48.2/小时、1 个工作日 9.71 小时、日单价 ¥468', () {
      final profile = _sampleProfile();

      // 月工时 = 22 × (480 + 70) + 720 = 12,820 分钟 = 213.67 小时
      expect(profile.monthlyWorkHours, closeTo(213.67, 0.01));
      // 净收入 = 12,000 − 1,700 = 10,300
      expect(profile.monthlyNetMinor, closeTo(1030000, 1));
      expect(profile.hourlyWageMinor, closeTo(4820.6, 1));
      // 工作日含通勤：9.71 而不是 8
      expect(profile.dailyHours, closeTo(9.712, 0.001));
      expect(profile.dailyCostMinor, closeTo(46824, 60));
      expect(profile.isConfigured, isTrue);
    });

    test('三级台阶：名义 ¥68.2 → 含通勤 ¥56.2 → 扣开销 ¥48.2', () {
      final profile = _sampleProfile();

      // 合同工时 = 22 × 8 = 176 小时。名义时薪 = 12,000 ÷ 176。
      expect(profile.contractedHours, closeTo(176, 0.001));
      expect(profile.nominalHourlyWageMinor, closeTo(6818.2, 1));

      // 分母换成含通勤的 213.67 小时：通勤一个人吃掉 ¥12。
      expect(profile.hourlyWageBeforeCostMinor, closeTo(5616.2, 1));

      // 再减掉 1,700 开销：又少 ¥8。两个调整分开看得见。
      expect(profile.hourlyWageMinor, closeTo(4820.6, 1));
      expect(
        profile.nominalHourlyWageMinor - profile.hourlyWageMinor,
        closeTo(
          (profile.nominalHourlyWageMinor - profile.hourlyWageBeforeCostMinor) +
              (profile.hourlyWageBeforeCostMinor - profile.hourlyWageMinor),
          0.001,
        ),
      );
      // 每月通勤 25.7 小时，跟台阶第二级对得上。
      expect(profile.commuteHoursPerMonth, closeTo(25.67, 0.01));
    });

    test('没填开销时，含通勤时薪就等于真实时薪', () {
      final profile = WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
        commuteMinutesPerDay: 70,
      );

      expect(profile.monthlyWorkCostMinor, 0);
      expect(
        profile.hourlyWageBeforeCostMinor,
        closeTo(profile.hourlyWageMinor, 0.001),
      );
    });

    test('四种付薪周期折算到月应当一致', () {
      final monthly = _sampleProfile().monthlyGrossMinor;
      expect(
        _sampleProfile(
          payAmountMinor: 14400000,
          payCycle: LifeEnergyPayCycle.year,
        ).monthlyGrossMinor,
        closeTo(monthly, 1),
      );
      expect(
        _sampleProfile(
          payAmountMinor: 54545,
          payCycle: LifeEnergyPayCycle.day,
        ).monthlyGrossMinor,
        closeTo(monthly, 15),
      );
      // 时薪只乘合同工时（480 分钟），不把通勤算成有偿劳动。
      expect(
        _sampleProfile(
          payAmountMinor: 6818,
          payCycle: LifeEnergyPayCycle.hour,
        ).monthlyGrossMinor,
        closeTo(monthly, 40),
      );
    });

    test('没填金额 / 没填天数都不算配置好，换算返回 null', () {
      final empty = WorkProfile.blank('user-1');
      expect(empty.isConfigured, isFalse);
      expect(empty.hoursFor(129900), isNull);
      expect(empty.daysFor(129900), isNull);

      final noDays = WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 0,
      );
      expect(noDays.isConfigured, isFalse);
    });

    test('通勤 0 分钟时，1 个工作日就是 8 小时', () {
      final profile = WorkProfile(
        userId: 'user-1',
        payAmountMinor: 1200000,
        workDaysPerMonth: 22,
        workMinutesPerDay: 480,
      );
      expect(profile.dailyHours, closeTo(8, 0.001));
    });

    test('¥1,899 的耳机 = 39.4 小时 ≈ 4.1 个工作日', () {
      final profile = _sampleProfile();
      expect(profile.hoursFor(189900)!, closeTo(39.4, 0.1));
      expect(profile.daysFor(189900)!, closeTo(4.06, 0.02));
    });
  });

  group('收入口径（累计预扣）', () {
    test('空档案默认「全年」，输入框标签跟着周期变', () {
      expect(WorkProfile.blank('user-1').payCycle, LifeEnergyPayCycle.year);
      expect(LifeEnergyPayCycle.values.first, LifeEnergyPayCycle.year);
      expect(LifeEnergyPayCycle.year.amountLabel, '全年到手');
      expect(LifeEnergyPayCycle.month.amountLabel, '每月到手');
      expect(LifeEnergyPayCycle.day.amountLabel, '每天到手');
      expect(LifeEnergyPayCycle.hour.amountLabel, '每小时到手');
    });

    test('全年到手 ÷ 12 与直接填月，同一份收入算出同一个时薪', () {
      final annual = _sampleProfile(
        payAmountMinor: 14400000,
        payCycle: LifeEnergyPayCycle.year,
      );
      final monthly = _sampleProfile(payAmountMinor: 1200000);
      expect(annual.hourlyWageMinor, closeTo(monthly.hourlyWageMinor, 0.001));
      expect(annual.monthlyNetMinor, closeTo(monthly.monthlyNetMinor, 0.001));
      // 天数也一致 —— 换算器与想买清单都走这个数。
      expect(annual.dailyHours, closeTo(monthly.dailyHours, 0.001));
    });

    test('拿某一个月当基准会偏，且收入越高偏得越多', () {
      // 累计预扣法的实际到手（预扣率表一）：
      // 应发 20,000 / 社保 3,500 / 专项附加 3,000
      //   → 1 月 16,245、12 月 15,650、全年 190,320（月均 15,860）
      final january = _sampleProfile(payAmountMinor: 1624500);
      final december = _sampleProfile(payAmountMinor: 1565000);
      final annualized = _sampleProfile(
        payAmountMinor: 19032000,
        payCycle: LifeEnergyPayCycle.year,
      );
      expect(
        january.hourlyWageMinor / annualized.hourlyWageMinor - 1,
        closeTo(0.027, 0.005),
        reason: '用 1 月的到手会高估',
      );
      expect(
        december.hourlyWageMinor / annualized.hourlyWageMinor - 1,
        closeTo(-0.015, 0.005),
        reason: '用 12 月的到手会低估',
      );

      // 应发 35,000 / 社保 6,000 / 专项附加 4,000 → 1 月 28,400、全年 316,920
      // 收入跨的税率档更多，1 月的偏差从 2.7% 涨到 8.1%。
      final highJanuary = _sampleProfile(payAmountMinor: 2840000);
      final highAnnual = _sampleProfile(
        payAmountMinor: 31692000,
        payCycle: LifeEnergyPayCycle.year,
      );
      expect(
        highJanuary.hourlyWageMinor / highAnnual.hourlyWageMinor - 1,
        closeTo(0.081, 0.005),
      );
    });

    test('年终奖落在任何单月之外：只按工资年化会低估两成以上', () {
      // 同一份工作：只拿 12 个月工资（全年 190,320）vs 另加 3 个月年终奖
      // （并入综合所得后全年 242,520）。年终奖不在任何一个月里，按月填永远
      // 抓不到它 —— 这是「填全年」最大的价值。
      final salaryOnly = _sampleProfile(
        payAmountMinor: 19032000,
        payCycle: LifeEnergyPayCycle.year,
      );
      final withBonus = _sampleProfile(
        payAmountMinor: 24252000,
        payCycle: LifeEnergyPayCycle.year,
      );
      expect(salaryOnly.hourlyWageMinor, closeTo(6626, 40));
      expect(withBonus.hourlyWageMinor, closeTo(8663, 40));
      expect(
        salaryOnly.hourlyWageMinor / withBonus.hourlyWageMinor - 1,
        closeTo(-0.235, 0.01),
      );
    });

    test('口径始终是税后：税前算出的时薪虚高近三成', () {
      // 应发 20,000 的名义时薪 ¥85.6 vs 真实时薪 ¥66.3（月均到手 15,860）。
      // 注意两个方向的基数不同：税前比税后高 29.1%，反过来税后比税前低
      // 22.6% —— 写「高 22.6%」是错的，这里钉住的是前者的口径。
      final pretax = _sampleProfile(payAmountMinor: 2000000);
      final real = _sampleProfile(
        payAmountMinor: 19032000,
        payCycle: LifeEnergyPayCycle.year,
      );
      expect(pretax.hourlyWageMinor, closeTo(8565, 40));
      expect(real.hourlyWageMinor, closeTo(6626, 40));
      expect(
        pretax.hourlyWageMinor / real.hourlyWageMinor - 1,
        closeTo(0.291, 0.01),
      );
    });
  });

  group('本期（加班月）', () {
    test('白干一周：时薪从 ¥48.2 掉到 ¥43.5（−9.8%）', () {
      final profile = _sampleProfile();
      final period = LifeEnergyPeriod(
        profile: profile,
        records: [
          // 工作日 11 小时 + 周六 5 小时；周六要多算一趟 70 分钟通勤。
          _record(id: 'r1', minutes: 660, extraCostMinor: 26000),
          _record(
            id: 'r2',
            minutes: 300,
            isRestDay: true,
            workDate: DateTime(2026, 10, 17),
          ),
        ],
      );

      // 213.67 + 16 + 1.17 = 230.83 小时
      expect(period.countedOvertimeMinutes, 960);
      expect(period.restDayCommuteMinutes, 70);
      expect(period.totalHours, closeTo(230.83, 0.02));
      expect(period.hourlyWageMinor, closeTo(4349.4, 2));
      expect(period.wageDeltaRatio, closeTo(-0.0978, 0.002));

      // 同样的 8,420 元支出：174.7 → 193.6 小时，多花 18.9 小时。
      expect(period.hoursFor(842000), closeTo(193.6, 0.2));
      expect(period.extraHoursFor(842000), closeTo(18.9, 0.2));
    });

    test('给钱：加班费 1,807 减掉打车 260 后时薪反而上升到 ¥51.3', () {
      final profile = _sampleProfile();
      final period = LifeEnergyPeriod(
        profile: profile,
        records: [
          _record(
            id: 'r1',
            minutes: 660,
            compensation: OvertimeCompensation.paid,
            payAmountMinor: 180700,
            extraCostMinor: 26000,
          ),
          _record(
            id: 'r2',
            minutes: 300,
            compensation: OvertimeCompensation.paid,
            isRestDay: true,
            workDate: DateTime(2026, 10, 17),
          ),
        ],
      );

      expect(period.paidOvertimeMinor, 180700);
      expect(period.hourlyWageMinor, closeTo(5132, 3));
      expect(period.wageDeltaRatio, greaterThan(0));
    });

    test('调休净额为零：不进本期，连它带来的开销也不进', () {
      final profile = _sampleProfile();
      final period = LifeEnergyPeriod(
        profile: profile,
        records: [
          _record(
            id: 'r1',
            minutes: 960,
            compensation: OvertimeCompensation.timeOff,
            extraCostMinor: 26000,
          ),
        ],
      );

      expect(period.hasRecords, isTrue);
      expect(period.countedOvertimeMinutes, 0);
      expect(period.extraCostMinor, 0);
      expect(period.timeOffMinutes, 960);
      expect(period.hourlyWageMinor, closeTo(profile.hourlyWageMinor, 0.001));
      expect(period.wageDeltaRatio, closeTo(0, 1e-9));
    });

    test('叠加不是替换：本期工时 = 基线（含常规加班）+ 记录之和', () {
      final profile = _sampleProfile();
      final period = LifeEnergyPeriod(
        profile: profile,
        records: [_record(minutes: 60)],
      );

      // 基线已经含 720 分钟常规加班；再加 60 分钟，而不是把 720 换掉。
      expect(period.totalMinutes, closeTo(12820 + 60, 0.001));
    });
  });

  group('想买清单', () {
    WishlistEntry entry({
      String id = 'w1',
      int amountMinor = 189900,
      DateTime? cooldownUntil,
      WishlistItemStatus status = WishlistItemStatus.waiting,
      WishDesireLevel desire = WishDesireLevel.want,
      bool? q1,
    }) {
      return WishlistEntry(
        id: id,
        userId: 'user-1',
        title: '降噪耳机',
        targetAmountMinor: amountMinor,
        desire: desire,
        storedStatus: status,
        cooldownUntil: cooldownUntil,
        q1Satisfaction: q1,
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      );
    }

    test('冷却期没到是等待，到了就变「可以决定」', () {
      final now = DateTime(2026, 10, 18);
      final waiting = entry(cooldownUntil: DateTime(2026, 10, 21));
      expect(waiting.statusAt(now), WishlistItemStatus.waiting);
      expect(waiting.cooldownDaysLeft(now), 3);

      final ready = entry(cooldownUntil: DateTime(2026, 10, 17, 23, 59));
      expect(ready.statusAt(now), WishlistItemStatus.ready);
      expect(ready.cooldownDaysLeft(now), 0);
    });

    test('已买 / 已放弃不会被冷却期改回去', () {
      final now = DateTime(2026, 10, 18);
      final bought = entry(
        status: WishlistItemStatus.bought,
        cooldownUntil: DateTime(2026, 12, 1),
      );
      expect(bought.statusAt(now), WishlistItemStatus.bought);
      expect(bought.statusAt(DateTime(2027, 1, 1)), WishlistItemStatus.bought);
    });

    test('汇总只算还没结束的项，天数是逐项相加', () {
      final profile = _sampleProfile();
      final now = DateTime(2026, 10, 18);
      final insight = WishlistInsight.from(
        entries: [
          entry(
            id: 'a',
            amountMinor: 189900,
            cooldownUntil: DateTime(2026, 10, 21),
          ),
          entry(id: 'b', amountMinor: 129900, q1: true),
          entry(
            id: 'c',
            amountMinor: 500000,
            status: WishlistItemStatus.bought,
          ),
        ],
        profile: profile,
        now: now,
      );

      expect(insight.activeCount, 2);
      expect(insight.totalAmountMinor, 189900 + 129900);
      expect(insight.waitingCount, 1);
      expect(insight.readyCount, 1);
      expect(insight.daysKnown, isTrue);
      expect(
        insight.totalWorkdays,
        closeTo(profile.daysFor(189900)! + profile.daysFor(129900)!, 0.001),
      );
    });

    test('三问可以清空回「未答」，不会被 ?? 当成没传', () {
      final answered = entry(q1: true);
      expect(answered.answeredQuestionCount, 1);

      final cleared = answered.copyWith(
        q1Satisfaction: null,
        replaceAnswers: true,
      );
      expect(cleared.q1Satisfaction, isNull);
      expect(cleared.answeredQuestionCount, 0);

      // 不传 replaceAnswers 时保持原值（普通编辑不该把答案弄丢）。
      expect(answered.copyWith(title: 'x').q1Satisfaction, isTrue);
    });

    test('档案没配好时不显示天数（daysKnown = false）', () {
      final insight = WishlistInsight.from(
        entries: [entry()],
        profile: null,
        now: DateTime(2026, 10, 18),
      );
      expect(insight.activeCount, 1);
      expect(insight.daysKnown, isFalse);
      expect(insight.totalWorkdays, 0);
    });
  });
}
