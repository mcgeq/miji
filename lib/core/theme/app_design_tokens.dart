import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_theme_tokens.dart';

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

@immutable
class AppSpacingTokens extends ThemeExtension<AppSpacingTokens> {
  const AppSpacingTokens({
    required this.pageCompact,
    required this.pageRegular,
    required this.sectionGap,
    required this.cardPadding,
    required this.fieldGap,
    this.listItemPadding = 14,
  });

  final double pageCompact;
  final double pageRegular;
  final double sectionGap;
  final double cardPadding;
  final double fieldGap;

  /// 列表行内边距：比卡片略紧，是刻意的两档，不再是各处硬编码。
  final double listItemPadding;

  @override
  AppSpacingTokens copyWith({
    double? pageCompact,
    double? pageRegular,
    double? sectionGap,
    double? cardPadding,
    double? fieldGap,
    double? listItemPadding,
  }) {
    return AppSpacingTokens(
      pageCompact: pageCompact ?? this.pageCompact,
      pageRegular: pageRegular ?? this.pageRegular,
      sectionGap: sectionGap ?? this.sectionGap,
      cardPadding: cardPadding ?? this.cardPadding,
      fieldGap: fieldGap ?? this.fieldGap,
      listItemPadding: listItemPadding ?? this.listItemPadding,
    );
  }

  @override
  AppSpacingTokens lerp(ThemeExtension<AppSpacingTokens>? other, double t) {
    if (other is! AppSpacingTokens) return this;
    return AppSpacingTokens(
      pageCompact: lerpDouble(pageCompact, other.pageCompact, t) ?? pageCompact,
      pageRegular: lerpDouble(pageRegular, other.pageRegular, t) ?? pageRegular,
      sectionGap: lerpDouble(sectionGap, other.sectionGap, t) ?? sectionGap,
      cardPadding: lerpDouble(cardPadding, other.cardPadding, t) ?? cardPadding,
      fieldGap: lerpDouble(fieldGap, other.fieldGap, t) ?? fieldGap,
      listItemPadding:
          lerpDouble(listItemPadding, other.listItemPadding, t) ??
          listItemPadding,
    );
  }
}

@immutable
class AppRadiusTokens extends ThemeExtension<AppRadiusTokens> {
  const AppRadiusTokens({
    required this.sm,
    required this.md,
    required this.lg,
    required this.pill,
    this.card = 16,
  });

  final double sm;
  final double md;
  final double lg;
  final double pill;

  /// 内容卡片专用圆角。
  ///
  /// 不复用 [md]（10）：`md` 同时被输入框、图标底、色块使用，把卡片提到 16
  /// 会让输入框一起变「胖」。卡片圆角是现代感最直观的一层，单独给一个 token。
  final double card;

  @override
  AppRadiusTokens copyWith({
    double? sm,
    double? md,
    double? lg,
    double? pill,
    double? card,
  }) {
    return AppRadiusTokens(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
      card: card ?? this.card,
    );
  }

  @override
  AppRadiusTokens lerp(ThemeExtension<AppRadiusTokens>? other, double t) {
    if (other is! AppRadiusTokens) return this;
    return AppRadiusTokens(
      sm: lerpDouble(sm, other.sm, t) ?? sm,
      md: lerpDouble(md, other.md, t) ?? md,
      lg: lerpDouble(lg, other.lg, t) ?? lg,
      pill: lerpDouble(pill, other.pill, t) ?? pill,
      card: lerpDouble(card, other.card, t) ?? card,
    );
  }
}

@immutable
class AppControlTokens extends ThemeExtension<AppControlTokens> {
  const AppControlTokens({
    required this.fieldHeight,
    required this.compactFieldHeight,
    required this.iconButtonSize,
    required this.dialogWidth,
    required this.contentMaxWidth,
  });

  final double fieldHeight;
  final double compactFieldHeight;
  final double iconButtonSize;
  final double dialogWidth;
  final double contentMaxWidth;

  @override
  AppControlTokens copyWith({
    double? fieldHeight,
    double? compactFieldHeight,
    double? iconButtonSize,
    double? dialogWidth,
    double? contentMaxWidth,
  }) {
    return AppControlTokens(
      fieldHeight: fieldHeight ?? this.fieldHeight,
      compactFieldHeight: compactFieldHeight ?? this.compactFieldHeight,
      iconButtonSize: iconButtonSize ?? this.iconButtonSize,
      dialogWidth: dialogWidth ?? this.dialogWidth,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
    );
  }

  @override
  AppControlTokens lerp(ThemeExtension<AppControlTokens>? other, double t) {
    if (other is! AppControlTokens) return this;
    return AppControlTokens(
      fieldHeight: lerpDouble(fieldHeight, other.fieldHeight, t) ?? fieldHeight,
      compactFieldHeight:
          lerpDouble(compactFieldHeight, other.compactFieldHeight, t) ??
          compactFieldHeight,
      iconButtonSize:
          lerpDouble(iconButtonSize, other.iconButtonSize, t) ?? iconButtonSize,
      dialogWidth: lerpDouble(dialogWidth, other.dialogWidth, t) ?? dialogWidth,
      contentMaxWidth:
          lerpDouble(contentMaxWidth, other.contentMaxWidth, t) ??
          contentMaxWidth,
    );
  }
}

