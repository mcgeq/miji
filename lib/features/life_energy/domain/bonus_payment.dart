import 'package:flutter/foundation.dart';

/// 一笔年终奖：**按纳税年度**记，一个人一年最多一条。
///
/// 三个决定都来自税法，不是口味：
///
/// 1. **按年度而不是按月/按段**。「全年一次性奖金」按**发放年度**计税，所以
///    决定它落在哪一年的，是发钱那天所在的年度 —— 而不是它在哪一段职业里。
///    7 月跳槽、次年 1 月拿到旧公司的奖金，这笔属于「次年」，发放方还是旧公司。
///    按段记就必须猜（年初段？年末段？），猜错的表现是某一年的账多出或少掉
///    一笔六位数的钱。
/// 2. **一年一条**。一个纳税年度内，这个单独计税办法**只能用一次**；第二条
///    必须并入综合所得。与其做「多笔奖金怎么分摊税率」的半成品，不如在入口
///    就把「一年一笔」说清楚，让用户自己把同年的奖金加总后填一个数。
/// 3. **发放方只是标签**。`sourceLabel` 不参与任何算式，它存在的唯一理由是
///    让人把「星野科技 2025 年那笔」和「云图科技 2026 年那笔」分得清 ——
///    换过公司的人一眼就知道哪笔是哪笔。
@immutable
class BonusPayment {
  const BonusPayment({
    required this.id,
    required this.userId,
    required this.taxYear,
    required this.amountMinor,
    this.sourceLabel,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// `taxYear = 0` 的意思是**还没填年度**（旧数据迁移过来的）。
  ///
  /// 用 0 而不是 null 当哨兵：`taxYear` 非空才能让「一人一年一条」的唯一
  /// 索引真的管用（SQLite 的唯一索引不管 NULL，多行 null 会一起放行）。
  /// 未指定年度的记录不会进任何一年的账 —— 宁可让它显眼地挂在「未指定」里，
  /// 也不猜一个年份替用户认领。
  static const int unspecifiedYear = 0;

  final String id;
  final String userId;

  /// 纳税年度（发放年度）。0 = 未指定。
  final int taxYear;

  /// 奖金金额（分），**税前**：单独计税的除数就是这个数。
  final int amountMinor;

  /// 谁发的（公司简称）。纯标签。
  final String? sourceLabel;

  final String? note;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasYear => taxYear > 0;

  bool get hasSource {
    final label = sourceLabel?.trim();
    return label != null && label.isNotEmpty;
  }

  String get sourceOrDefault => hasSource ? sourceLabel!.trim() : '未填写发放方';

  String get yearLabel => hasYear ? '$taxYear 年度' : '未指定年度';

  BonusPayment copyWith({
    int? taxYear,
    int? amountMinor,
    String? sourceLabel,
    bool clearSourceLabel = false,
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) {
    return BonusPayment(
      id: id,
      userId: userId,
      taxYear: taxYear ?? this.taxYear,
      amountMinor: amountMinor ?? this.amountMinor,
      // `??` 会把「明确传入 null」当成「没传」，所以要显式开关。
      sourceLabel: clearSourceLabel ? null : (sourceLabel ?? this.sourceLabel),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
