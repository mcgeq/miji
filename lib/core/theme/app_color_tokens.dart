import 'package:flutter/material.dart';

/// 颜色类的**类型定义**：语义色、Hero 渐变、图表色板。
///
/// 这里只放「有哪些字段、每个字段管什么」，不放任何具体色值 ——
/// 九套配色的值全在 `app_palette.dart`，主题装配在 `app_theme.dart`。
/// 三个类都是 `ThemeExtension`，运行时从 `Theme.of(context)` 上取，
/// 所以换配色时不用改任何调用方。
///
/// 从 `app_design_tokens.dart` 拆出来，是为了让 `app_palette.dart` 只依赖它、
/// 不再反向依赖「间距/圆角/控件尺寸」那一层。
@immutable
class AppMoneyColors extends ThemeExtension<AppMoneyColors> {
  const AppMoneyColors({
    required this.income,
    required this.expense,
    required this.transfer,
    required this.credit,
    required this.warning,
    required this.success,
    required this.incomeStrong,
    required this.expenseStrong,
    required this.transferStrong,
    required this.creditStrong,
    required this.warningStrong,
    required this.incomeContainer,
    required this.expenseContainer,
    required this.transferContainer,
    required this.creditContainer,
    required this.warningContainer,
  });

  /// 金额色（vivid）。金额是**超大号粗体**，WCAG 只要求 3:1，所以这里放的是正色。
  final Color income;
  final Color expense;
  final Color transfer;
  final Color credit;
  final Color warning;

  /// 与 [income] 同值。留着是因为「成功」在记账语境里读起来是另一件事
  /// （同步成功、收款成功），调用方不该为了语义去写 income。
  ///
  /// 它**不配**独立的 Strong / Container——需要时直接用 income 那套。
  final Color success;

  /// 语义色的**小号文字版**。同一个色相压到 4.5:1 以上，
  /// 用于 12px 及以下、或压在 [incomeContainer] 这类淡底上的文字。
  ///
  /// 为什么要两套：把 vivid 压到 4.5 就会变成旧体系那种 `#0D5900` 墨绿，
  /// 而金额本来就只要求 3:1 —— 一个颜色兼顾不了「超大号金额」和「10px 角标」两端。
  final Color incomeStrong;
  final Color expenseStrong;
  final Color transferStrong;
  final Color creditStrong;
  final Color warningStrong;

  /// 语义色的**淡底版**。
  ///
  /// 替代 `color.withValues(alpha: .12)` 那种硬凑写法：alpha 叠在深色面上会发灰，
  /// 而且底色的实际明度取决于它压在什么上面。容器色是实色，两个模式各自定档。
  final Color incomeContainer;
  final Color expenseContainer;
  final Color transferContainer;
  final Color creditContainer;
  final Color warningContainer;

  @override
  AppMoneyColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? credit,
    Color? warning,
    Color? success,
    Color? incomeStrong,
    Color? expenseStrong,
    Color? transferStrong,
    Color? creditStrong,
    Color? warningStrong,
    Color? incomeContainer,
    Color? expenseContainer,
    Color? transferContainer,
    Color? creditContainer,
    Color? warningContainer,
  }) {
    return AppMoneyColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      credit: credit ?? this.credit,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      incomeStrong: incomeStrong ?? this.incomeStrong,
      expenseStrong: expenseStrong ?? this.expenseStrong,
      transferStrong: transferStrong ?? this.transferStrong,
      creditStrong: creditStrong ?? this.creditStrong,
      warningStrong: warningStrong ?? this.warningStrong,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      transferContainer: transferContainer ?? this.transferContainer,
      creditContainer: creditContainer ?? this.creditContainer,
      warningContainer: warningContainer ?? this.warningContainer,
    );
  }

  @override
  AppMoneyColors lerp(ThemeExtension<AppMoneyColors>? other, double t) {
    if (other is! AppMoneyColors) return this;
    return AppMoneyColors(
      income: Color.lerp(income, other.income, t) ?? income,
      expense: Color.lerp(expense, other.expense, t) ?? expense,
      transfer: Color.lerp(transfer, other.transfer, t) ?? transfer,
      credit: Color.lerp(credit, other.credit, t) ?? credit,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      success: Color.lerp(success, other.success, t) ?? success,
      incomeStrong:
          Color.lerp(incomeStrong, other.incomeStrong, t) ?? incomeStrong,
      expenseStrong:
          Color.lerp(expenseStrong, other.expenseStrong, t) ?? expenseStrong,
      transferStrong:
          Color.lerp(transferStrong, other.transferStrong, t) ?? transferStrong,
      creditStrong:
          Color.lerp(creditStrong, other.creditStrong, t) ?? creditStrong,
      warningStrong:
          Color.lerp(warningStrong, other.warningStrong, t) ?? warningStrong,
      incomeContainer:
          Color.lerp(incomeContainer, other.incomeContainer, t) ??
          incomeContainer,
      expenseContainer:
          Color.lerp(expenseContainer, other.expenseContainer, t) ??
          expenseContainer,
      transferContainer:
          Color.lerp(transferContainer, other.transferContainer, t) ??
          transferContainer,
      creditContainer:
          Color.lerp(creditContainer, other.creditContainer, t) ??
          creditContainer,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t) ??
          warningContainer,
    );
  }
}

