import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_theme_tokens.dart';

/// 两套 `ThemeData`（A 晴空）。
///
/// 这一层只做三件事：把 token 灌进 `ColorScheme`、把「填充色」灌进需要的组件主题、
/// 把语义色/Hero/色板挂成 `ThemeExtension`。**不要在这里写具体颜色值**——
/// 值都在 `app_theme_tokens.dart`，这里只决定「哪个 token 放到哪个槽位」。
class AppTheme {
  const AppTheme._();

  static const _fontFamilyFallback = <String>[
    'Microsoft YaHei UI',
    'Microsoft YaHei',
    'PingFang SC',
    'Hiragino Sans GB',
    'Noto Sans CJK SC',
    'Source Han Sans SC',
    'Roboto',
    'sans-serif',
  ];

  /// 两份 `ThemeData` **只构建一次**。
  ///
  /// 必须缓存，不能每次 build 现造：`MaterialApp` 内部用 `AnimatedTheme` 承载主题，
  /// 它的判断是「新 data 与旧 data 不相等就播一次 [themeAnimationDuration] 过渡」，
  /// 而 `ThemeData.==` 会把 `extensions` 里的对象按**实例**比较 —— 现造的话
  /// `AppTheme.light() != AppTheme.light()` 恒成立（实测 `extensions` 不相等），
  /// 于是 App 根组件每重建一次，整棵树就要被重放一遍 420ms 的主题过渡。
  ///
  /// 根组件（`MijiApp`）长期 watch 了提醒同步 / 预取这类 provider，**切模块时新页面
  /// 加载数据就会把它顶着重建**，于是正好在切模块的那一刻触发约 25 帧的全量重建：
  /// 界面（尤其是成片的背景色）看起来就是「点了之后半天才跟上」。
  ///
  /// 过渡本身没错 —— 它该只在真正换浅/深色时播一次。缓存实例后
  /// `identical` 直接短路了相等判断，切模块不再触发任何主题动画。
  static final ThemeData _light = _buildLight();
  static final ThemeData _dark = _buildDark();

  static ThemeData light() => _light;

  static ThemeData dark() => _dark;

  static ThemeData _buildLight() {
    final theme = FlexThemeData.light(
      colors: const FlexSchemeColor(
        primary: AppThemeTokens.lightPrimary,
        secondary: AppThemeTokens.lightSecondary,
        tertiary: AppThemeTokens.lightTertiary,
      ),
      useMaterial3: true,
    );

    return _withThemeOverrides(
      theme,
      colorScheme: theme.colorScheme.copyWith(
        // primary 是**文字/图标**角色：它在这 230 处被当颜色用在 label / icon 上，
        // 所以必须是过 AA 的深色（#006AB1 在 surface 上 6.4:1）。
        // 实心按钮那种「填充」角色走下面的 primarySolid，两者不能合成一个槽位。
        primary: AppThemeTokens.lightPrimary,
        onPrimary: Colors.white,
        primaryContainer: AppThemeTokens.lightPrimaryContainer,
        onPrimaryContainer: AppThemeTokens.lightOnPrimaryContainer,
        secondary: AppThemeTokens.lightSecondary,
        secondaryContainer: AppThemeTokens.lightSecondaryContainer,
        onSecondaryContainer: AppThemeTokens.lightSecondaryStrong,
        tertiary: AppThemeTokens.lightTertiary,
        tertiaryContainer: AppThemeTokens.lightTertiaryContainer,
        onTertiaryContainer: AppThemeTokens.lightTertiaryStrong,
        // 容器组必须显式给：FlexColorScheme 按本色推出来的容器实测只有 4.13:1
        // （tertiary 那对），达不到「浅底 + 深字 4.5:1」的容器契约。
        // 表单校验、删除确认走语义红，不用 Flex 自己的 error 红——
        // 否则同一个 App 里会出现两种互不相干的「错误红」。
        error: AppThemeFallbacks.moneyColors.expenseStrong,
        onError: AppThemeFallbacks.moneyColors.incomeContainer,
        errorContainer: AppThemeFallbacks.moneyColors.expenseContainer,
        onErrorContainer: AppThemeFallbacks.moneyColors.expenseStrong,
        surface: AppThemeTokens.lightSurface,
        onSurface: AppThemeTokens.lightText,
        onSurfaceVariant: AppThemeTokens.lightTextSecondary,
        // 四级表面阶梯：浅色下 surface 与 raised 刻意同色（白卡浮在灰底上），
        // 所以 Lowest/Low/Container 三档都是白，High/Highest 才是凹槽灰。
        surfaceContainerLowest: AppThemeTokens.lightSurface,
        surfaceContainerLow: AppThemeTokens.lightSurface,
        surfaceContainer: AppThemeTokens.lightSurface,
        surfaceContainerHigh: AppThemeTokens.lightSurfaceSunken,
        surfaceContainerHighest: AppThemeTokens.lightSurfaceSunken,
        outline: AppThemeTokens.lightOutline,
        outlineVariant: AppThemeTokens.lightOutlineVariant,
      ),
      scaffoldBackgroundColor: AppThemeTokens.lightBackground,
      hintColor: AppThemeTokens.lightTextTertiary,
      solidAccent: AppThemeTokens.lightPrimarySolid,
      onSolidAccent: AppThemeTokens.lightOnPrimarySolid,
      moneyColors: AppThemeFallbacks.moneyColors,
      heroGradients: AppThemeFallbacks.heroGradients,
      chartPalette: AppThemeFallbacks.chartPalette,
    );
  }

