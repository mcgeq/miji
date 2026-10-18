import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';

/// 收入与工时（页面标题）：算真实时薪需要的全部输入 + 所有派生量。
///
/// 为什么派生量不放数据库：`realHourlyWage` 是这功能唯一的尺子，任何一项输入
/// 变了它就得跟着变。落库就要维护「什么时候重算」，而漏算一次的表现是换算
/// 结果莫名其妙（用户改完档案，清单上的天数还是旧的）。这里一律现算。
@immutable
class WorkProfile {
  const WorkProfile({
    required this.userId,
    required this.payAmountMinor,
    this.employer,
    this.payCycle = LifeEnergyPayCycle.month,
    this.currencyCode = 'CNY',
    this.compensationMode = LifeEnergyCompensationMode.net,
    this.grossMonthlyMinor = 0,
    this.payroll = SocialInsuranceConfig.defaults,
    this.workDaysPerMonth = 22,
    this.workMinutesPerDay = 480,
    this.commuteMinutesPerDay = 0,
    this.overtimeMinutesPerMonth = 0,
    this.costTransportMinor = 0,
    this.costMealMinor = 0,
    this.costClothingMinor = 0,
    this.costChildcareMinor = 0,
    this.costDecompressMinor = 0,
    this.costOtherMinor = 0,
    this.workCostOverrideMinor,
  });

  /// 第一次进档案页时的空档案：只有默认的 22 天 / 8 小时，金额为 0。
  ///
  /// **不预填任何时薪**：给一个「全国平均 ¥50/小时」会让用户看到一套很专业的
  /// 假数字，然后拿它做决定 —— 空着并且说清为什么空着，比错着好。
  ///
  /// 周期默认「全年」而不是「按月」：月到手受累计预扣影响逐月变化，拿某一个月
  /// 当基准会系统性偏（见 [payAmountMinor]）。
  factory WorkProfile.blank(String userId, {String currencyCode = 'CNY'}) {
    return WorkProfile(
      userId: userId,
      payAmountMinor: 0,
      currencyCode: currencyCode,
      payCycle: LifeEnergyPayCycle.year,
    );
  }

  final String userId;

  /// 当前工作单位（公司简称）。**不影响任何算式**，只用来区分「同公司涨薪」
  /// 和「跳槽」——这两件事在金额上常常看不出差别，在时薪上差一半。
  ///
  /// 不落 `life_energy_profiles` 表：公司名属于「哪一段」，真相在
  /// `salary_segments`。这里只是解析当段之后带出来的投影。
  final String? employer;

  /// 每个付薪周期**实际到手**（税后）的钱。
  ///
  /// 为什么坚持税后：税前是「名义上的钱」，从来不进口袋。应发 2 万、社保公积金
  /// 3,500 的人，税前口径算出的时薪比真实值高 29.1% —— 相当于把「公司付的」
  /// 当成「我拿到的」，这功能的全部意义就没了。
  ///
  /// 为什么默认按全年：个税是累计预扣的，同一个应发金额在一年内的到手先高后低。
  /// 填 1 月会偏高（应发 3.5 万时偏高 8.1%），填 12 月会偏低（5.7%），而年终奖
  /// 干脆不在任何一个月里 —— 只按工资月均算会低估 23.5%。全年 ÷ 12 三个问题
  /// 一起解决，且这个数不用每个月改。
  final int payAmountMinor;

  final LifeEnergyPayCycle payCycle;
  final String currencyCode;

  /// 收入口径。`net` 时 [payAmountMinor] 是用户填的到手；`gross` 时主输入
  /// 是 [grossMonthlyMinor]，[payAmountMinor] 变成「当月推算出来的到手」。
  ///
  /// 两套**不混用**：切换模式不会去换算另一个数。net → gross 时税前是空的，
  /// 因为反推税前是多解的（社保基数封顶后，税前差 1,000 到手可能只差 600）。
  final LifeEnergyCompensationMode compensationMode;

  bool get isGrossMode => compensationMode == LifeEnergyCompensationMode.gross;

  /// 税前月薪（分）。只在 `gross` 模式下当输入。
  final int grossMonthlyMinor;

  /// 五险一金 / 专项附加扣除参数。只在 `gross` 模式下参与算式。
  final SocialInsuranceConfig payroll;

  /// 每月工作天数（默认 22）。
  final int workDaysPerMonth;

  /// 每天合同工作分钟（不含通勤、不含加班）。
  final int workMinutesPerDay;

  /// 每个工作日往返通勤分钟。
  final int commuteMinutesPerDay;

  /// **常规**加班分钟（典型月份），不是本月实际。
  final int overtimeMinutesPerMonth;

  /// 工作开销六项（分）：为了上班才多花的部分。
  final int costTransportMinor;
  final int costMealMinor;
  final int costClothingMinor;
  final int costChildcareMinor;
  final int costDecompressMinor;
  final int costOtherMinor;

