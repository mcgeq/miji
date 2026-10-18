import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 一条加班记录（临时加班 / 连续一周加班里的一天）。
@immutable
class OvertimeRecord {
  const OvertimeRecord({
    required this.id,
    required this.userId,
    required this.workDate,
    required this.minutes,
    this.ledgerId,
    this.compensation = OvertimeCompensation.paid,
    this.payAmountMinor = 0,
    this.extraCostMinor = 0,
    this.isRestDay = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? ledgerId;

  final DateTime workDate;
  final int minutes;
  final OvertimeCompensation compensation;

  /// 实际拿到的加班费（分）。不按倍率推算「应得」，只记实得。
  final int payAmountMinor;

  /// 这次加班多花的钱（打车回家、宵夜）。
  final int extraCostMinor;

  /// 休息日加班：要多算一趟往返通勤。
  final bool isRestDay;

  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// 调休的净额为零：多上了 16 小时，之后也少上 16 小时，不该动本期时薪。
  ///
  /// 所以调休记录原样保留（月底未休完要提示），但**整条不进本期聚合**，
  /// 连它带来的额外开销也不进 —— 那笔钱属于「已经花了」，混进本期会让
  /// 调休看起来像白干。
  bool get countsInPeriod => compensation != OvertimeCompensation.timeOff;

  OvertimeRecord copyWith({
    DateTime? workDate,
    int? minutes,
    OvertimeCompensation? compensation,
    int? payAmountMinor,
    int? extraCostMinor,
    bool? isRestDay,
    String? note,
    DateTime? updatedAt,
  }) {
    return OvertimeRecord(
      id: id,
      userId: userId,
      ledgerId: ledgerId,
      workDate: workDate ?? this.workDate,
      minutes: minutes ?? this.minutes,
      compensation: compensation ?? this.compensation,
      payAmountMinor: payAmountMinor ?? this.payAmountMinor,
      extraCostMinor: extraCostMinor ?? this.extraCostMinor,
      isRestDay: isRestDay ?? this.isRestDay,
      note: note ?? this.note,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 「本期」视图：基线 + 本月加班记录聚合出来的时薪。
///
/// 两条口径分界，整个功能最容易做错的地方就在这里：
/// 1. **单品换算恒用基线**（`profile.hoursFor`）——尺子的刻度不能天天变。
///    按本期算，加班月里所有东西会一起涨价，用户先怀疑功能坏了。
/// 2. **「本月卖出 / 本月花掉」必须同用本期**——这两个数是同一个分数的上下一半，
///    混口径算出来的比例是假的，而且没人看得出错在哪。
///
/// 聚合是「**叠加**」不是「替换」：本期工时 = 基线 + 记录之和。若改成用记录
/// 替换基线里的常规加班，用户漏记一次就会把时薪**算高** —— 宁可算低一档。
@immutable
class LifeEnergyPeriod {
  const LifeEnergyPeriod({required this.profile, required this.records});

  final WorkProfile profile;
  final List<OvertimeRecord> records;

  bool get hasRecords => records.isNotEmpty;

  Iterable<OvertimeRecord> get _counted =>
      records.where((record) => record.countsInPeriod);

  /// 计入本期的加班分钟（不含调休）。
  int get countedOvertimeMinutes =>
      _counted.fold(0, (sum, record) => sum + record.minutes);

  /// 调休分钟（只用于提示「有 16 小时调休没休」）。
  int get timeOffMinutes => records
      .where((record) => !record.countsInPeriod)
      .fold(0, (sum, record) => sum + record.minutes);

  /// 休息日加班补的那几趟通勤。
  int get restDayCommuteMinutes =>
      _counted.where((record) => record.isRestDay).length *
      profile.commuteMinutesPerDay;

  int get paidOvertimeMinor => _counted
      .where((record) => record.compensation == OvertimeCompensation.paid)
      .fold(0, (sum, record) => sum + record.payAmountMinor);

  int get extraCostMinor =>
      _counted.fold(0, (sum, record) => sum + record.extraCostMinor);

  /// 本期卖出的小时数 = 基线（工作 + 通勤 + 常规加班）+ 临时加班 + 休息日通勤。
  double get totalMinutes =>
      profile.monthlyWorkMinutes +
      countedOvertimeMinutes +
      restDayCommuteMinutes;

  double get totalHours => totalMinutes / 60;

  /// 本期净收入。白干的加班只会让分母变大（时薪下降），给钱的同时抬分子。
  double get netMinor =>
      profile.monthlyNetMinor + paidOvertimeMinor - extraCostMinor;

  double get hourlyWageMinor => totalHours <= 0 ? 0 : netMinor / totalHours;

  double get baselineHourlyWageMinor => profile.hourlyWageMinor;

  /// 相对基线的涨跌幅，-1 表示归零。
  double get wageDeltaRatio => baselineHourlyWageMinor <= 0
      ? 0
      : hourlyWageMinor / baselineHourlyWageMinor - 1;

  double hoursFor(int amountMinor) =>
      hourlyWageMinor <= 0 ? 0 : amountMinor / hourlyWageMinor;

  /// 同样的支出，因为本期时薪变化而**多花**的小时数（可能为负）。
  double extraHoursFor(int amountMinor) {
    final baselineHours = profile.hoursFor(amountMinor);
    if (baselineHours == null) {
      return 0;
    }
    return hoursFor(amountMinor) - baselineHours;
  }
}