  static ThemeData _buildDark() {
    final theme = FlexThemeData.dark(
      colors: const FlexSchemeColor(
        primary: AppThemeTokens.darkPrimary,
        secondary: AppThemeTokens.darkSecondary,
        tertiary: AppThemeTokens.darkTertiary,
      ),
      useMaterial3: true,
    );

    return _withThemeOverrides(
      theme,
      colorScheme: theme.colorScheme.copyWith(
        primary: AppThemeTokens.darkPrimary,
        onPrimary: AppThemeTokens.darkOnPrimarySolid,
        primaryContainer: AppThemeTokens.darkPrimaryContainer,
        onPrimaryContainer: AppThemeTokens.darkOnPrimaryContainer,
        secondary: AppThemeTokens.darkSecondary,
        secondaryContainer: AppThemeTokens.darkSecondaryContainer,
        onSecondaryContainer: AppThemeTokens.darkSecondaryStrong,
        tertiary: AppThemeTokens.darkTertiary,
        tertiaryContainer: AppThemeTokens.darkTertiaryContainer,
        onTertiaryContainer: AppThemeTokens.darkTertiaryStrong,
        error: darkMoneyColors.expenseStrong,
        onError: darkMoneyColors.expenseContainer,
        errorContainer: darkMoneyColors.expenseContainer,
        onErrorContainer: darkMoneyColors.expenseStrong,
        surface: AppThemeTokens.darkSurface,
        onSurface: AppThemeTokens.darkText,
        onSurfaceVariant: AppThemeTokens.darkTextSecondary,
        surfaceContainerLowest: AppThemeTokens.darkSurfaceSunken,
        surfaceContainerLow: AppThemeTokens.darkBackground,
        surfaceContainer: AppThemeTokens.darkSurface,
        surfaceContainerHigh: AppThemeTokens.darkSurfaceRaised,
        surfaceContainerHighest: AppThemeTokens.darkSurfaceRaised,
        outline: AppThemeTokens.darkOutline,
        outlineVariant: AppThemeTokens.darkOutlineVariant,
      ),
      scaffoldBackgroundColor: AppThemeTokens.darkBackground,
      hintColor: AppThemeTokens.darkTextTertiary,
      solidAccent: AppThemeTokens.darkPrimarySolid,
      onSolidAccent: AppThemeTokens.darkOnPrimarySolid,
      moneyColors: darkMoneyColors,
      heroGradients: darkHeroGradients,
      chartPalette: darkChartPalette,
    );
  }

