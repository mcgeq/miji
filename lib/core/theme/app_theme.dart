import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/core/theme/app_palette.dart';

/// 把某套配色灌进 `ThemeData`。
///
/// 这一层只做三件事：把 palette 的值放进 `ColorScheme`、把「填充色」放进需要的
/// 组件主题、把语义色/Hero/图表色板挂成 `ThemeExtension`。
/// **不要在这里写具体颜色值** —— 九套配色的值都在 `app_palette.dart`，
/// 这里只决定「哪个 token 放到哪个槽位」。
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

  /// **每套配色 × 每个明暗档只构建一次**，按 id 缓存。
  ///
  /// 必须缓存，不能每次 build 现造：`MaterialApp` 内部用 `AnimatedTheme` 承载主题，
  /// 它判断「新 data 与旧 data 不相等就播一次主题过渡」，而 `ThemeData.==` 会把
  /// `extensions` 里的对象按**实例**比较 —— 现造的话
  /// `AppTheme.light() != AppTheme.light()` 恒成立（实测 `extensions` 不相等），
  /// 于是 App 根组件每重建一次，整棵树就要被重放一遍 420ms 的主题过渡。
  ///
  /// 根组件（`MijiApp`）长期 watch 了提醒同步 / 预取这类 provider，**切模块时新页面
  /// 加载数据就会把它顶着重建**，于是正好在切模块的那一刻触发约 25 帧的全量重建：
  /// 界面（尤其是成片的背景色）看起来就是「点了之后半天才跟上」。
  ///
  /// 缓存实例后 `identical` 直接短路了相等判断：切模块不再触发主题动画，
  /// 只有真正换**配色**（key 变了）或换明暗时才播一次过渡 —— 这正是想要的。
  static final Map<String, ThemeData> _cache = <String, ThemeData>{};

  static ThemeData light([String paletteId = AppPalettes.defaultId]) =>
      _forPalette(paletteId, Brightness.light);

  static ThemeData dark([String paletteId = AppPalettes.defaultId]) =>
      _forPalette(paletteId, Brightness.dark);

  static ThemeData _forPalette(String paletteId, Brightness brightness) {
    final palette = AppPalettes.byId(paletteId);
    final key = '${palette.id}:${brightness.name}';
    return _cache.putIfAbsent(key, () => _build(palette, brightness));
  }

  static ThemeData _build(AppPalette palette, Brightness brightness) {
    final mode = palette.of(brightness);
    final dark = brightness == Brightness.dark;
    final brand = mode.brandColors;
    final surface = mode.surfaceColors;
    final money = mode.money;

    final theme = dark
        ? FlexThemeData.dark(
            colors: FlexSchemeColor(
              primary: brand.primary,
              secondary: brand.secondary,
              tertiary: brand.tertiary,
            ),
            useMaterial3: true,
          )
        : FlexThemeData.light(
            colors: FlexSchemeColor(
              primary: brand.primary,
              secondary: brand.secondary,
              tertiary: brand.tertiary,
            ),
            useMaterial3: true,
          );

    return _withThemeOverrides(
      theme,
      colorScheme: theme.colorScheme.copyWith(
        // primary 是**文字/图标**角色：它在库里两百多处被当颜色用在 label / icon 上，
        // 所以必须是过 AA 的那一档（每套都在 surface 上验到 ≥4.5:1）。
        // 实心按钮那种「填充」角色走 solidAccent，两者不能合成一个槽位。
        primary: brand.primary,
        onPrimary: dark ? brand.onPrimarySolid : Colors.white,
        primaryContainer: brand.primaryContainer,
        onPrimaryContainer: brand.onPrimaryContainer,
        secondary: brand.secondary,
        secondaryContainer: brand.secondaryContainer,
        onSecondaryContainer: brand.secondaryStrong,
        tertiary: brand.tertiary,
        tertiaryContainer: brand.tertiaryContainer,
        onTertiaryContainer: brand.tertiaryStrong,
        // 容器组必须显式给：FlexColorScheme 按本色推出来的容器在几套配色上
        // 只有 4.1:1 左右，达不到「浅底 + 深字 4.5:1」的容器契约。
        // 表单校验、删除确认走语义红，不用 Flex 自己的 error 红 ——
        // 否则同一个 App 里会出现两种互不相干的「错误红」。
        error: money.expenseStrong,
        onError: money.expenseContainer,
        errorContainer: money.expenseContainer,
        onErrorContainer: money.expenseStrong,
        surface: surface.surface,
        onSurface: mode.textColors.primary,
        onSurfaceVariant: mode.textColors.secondary,
        // 四级表面阶梯：浅色下 surface 与 raised 刻意同色（白卡浮在灰底上），
        // 所以 Lowest/Low/Container 三档同色，High/Highest 才是凹槽。
        // 深色反过来：Lowest 是最深的凹槽，Low 是页面底，High/Highest 是抬升面。
        surfaceContainerLowest: dark ? surface.sunken : surface.surface,
        surfaceContainerLow: dark ? surface.background : surface.surface,
        surfaceContainer: surface.surface,
        surfaceContainerHigh: dark ? surface.raised : surface.sunken,
        surfaceContainerHighest: dark ? surface.raised : surface.sunken,
        outline: surface.outline,
        outlineVariant: surface.outlineVariant,
      ),
      scaffoldBackgroundColor: surface.background,
      hintColor: mode.textColors.tertiary,
      solidAccent: brand.primarySolid,
      onSolidAccent: brand.onPrimarySolid,
      moneyColors: money,
      heroGradients: mode.hero,
      chartPalette: dark
          ? AppThemeFallbacks.darkChartPalette
          : AppThemeFallbacks.chartPalette,
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
      // 不靠 colorScheme.primary 是因为 M3 把「文字色」和「填充色」塞在同一个
      // 槽位里，一个颜色没法同时过「小号文字 4.5:1」和「够鲜亮的按钮」两端。
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
