import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/bonus_payment.dart';
import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/payroll.dart';
import 'package:miji/features/life_energy/domain/salary_segment.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 一份职业履历 = 档案（当前值）+ 段列表（历史）。
///
/// 为什么不是「段表就是全部」：`life_energy_profiles` 里已经存着一份完整档案
/// （六项开销、工时、周期），而段表只存「变过的那几项」。把两者合成一个
/// 对象再解析，比把档案拆成字段更小的改动，也不会让老库（段表为空）读不出数。
///
/// **段表为空时，一切都是档案本身** —— 老用户的行为一点不变。
@immutable
class SalaryHistory {
  SalaryHistory({
    required this.profile,
    required Iterable<SalarySegment> segments,
    Iterable<BonusPayment> bonuses = const [],
  }) : segments = List.unmodifiable(
         segments.toList()..sort((a, b) => a.start.compareTo(b.start)),
       ),
       bonuses = List.unmodifiable(bonuses.toList());

  /// 档案（当前值）。段表里没有覆盖到的项都从这里取。
  final WorkProfile profile;

  /// 按生效月**升序**。
  final List<SalarySegment> segments;

  /// 年终奖，按**纳税年度**记（一年最多一条）。与段无关 —— 见 [BonusPayment]。
  final List<BonusPayment> bonuses;

  /// 某一年的年终奖（税前，分）。没记就是 0。
  ///
  /// 只认 `taxYear == year` 的那条；未指定年度（0）的不算 —— 那笔钱确实存在，
  /// 但它属于哪一年只有用户知道。
  int bonusForYear(int year) {
    for (final bonus in bonuses) {
      if (bonus.taxYear == year) {
        return bonus.amountMinor;
      }
    }
    return 0;
  }

  BonusPayment? bonusPaymentForYear(int year) {
    for (final bonus in bonuses) {
      if (bonus.taxYear == year) {
        return bonus;
      }
    }
    return null;
  }

  /// 只有一段时不显示「薪资历史」入口：不涨薪也不跳槽的人不该看到一个
  /// 只有一行的列表。空表同理。
  bool get hasHistory => segments.length > 1;

  SalarySegment? get currentSegment => segments.isEmpty ? null : segments.last;

  /// 某个月生效的段（只看年月）。
  ///
  /// 早于第一段时返回第一段，不返回 null：没有更早的记录，把最早那段当成
  /// 「一直如此」比让整个清单空掉更有用，而空掉会让人以为数据丢了。
  SalarySegment? segmentAt(DateTime at) {
    if (segments.isEmpty) {
      return null;
    }
    SalarySegment? found;
    for (final segment in segments) {
      if (!segment.isEffectiveAt(at)) {
        break;
      }
      found = segment;
    }
    return found ?? segments.first;
  }

  /// 某个时刻的尺子。段表为空时返回档案本身。
  ///
  /// 税前口径下这里会**跑一遍那一年的累计预扣**，再把当月到手写回档案
  /// （见 [WorkProfile.withResolvedNet]）。所以「时薪取当月」这件事在段、
  /// 涨停、跳槽、清单上全部自动成立，不需要每个调用点各自传月份。
  WorkProfile profileAt(DateTime at) {
    final segment = segmentAt(at);
    final base = segment == null ? profile : _resolve(segment);
    if (!base.isGrossMode) {
      return base;
    }
    final plan = annualPayrollFor(at.year);
    return base.withResolvedNet(plan.months[at.month - 1].netMinor);
  }