  /// 工作开销的**合计覆盖**（分）。非空时直接顶掉六项之和。
  ///
  /// 给职业段用：历史段只存一个合计，不存三年前的通勤费明细。档案本身恒为
  /// null（六项才是真相），所以这个字段不会被写进 `life_energy_profiles`。
  final int? workCostOverrideMinor;

  /// 折算到月的**到手**收入（分，可能带小数）。
  ///
  /// 年 → /12；日 → ×工作天数；时 → ×工作天数 × 每天合同小时。日 / 时两种
  /// 只乘**合同**工时，不把通勤算进收入 —— 通勤是成本，不是有偿劳动。
  ///
  /// 名字里的 `Gross` 指「扣工作开销之前」，不是「税前」—— 口径全程到手。
  double get monthlyGrossMinor => switch (payCycle) {
    LifeEnergyPayCycle.month => payAmountMinor.toDouble(),
    LifeEnergyPayCycle.year => payAmountMinor / 12,
    LifeEnergyPayCycle.day => payAmountMinor * workDaysPerMonth.toDouble(),
    LifeEnergyPayCycle.hour =>
      payAmountMinor * workDaysPerMonth * (workMinutesPerDay / 60),
  };

  /// 把「这个月推算出来的到手」写回 [payAmountMinor]，并把周期钉成「按月」。
  ///
  /// 为什么不直接给时薪加一个月的参数：`monthlyNetMinor → hourlyWageMinor`
  /// 这条链下游还有六个使用点（面板、清单、换算器、历史页…），全改成带月份
  /// 会把签名污染到每一处。写回来之后它们看到的仍是一个普通的「按月到手」
  /// 档案 —— 一行都不用改。
  ///
  /// `compensationMode` 与 `grossMonthlyMinor` 仍然保留：界面靠它知道自己是
  /// 税前口径（吸底条写「10 月到手」、档案页多出三组字段）。
  WorkProfile withResolvedNet(int netMinor) {
    return copyWith(
      payAmountMinor: netMinor < 0 ? 0 : netMinor,
      payCycle: LifeEnergyPayCycle.month,
    );
  }

  /// 按**当前这份档案**跑 12 个月累计预扣（忽略薪资段）。
  ///
  /// 只给表单里的实时预览用：改一个字段就要立刻看到「10 月到手变成多少」。
  /// 历史段的差异由 `SalaryHistory` 接管，那才是展示口径。
  /// [bonusMinor] 由调用方从**年度**那一份年终奖里取（见 `BonusPayment`）：
  /// 它不属于档案，属于某一年。
  AnnualPayroll payrollPreview({int year = 2000, int bonusMinor = 0}) {
    return PayrollCalculator(config: payroll, bonusMinor: bonusMinor).annual(
      year: year,
      inputs: List.generate(
        12,
        (_) => PayrollMonthInput.gross(grossMonthlyMinor),
      ),
    );
  }

  int get monthlyWorkCostMinor =>
      workCostOverrideMinor ??
      costTransportMinor +
          costMealMinor +
          costClothingMinor +
          costChildcareMinor +
          costDecompressMinor +
          costOtherMinor;

  /// 每月净收入（分，可能带小数）= 到手 − 工作开销。
  double get monthlyNetMinor => monthlyGrossMinor - monthlyWorkCostMinor;

  /// 每月卖出去的分钟数 = 工作 + 通勤 + 常规加班。
  double get monthlyWorkMinutes =>
      (workDaysPerMonth * (workMinutesPerDay + commuteMinutesPerDay) +
              overtimeMinutesPerMonth)
          .toDouble();

  double get monthlyWorkHours => monthlyWorkMinutes / 60;

  /// 真实时薪（**分/小时**，可能带小数）。
  ///
  /// 这是全书的核心：到手扣掉「为了上班额外花的钱」，再除以「为了上班真正
  /// 花掉的时间（含通勤）」。
  double get hourlyWageMinor =>
      monthlyWorkHours <= 0 ? 0 : monthlyNetMinor / monthlyWorkHours;

  /// 合同工时（小时/月）：每月工作天数 × 每天合同工时，**不含通勤、不含加班**。
  double get contractedHours => workDaysPerMonth * workMinutesPerDay / 60;

  /// 名义时薪（分/小时）= 到手 ÷ 合同工时。
  ///
  /// 「工资条上那个数」：拿它跟真实时薪对比，才能看出通勤和时间把时薪吃掉了
  /// 多少。用合同工时算，不用实际工时 —— 一换分母它就不是名义时薪了。
  double get nominalHourlyWageMinor =>
      contractedHours <= 0 ? 0 : monthlyGrossMinor / contractedHours;

