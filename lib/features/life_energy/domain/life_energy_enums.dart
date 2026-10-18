/// 时薪功能的枚举与数据库字符串的互转。
///
/// 落库一律存字符串（`month` / `paid` / `waiting` …）而不是序号：序号在加一个
/// 枚举值时会让旧数据全部错位，而字符串不认识时还能退到默认档。
library;

/// 付薪周期。四种输入统一折算到「月」，因为下游所有算式都是月口径。
///
/// **「全年」排第一，也是默认档。** 工资薪金的个税走累计预扣法（预扣率表一）：
/// 年初累计应纳税所得额小、压在 3% 档上，跨档之后逐月变少 —— 应发 2 万的人
/// 1 月和 12 月到手差 595 元（约 3.8%），应发 3.5 万的差 3,400 元（约 12%）。
/// 年终奖更是落在任何单月之外。只有「全年 ÷ 12」是稳定值，而且**不是估算**：
/// 全年的个税总额本来就确定，年化得到的就是精确的月均值。
enum LifeEnergyPayCycle {
  year('year', '全年'),
  month('month', '按月'),
  day('day', '按日'),
  hour('hour', '按时');

  const LifeEnergyPayCycle(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// 金额输入框的标签，跟着周期变。
  ///
  /// 只写「到手」不行：填全年时用户会以为自己填的是月，填完一看时薪只有
  /// 四分之一，然后以为算错了。
  String get amountLabel => switch (this) {
    LifeEnergyPayCycle.year => '全年到手',
    LifeEnergyPayCycle.month => '每月到手',
    LifeEnergyPayCycle.day => '每天到手',
    LifeEnergyPayCycle.hour => '每小时到手',
  };

  static LifeEnergyPayCycle fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return LifeEnergyPayCycle.month;
  }
}

/// 收入口径：**直接填到手** 还是 **税前推算**。
///
/// 默认 `net`。两种模式并存是因为它们服务不同的人：net 适合「对不上工资条」
/// 的人（只要一个数就行），gross 适合「只记得合同上写的数」的人 —— 后者正是
/// 大多数，因为他们从来没在别处看到过「到手」这个数。
///
/// **两套不混用**：模式决定「金额输入框里那个数是什么」，切换模式不会去
/// 换算另一个数（换算就会假装两个数是等价的，而它们不是）。
enum LifeEnergyCompensationMode {
  net('net', '直接填到手'),
  gross('gross', '税前推算');

  const LifeEnergyCompensationMode(this.dbValue, this.label);

  final String dbValue;
  final String label;

  /// 输入金额那一项的标签。
  String get amountLabel => switch (this) {
    LifeEnergyCompensationMode.net => '到手金额',
    LifeEnergyCompensationMode.gross => '税前月薪',
  };

  static LifeEnergyCompensationMode fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return LifeEnergyCompensationMode.net;
  }
}

/// 社保缴费基数怎么定。
///
/// `auto` = 跟随税前月薪再夹到上下限；`manual` = 用用户填的那个数。
/// 必须能手动改：社保按**上年度**月平均工资核定，月薪从 2 万涨到 3 万，当年
/// 7 月之前大概率还按 2 万缴。
enum SocialBaseMode {
  auto('auto', '跟随税前'),
  manual('manual', '手填');

  const SocialBaseMode(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static SocialBaseMode fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return SocialBaseMode.auto;
  }
}

/// 「有多想要」三档。
///
/// 刻意不给五星：星级会变成自我评分游戏，三档足够表达相对强度，也不占屏幕。
enum WishDesireLevel {
  want('want', '想要'),
  strong('strong', '很想要'),
  need('need', '没它不行');

  const WishDesireLevel(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static WishDesireLevel fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return WishDesireLevel.want;
  }
}

/// 清单项状态。
///
/// [ready] 是**派生**状态：只看 `cooldownUntil` 与当前时间，不落库。落库就会
/// 依赖定时任务，漏跑一次就永远卡在「冷却中」。
enum WishlistItemStatus {
  waiting('waiting', '冷却中'),
  ready('ready', '可以决定了'),
  bought('bought', '已买'),
  dropped('dropped', '已放弃');

  const WishlistItemStatus(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static WishlistItemStatus fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return WishlistItemStatus.waiting;
  }

  /// 已经结束的两态（不能再改回冷却中）。
  bool get isSettled => this == bought || this == dropped;
}

/// 加班的补偿方式。
///
/// 同一个时长下三种补偿的净效应方向相反：给钱让本期时薪**上升**，白干**下降**，
/// 调休净额为零（不进本期）。
enum OvertimeCompensation {
  paid('paid', '给钱'),
  timeOff('timeOff', '调休'),
  none('none', '白干');

  const OvertimeCompensation(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static OvertimeCompensation fromDb(String? raw) {
    for (final value in values) {
      if (value.dbValue == raw) {
        return value;
      }
    }
    return OvertimeCompensation.paid;
  }
}
