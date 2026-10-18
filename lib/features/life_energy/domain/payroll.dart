import 'package:flutter/foundation.dart';

import 'package:miji/features/life_energy/domain/life_energy_enums.dart';

/// 工资薪金的「税前 → 到手」推算。
///
/// 为什么这是一个纯函数模块、不落任何快照表：到手是「月薪 + 参数 + 月份」的
/// 函数，落库就要维护「什么时候重算」。漏算一次的表现是数对不上，而用户根本
/// 查不出是哪天出的错。跑 12 个月累计预扣是微秒级的，每次现算最省心。
///
/// **口径说明**：全程 int（分），比例用万分比整数（800 = 8%）。不用 double 是
/// 因为 `0.08` 在浮点里是 `0.08000000000000002`，累乘 12 个月能差出几分钱，
/// 而「几分钱对不上工资条」正是这个功能最不该有的错。

/// 起征点 5,000 元/月（分）。
const int payrollBasicDeductionMinor = 500000;

/// 一档税率。
@immutable
class TaxBracket {
  const TaxBracket({
    required this.upperBoundMinor,
    required this.rateBp,
    required this.quickDeductionMinor,
  });

  /// 本档上限（含）。累计应纳税所得额 **不超过** 它就走本档。
  final int upperBoundMinor;

  /// 万分比。1000 = 10%。
  final int rateBp;

  /// 速算扣除数（分）。
  final int quickDeductionMinor;
}

/// 预扣率表一：居民个人工资薪金所得的**累计**预扣率。
///
/// 注意它是「累计应纳税所得额」的档位，不是「月收入」的档位 —— 这是累计
/// 预扣法最容易被理解错的地方：同一个 2 万月薪，1 月落在 3% 档，5 月跨到
/// 10% 档，之后一直停在 10%。
const List<TaxBracket> cumulativeTaxBrackets = [
  TaxBracket(upperBoundMinor: 3600000, rateBp: 300, quickDeductionMinor: 0),
  TaxBracket(
    upperBoundMinor: 14400000,
    rateBp: 1000,
    quickDeductionMinor: 252000,
  ),
  TaxBracket(
    upperBoundMinor: 30000000,
    rateBp: 2000,
    quickDeductionMinor: 1692000,
  ),
  TaxBracket(
    upperBoundMinor: 42000000,
    rateBp: 2500,
    quickDeductionMinor: 3192000,
  ),
  TaxBracket(
    upperBoundMinor: 66000000,
    rateBp: 3000,
    quickDeductionMinor: 5292000,
  ),
  TaxBracket(
    upperBoundMinor: 96000000,
    rateBp: 3500,
    quickDeductionMinor: 8592000,
  ),
  TaxBracket(
    upperBoundMinor: 1 << 62,
    rateBp: 4500,
    quickDeductionMinor: 18192000,
  ),
];

/// 按月换算后的综合所得税率表，**只给年终奖单独计税用**。
///
/// 用法是「奖金 ÷ 12 找档，再用**全额**乘税率减速算扣除数」—— 除以 12 只是
/// 为了找档，不是把奖金拆成 12 个月。这个细节错了会差 12 倍。
const List<TaxBracket> monthlyBonusBrackets = [
  TaxBracket(upperBoundMinor: 300000, rateBp: 300, quickDeductionMinor: 0),
  TaxBracket(
    upperBoundMinor: 1200000,
    rateBp: 1000,
    quickDeductionMinor: 21000,
  ),
  TaxBracket(
    upperBoundMinor: 2500000,
    rateBp: 2000,
    quickDeductionMinor: 141000,
  ),
  TaxBracket(
    upperBoundMinor: 3500000,
    rateBp: 2500,
    quickDeductionMinor: 266000,
  ),
  TaxBracket(
    upperBoundMinor: 5500000,
    rateBp: 3000,
    quickDeductionMinor: 441000,
  ),
  TaxBracket(
    upperBoundMinor: 8000000,
    rateBp: 3500,
    quickDeductionMinor: 716000,
  ),
  TaxBracket(
    upperBoundMinor: 1 << 62,
    rateBp: 4500,
    quickDeductionMinor: 1516000,
  ),
];

/// 按档位算税。`taxable <= 0` 时返回 0（不是负数）。
int taxForBracket(int taxableMinor, List<TaxBracket> brackets) {
  if (taxableMinor <= 0) {
    return 0;
  }
  for (final bracket in brackets) {
    if (taxableMinor <= bracket.upperBoundMinor) {
      final tax =
          (taxableMinor * bracket.rateBp / 10000).round() -
          bracket.quickDeductionMinor;
      return tax < 0 ? 0 : tax;
    }
  }
  return 0;
}