  /// 某一年的 12 个月工资计划（累计预扣跑满 12 次）。
  ///
  /// 按月分别解析「这个月是哪一段」：年中涨薪时，7 月之后的累计应纳税所得额
  /// 里已经含了 1–6 月按旧工资算的部分 —— 这正是「涨薪之后到手涨幅低于税前
  /// 涨幅」的来源之一。整年用同一个月薪跑是错的（会少算已预缴的税）。
  ///
  /// 段上没存税前数字的那些月（在「直接填到手」模式下记的历史）走
  /// [PayrollMonthInput.netCalibrated]：用当时记的到手，不参与累计。
  /// 宁可那一年的累计税额偏低一点，也不凭空给历史补一个税前。
  AnnualPayroll annualPayrollFor(int year) {
    final inputs = <PayrollMonthInput>[];
    for (var month = 1; month <= 12; month++) {
      final segment = segmentAt(DateTime(year, month));
      final resolved = segment == null ? profile : _resolve(segment);
      // 每个月带上**当月那一段**的参数：年内换城市 / 换公司 / 7 月基数调整
      // 时，1–6 月必须按旧参数算 —— 否则累计应纳税所得额从 1 月就被新比例
      // 污染，预扣档位跟着一起错，全年税额对不上任何一个月。
      final config = resolved.payroll;
      if (resolved.isGrossMode) {
        inputs.add(
          PayrollMonthInput.gross(resolved.grossMonthlyMinor, config: config),
        );
      } else {
        inputs.add(
          PayrollMonthInput.netCalibrated(
            resolved.monthlyGrossMinor.round(),
            config: config,
          ),
        );
      }
    }
    return PayrollCalculator(
      // 参数上那份 config 只是兜底，每个月的 input 自己带着当月参数。
      config: profile.payroll,
      bonusMinor: bonusForYear(year),
    ).annual(year: year, inputs: inputs);
  }

  /// 不算 copyWith：`employer` 要从「档案的值」变成「段的值」，而 copyWith
  /// 的 `??` 会把「段上没填公司名」当成「没传」，于是历史段被染上当前公司名。
  WorkProfile _resolve(SalarySegment segment) {
    // 只有在「税前推算」模式下、且这一段确实存过税前，才走推算。否则用段上
    // 记的到手 —— 切换口径不该改写历史。
    final useGross = profile.isGrossMode && segment.grossAmountMinor != null;
    return WorkProfile(
      userId: profile.userId,
      employer: segment.employer,
      payAmountMinor: segment.amountMinor,
      payCycle: segment.payCycle ?? profile.payCycle,
      currencyCode: profile.currencyCode,
      compensationMode: useGross
          ? LifeEnergyCompensationMode.gross
          : LifeEnergyCompensationMode.net,
      grossMonthlyMinor: segment.grossAmountMinor ?? 0,
      // 段上冻着参数就用它 —— 这一段的到手和时薪是按**当时**的口径算的，
      // 不该被今天的比例改写。null（老数据 / 没单独填）才跟随档案。
      payroll: segment.payroll ?? profile.payroll,
      workDaysPerMonth: segment.workDaysPerMonth ?? profile.workDaysPerMonth,
      workMinutesPerDay: segment.workMinutesPerDay ?? profile.workMinutesPerDay,
      commuteMinutesPerDay:
          segment.commuteMinutesPerDay ?? profile.commuteMinutesPerDay,
      overtimeMinutesPerMonth:
          segment.overtimeMinutesPerMonth ?? profile.overtimeMinutesPerMonth,
      costTransportMinor: profile.costTransportMinor,
      costMealMinor: profile.costMealMinor,
      costClothingMinor: profile.costClothingMinor,
      costChildcareMinor: profile.costChildcareMinor,
      costDecompressMinor: profile.costDecompressMinor,
      costOtherMinor: profile.costOtherMinor,
      workCostOverrideMinor: segment.workCostMonthlyMinor,
    );
  }

  /// 第 [index] 段的最后一个月。
  ///
  /// 时薪取**该段末期**而不是起点：离开这份薪水时的状态才是「这段值多少」
  /// 的答案（起点那个月还带着上一年的预扣节奏）。
  DateTime endOf(int index, DateTime now) {
    if (index + 1 < segments.length) {
      final next = segments[index + 1];
      // DateTime(y, 0) 会正确回退到上一年 12 月，不必手写年份判断。
      return DateTime(next.effectiveYear, next.effectiveMonth - 1);
    }
    return now;
  }

