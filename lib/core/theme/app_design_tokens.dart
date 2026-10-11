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
  });

  final Color income;
  final Color expense;
  final Color transfer;
  final Color credit;
  final Color warning;
  final Color success;

  @override
  AppMoneyColors copyWith({
    Color? income,
    Color? expense,
    Color? transfer,
    Color? credit,
    Color? warning,
    Color? success,
  }) {
    return AppMoneyColors(
      income: income ?? this.income,
      expense: expense ?? this.expense,
      transfer: transfer ?? this.transfer,
      credit: credit ?? this.credit,
      warning: warning ?? this.warning,
      success: success ?? this.success,
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
    );
  }
}

/// 一套 Hero 渐变。
///
/// 存多档停靠点而不是两个端点：两端插值会经过一段发灰的中间色，
/// 三档才能控制中间那一段的走向。
@immutable
class AppHeroGradient {
  const AppHeroGradient({required this.colors, this.shadowColor});

  final List<Color> colors;

  /// 投影色；为空时用第一档颜色。
  final Color? shadowColor;

  Color get shadow => shadowColor ?? colors.first;

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
    this.amber = const Color(0xFFFFE6BC),
  });

  /// Hero 上的次级数字色（净资产卡里的「负债」、分类预算的超支进度条）。
  ///
  /// 原来是散在三个文件里的硬编码 `#FFD9A0`：它在净资产渐变右端只有 3.44:1，
  /// 不满足 4.5:1。现在提成 token，并由求解器保证在每个渐变端点上 ≥4.5:1。
  final Color amber;

  /// 资产 / 净资产：全局唯一的紫→青冷色渐变（色相跨度 90°+）。
  final AppHeroGradient netWorth;

  /// 品牌：珊瑚 → 品红，用于首页 Hero、预算卡。
  final AppHeroGradient brand;

  /// 告警：超支、失败。
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

  /// 浅色语义色（D2 暖纸 · 靛蓝）。
  ///
  /// 与旧值的区别不只是色相：这五个颜色是在**色觉缺陷模拟空间**里求解出来的 ——
  /// 只把五色调到等明度时，绿色盲下「支出↔收入」的 OKLab ΔE 只有 0.015（几乎同色）；
  /// 这里用明度梯度做冗余编码，红/绿/蓝三种色盲下最差 ΔE 也 ≥0.06，
  /// 同时每个色在 surface / sunken 上都 ≥4.5:1。
  static const moneyColors = AppMoneyColors(
    income: Color(0xFF006E30),
    expense: Color(0xFFA7463C),
    transfer: Color(0xFF004557),
    credit: Color(0xFF7B428C),
    warning: Color(0xFF473D00),
    success: Color(0xFF006E30),
  );

  static const heroGradients = AppHeroGradients(
    netWorth: AppHeroGradient(
      colors: [Color(0xFF6A55C6), Color(0xFF006EA0), Color(0xFF007370)],
    ),
    // 品牌卡（首页 Hero / 预算卡）：暖赭金。
    // 不用冷渐变的原因：纸底是暖色（色相 35°），冷渐变与它近互补（色相差 124~165°）
    // ＋彩度 0.17，一大块冷色压上去会「突兀」。
    // 也不用暖玫：它与超支告警渐变 ΔE 只有 0.03（几乎同色），会把「正常」与「超支」
    // 两个状态糊在一起 —— 旧配色的品牌卡 vs 超支卡 ΔE 也只有 0.08~0.14，同样分不清。
    // 赭金既在暖色区（不突兀），与告警的 ΔE 又有 0.17（分得清）。
    brand: AppHeroGradient(
      colors: [Color(0xFFA15500), Color(0xFF9C6400), Color(0xFF936E00)],
    ),
    danger: AppHeroGradient(
      colors: [Color(0xFFB2397C), Color(0xFFBF3D6D), Color(0xFFCB4453)],
    ),
    amber: AppThemeTokens.lightHeroAmber,
  );

  static const chartPalette = AppChartPalette(
    colors: [
      Color(0xFFA66C11),
      Color(0xFF008B97),
      Color(0xFFA95C8F),
      Color(0xFF77821F),
      Color(0xFF3E7EBF),
      Color(0xFFB75B54),
      Color(0xFF1E9063),
      Color(0xFF816AB9),
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
