import 'package:miji/features/bookkeeping/domain/money_budget_entity.dart';

/// 预算「花得快慢」的状态。
enum MoneyBudgetPaceStatus {
  /// 周期已结束（含今天之后没有剩余天数）。
  ended,

  /// 已超支。
  overspent,

  /// 周期最后一天。
  lastDay,

  /// 正常节奏。
  onTrack,
}

/// 预算剩余额度按天摊开后的结果：「还剩 N 天，日均可用 ¥X」。
///
/// 卡片原本只给「剩余 ¥464」，用户还得自己除以剩余天数才知道今天能花多少。
/// 抽出来是因为预算卡和统计页的预算执行卡都要显示同一句话，
/// 两边各写一份迟早会算出两个不同的数。
class MoneyBudgetPace {
  const MoneyBudgetPace._({
    required this.daysLeft,
    required this.dailyAvailableMinor,
    required this.overspentMinor,
    required this.status,
  });

  /// 剩余天数（含今天）：0 表示今天是周期最后一天，负数表示已结束。
  final int daysLeft;

  /// 剩余额度按剩余天数摊开的日均可用额；超支或周期结束时为 0。
  final int dailyAvailableMinor;

  /// 超出预算的金额（未超支为 0）。
  final int overspentMinor;

  final MoneyBudgetPaceStatus status;

  bool get isOverspent => status == MoneyBudgetPaceStatus.overspent;

  bool get isEnded => status == MoneyBudgetPaceStatus.ended;

  bool get isLastDay => status == MoneyBudgetPaceStatus.lastDay;

  /// 计算 [budget] 在 [now] 时刻的节奏；不适用时返回 null。
  ///
  /// 不适用的情况：收入目标（「日均可用」没有意义）、已完成（收入达标）、
  /// 周期已结束。周期结束仍返回对象，是为了让调用方能显示「已结束」而不是
  /// 整行消失——用户需要知道这个周期已经封账。
  static MoneyBudgetPace? of(MoneyBudgetEntity budget, DateTime now) {
    if (budget.isIncomeTarget || budget.isCompleted) {
      return null;
    }
    final today = DateTime(now.year, now.month, now.day);
    final end = budget.periodEnd.toLocal();
    final lastDay = DateTime(end.year, end.month, end.day);
    // +1：今天也算一天，今天剩下的额度今天就还能花。
    final daysLeft = lastDay.difference(today).inDays;

    if (budget.isOverspent) {
      return MoneyBudgetPace._(
        daysLeft: daysLeft < 0 ? 0 : daysLeft,
        dailyAvailableMinor: 0,
        overspentMinor: -budget.remainingAmountMinor,
        status: MoneyBudgetPaceStatus.overspent,
      );
    }
    if (daysLeft < 0) {
      return MoneyBudgetPace._(
        daysLeft: 0,
        dailyAvailableMinor: 0,
        overspentMinor: 0,
        status: MoneyBudgetPaceStatus.ended,
      );
    }
    if (daysLeft == 0) {
      return MoneyBudgetPace._(
        daysLeft: 0,
        dailyAvailableMinor: budget.remainingAmountMinor,
        overspentMinor: 0,
        status: MoneyBudgetPaceStatus.lastDay,
      );
    }
    return MoneyBudgetPace._(
      daysLeft: daysLeft,
      dailyAvailableMinor: budget.remainingAmountMinor ~/ daysLeft,
      overspentMinor: 0,
      status: MoneyBudgetPaceStatus.onTrack,
    );
  }
}