  /// 历史页需要的视图，**倒序**（最近的在上）。
  List<SalarySegmentView> views(DateTime now) {
    final result = <SalarySegmentView>[];
    for (var i = segments.length - 1; i >= 0; i--) {
      final segment = segments[i];
      final end = endOf(i, now);
      final resolved = profileAt(end);
      final isCurrent = i == segments.length - 1;

      SalarySegmentView? previous;
      if (i > 0) {
        final prevSegment = segments[i - 1];
        final prevEnd = endOf(i - 1, now);
        final prevProfile = profileAt(prevEnd);
        previous = SalarySegmentView(
          segment: prevSegment,
          profile: prevProfile,
          isCurrent: false,
        );
      }

      result.add(
        SalarySegmentView(
          segment: segment,
          profile: resolved,
          isCurrent: isCurrent,
          isJobChange: _isJobChange(previous?.segment, segment),
          isParameterAdjustment: _isParameterAdjustment(
            previous,
            segment,
            resolved,
          ),
          amountChangePercent: _percent(
            previous?.profile.monthlyGrossMinor,
            resolved.monthlyGrossMinor,
          ),
          hourlyChangePercent: _percent(
            previous?.profile.hourlyWageMinor,
            resolved.hourlyWageMinor,
          ),
        ),
      );
    }
    return result;
  }

  /// 这一段是不是「钱没变，只是参数变了」（7 月基数调整、换城市后的社保口径）。
  ///
  /// 判定条件三条同时成立：前面有段、金额两列都没动、参数确实不一样。
  /// 少任何一条都不算 —— 涨薪 + 顺手改参数是涨薪，不能因为参数也变了就说
  /// 「你这次没涨」。
  static bool _isParameterAdjustment(
    SalarySegmentView? previous,
    SalarySegment segment,
    WorkProfile resolved,
  ) {
    if (previous == null || !segment.hasPayroll) {
      return false;
    }
    final before = previous.segment;
    final amountUnchanged =
        before.amountMinor == segment.amountMinor &&
        before.grossAmountMinor == segment.grossAmountMinor;
    return amountUnchanged && previous.profile.payroll != resolved.payroll;
  }

  /// 只有**相邻两段都填了公司名且不同**才算跳槽。
  ///
  /// 一段空一段有**不判**：用户补填第一条时，整段历史会从「涨薪」变成
  /// 「跳槽」，涨幅解释跟着全变——一次补填不该改写过去。
  static bool _isJobChange(SalarySegment? previous, SalarySegment current) {
    if (previous == null || !previous.hasEmployer || !current.hasEmployer) {
      return false;
    }
    return previous.employer!.trim() != current.employer!.trim();
  }

  static double? _percent(num? from, num to) {
    if (from == null || from <= 0) {
      return null;
    }
    return (to - from) / from;
  }
}

/// 历史页一行。
@immutable
class SalarySegmentView {
  const SalarySegmentView({
    required this.segment,
    required this.profile,
    required this.isCurrent,
    this.isJobChange = false,
    this.isParameterAdjustment = false,
    this.amountChangePercent,
    this.hourlyChangePercent,
  });

  final SalarySegment segment;

  /// 该段末期的尺子（时薪、日工时都从这里取）。
  final WorkProfile profile;

  final bool isCurrent;
  final bool isJobChange;

  /// 只有参数变了（社保基数调整 / 换了城市的口径），薪水本身没动。
  final bool isParameterAdjustment;

  /// 与上一段相比的涨幅（0.269 = +26.9%）。金额那项已经折算到月。
  final double? amountChangePercent;
  final double? hourlyChangePercent;

  String get employerLabel {
    final name = segment.employer?.trim();
    if (name == null || name.isEmpty) {
      return '未填写工作单位';
    }
    return name;
  }
}