/// 落在哪一档（给「3% 档 · 4 个月」这类文案用）。
TaxBracket bracketFor(int taxableMinor, List<TaxBracket> brackets) {
  for (final bracket in brackets) {
    if (taxableMinor <= bracket.upperBoundMinor) {
      return bracket;
    }
  }
  return brackets.last;
}

/// 年终奖单独计税的税额。
///
/// 单独计税有「盲区」：36,000 交 1,080，36,001 交 3,390 —— 多发 1 元多交
/// 2,310。这里只算，不提示怎么发更划算（那是 HR 的事）。
int bonusTaxMinorFor(int bonusMinor) {
  if (bonusMinor <= 0) {
    return 0;
  }
  final monthly = bonusMinor / 12;
  final bracket = bracketFor(monthly.ceil(), monthlyBonusBrackets);
  final tax =
      (bonusMinor * bracket.rateBp / 10000).round() -
      bracket.quickDeductionMinor;
  return tax < 0 ? 0 : tax;
}

/// 个人承担的五险一金（分/月）。
@immutable
class IndividualSocial {
  const IndividualSocial({
    this.pensionMinor = 0,
    this.medicalMinor = 0,
    this.unemploymentMinor = 0,
    this.housingFundMinor = 0,
    this.fixedMinor = 0,
  });

  static const zero = IndividualSocial();

  final int pensionMinor;
  final int medicalMinor;
  final int unemploymentMinor;
  final int housingFundMinor;

  /// 大额医疗互助这类「固定几块钱」的项目。各地口径不同（3 元 / 0.5%），
  /// 所以单独一列、可填 0，不并进医疗比例里。
  final int fixedMinor;

  int get totalMinor =>
      pensionMinor +
      medicalMinor +
      unemploymentMinor +
      housingFundMinor +
      fixedMinor;

  /// 「养老 19,200 · 医疗 4,800 · 其余 6,000」这类拆解文案要用的三项小计。
  int get othersMinor => medicalMinor + unemploymentMinor + fixedMinor;

  IndividualSocial operator +(IndividualSocial other) => IndividualSocial(
    pensionMinor: pensionMinor + other.pensionMinor,
    medicalMinor: medicalMinor + other.medicalMinor,
    unemploymentMinor: unemploymentMinor + other.unemploymentMinor,
    housingFundMinor: housingFundMinor + other.housingFundMinor,
    fixedMinor: fixedMinor + other.fixedMinor,
  );
}

/// 单位承担的五险一金（分/月）。**只进年度账，永不进时薪。**
@immutable
class EmployerSocial {
  const EmployerSocial({
    this.pensionMinor = 0,
    this.medicalMinor = 0,
    this.unemploymentMinor = 0,
    this.injuryMinor = 0,
    this.housingFundMinor = 0,
  });

  static const zero = EmployerSocial();

  final int pensionMinor;
  final int medicalMinor;
  final int unemploymentMinor;
  final int injuryMinor;
  final int housingFundMinor;

  int get totalMinor =>
      pensionMinor +
      medicalMinor +
      unemploymentMinor +
      injuryMinor +
      housingFundMinor;

  int get othersMinor => medicalMinor + unemploymentMinor + injuryMinor;

  EmployerSocial operator +(EmployerSocial other) => EmployerSocial(
    pensionMinor: pensionMinor + other.pensionMinor,
    medicalMinor: medicalMinor + other.medicalMinor,
    unemploymentMinor: unemploymentMinor + other.unemploymentMinor,
    injuryMinor: injuryMinor + other.injuryMinor,
    housingFundMinor: housingFundMinor + other.housingFundMinor,
  );
}

/// 五险一金参数 + 专项附加扣除 + 年终奖。
///
/// **没有城市预设**：这里的默认值只是一个起算点（个人 22.5% / 单位 38.4%，
/// 基数上下限 6,821 / 35,811），与设计稿第五节那组示例数字对得上：税前
/// 20,000 → 个人 4,500 → 年到手 178,320。曾经有一组按城市一键填充的预设，
/// 后来摘掉了 —— 各地口径逐年调整、公积金比例还由单位在区间内自定，
/// 「填好了你直接用」比「空着让你自己查」更容易骗人。缺的数请自己填。
@immutable
class SocialInsuranceConfig {
  const SocialInsuranceConfig({
    this.baseMode = SocialBaseMode.auto,
    this.baseOverrideMinor = 0,
    this.baseFloorMinor = 682100,
    this.baseCeilingMinor = 3581100,
    this.pensionBp = 800,
    this.medicalBp = 200,
    this.unemploymentBp = 50,
    this.housingFundBp = 1200,
    this.pensionErBp = 1600,
    this.medicalErBp = 950,
    this.unemploymentErBp = 50,
    this.injuryErBp = 40,
    this.housingFundErBp = 1200,
    this.medicalFixedMinor = 0,
    this.specialDeductionMinor = 0,
  });