  static ThemeData _withThemeOverrides(
    ThemeData theme, {
    required ColorScheme colorScheme,
    required Color scaffoldBackgroundColor,
    required Color hintColor,
    required Color solidAccent,
    required Color onSolidAccent,
    required AppMoneyColors moneyColors,
    required AppHeroGradients heroGradients,
    required AppChartPalette chartPalette,
  }) {
    return theme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      hintColor: hintColor,
      // 实心控件的底色统一走 primarySolid + onPrimarySolid。
      // 不靠 colorScheme.primary 是因为 M3 把「文字色」和「填充色」塞在同一个槽位里，
      // 一个颜色没法同时过「小号文字 4.5:1」和「够鲜亮的按钮」两端。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: solidAccent,
          foregroundColor: onSolidAccent,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: solidAccent,
        foregroundColor: onSolidAccent,
      ),
      // 只覆盖「选中」那一态，未选中交给 M3 默认，避免把描边/高度一起改掉。
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? solidAccent : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? onSolidAccent : null,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: solidAccent),
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      textTheme: _withTextFallback(theme.textTheme),
      primaryTextTheme: _withTextFallback(theme.primaryTextTheme),
      extensions: <ThemeExtension<dynamic>>[
        moneyColors,
        heroGradients,
        chartPalette,
        AppThemeFallbacks.spacingTokens,
        AppThemeFallbacks.radiusTokens,
        AppThemeFallbacks.controlTokens,
      ],
    );
  }

  /// 深色语义色。浅色的在 `AppThemeFallbacks.moneyColors`（那份同时兼「没有扩展时的兜底」），
  /// 深色只需要一份这里用的常量，不再重复一遍。
  static const darkMoneyColors = AppMoneyColors(
    income: Color(0xFF75D290),
    expense: Color(0xFFFF9D9D),
    transfer: Color(0xFF22D1E7),
    credit: Color(0xFFDD9FF1),
    warning: Color(0xFFDBAC45),
    success: Color(0xFF75D290),
    incomeStrong: Color(0xFF90E4A7),
    expenseStrong: Color(0xFFFFBCBA),
    transferStrong: Color(0xFF59E4F7),
    creditStrong: Color(0xFFEDB6FF),
    warningStrong: Color(0xFFECC066),
    incomeContainer: Color(0xFF163620),
    expenseContainer: Color(0xFF462222),
    transferContainer: Color(0xFF00353C),
    creditContainer: Color(0xFF392540),
    warningContainer: Color(0xFF3B2B07),
  );

  static const darkHeroGradients = AppHeroGradients(
    netWorth: AppHeroGradient(
      colors: [Color(0xFF2396F7), Color(0xFF8EA4FF), Color(0xFFA886F6)],
      onColor: AppThemeTokens.darkOnNetWorth,
    ),
    brand: AppHeroGradient(
      colors: [Color(0xFF212A33), Color(0xFF353B43), Color(0xFF2C3038)],
      onColor: AppThemeTokens.darkOnBrand,
    ),
    danger: AppHeroGradient(
      colors: [Color(0xFF861756), Color(0xFFA71E4B), Color(0xFF992127)],
      onColor: AppThemeTokens.darkOnDanger,
    ),
    amber: AppThemeTokens.darkHeroAmber,
  );

  /// 深色色板与浅色**同序**：同一个分类在两个模式下落在同一个色相上。
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

  static TextTheme _withTextFallback(TextTheme textTheme) {
    return textTheme.copyWith(
      displayLarge: _withFontFallback(textTheme.displayLarge),
      displayMedium: _withFontFallback(textTheme.displayMedium),
      displaySmall: _withFontFallback(textTheme.displaySmall),
      headlineLarge: _withFontFallback(textTheme.headlineLarge),
      headlineMedium: _withFontFallback(textTheme.headlineMedium),
      headlineSmall: _withFontFallback(textTheme.headlineSmall),
      titleLarge: _withFontFallback(textTheme.titleLarge),
      titleMedium: _withFontFallback(textTheme.titleMedium),
      titleSmall: _withFontFallback(textTheme.titleSmall),
      bodyLarge: _withFontFallback(textTheme.bodyLarge),
      bodyMedium: _withFontFallback(textTheme.bodyMedium),
      bodySmall: _withFontFallback(textTheme.bodySmall),
      labelLarge: _withFontFallback(textTheme.labelLarge),
      labelMedium: _withFontFallback(textTheme.labelMedium),
      labelSmall: _withFontFallback(textTheme.labelSmall),
    );
  }

  static TextStyle? _withFontFallback(TextStyle? style) {
    return style?.copyWith(
      fontFamilyFallback: _fontFamilyFallback,
      letterSpacing: 0,
    );
  }
}
