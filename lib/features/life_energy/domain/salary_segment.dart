import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';

/// 一段职业经历：从某个月起、在哪家公司、拿多少钱、什么工作条件。
///
/// 段与段首尾相接，**只存起点**（`effectiveYear/Month`）：区间 = 相邻两条之间。
/// 多存一个 `end` 就有两份真相，编辑中间那段时要么批量改邻居、要么留下空洞。
///
/// 除 `employer` 和 `amountMinor` 外，其余字段都是**可空覆盖**：null 表示
/// 「继承档案」「那段时间和现在一样」。只有真正变过的那几项才写值。
@immutable
class SalarySegment {
  const SalarySegment({
    required this.id,
    required this.userId,
    required this.effectiveYear,
    required this.effectiveMonth,
    required this.amountMinor,
    this.grossAmountMinor,
    this.employer,
    this.payCycle,
    this.workDaysPerMonth,
    this.workMinutesPerDay,
    this.commuteMinutesPerDay,
    this.overtimeMinutesPerMonth,
    this.workCostMonthlyMinor,
    this.payroll,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;

  /// 工作单位（公司简称）。空 = 没填，「涨薪还是跳槽」不猜。
  final String? employer;

  final int effectiveYear;
  final int effectiveMonth;

  /// 到手（分）。口径跟随 [payCycle]，**恒为到手** —— [grossAmountMinor]
  /// 那列才存税前，两列各管一件事，切换口径不会互相改写。
  final int amountMinor;

  /// 税前月薪（分）。只在使用「税前推算」时写入；null = 这一段是在「直接填
  /// 到手」模式下记的，没有税前数字。
  ///
  /// 为什么不是「切换模式时把 [amountMinor] 重新解释一遍」：那样做会让
  /// 「之前的保持不变」失效 —— 用户在 net 模式下记的 20,000 到手，切到 gross
  /// 之后会被当成 20,000 税前，算出 14,650，整段历史一夜之间变差。
  final int? grossAmountMinor;

  final LifeEnergyPayCycle? payCycle;
  final int? workDaysPerMonth;
  final int? workMinutesPerDay;
  final int? commuteMinutesPerDay;
  final int? overtimeMinutesPerMonth;

  /// 工作开销**月合计**覆盖（分）。历史段不存六项细目。
  final int? workCostMonthlyMinor;

  /// 这一段的五险一金参数**快照**（含专项附加扣除）。null = 跟随档案。
  ///
  /// 为什么必须有它：参数不是常数。换城市（北京 ⟷ 深圳，基数下限与公积金
  /// 比例全换）、换公司（公积金比例由单位在区间内定）、每年 7 月基数调整，
  /// 都会在年中变一次。而历史段的到手和时薪是靠参数算出来的 —— 只存一份
  /// 档案参数，用户改一次城市，去年那 12 个月的时薪就会凭空舭高一截。
  ///
  /// 什么时候写值：新建一段时，把**被合上的那一段**的参数冻下来（见
  /// `LifeEnergyRepository.createSalarySegment`）；当前段保持 null，跟着档案
  /// 实时变 —— 还在用的东西不该被冻。
  final SocialInsuranceConfig? payroll;

  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 生效月的第一天。日一律取 1：段比的是「哪个月」，带具体日期会让
  /// 「7 月生效」在 7 月 1 日之前被当成还没生效。
  DateTime get start => DateTime(effectiveYear, effectiveMonth);

  /// 这个月是否已经落到本段（只看年月）。
  bool isEffectiveAt(DateTime at) =>
      !start.isAfter(DateTime(at.year, at.month));

  bool get hasEmployer => employer != null && employer!.trim().isNotEmpty;

  /// 这一段是否带了「工作条件」的覆盖。历史页用它决定要不要显示
  /// 「通勤 / 开销变了」那行小字。
  bool get hasConditionOverride =>
      workDaysPerMonth != null ||
      workMinutesPerDay != null ||
      commuteMinutesPerDay != null ||
      overtimeMinutesPerMonth != null ||
      workCostMonthlyMinor != null;

  /// 这一段是否自己带了五险一金参数（否则跟随档案）。
  bool get hasPayroll => payroll != null;

  SalarySegment copyWith({
    String? employer,
    bool clearEmployer = false,
    int? effectiveYear,
    int? effectiveMonth,
    int? amountMinor,
    int? grossAmountMinor,
    bool clearGrossAmount = false,
    LifeEnergyPayCycle? payCycle,
    int? workDaysPerMonth,
    int? workMinutesPerDay,
    int? commuteMinutesPerDay,
    int? overtimeMinutesPerMonth,
    int? workCostMonthlyMinor,
    SocialInsuranceConfig? payroll,
    bool clearPayroll = false,
    String? note,
    DateTime? updatedAt,
  }) {
    return SalarySegment(
      id: id,
      userId: userId,
      // `??` 会把「明确传入 null」当成「没传」，所以要一个显式开关。
      employer: clearEmployer ? null : (employer ?? this.employer),
      effectiveYear: effectiveYear ?? this.effectiveYear,
      effectiveMonth: effectiveMonth ?? this.effectiveMonth,
      amountMinor: amountMinor ?? this.amountMinor,
      grossAmountMinor: clearGrossAmount
          ? null
          : (grossAmountMinor ?? this.grossAmountMinor),
      payCycle: payCycle ?? this.payCycle,
      workDaysPerMonth: workDaysPerMonth ?? this.workDaysPerMonth,
      workMinutesPerDay: workMinutesPerDay ?? this.workMinutesPerDay,
      commuteMinutesPerDay: commuteMinutesPerDay ?? this.commuteMinutesPerDay,
      overtimeMinutesPerMonth:
          overtimeMinutesPerMonth ?? this.overtimeMinutesPerMonth,
      workCostMonthlyMinor: workCostMonthlyMinor ?? this.workCostMonthlyMinor,
      payroll: clearPayroll ? null : (payroll ?? this.payroll),
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