  /// 空白配置：上面那组默认值。名字不叫 `beijing` —— 它只是一组起算值，
  /// 不承诺对北京或任何城市成立。
  static const defaults = SocialInsuranceConfig();

  /// 基数自动跟随税前（再 clamp 到上下限），还是用用户填的那个数。
  ///
  /// **基数不等于月薪**：它按上年度月平均工资核定，月薪 5,000 的人按下限
  /// 缴（比工资还高），月薪 8 万的人只按上限缴。所以必须能手动改。
  final SocialBaseMode baseMode;
  final int baseOverrideMinor;
  final int baseFloorMinor;
  final int baseCeilingMinor;

  // 个人四项（万分比）。
  final int pensionBp;
  final int medicalBp;
  final int unemploymentBp;
  final int housingFundBp;

  // 单位五项（万分比）。
  final int pensionErBp;
  final int medicalErBp;
  final int unemploymentErBp;
  final int injuryErBp;
  final int housingFundErBp;

  final int medicalFixedMinor;

  /// 专项附加扣除（分/月）。**减的是计税基数，不是税额** —— 2,000 的扣除在
  /// 10% 档只值 200 元税，写成「每月少交 2,000」是错的。
  final int specialDeductionMinor;

  int get individualRateBp =>
      pensionBp + medicalBp + unemploymentBp + housingFundBp;

  int get employerRateBp =>
      pensionErBp +
      medicalErBp +
      unemploymentErBp +
      injuryErBp +
      housingFundErBp;

  /// 这个月按多少基数缴。
  int baseFor(int grossMonthlyMinor) {
    if (baseMode == SocialBaseMode.manual) {
      return baseOverrideMinor < 0 ? 0 : baseOverrideMinor;
    }
    if (grossMonthlyMinor <= 0) {
      return 0;
    }
    // 上下限填反了（手填时可能）就退回不夹，免得 clamp 抛异常让整页白屏。
    if (baseCeilingMinor < baseFloorMinor) {
      return grossMonthlyMinor;
    }
    return grossMonthlyMinor.clamp(baseFloorMinor, baseCeilingMinor);
  }

  IndividualSocial individualFor(int baseMinor) => IndividualSocial(
    pensionMinor: _apply(baseMinor, pensionBp),
    medicalMinor: _apply(baseMinor, medicalBp),
    unemploymentMinor: _apply(baseMinor, unemploymentBp),
    housingFundMinor: _apply(baseMinor, housingFundBp),
    fixedMinor: medicalFixedMinor,
  );

  EmployerSocial employerFor(int baseMinor) => EmployerSocial(
    pensionMinor: _apply(baseMinor, pensionErBp),
    medicalMinor: _apply(baseMinor, medicalErBp),
    unemploymentMinor: _apply(baseMinor, unemploymentErBp),
    injuryMinor: _apply(baseMinor, injuryErBp),
    housingFundMinor: _apply(baseMinor, housingFundErBp),
  );

  static int _apply(int baseMinor, int rateBp) {
    if (baseMinor <= 0 || rateBp <= 0) {
      return 0;
    }
    return (baseMinor * rateBp / 10000).round();
  }

  /// 快照用。职业段把一整份参数冻在 `payroll_json` 里，而不是拆成十几列 ——
  /// 参数还会加项（补充公积金、专项扣除新条目），而 JSON 加字段不需要迁移。
  ///
  /// 存**整份**、不存差异：段上的条件字段已经是差异式（null = 继承），参数
  /// 再来一层，`_resolve` 里两层 `??` 叠在一起就没人推得出「这个月到底用
  /// 哪套数」了。
  Map<String, Object?> toJson() => {
    'baseMode': baseMode.dbValue,
    'baseOverrideMinor': baseOverrideMinor,
    'baseFloorMinor': baseFloorMinor,
    'baseCeilingMinor': baseCeilingMinor,
    'pensionBp': pensionBp,
    'medicalBp': medicalBp,
    'unemploymentBp': unemploymentBp,
    'housingFundBp': housingFundBp,
    'pensionErBp': pensionErBp,
    'medicalErBp': medicalErBp,
    'unemploymentErBp': unemploymentErBp,
    'injuryErBp': injuryErBp,
    'housingFundErBp': housingFundErBp,
    'medicalFixedMinor': medicalFixedMinor,
    'specialDeductionMinor': specialDeductionMinor,
  };

