import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';
import 'package:miji/features/life_energy/domain/work_profile.dart';

/// 书里的三个问题，顺序与 [WishlistEntry.q1Satisfaction] 等字段一一对应。
///
/// 放在 domain 而不是界面里：加进来的表单要问一遍，详情页要再看一遍，两处
/// 各写一份字符串，早晚会出现「表单问的是这句、详情显示的是那句」。
const List<String> wishlistQuestions = [
  '它会让我更满足，而不只是短暂开心？',
  '它和我现在的生活目标一致？',
  '如果我不需要上班，我还会买它？',
];

/// 想买的一件东西。
///
/// 它**不是支出**：不进流水、不进统计、不影响预算。只有用户标记「买了」并且
/// 选择记一笔时，才会落一条正常的 `money_transactions`。
@immutable
class WishlistEntry {
  const WishlistEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.targetAmountMinor,
    this.ledgerId,
    this.notes,
    this.desire = WishDesireLevel.want,
    this.storedStatus = WishlistItemStatus.waiting,
    this.cooldownUntil,
    this.q1Satisfaction,
    this.q2Aligned,
    this.q3NoJob,
    this.decidedAt,
    this.transactionId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String? ledgerId;

  final String title;
  final String? notes;

  /// 目标金额（分）。
  final int targetAmountMinor;

  final WishDesireLevel desire;

  /// 落库的状态。只可能是 `bought` / `dropped` / `waiting`；
  /// `ready` 由 [statusAt] 现算，不落库。
  final WishlistItemStatus storedStatus;

  /// 冷却截止日。为空 = 没设冷却，立刻可以决定。
  final DateTime? cooldownUntil;

  /// 书里的三个问题。null = 还没回答；三个都答「否」也照样能加进清单。
  final bool? q1Satisfaction;
  final bool? q2Aligned;
  final bool? q3NoJob;

  final DateTime? decidedAt;
  final String? transactionId;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// 当前真实状态：已买 / 已放弃 原样返回；其余看冷却期到没到。
  ///
  /// 派生而不是落库：落库就得有定时任务把「到期」写回，漏跑一次用户会永远
  /// 看到「冷却中 · 还有 1 天」。
  WishlistItemStatus statusAt(DateTime now) {
    if (storedStatus.isSettled) {
      return storedStatus;
    }
    final deadline = cooldownUntil;
    if (deadline == null || !now.isBefore(deadline)) {
      return WishlistItemStatus.ready;
    }
    return WishlistItemStatus.waiting;
  }

  /// 冷却还剩几天（向上取整）。已经到期或没设冷却时返回 0。
  int cooldownDaysLeft(DateTime now) {
    final deadline = cooldownUntil;
    if (deadline == null) {
      return 0;
    }
    final minutes = deadline.difference(now).inMinutes;
    if (minutes <= 0) {
      return 0;
    }
    return (minutes / (60 * 24)).ceil();
  }

  /// 三个问题的答案，按 [wishlistQuestions] 的顺序；null = 还没答。
  List<bool?> get questionAnswers => [q1Satisfaction, q2Aligned, q3NoJob];

  /// 三个问题答了几个（0~3）。界面只显示「已答 2/3」，不做通过率。
  int get answeredQuestionCount => [
    q1Satisfaction,
    q2Aligned,
    q3NoJob,
  ].where((answer) => answer != null).length;

  /// 这件东西值多少小时；档案没配好时返回 null。
  double? hoursFor(WorkProfile profile) => profile.hoursFor(targetAmountMinor);

  /// 这件东西值多少个工作日；档案没配好时返回 null。
  double? daysFor(WorkProfile profile) => profile.daysFor(targetAmountMinor);

  WishlistEntry copyWith({
    String? title,
    String? notes,
    bool clearNotes = false,
    int? targetAmountMinor,
    WishDesireLevel? desire,
    WishlistItemStatus? storedStatus,
    DateTime? cooldownUntil,
    bool? q1Satisfaction,
    bool? q2Aligned,
    bool? q3NoJob,
    DateTime? decidedAt,
    String? transactionId,
    bool clearTransactionId = false,
    DateTime? updatedAt,

    /// 三问的取值允许被**清空**（未答），所以编辑时要显式说「按传入值整组覆盖」，
    /// 否则 `q1Satisfaction: null` 会被 `??` 当成「没传」而保留旧答案 ——
    /// 用户点了「是 → 否 → 未答」之后，第三个答案永远存不下来。
    bool replaceAnswers = false,
  }) {
    return WishlistEntry(
      id: id,
      userId: userId,
      ledgerId: ledgerId,
      title: title ?? this.title,
      // 备注可以清空：清空后详情页那一段就该消失，而不是继续显示上一句。
      notes: clearNotes ? null : (notes ?? this.notes),
      targetAmountMinor: targetAmountMinor ?? this.targetAmountMinor,
      desire: desire ?? this.desire,
      storedStatus: storedStatus ?? this.storedStatus,
      cooldownUntil: cooldownUntil ?? this.cooldownUntil,
      q1Satisfaction: replaceAnswers
          ? q1Satisfaction
          : (q1Satisfaction ?? this.q1Satisfaction),
      q2Aligned: replaceAnswers ? q2Aligned : (q2Aligned ?? this.q2Aligned),
      q3NoJob: replaceAnswers ? q3NoJob : (q3NoJob ?? this.q3NoJob),
      decidedAt: decidedAt ?? this.decidedAt,
      transactionId: clearTransactionId
          ? null
          : (transactionId ?? this.transactionId),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