/// 一套 Hero 渐变。
///
/// 存多档停靠点而不是两个端点：两端插值会经过一段发灰的中间色，
/// 三档才能控制中间那一段的走向。
@immutable
class AppHeroGradient {
  const AppHeroGradient({
    required this.colors,
    this.onColor = const Color(0xFFFFFFFF),
    this.shadowColor,
  });

  final List<Color> colors;

  /// 卡上正文色。**必须由 token 给，代码里不要写死 `Colors.white`**：
  /// 亮卡（净资产）配白字只有 2.2~3.3:1，得配深字；深卡（品牌/超支）才配白字。
  /// 三张卡各自的 [onColor] 都已在每个停靠点上验到 ≥4.5:1。
  final Color onColor;

  /// 投影色；为空时用第一档颜色。
  final Color? shadowColor;

  Color get shadow => shadowColor ?? colors.first;

  /// 卡上次级文字（标签、辅助金额）在 [onColor] 上降级用的不透明度。
  ///
  /// 0.78 是求解出来的上限：再淡一档，在最亮的那张贴靠点上就掉到 4.5:1 以下了。
  static const secondaryOpacity = 0.78;

  LinearGradient get linear => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );

  AppHeroGradient lerpTo(AppHeroGradient other, double t) {
    if (other.colors.length != colors.length) {
      return t < 0.5 ? this : other;
    }
    return AppHeroGradient(
      colors: [
        for (var i = 0; i < colors.length; i++)
          Color.lerp(colors[i], other.colors[i], t) ?? colors[i],
      ],
      onColor: Color.lerp(onColor, other.onColor, t) ?? onColor,
      shadowColor: Color.lerp(shadow, other.shadow, t) ?? shadow,
    );
  }
}

/// 数据可视化色板（8 色）。
///
/// 之前四张图各自内联了一份调色板（顺序都不一样），并且直接用 Material 原色
/// （Colors.orange / teal / indigo / pink…）—— 那些颜色不随主题变，深色模式下会过暗。
/// 现在统一成主题扩展：等感知明度（靠色相区分）、相邻切片色相相距 135°、
/// 每个色对卡片的对比度 ≥3:1（非文字图形标准）。
class AppChartPalette extends ThemeExtension<AppChartPalette> {
  const AppChartPalette({required this.colors});

  final List<Color> colors;

  Color operator [](int index) => colors[index % colors.length];

  int get length => colors.length;

  @override
  AppChartPalette copyWith({List<Color>? colors}) {
    return AppChartPalette(colors: colors ?? this.colors);
  }

  @override
  AppChartPalette lerp(ThemeExtension<AppChartPalette>? other, double t) {
    if (other is! AppChartPalette || other.colors.length != colors.length) {
      return this;
    }
    return AppChartPalette(
      colors: [
        for (var i = 0; i < colors.length; i++)
          Color.lerp(colors[i], other.colors[i], t) ?? colors[i],
      ],
    );
  }
}

/// App 内所有 Hero / 大色块渐变。
///
/// 之前这些颜色是硬编码在各自的组件里的（账户页净资产卡、首页 Hero、
/// 首次使用引导），既没法复用也不受主题管理。集中到这里之后，
/// 「净资产配色」可以被任何页面直接取用。
@immutable
class AppHeroGradients extends ThemeExtension<AppHeroGradients> {
  const AppHeroGradients({
    required this.netWorth,
    required this.brand,
    required this.danger,
    this.amber = const Color(0xFFFFC94F),
  });

  /// Hero 上的次级数字色（净资产卡里的「负债」、分类预算的超支进度条）。
  ///
  /// 原来是散在三个文件里的硬编码 `#FFD9A0`：它在净资产渐变右端只有 3.44:1，
  /// 不满足 4.5:1。现在提成 token，并由求解器保证在每个渐变端点上 ≥4.5:1。
  ///
  /// 只用在**深卡**（品牌 / 超支）上：它是暖色，而 A 的中性面是冷色，
  /// 同框会冲突；但深卡内部没有冷底，暖色反而正是「告警」该有的语气。
  /// 净资产卡是亮卡，那边的次级数字走 `gradient.onColor` + 降不透明度，不用它。
  final Color amber;

  /// 资产 / 净资产：亮蓝 → 淡紫的冷色渐变。**配深字（`onColor`）**。
  final AppHeroGradient netWorth;

  /// 品牌：石墨灰。用于首页 Hero、预算卡，配白字。
  final AppHeroGradient brand;

  /// 告警：超支、失败。深红，配白字。
  final AppHeroGradient danger;

  @override
  AppHeroGradients copyWith({
    AppHeroGradient? netWorth,
    AppHeroGradient? brand,
    AppHeroGradient? danger,
    Color? amber,
  }) {
    return AppHeroGradients(
      netWorth: netWorth ?? this.netWorth,
      brand: brand ?? this.brand,
      danger: danger ?? this.danger,
      amber: amber ?? this.amber,
    );
  }

  @override
  AppHeroGradients lerp(ThemeExtension<AppHeroGradients>? other, double t) {
    if (other is! AppHeroGradients) {
      return this;
    }
    return AppHeroGradients(
      netWorth: netWorth.lerpTo(other.netWorth, t),
      brand: brand.lerpTo(other.brand, t),
      danger: danger.lerpTo(other.danger, t),
      amber: Color.lerp(amber, other.amber, t) ?? amber,
    );
  }
}