  /// 读快照。缺的键走默认值、多出来的键忽略 —— 旧版本写的快照要能读，
  /// 新版本写的东西被旧版本读到也不能炸。
  factory SocialInsuranceConfig.fromJson(Map<String, Object?> json) {
    const fallback = SocialInsuranceConfig.defaults;
    int intOf(String key, int fallbackValue) {
      final value = json[key];
      return value is int ? value : fallbackValue;
    }

    return SocialInsuranceConfig(
      baseMode: SocialBaseMode.fromDb(
        json['baseMode'] is String ? json['baseMode']! as String : null,
      ),
      baseOverrideMinor: intOf('baseOverrideMinor', fallback.baseOverrideMinor),
      baseFloorMinor: intOf('baseFloorMinor', fallback.baseFloorMinor),
      baseCeilingMinor: intOf('baseCeilingMinor', fallback.baseCeilingMinor),
      pensionBp: intOf('pensionBp', fallback.pensionBp),
      medicalBp: intOf('medicalBp', fallback.medicalBp),
      unemploymentBp: intOf('unemploymentBp', fallback.unemploymentBp),
      housingFundBp: intOf('housingFundBp', fallback.housingFundBp),
      pensionErBp: intOf('pensionErBp', fallback.pensionErBp),
      medicalErBp: intOf('medicalErBp', fallback.medicalErBp),
      unemploymentErBp: intOf('unemploymentErBp', fallback.unemploymentErBp),
      injuryErBp: intOf('injuryErBp', fallback.injuryErBp),
      housingFundErBp: intOf('housingFundErBp', fallback.housingFundErBp),
      medicalFixedMinor: intOf('medicalFixedMinor', fallback.medicalFixedMinor),
      specialDeductionMinor: intOf(
        'specialDeductionMinor',
        fallback.specialDeductionMinor,
      ),
    );
  }

  /// 值相等。历史页要判断「这一段是不是只换了参数」，比较的是整份配置。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SocialInsuranceConfig &&
        other.baseMode == baseMode &&
        other.baseOverrideMinor == baseOverrideMinor &&
        other.baseFloorMinor == baseFloorMinor &&
        other.baseCeilingMinor == baseCeilingMinor &&
        other.pensionBp == pensionBp &&
        other.medicalBp == medicalBp &&
        other.unemploymentBp == unemploymentBp &&
        other.housingFundBp == housingFundBp &&
        other.pensionErBp == pensionErBp &&
        other.medicalErBp == medicalErBp &&
        other.unemploymentErBp == unemploymentErBp &&
        other.injuryErBp == injuryErBp &&
        other.housingFundErBp == housingFundErBp &&
        other.medicalFixedMinor == medicalFixedMinor &&
        other.specialDeductionMinor == specialDeductionMinor;
  }

  @override
  int get hashCode => Object.hashAll([
    baseMode,
    baseOverrideMinor,
    baseFloorMinor,
    baseCeilingMinor,
    pensionBp,
    medicalBp,
    unemploymentBp,
    housingFundBp,
    pensionErBp,
    medicalErBp,
    unemploymentErBp,
    injuryErBp,
    housingFundErBp,
    medicalFixedMinor,
    specialDeductionMinor,
  ]);

  SocialInsuranceConfig copyWith({
    SocialBaseMode? baseMode,
    int? baseOverrideMinor,
    int? baseFloorMinor,
    int? baseCeilingMinor,
    int? pensionBp,
    int? medicalBp,
    int? unemploymentBp,
    int? housingFundBp,
    int? pensionErBp,
    int? medicalErBp,
    int? unemploymentErBp,
    int? injuryErBp,
    int? housingFundErBp,
    int? medicalFixedMinor,
    int? specialDeductionMinor,
  }) {
    return SocialInsuranceConfig(
      baseMode: baseMode ?? this.baseMode,
      baseOverrideMinor: baseOverrideMinor ?? this.baseOverrideMinor,
      baseFloorMinor: baseFloorMinor ?? this.baseFloorMinor,
      baseCeilingMinor: baseCeilingMinor ?? this.baseCeilingMinor,
      pensionBp: pensionBp ?? this.pensionBp,
      medicalBp: medicalBp ?? this.medicalBp,
      unemploymentBp: unemploymentBp ?? this.unemploymentBp,
      housingFundBp: housingFundBp ?? this.housingFundBp,
      pensionErBp: pensionErBp ?? this.pensionErBp,
      medicalErBp: medicalErBp ?? this.medicalErBp,
      unemploymentErBp: unemploymentErBp ?? this.unemploymentErBp,
      injuryErBp: injuryErBp ?? this.injuryErBp,
      housingFundErBp: housingFundErBp ?? this.housingFundErBp,
      medicalFixedMinor: medicalFixedMinor ?? this.medicalFixedMinor,
      specialDeductionMinor:
          specialDeductionMinor ?? this.specialDeductionMinor,
    );
  }
}

