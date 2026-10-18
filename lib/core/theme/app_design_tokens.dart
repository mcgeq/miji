import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_color_tokens.dart';
import 'package:miji/core/theme/app_palette.dart';

/// 颜色类型（语义色 / Hero 渐变 / 图表色板）在 `app_color_tokens.dart`，
/// 具体色值在 `app_palette.dart`。这里只留**与颜色无关**的那三层 token：
/// 间距、圆角、控件尺寸 —— 它们不随配色变，所以不进 palette。
export 'package:miji/core/theme/app_color_tokens.dart';

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
  /// 没有配色扩展时（裸 `ThemeData()`、组件单测直接 `MaterialApp()`）回退到
  /// 默认配色的浅色档，而不是抛异常 —— 组件不该为了「拿不到主题」而崩。
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

  /// 回退用：默认配色的浅色档。跑在真实 App 里时永远走扩展，
  /// 这组值只在「没有 MaterialApp 主题」的组件测试里露脸。
  static AppMoneyColors get moneyColors =>
      AppPalettes.byId(AppPalettes.defaultId).light.money;

  static AppHeroGradients get heroGradients =>
      AppPalettes.byId(AppPalettes.defaultId).light.hero;

  /// 图表 8 色**九套配色共用**。
  ///
  /// 图表色板表达的是「八个分类彼此可分」，不是品牌气质：换成石墨/手账，
  /// 饼图也不该跟着变成棕色系 —— 那样八个扇区会黏在一起。
  /// 它们只守一条：每个色对卡片 ≥3:1（非文字图形标准）。
  /// 深浅两套**顺序一致**：同一个分类在两个模式下落在同一个色相上，
  /// 用户切换明暗时「哪块是谁」不会重排。
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

  static const darkChartPalette = AppChartPalette(
    colors: [
      Color(0xFFFF9F9E),
      Color(0xFF72C278),
      Color(0xFFDEA3F8),
      Color(0xFF18C7AF),
      Color(0xFFE7B54E),
      Color(0xFF82AAFF),
      Color(0xFFFFA47A),
      Color(0xFF00C3D4),
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
