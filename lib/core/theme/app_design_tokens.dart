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
}

class AppThemeFallbacks {
  const AppThemeFallbacks._();

  static const moneyColors = AppMoneyColors(
    income: Color(0xFF168A5B),
    expense: Color(0xFFD44D6E),
    transfer: Color(0xFF4F7DD9),
    credit: Color(0xFFB36A18),
    warning: Color(0xFFE08A1E),
    success: Color(0xFF168A5B),
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