/// 一个月的输入：要么给税前（跑累计预扣），要么给一个已经校准的到手数。
///
/// 为什么允许「校准到手」混进来：用户可能在「直接填到手」模式下记过历史段，
/// 后来又切到税前推算。旧段没有税前数字，不能凭空补一个 —— 那就直接用它
/// 当时记的到手，不参与累计（它的税已经扣过了，只是我们不知道扣了多少）。
/// 这样切换模式不会改写历史，代价是那一年的累计税额偏低一点。
@immutable
class PayrollMonthInput {
  const PayrollMonthInput.gross(this.grossMinor, {this.config})
    : netMinor = null;

  const PayrollMonthInput.netCalibrated(this.netMinor, {this.config})
    : grossMinor = null;

  final int? grossMinor;
  final int? netMinor;

  /// 这个月用哪套五险一金参数。null = 用 [PayrollCalculator] 上那一份。
  ///
  /// 为什么参数要能**逐月**变：换城市（北京 → 深圳，基数下限与公积金比例
  /// 全换）、换公司（公积金比例由单位定）、每年 7 月社保基数调整 —— 一年里
  /// 参数变好几次是常态。整年共用一份配置，就是把 1–6 月也按 7 月之后的比例
  /// 重算，累计预扣的档位跟着一起错。
  final SocialInsuranceConfig? config;

  bool get isNetCalibrated => grossMinor == null;
}

/// 某个月的扣缴结果。
@immutable
class MonthlyPayroll {
  const MonthlyPayroll({
    required this.month,
    required this.grossMinor,
    required this.baseMinor,
    required this.individual,
    required this.employer,
    required this.cumulativeTaxableMinor,
    required this.taxMinor,
    required this.netMinor,
    this.isNetCalibrated = false,
  });

  final int month;

  /// 税前应发（分）。net 校准的月份为 0。
  final int grossMinor;
  final int baseMinor;
  final IndividualSocial individual;
  final EmployerSocial employer;

  /// 截至本月累计应纳税所得额（分）。柱子看的是 [taxMinor]，这一项是解释用的。
  final int cumulativeTaxableMinor;

  /// **本月**个税（分）。12 根柱子画的就是它 —— 到手只差 3.9%，税差 3.3 倍，
  /// 画到手看不出「5 月跨档了」。
  final int taxMinor;

  final int netMinor;
  final bool isNetCalibrated;

  /// 本月预扣率（万分比）。
  int get rateBp => cumulativeTaxableMinor <= 0
      ? 0
      : bracketFor(cumulativeTaxableMinor, cumulativeTaxBrackets).rateBp;
}

/// 一年的账。
@immutable
class AnnualPayroll {
  const AnnualPayroll({
    required this.year,
    required this.months,
    this.bonusMinor = 0,
    this.bonusTaxMinor = 0,
  });

  final int year;

  /// 固定 12 个月，索引 0 = 1 月。
  final List<MonthlyPayroll> months;

  final int bonusMinor;
  final int bonusTaxMinor;

  int get grossMinor => months.fold(0, (sum, month) => sum + month.grossMinor);

  IndividualSocial get individual => months.fold(
    IndividualSocial.zero,
    (sum, month) => sum + month.individual,
  );

  EmployerSocial get employer =>
      months.fold(EmployerSocial.zero, (sum, month) => sum + month.employer);

  int get taxMinor => months.fold(0, (sum, month) => sum + month.taxMinor);

  int get netMinor => months.fold(0, (sum, month) => sum + month.netMinor);