extension AppThemeTokenLookup on ThemeData {
  AppMoneyColors get moneyColors =>
      extension<AppMoneyColors>() ?? AppThemeFallbacks.moneyColors;

  AppSpacingTokens get spacingTokens =>
      extension<AppSpacingTokens>() ?? AppThemeFallbacks.spacingTokens;

  AppRadiusTokens get radiusTokens =>
      extension<AppRadiusTokens>() ?? AppThemeFallbacks.radiusTokens;

  AppControlTokens get controlTokens =>
      extension<AppControlTokens>() ?? AppThemeFallbacks.controlTokens;

  AppHeroGradients get heroGradients =>
      extension<AppHeroGradients>() ?? AppThemeFallbacks.heroGradients;

  AppChartPalette get chartPalette =>
      extension<AppChartPalette>() ?? AppThemeFallbacks.chartPalette;
}

class AppThemeFallbacks {
  const AppThemeFallbacks._();

  /// 浅色语义色（A 晴空）。
  ///
  /// 与上一版「暖纸 · 靛蓝」的区别不只是色相：旧值是把五色按正文的 **4.5:1** 卡出来的，
  /// 结果只能退成 `#0D5900` 墨绿、`#473D00` 橄榄这类暗浊色，一屏金额看上去像蒙了灰。
  /// 现在金额走 3:1 档（vivid），小号文字走 4.5:1 档（`*Strong`），淡底走实色的
  /// `*Container` —— 三个角色各自达标，不再互相迁就。
  static const moneyColors = AppMoneyColors(
    income: Color(0xFF2B933E),
    expense: Color(0xFFCA4B51),
    transfer: Color(0xFF008692),
    credit: Color(0xFF9E5BBA),
    warning: Color(0xFF956D00),
    success: Color(0xFF2B933E),
    incomeStrong: Color(0xFF00651D),
    expenseStrong: Color(0xFF981729),
    transferStrong: Color(0xFF005961),
    creditStrong: Color(0xFF712F8C),
    warningStrong: Color(0xFF634700),
    incomeContainer: Color(0xFFD6F7D7),
    expenseContainer: Color(0xFFFFE6E5),
    transferContainer: Color(0xFFC3F8FF),
    creditContainer: Color(0xFFF7E6FF),
    warningContainer: Color(0xFFFFEAC4),
  );

  static const heroGradients = AppHeroGradients(
    // 净资产：亮蓝 → 淡紫，配**深字**。旧版是「紫→青」配白字，亮起来就压不住白字，
    // 只能把渐变停在中间明度（0.48~0.58），两头都够不着，页面上像一条脏色带；
    // 改成亮渐变 + 深字之后，「越有钱越亮」这个语义才真的做出来。
    netWorth: AppHeroGradient(
      colors: [Color(0xFF188FF0), Color(0xFF859DFF), Color(0xFFA280EF)],
      onColor: AppThemeTokens.lightOnNetWorth,
    ),
    // 品牌卡（首页 Hero / 预算卡）：石墨。深卡配白字，对比度 12~15:1，
    // 与净资产的亮蓝卡并排也不会被误认成同一种卡。
    brand: AppHeroGradient(
      colors: [Color(0xFF1D252D), Color(0xFF30363E), Color(0xFF282B32)],
      onColor: AppThemeTokens.lightOnBrand,
    ),
    // 超支卡：深红。与品牌石墨卡同为深卡，但色相差 330°+，一眼分得开。
    danger: AppHeroGradient(
      colors: [Color(0xFF800E50), Color(0xFFA01445), Color(0xFF921921)],
      onColor: AppThemeTokens.lightOnDanger,
    ),
    amber: AppThemeTokens.lightHeroAmber,
  );

  /// 图表 8 色。深浅两套**顺序一致**：同一个分类在两个模式下落在同一个色相上，
  /// 用户切换主题时「哪块是谁」不会重排。
  static const chartPalette = AppChartPalette(
    colors: [
      Color(0xFFD15B5E),
      Color(0xFF2B8E3B),
      Color(0xFFA867C3),
      Color(0xFF008B7A),
      Color(0xFFAB7E00),
      Color(0xFF4972CF),
      Color(0xFFCD632D),
      Color(0xFF008794),
    ],
  );

  static const spacingTokens = AppSpacingTokens(
    pageCompact: 12,
    pageRegular: 24,
    sectionGap: 16,
    cardPadding: 16,
    fieldGap: 12,
  );

  static const radiusTokens = AppRadiusTokens(sm: 8, md: 10, lg: 14, pill: 999);

  static const controlTokens = AppControlTokens(
    fieldHeight: 46,
    compactFieldHeight: 40,
    iconButtonSize: 40,
    dialogWidth: 520,
    contentMaxWidth: 1080,
  );
}
