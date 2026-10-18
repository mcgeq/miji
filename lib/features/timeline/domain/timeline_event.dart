import 'package:flutter/foundation.dart';

/// 一条事件属于哪一类时间。
///
/// 这不是「样式标签」，而是**语义**：事实不能改、承诺会变、预测可能不成立、
/// 容器是背景。界面按它决定外形，统计按它决定是否计数。
enum TimelineNature {
  /// 已经发生、不可再改语义（流水、打卡记录、完成的待办、经期记录）。
  fact,

  /// 还没发生、但确定会发生（待办日期、周期账单、分期待还、账单提醒）。
  commitment,

  /// 统计推断，可能不成立（下次经期、易孕窗、PMS）。
  prediction,

  /// 区间背景（预算周期、薪水段），不作为一个「事件行」出现。
  container;

  bool get isFact => this == TimelineNature.fact;
  bool get isPrediction => this == TimelineNature.prediction;
}

/// 事件属于哪个模块。配色与跳转目标都按它来。
enum TimelineModule {
  money('记账'),
  health('健康'),
  action('行动'),
  lifeEnergy('时薪');

  const TimelineModule(this.label);

  final String label;
}

/// 时间精度。
///
/// 日粒度的事件**不许**编一个时刻显示：打卡和经期只有「哪天」，写成 09:00
/// 是把精度伪装出来的，用户会拿它跟真实时刻对账。
enum TimelinePrecision {
  day,
  minute;

  bool get isTimed => this == TimelinePrecision.minute;
}

/// 需要强调的程度。`attention` 只给「需要你处理」的：逾期、临近、超限。
enum TimelineEmphasis { normal, attention }

/// 点击去哪。
@immutable
class TimelineTarget {
  const TimelineTarget({
    required this.route,
    this.label,
    this.askRuleScope = false,
  });

  /// 目标路由（含参数）。
  final String route;

  /// 动作文案（「看流水」「改规则」），给无障碍与提示用。
  final String? label;

  /// 来自重复规则：点之前先问「改这一次 / 改整条规则」。
  final bool askRuleScope;
}

/// 时间线上的一行。
@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.occurredOn,
    required this.module,
    required this.nature,
    required this.kind,
    required this.title,
    this.subtitle,
    this.at,
    this.precision = TimelinePrecision.day,
    this.amountMinor,
    this.currencyCode,
    this.emphasis = TimelineEmphasis.normal,
    this.ruleId,
    this.target,
    this.sensitive = false,
    this.count,
  });

  /// 稳定身份：`module:table:id`。同一件事不能因为被两个窗口查到就出现两次。
  final String id;

  /// 归属哪一天（UTC date-key，与项目里其它日粒度字段同一套约定）。
  final DateTime occurredOn;

  final TimelineModule module;
  final TimelineNature nature;

  /// 细分类别：`transaction` / `taskDue` / `planReminder` / `installmentDue` /
  /// `cyclePredicted` / `salaryChange` …
  final String kind;

  final String title;
  final String? subtitle;

  /// 仅 `precision == minute` 时有值。
  final DateTime? at;

  final TimelinePrecision precision;

  /// 财务类事件的金额（分）。显示前必须过 `MoneyPrivacy`。
  final int? amountMinor;
  final String? currencyCode;

  final TimelineEmphasis emphasis;

  /// 承诺类事件来自哪条规则；有值时点击要先问「改这一次 / 改规则」。
  final String? ruleId;

  final TimelineTarget? target;

  /// 需要二次验证才显示细节（经期、金额）。
  final bool sensitive;

  /// 聚合行背后的条数（例如「打卡 4 次」→ 4）。
  ///
  /// 回顾视图要按天汇总这些数字；从 title 里解析「4」是在给未来的自己挖坑。
  final int? count;

  /// 桶键：只按年月日，不看时刻。
  DateTime get dayKey =>
      DateTime.utc(occurredOn.year, occurredOn.month, occurredOn.day);

  bool get isTimed => precision.isTimed && at != null;
}

/// 一个查询窗口。**不提供「全部」**：时间线只回答「这段时间里有什么」，
/// 全历史对「要面对什么」没有帮助，还会把查询拖成全表扫描。
@immutable
class TimelineWindow {
  TimelineWindow({required DateTime start, required DateTime end})
    : assert(!end.isBefore(start), '窗口的结束不能早于开始'),
      start = _dayKey(start),
      end = _dayKey(end);

  /// 含。
  final DateTime start;

  /// 含（按天）。
  final DateTime end;

  /// 窗口内的每一天（升序）。
  List<DateTime> get days {
    final result = <DateTime>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      result.add(cursor);
      cursor = DateTime.utc(cursor.year, cursor.month, cursor.day + 1);
    }
    return result;
  }

  int get dayCount => days.length;

  bool contains(DateTime day) {
    final key = DateTime.utc(day.year, day.month, day.day);
    return !key.isBefore(start) && !key.isAfter(end);
  }

  static DateTime _dayKey(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// 以 [anchor] 所在周（周一起）为窗口。
  factory TimelineWindow.weekOf(DateTime anchor) {
    final day = _dayKey(anchor);
    final monday = DateTime.utc(
      day.year,
      day.month,
      day.day - (day.weekday - 1),
    );
    return TimelineWindow(
      start: monday,
      end: DateTime.utc(monday.year, monday.month, monday.day + 6),
    );
  }

  /// 以 [anchor] 所在自然月为窗口。
  factory TimelineWindow.monthOf(DateTime anchor) {
    final day = _dayKey(anchor);
    return TimelineWindow(
      start: DateTime.utc(day.year, day.month, 1),
      // 下个月 0 日 = 本月最后一天。
      end: DateTime.utc(day.year, day.month + 1, 0),
    );
  }

  factory TimelineWindow.dayOf(DateTime anchor) {
    final day = _dayKey(anchor);
    return TimelineWindow(start: day, end: day);
  }
}