  /// 年终奖净额（单独计税之后）。
  int get bonusNetMinor => bonusMinor - bonusTaxMinor;

  /// 全年到手 = 12 个月 + 年终奖净额。
  int get totalNetMinor => netMinor + bonusNetMinor;

  /// 全年到手占应发的比例（0.743 = 74.3%）。分母含年终奖，否则带奖金的人
  /// 会看到一个明显偏高的比例。
  double get netRatio {
    final total = grossMinor + bonusMinor;
    if (total <= 0) {
      return 0;
    }
    return totalNetMinor / total;
  }

  /// 公积金（个人 + 单位）：都是你的钱，只是取不出来。
  int get housingFundBothSidesMinor =>
      individual.housingFundMinor + employer.housingFundMinor;

  /// 单位为你另外掏的钱（不含工资本身）。
  int get employerTotalMinor => employer.totalMinor;

  /// 用工成本 = 应发 + 单位五险一金。
  int get employmentCostMinor => grossMinor + bonusMinor + employerTotalMinor;

  bool get hasData => grossMinor > 0;

  /// 某个月的到手（1–12）。越界返回 null，而不是静默给 0。
  MonthlyPayroll? month(int monthNumber) {
    if (monthNumber < 1 || monthNumber > months.length) {
      return null;
    }
    return months[monthNumber - 1];
  }

  /// 12 个月的平均到手（不含年终奖）。**只用于「全年平均 ¥61.6」这类参照**，
  /// 时薪永远取当月，不取这个均值。
  double get averageMonthlyNetMinor => netMinor / 12;
}

/// 跑完 12 次累计预扣。
///
/// 算法骨架（与法定口径一致）：
/// ```
/// 本月税 = 累计税 − 已预缴
/// 累计税 = 累计应纳税所得额 × 率 − 速算扣除数
/// 累计应纳税所得额 += 应发 − 5,000 − 个人五险一金 − 专项附加扣除
/// ```
/// 两个细节：累计额可以是负数（低薪月），此时税额为 0；本月税也**不允许为负**
/// （多缴的部分要等年度汇算退，预扣阶段不退）。
class PayrollCalculator {
  const PayrollCalculator({required this.config, this.bonusMinor = 0});

  final SocialInsuranceConfig config;
  final int bonusMinor;

  AnnualPayroll annual({
    required int year,
    required List<PayrollMonthInput> inputs,
  }) {
    assert(inputs.length == 12, '累计预扣必须跑满 12 个月');
    final months = <MonthlyPayroll>[];
    var cumulativeTaxable = 0;
    var taxPaid = 0;

    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final monthNumber = i + 1;

      if (input.isNetCalibrated) {
        // 已经校准的到手：不参与累计，也不产生税。理由见 [PayrollMonthInput]。
        months.add(
          MonthlyPayroll(
            month: monthNumber,
            grossMinor: 0,
            baseMinor: 0,
            individual: IndividualSocial.zero,
            employer: EmployerSocial.zero,
            cumulativeTaxableMinor: cumulativeTaxable,
            taxMinor: 0,
            netMinor: input.netMinor ?? 0,
            isNetCalibrated: true,
          ),
        );
        continue;
      }

      // 参数可以逐月变（换城市 / 换公司 / 7 月基数调整）。没有单独给的那个月
      // 就用计算器上这一份。
      final monthConfig = input.config ?? config;
      final gross = input.grossMinor ?? 0;
      final base = monthConfig.baseFor(gross);
      final individual = monthConfig.individualFor(base);
      final employer = monthConfig.employerFor(base);

      cumulativeTaxable +=
          gross -
          payrollBasicDeductionMinor -
          individual.totalMinor -
          monthConfig.specialDeductionMinor;

      final cumulativeTax = taxForBracket(
        cumulativeTaxable,
        cumulativeTaxBrackets,
      );
      final tax = (cumulativeTax - taxPaid).clamp(0, cumulativeTax);
      taxPaid += tax;

      months.add(
        MonthlyPayroll(
          month: monthNumber,
          grossMinor: gross,
          baseMinor: base,
          individual: individual,
          employer: employer,
          cumulativeTaxableMinor: cumulativeTaxable,
          taxMinor: tax,
          netMinor: gross - individual.totalMinor - tax,
        ),
      );
    }

    return AnnualPayroll(
      year: year,
      months: List.unmodifiable(months),
      bonusMinor: bonusMinor,
      bonusTaxMinor: bonusTaxMinorFor(bonusMinor),
    );
  }
}