  /// 只把时间算进去、还没扣开销的时薪（分/小时）= 到手 ÷ 实际工时。
  ///
  /// 名义 → 含通勤 → 真实 这条台阶的中间那一级：它把两个调整拆开了 ——
  /// **通勤撑大分母**、**开销减小分子**。合成一个数就看不出是哪一项在动。
  double get hourlyWageBeforeCostMinor =>
      monthlyWorkHours <= 0 ? 0 : monthlyGrossMinor / monthlyWorkHours;

  /// 每月通勤小时数（往返 × 工作天数）。和上面的台阶配套显示用。
  double get commuteHoursPerMonth =>
      workDaysPerMonth * commuteMinutesPerDay / 60;

  /// 全年 12 个月时薪的平均（分/小时）。
  ///
  /// 只用于「全年平均 ¥61.6」这类**参照**，时薪本身永远取当月。它存在的唯一
  /// 理由是防止把预扣节奏当成涨薪：1 月的税还没爬满档，时薪会比年末高 4.6%，
  /// 不给参照用户会以为自己涨薪了，而下个月它又会掉回去。
  double get averageHourlyWageMinor {
    if (monthlyWorkHours <= 0) {
      return 0;
    }
    final averageNet = payrollPreview().averageMonthlyNetMinor;
    return (averageNet - monthlyWorkCostMinor) / monthlyWorkHours;
  }

  /// 1 个工作日的时长（小时）。示例：480 + 70 + 32.7 分钟 = 9.71 小时。
  double get dailyHours =>
      workDaysPerMonth <= 0 ? 0 : monthlyWorkHours / workDaysPerMonth;

  /// 1 个工作日值多少钱（分）。
  double get dailyCostMinor => hourlyWageMinor * dailyHours;

  /// 档案是否足以给出有意义的换算。
  ///
  /// 三个条件缺一不可：有金额、有天数、算出正的时薪。缺任何一项就**什么都不
  /// 显示**，而不是显示 0 或「约 0 天」。
  bool get isConfigured =>
      payAmountMinor > 0 &&
      workDaysPerMonth > 0 &&
      workMinutesPerDay > 0 &&
      hourlyWageMinor > 0;

  /// 一个金额等于多少小时；档案没配好时返回 null。
  double? hoursFor(int amountMinor) {
    if (!isConfigured || hourlyWageMinor <= 0) {
      return null;
    }
    return amountMinor / hourlyWageMinor;
  }

  /// 一个金额等于多少个工作日；档案没配好时返回 null。
  double? daysFor(int amountMinor) {
    final hours = hoursFor(amountMinor);
    if (hours == null || dailyHours <= 0) {
      return null;
    }
    return hours / dailyHours;
  }

  WorkProfile copyWith({
    int? payAmountMinor,
    String? employer,
    bool clearEmployer = false,
    LifeEnergyPayCycle? payCycle,
    String? currencyCode,
    LifeEnergyCompensationMode? compensationMode,
    int? grossMonthlyMinor,
    SocialInsuranceConfig? payroll,
    int? workDaysPerMonth,
    int? workMinutesPerDay,
    int? commuteMinutesPerDay,
    int? overtimeMinutesPerMonth,
    int? costTransportMinor,
    int? costMealMinor,
    int? costClothingMinor,
    int? costChildcareMinor,
    int? costDecompressMinor,
    int? costOtherMinor,
    int? workCostOverrideMinor,
    bool clearWorkCostOverride = false,
  }) {
    return WorkProfile(
      userId: userId,
      payAmountMinor: payAmountMinor ?? this.payAmountMinor,
      employer: clearEmployer ? null : (employer ?? this.employer),
      payCycle: payCycle ?? this.payCycle,
      currencyCode: currencyCode ?? this.currencyCode,
      compensationMode: compensationMode ?? this.compensationMode,
      grossMonthlyMinor: grossMonthlyMinor ?? this.grossMonthlyMinor,
      payroll: payroll ?? this.payroll,
      workDaysPerMonth: workDaysPerMonth ?? this.workDaysPerMonth,
      workMinutesPerDay: workMinutesPerDay ?? this.workMinutesPerDay,
      commuteMinutesPerDay: commuteMinutesPerDay ?? this.commuteMinutesPerDay,
      overtimeMinutesPerMonth:
          overtimeMinutesPerMonth ?? this.overtimeMinutesPerMonth,
      costTransportMinor: costTransportMinor ?? this.costTransportMinor,
      costMealMinor: costMealMinor ?? this.costMealMinor,
      costClothingMinor: costClothingMinor ?? this.costClothingMinor,
      costChildcareMinor: costChildcareMinor ?? this.costChildcareMinor,
      costDecompressMinor: costDecompressMinor ?? this.costDecompressMinor,
      costOtherMinor: costOtherMinor ?? this.costOtherMinor,
      workCostOverrideMinor: clearWorkCostOverride
          ? null
          : (workCostOverrideMinor ?? this.workCostOverrideMinor),
    );
  }
}
