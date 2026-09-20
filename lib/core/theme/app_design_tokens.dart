import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

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
  });

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
  }) {
    return AppHeroGradients(
      netWorth: netWorth ?? this.netWorth,
      brand: brand ?? this.brand,
      danger: danger ?? this.danger,
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
  });

  final double pageCompact;
  final double pageRegular;
  final double sectionGap;
  final double cardPadding;
  final double fieldGap;

  @override
  AppSpacingTokens copyWith({
    double? pageCompact,
    double? pageRegular,
    double? sectionGap,
    double? cardPadding,
    double? fieldGap,
  }) {
    return AppSpacingTokens(
      pageCompact: pageCompact ?? this.pageCompact,
      pageRegular: pageRegular ?? this.pageRegular,
      sectionGap: sectionGap ?? this.sectionGap,
      cardPadding: cardPadding ?? this.cardPadding,
      fieldGap: fieldGap ?? this.fieldGap,
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
  });

  final double sm;
  final double md;
  final double lg;
  final double pill;

  @override
  AppRadiusTokens copyWith({double? sm, double? md, double? lg, double? pill}) {
    return AppRadiusTokens(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
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
}

class AppThemeFallbacks {
  const AppThemeFallbacks._();

  /// 浅色语义色。
  ///
  /// 每个值都保证在白色 / 暖白 / 次表面三种底色上 ≥4.5:1（WCAG AA），
  /// 并且两两色相距离 ≥25°：原来的值在暖白底上只有 2.55~4.14:1，
  /// 其中 warning 与背景色相只差 5.7°，天然吃亏。
  static const moneyColors = AppMoneyColors(
    income: Color(0xFF157F41),
    expense: Color(0xFFCD323F),
    transfer: Color(0xFF2270BF),
    credit: Color(0xFF8757BE),
    warning: Color(0xFF856C06),
    success: Color(0xFF157F41),
  );

  static const heroGradients = AppHeroGradients(
    netWorth: AppHeroGradient(colors: [Color(0xFF6C507B), Color(0xFF2C8089)]),
    brand: AppHeroGradient(
      colors: [Color(0xFFC25144), Color(0xFFC0515C), Color(0xFFBE506A)],
    ),
    danger: AppHeroGradient(
      colors: [Color(0xFF9E001D), Color(0xFFB00020), Color(0xFFBD1D45)],
    ),
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
