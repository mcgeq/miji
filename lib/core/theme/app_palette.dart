import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_color_tokens.dart';

/// 一套配色里「面」的部分：底色、卡片、凹槽、描边。
///
/// 浅色下 [surface] 与 [raised] **刻意同色**：层级靠「白卡浮在灰底上」+ 阴影，
/// 不靠明度微差（四级明度只差 4% 时肉眼根本分不出层级）。
@immutable
class AppSurfaceColors {
  const AppSurfaceColors({
    required this.background,
    required this.surface,
    required this.raised,
    required this.sunken,
    required this.outline,
    required this.outlineVariant,
  });

  /// 页面底。允许带一点倾向（暖纸灰 / 微紫 / 冷青 / 暖米），不是纯灰。
  final Color background;

  /// 卡片面。绝大多数内容都在这层上。
  final Color surface;

  /// 抬升面（对话框、悬浮层）。浅色下与 [surface] 同色；深色下必须更亮一档。
  final Color raised;

  /// 凹槽（输入框底、分段控件轨道）。
  final Color sunken;

  /// 控件描边，守 3:1（WCAG 1.4.11 非文字图形）。
  final Color outline;

  /// 分隔线。只要求「看得见」，不要求 3:1。
  final Color outlineVariant;
}

/// 文字三档。
///
/// 前两档守 4.5:1；[tertiary] 是提示/占位层（可省的辅助信息），
/// 与旧体系一样只守 3:1 —— 把它也压到 4.5 会让提示文字读起来像正文。
@immutable
class AppTextColors {
  const AppTextColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;
}

/// 品牌色三个角色 + 次要/第三强调色。
///
/// [primary] / [primarySolid] **不能合并**：`primary` 在库里两百多处当小号
/// 文字和图标色用，必须过 4.5:1；`primarySolid` 要够鲜亮当实心按钮底，
/// 配 [onPrimarySolid]（浅色下通常是**深字**，代码里别写死白字）。
/// M3 把这两个角色塞在同一个 `primary` 槽位里，一个颜色兼顾不了两端。
@immutable
class AppBrandColors {
  const AppBrandColors({
    required this.primary,
    required this.primarySolid,
    required this.onPrimarySolid,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryStrong,
    required this.secondaryContainer,
    required this.tertiary,
    required this.tertiaryStrong,
    required this.tertiaryContainer,
  });

  /// 文字/图标版主色（surface 上 ≥4.5:1）。
  final Color primary;

  /// 填充版主色：实心按钮、FAB、分段选中态。
  final Color primarySolid;
  final Color onPrimarySolid;

  /// 选中态浅底（chip、导航高亮）与它上面的字。
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// 弱化的品牌色（同色系压彩度），不是「收入绿」。
  final Color secondary;
  final Color secondaryStrong;
  final Color secondaryContainer;

  /// 第三强调色。九套里它按「品牌色色相转 180°、彩度压到 0.2」派生 ——
  /// 直接取主色 +140° 会落到支出红或收入绿上，和语义色撞车。
  final Color tertiary;
  final Color tertiaryStrong;
  final Color tertiaryContainer;
}

/// 一套配色的**一个明暗档**。
///
/// 换配色 = 换 [money] / [hero] / 品牌色 / 中性面这四组值，主题装配代码一行不动。
/// 深浅两档是**各自定档**，不是把浅色整体压暗：深色下主色要反过来提亮，
/// 卡片要抬到页面底之上，投影要用暗色。
@immutable
class AppPaletteMode {
  const AppPaletteMode({
    required this.surfaceColors,
    required this.textColors,
    required this.brandColors,
    required this.money,
    required this.hero,
  });

  final AppSurfaceColors surfaceColors;
  final AppTextColors textColors;
  final AppBrandColors brandColors;
  final AppMoneyColors money;
  final AppHeroGradients hero;

  /// 设置页的预览三色：主色实心、页面底、支出红。
  /// 三个刚好交代「品牌 / 面 / 语义」三层，再多就变成调色盘了。
  List<Color> get swatches => [
    brandColors.primarySolid,
    surfaceColors.background,
    money.expense,
  ];
}

/// 一套配色（浅 + 深）。
@immutable
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.tagline,
    required this.light,
    required this.dark,
  });

  /// 持久化用的稳定 id。**改名可以，改 id 会把用户已选的配色打回默认。**
  final String id;

  final String name;

  /// 一句话说明这套配色的取舍，显示在设置页的选择卡上。
  final String tagline;

  final AppPaletteMode light;
  final AppPaletteMode dark;

  AppPaletteMode of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}

/// 九套配色的全部色值。
///
/// ## 为什么是九套而不是一套「最优解」
///
/// 配色没有唯一解，只有取舍：石墨把彩度收到近乎无彩，换来「异常一眼可见」；
/// 手账把界面做成暖米色，换来「像纸质账本」的松弛感，代价是户外强光下层次变弱。
/// 与其替用户猜，不如给几套各自站得住的方案让他自己选。
///
/// ## 四层结构（九套都守这一条）
///
/// 1. **中性面**：底 / 卡 / 描边 / 文字，彩度 ≤6%，不承载语义；
/// 2. **语义色**：收 / 支 / 转账 / 信用 / 告警，只出现在金额和 tag 上；
/// 3. **品牌色**：导航、主操作 —— 这层才是「换配色」真正改变的东西；
/// 4. **领域色**（健康模块）：不进本表，见 `features/health`。
///
/// 九个颜色同时出现在一屏时人会数不清，所以「红」不合并也不新增，
/// 而是靠**载体**区分：支出红在金额、待办高优先级红在竖条、经期红在日历格。
///
/// ## 数值怎么来的
///
/// 先在 `docs/specs/theme-redesign-v3-mockup.html` 里按设计意图定主色与中性面，
/// 再由 `app_theme_contrast_test.dart` 逐项验算；派生规则写在下面对应字段的注释里。
/// **运行时不求解任何颜色**，表里的值就是渲染的值。
class AppPalettes {
  const AppPalettes._();

  /// 默认配色。改这里 = 改所有新用户的第一次观感。
  static const defaultId = 'ink';

  /// v2 的宝蓝配冷白，兼容老用户的观感
  static const azure = AppPalette(
    id: 'azure',
    name: '经典蔚蓝',
    tagline: 'v2 的宝蓝配冷白，兼容老用户的观感',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF3F6F9),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFEBEDF0),
        outline: Color(0xFF848C94),
        outlineVariant: Color(0xFFD9DDE1),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF15171A),
        secondary: Color(0xFF585B5E),
        tertiary: Color(0xFF797C7F),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF006AB1),
        primarySolid: Color(0xFF008EE9),
        onPrimarySolid: Color(0xFF001830),
        primaryContainer: Color(0xFFDFEFFF),
        onPrimaryContainer: Color(0xFF004D83),
        secondary: Color(0xFF5D7791),
        secondaryStrong: Color(0xFF3F566E),
        secondaryContainer: Color(0xFFE5E9ED),
        tertiary: Color(0xFF438883),
        tertiaryStrong: Color(0xFF275E5A),
        tertiaryContainer: Color(0xFFE1ECEB),
      ),
      money: AppMoneyColors(
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
        warningStrong: Color(0xFF886400),
        incomeContainer: Color(0xFFD6F7D7),
        expenseContainer: Color(0xFFFFE6E5),
        transferContainer: Color(0xFFC3F8FF),
        creditContainer: Color(0xFFF7E6FF),
        warningContainer: Color(0xFFFFEAC4),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF188FF0), Color(0xFF859DFF), Color(0xFFA280EF)],
          onColor: Color(0xFF10152C),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF1D252D), Color(0xFF30363E), Color(0xFF282B32)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF30363E),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF800E50), Color(0xFFA01445), Color(0xFF921921)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFFFC94F),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF222426),
        surface: Color(0xFF303234),
        raised: Color(0xFF3D3F42),
        sunken: Color(0xFF181A1C),
        outline: Color(0xFF838A92),
        outlineVariant: Color(0xFF494E52),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFEBEDEE),
        secondary: Color(0xFFACAFB2),
        tertiary: Color(0xFF898C90),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF89C5FF),
        primarySolid: Color(0xFF74BCFF),
        onPrimarySolid: Color(0xFF001B33),
        primaryContainer: Color(0xFF093050),
        onPrimaryContainer: Color(0xFFAFD7FF),
        secondary: Color(0xFFA6C1DC),
        secondaryStrong: Color(0xFFCFE4FA),
        secondaryContainer: Color(0xFF3C434A),
        tertiary: Color(0xFF7CD3CD),
        tertiaryStrong: Color(0xFF9FE8E2),
        tertiaryContainer: Color(0xFF344747),
      ),
      money: AppMoneyColors(
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
        warningStrong: Color(0xFFDBAC45),
        incomeContainer: Color(0xFF163620),
        expenseContainer: Color(0xFF462222),
        transferContainer: Color(0xFF00353C),
        creditContainer: Color(0xFF392540),
        warningContainer: Color(0xFF3B2B07),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2396F7), Color(0xFF8EA4FF), Color(0xFFA886F6)],
          onColor: Color(0xFF10152C),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF353A42), Color(0xFF454A53), Color(0xFF3C414A)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF0F1011),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF861756), Color(0xFFA71E4B), Color(0xFF992127)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFFFC94F),
      ),
    ),
  );

  /// 深靛压住界面，暖纸灰底，默认
  static const ink = AppPalette(
    id: 'ink',
    name: '靛墨',
    tagline: '深靛压住界面，暖纸灰底，默认',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF3F3F1),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFEAE9E5),
        outline: Color(0xFF8D8C87),
        outlineVariant: Color(0xFFDAD9D6),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF1B1A17),
        secondary: Color(0xFF5C5A54),
        tertiary: Color(0xFF8B8880),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF2A3C5C),
        primarySolid: Color(0xFF24344F),
        onPrimarySolid: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE5E9F1),
        onPrimaryContainer: Color(0xFF28374F),
        secondary: Color(0xFF464D58),
        secondaryStrong: Color(0xFF464D58),
        secondaryContainer: Color(0xFFE9EAEB),
        tertiary: Color(0xFF776950),
        tertiaryStrong: Color(0xFF71634C),
        tertiaryContainer: Color(0xFFEFEDEA),
      ),
      money: AppMoneyColors(
        income: Color(0xFF0E7A48),
        expense: Color(0xFFB93A2C),
        transfer: Color(0xFF2C6E93),
        credit: Color(0xFF8E5AA8),
        warning: Color(0xFFA9701A),
        success: Color(0xFF0E7A48),
        incomeStrong: Color(0xFF0E7747),
        expenseStrong: Color(0xFFB93A2C),
        transferStrong: Color(0xFF2C6E92),
        creditStrong: Color(0xFF85539E),
        warningStrong: Color(0xFF8D5E16),
        incomeContainer: Color(0xFFE2F0E8),
        expenseContainer: Color(0xFFF9E6E2),
        transferContainer: Color(0xFFE2EDF3),
        creditContainer: Color(0xFFF1EBF5),
        warningContainer: Color(0xFFF3EBDF),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFE5EAF4), Color(0xFFE6E8F0), Color(0xFFFFFFFF)],
          onColor: Color(0xFF1B1A17),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF2C3E56), Color(0xFF1F2D3F), Color(0xFF16202E)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF1F2D3F),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF792D24), Color(0xFF5E211A), Color(0xFF4B1913)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF15171A),
        surface: Color(0xFF22252A),
        raised: Color(0xFF303337),
        sunken: Color(0xFF111316),
        outline: Color(0xFF767674),
        outlineVariant: Color(0xFF48494A),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFEDECE8),
        secondary: Color(0xFFACA9A3),
        tertiary: Color(0xFF87847D),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFA8C3E8),
        primarySolid: Color(0xFF8FB0DC),
        onPrimarySolid: Color(0xFF0B1A2C),
        primaryContainer: Color(0xFF23303D),
        onPrimaryContainer: Color(0xFFBCD3EE),
        secondary: Color(0xFFAAB5C2),
        secondaryStrong: Color(0xFFAAB5C2),
        secondaryContainer: Color(0xFF2A2D32),
        tertiary: Color(0xFFBAAB97),
        tertiaryStrong: Color(0xFFBAAB97),
        tertiaryContainer: Color(0xFF2F2F2E),
      ),
      money: AppMoneyColors(
        income: Color(0xFF4FC286),
        expense: Color(0xFFF2776A),
        transfer: Color(0xFF6BB6DA),
        credit: Color(0xFFA67EBB),
        warning: Color(0xFFE0A94E),
        success: Color(0xFF4FC286),
        incomeStrong: Color(0xFF4FC286),
        expenseStrong: Color(0xFFF2776A),
        transferStrong: Color(0xFF6BB6DA),
        creditStrong: Color(0xFFB899C9),
        warningStrong: Color(0xFFE0A94E),
        incomeContainer: Color(0xFF1B3227),
        expenseContainer: Color(0xFF38211F),
        transferContainer: Color(0xFF1B2C34),
        creditContainer: Color(0xFF3C3747),
        warningContainer: Color(0xFF443D30),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF29313C), Color(0xFF222830), Color(0xFF23282F)],
          onColor: Color(0xFFEDECE8),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF2E3D52), Color(0xFF24303F), Color(0xFF222A36)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF090A0C),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6B2A24), Color(0xFF511E1A), Color(0xFF421B18)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 低饱和紫灰，个性最强、不撞脸
  static const violet = AppPalette(
    id: 'violet',
    name: '紫檀',
    tagline: '低饱和紫灰，个性最强、不撞脸',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF4F3F8),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFEAE8F1),
        outline: Color(0xFF8D8A95),
        outlineVariant: Color(0xFFDAD8DD),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF1A1720),
        secondary: Color(0xFF5A5566),
        tertiary: Color(0xFF8A8594),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF4E3C78),
        primarySolid: Color(0xFF544180),
        onPrimarySolid: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE9E3F4),
        onPrimaryContainer: Color(0xFF453468),
        secondary: Color(0xFF554A6E),
        secondaryStrong: Color(0xFF554A6E),
        secondaryContainer: Color(0xFFEBE9EE),
        tertiary: Color(0xFF646F4A),
        tertiaryStrong: Color(0xFF5F6946),
        tertiaryContainer: Color(0xFFECEEE9),
      ),
      money: AppMoneyColors(
        income: Color(0xFF0C7A4C),
        expense: Color(0xFFB23A38),
        transfer: Color(0xFF2B6A93),
        credit: Color(0xFFB04A8E),
        warning: Color(0xFFA26B1A),
        success: Color(0xFF0C7A4C),
        incomeStrong: Color(0xFF0C774A),
        expenseStrong: Color(0xFFB23A38),
        transferStrong: Color(0xFF2B6A93),
        creditStrong: Color(0xFFA44584),
        warningStrong: Color(0xFF8E5D17),
        incomeContainer: Color(0xFFE1F0E8),
        expenseContainer: Color(0xFFF9E5E3),
        transferContainer: Color(0xFFE1ECF3),
        creditContainer: Color(0xFFF6E9F1),
        warningContainer: Color(0xFFF2EADF),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFECE7F5), Color(0xFFEFEAF3), Color(0xFFFFFFFF)],
          onColor: Color(0xFF1A1720),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF3E3160), Color(0xFF2F244A), Color(0xFF241B3A)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF2F244A),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7C2C33), Color(0xFF602027), Color(0xFF4C171F)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF16151B),
        surface: Color(0xFF25242C),
        raised: Color(0xFF33323A),
        sunken: Color(0xFF111016),
        outline: Color(0xFF777380),
        outlineVariant: Color(0xFF4A4752),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFEDEBF2),
        secondary: Color(0xFFABA6B6),
        tertiary: Color(0xFF868190),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFC0B0E9),
        primarySolid: Color(0xFFA795D8),
        onPrimarySolid: Color(0xFF1A1230),
        primaryContainer: Color(0xFF2B2440),
        onPrimaryContainer: Color(0xFFD3C6F2),
        secondary: Color(0xFFB4AACD),
        secondaryStrong: Color(0xFFB4AACD),
        secondaryContainer: Color(0xFF2C2A34),
        tertiary: Color(0xFFB0BA97),
        tertiaryStrong: Color(0xFFB0BA97),
        tertiaryContainer: Color(0xFF2F2F2F),
      ),
      money: AppMoneyColors(
        income: Color(0xFF4EC28C),
        expense: Color(0xFFF17A78),
        transfer: Color(0xFF69B4D8),
        credit: Color(0xFFC472A8),
        warning: Color(0xFFDFA84D),
        success: Color(0xFF4EC28C),
        incomeStrong: Color(0xFF4EC28C),
        expenseStrong: Color(0xFFF17A78),
        transferStrong: Color(0xFF69B4D8),
        creditStrong: Color(0xFFD191BB),
        warningStrong: Color(0xFFDFA84D),
        incomeContainer: Color(0xFF1B3229),
        expenseContainer: Color(0xFF38211F),
        transferContainer: Color(0xFF1B2C34),
        creditContainer: Color(0xFF453445),
        warningContainer: Color(0xFF463C32),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2F2A3D), Color(0xFF272533), Color(0xFF24242E)],
          onColor: Color(0xFFEDEBF2),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF40345E), Color(0xFF302748), Color(0xFF29223C)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF0A090C),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6E2930), Color(0xFF531D24), Color(0xFF431921)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 墨绿主色，清新克制，与健康模块同语气
  static const celadon = AppPalette(
    id: 'celadon',
    name: '青瓷',
    tagline: '墨绿主色，清新克制，与健康模块同语气',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF1F4F1),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFE6EBE7),
        outline: Color(0xFF878D8B),
        outlineVariant: Color(0xFFD8DAD9),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF171A19),
        secondary: Color(0xFF545C59),
        tertiary: Color(0xFF848B88),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF1F5A4C),
        primarySolid: Color(0xFF245F51),
        onPrimarySolid: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFDEEAE4),
        onPrimaryContainer: Color(0xFF1C4E43),
        secondary: Color(0xFF3C5B53),
        secondaryStrong: Color(0xFF3C5B53),
        secondaryContainer: Color(0xFFE8EBEA),
        tertiary: Color(0xFF815660),
        tertiaryStrong: Color(0xFF815660),
        tertiaryContainer: Color(0xFFF0EBEC),
      ),
      money: AppMoneyColors(
        income: Color(0xFF1E9155),
        expense: Color(0xFFB03B33),
        transfer: Color(0xFF2A6E90),
        credit: Color(0xFF9A5AA6),
        warning: Color(0xFFA06F1D),
        success: Color(0xFF1E9155),
        incomeStrong: Color(0xFF197746),
        expenseStrong: Color(0xFFB03B33),
        transferStrong: Color(0xFF2A6E90),
        creditStrong: Color(0xFF8C5298),
        warningStrong: Color(0xFF8A6019),
        incomeContainer: Color(0xFFE1F0E7),
        expenseContainer: Color(0xFFF8E5E2),
        transferContainer: Color(0xFFE0EBF1),
        creditContainer: Color(0xFFF3EBF4),
        warningContainer: Color(0xFFF2EBDF),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFE4EEE9), Color(0xFFE5EDEB), Color(0xFFFFFFFF)],
          onColor: Color(0xFF171A19),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF254C42), Color(0xFF1B3B33), Color(0xFF132E28)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF1B3B33),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7B3227), Color(0xFF5F251C), Color(0xFF4B1B14)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF141817),
        surface: Color(0xFF202624),
        raised: Color(0xFF2E3432),
        sunken: Color(0xFF0F1211),
        outline: Color(0xFF6F7774),
        outlineVariant: Color(0xFF454C4A),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFE9EFEC),
        secondary: Color(0xFFA6B0AC),
        tertiary: Color(0xFF828B87),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF8FCDB9),
        primarySolid: Color(0xFF7BBFA9),
        onPrimarySolid: Color(0xFF062019),
        primaryContainer: Color(0xFF213330),
        onPrimaryContainer: Color(0xFFA9DCC9),
        secondary: Color(0xFF9CBDB2),
        secondaryStrong: Color(0xFF9CBDB2),
        secondaryContainer: Color(0xFF272F2D),
        tertiary: Color(0xFFBA97A2),
        tertiaryStrong: Color(0xFFBA97A2),
        tertiaryContainer: Color(0xFF2F2C2D),
      ),
      money: AppMoneyColors(
        income: Color(0xFF4FC98E),
        expense: Color(0xFFEF7C6E),
        transfer: Color(0xFF6BB2D4),
        credit: Color(0xFFAE7AB8),
        warning: Color(0xFFDEA64C),
        success: Color(0xFF4FC98E),
        incomeStrong: Color(0xFF4FC98E),
        expenseStrong: Color(0xFFEF7C6E),
        transferStrong: Color(0xFF6BB2D4),
        creditStrong: Color(0xFFBF96C7),
        warningStrong: Color(0xFFDEA64C),
        incomeContainer: Color(0xFF18322A),
        expenseContainer: Color(0xFF372120),
        transferContainer: Color(0xFF1A2C33),
        creditContainer: Color(0xFF3C3742),
        warningContainer: Color(0xFF423D2B),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2A3330), Color(0xFF232B29), Color(0xFF222826)],
          onColor: Color(0xFFE9EFEC),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF284A41), Color(0xFF1D3932), Color(0xFF152C27)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF090B0A),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6B2D24), Color(0xFF50201A), Color(0xFF411B17)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 咖啡棕配米白卡，最像纸质账本
  static const clay = AppPalette(
    id: 'clay',
    name: '手账',
    tagline: '咖啡棕配米白卡，最像纸质账本',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF6F2EC),
        surface: Color(0xFFFFFDF9),
        raised: Color(0xFFFFFDF9),
        sunken: Color(0xFFEEE8DF),
        outline: Color(0xFF928B82),
        outlineVariant: Color(0xFFDAD6CF),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF1F1A15),
        secondary: Color(0xFF5E554A),
        tertiary: Color(0xFF8C8275),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF6A4B38),
        primarySolid: Color(0xFF6A4B38),
        onPrimarySolid: Color(0xFFFFF8EF),
        primaryContainer: Color(0xFFEFE3D6),
        onPrimaryContainer: Color(0xFF5B3F2E),
        secondary: Color(0xFF635042),
        secondaryStrong: Color(0xFF635042),
        secondaryContainer: Color(0xFFECE8E3),
        tertiary: Color(0xFF546E7F),
        tertiaryStrong: Color(0xFF4F6878),
        tertiaryContainer: Color(0xFFEAECEA),
      ),
      money: AppMoneyColors(
        income: Color(0xFF3F7A45),
        expense: Color(0xFFB2442E),
        transfer: Color(0xFF3A6B7C),
        credit: Color(0xFF8C5A78),
        warning: Color(0xFFA66A1E),
        success: Color(0xFF3F7A45),
        incomeStrong: Color(0xFF3C7341),
        expenseStrong: Color(0xFFB1442E),
        transferStrong: Color(0xFF3A6B7C),
        creditStrong: Color(0xFF8A5876),
        warningStrong: Color(0xFF905C1A),
        incomeContainer: Color(0xFFE6EFE2),
        expenseContainer: Color(0xFFF8E6DF),
        transferContainer: Color(0xFFE3EDEF),
        creditContainer: Color(0xFFF1E9EA),
        warningContainer: Color(0xFFF3E8DA),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFF0E7DB), Color(0xFFEDE9DE), Color(0xFFFFFDF9)],
          onColor: Color(0xFF1F1A15),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF4C3B2E), Color(0xFF392C22), Color(0xFF2B211A)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF392C22),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7D3122), Color(0xFF622419), Color(0xFF4E1B12)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF191512),
        surface: Color(0xFF28231F),
        raised: Color(0xFF36312D),
        sunken: Color(0xFF120E0B),
        outline: Color(0xFF7D746C),
        outlineVariant: Color(0xFF4F4741),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFF1EBE3),
        secondary: Color(0xFFB6AAA0),
        tertiary: Color(0xFF8E8278),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFD8B79C),
        primarySolid: Color(0xFFC6A488),
        onPrimarySolid: Color(0xFF2A190E),
        primaryContainer: Color(0xFF2E241C),
        onPrimaryContainer: Color(0xFFE9CFB8),
        secondary: Color(0xFFC5B09E),
        secondaryStrong: Color(0xFFC5B09E),
        secondaryContainer: Color(0xFF312B26),
        tertiary: Color(0xFF97AABA),
        tertiaryStrong: Color(0xFF97AABA),
        tertiaryContainer: Color(0xFF2D2D2D),
      ),
      money: AppMoneyColors(
        income: Color(0xFF8BC98F),
        expense: Color(0xFFF0896F),
        transfer: Color(0xFF7FB4C0),
        credit: Color(0xFFAC7F9A),
        warning: Color(0xFFDFA857),
        success: Color(0xFF8BC98F),
        incomeStrong: Color(0xFF8BC98F),
        expenseStrong: Color(0xFFF0896F),
        transferStrong: Color(0xFF7FB4C0),
        creditStrong: Color(0xFFBD99AE),
        warningStrong: Color(0xFFDFA857),
        incomeContainer: Color(0xFF23301F),
        expenseContainer: Color(0xFF38211C),
        transferContainer: Color(0xFF1E2C30),
        creditContainer: Color(0xFF423538),
        warningContainer: Color(0xFF493B29),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF362F2A), Color(0xFF2A2420), Color(0xFF2B2623)],
          onColor: Color(0xFFF1EBE3),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF4A3A2D), Color(0xFF372C22), Color(0xFF2E251F)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF0B0908),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6E2D20), Color(0xFF532017), Color(0xFF441C16)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 近乎无彩，只有金额和分类有颜色
  static const graphite = AppPalette(
    id: 'graphite',
    name: '石墨',
    tagline: '近乎无彩，只有金额和分类有颜色',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF2F2F0),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFE8E8E5),
        outline: Color(0xFF8C8C89),
        outlineVariant: Color(0xFFDADAD8),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF171716),
        secondary: Color(0xFF5A5A57),
        tertiary: Color(0xFF8A8A85),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF232323),
        primarySolid: Color(0xFF232323),
        onPrimarySolid: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE8E8E5),
        onPrimaryContainer: Color(0xFF232323),
        secondary: Color(0xFF414140),
        secondaryStrong: Color(0xFF414140),
        secondaryContainer: Color(0xFFE8E8E8),
        tertiary: Color(0xFF4C5D6B),
        tertiaryStrong: Color(0xFF4C5D6B),
        tertiaryContainer: Color(0xFFEAECED),
      ),
      money: AppMoneyColors(
        income: Color(0xFF1B7A4A),
        expense: Color(0xFFC0392B),
        transfer: Color(0xFF3A6B8A),
        credit: Color(0xFF8A6E9C),
        warning: Color(0xFFB4771E),
        success: Color(0xFF1B7A4A),
        incomeStrong: Color(0xFF1A7547),
        expenseStrong: Color(0xFFBB382A),
        transferStrong: Color(0xFF3A6B8A),
        creditStrong: Color(0xFF775D88),
        warningStrong: Color(0xFF8D5D18),
        incomeContainer: Color(0xFFE2F0E8),
        expenseContainer: Color(0xFFF9E4E1),
        transferContainer: Color(0xFFE3ECF1),
        creditContainer: Color(0xFFF1EEF3),
        warningContainer: Color(0xFFF5ECE0),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFE7E7E4), Color(0xFFFCFCFA), Color(0xFFFFFFFF)],
          onColor: Color(0xFF171716),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF3B3B37), Color(0xFF2B2B2A), Color(0xFF202020)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF2B2B2A),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7A2A22), Color(0xFF5E1E19), Color(0xFF4A1512)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFEAA94A),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF121212),
        surface: Color(0xFF21211F),
        raised: Color(0xFF2F2F2D),
        sunken: Color(0xFF0D0D0D),
        outline: Color(0xFF73736F),
        outlineVariant: Color(0xFF464643),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFEDEDEA),
        secondary: Color(0xFFA9A9A4),
        tertiary: Color(0xFF82827D),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFE6E6E1),
        primarySolid: Color(0xFFDCDCD6),
        onPrimarySolid: Color(0xFF141413),
        primaryContainer: Color(0xFF2A2A28),
        onPrimaryContainer: Color(0xFFE6E6E1),
        secondary: Color(0xFFC4C4BF),
        secondaryStrong: Color(0xFFC4C4BF),
        secondaryContainer: Color(0xFF2B2B2A),
        tertiary: Color(0xFFB9CBD8),
        tertiaryStrong: Color(0xFFB9CBD8),
        tertiaryContainer: Color(0xFF2D3032),
      ),
      money: AppMoneyColors(
        income: Color(0xFF58C98C),
        expense: Color(0xFFF07C6E),
        transfer: Color(0xFF78B6D4),
        credit: Color(0xFF9980A8),
        warning: Color(0xFFDFA94F),
        success: Color(0xFF58C98C),
        incomeStrong: Color(0xFF58C98C),
        expenseStrong: Color(0xFFF07C6E),
        transferStrong: Color(0xFF78B6D4),
        creditStrong: Color(0xFFAC98B9),
        warningStrong: Color(0xFFDFA94F),
        incomeContainer: Color(0xFF1A2F26),
        expenseContainer: Color(0xFF37211F),
        transferContainer: Color(0xFF1B2B33),
        creditContainer: Color(0xFF39343A),
        warningContainer: Color(0xFF433928),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2F2F2E), Color(0xFF262625), Color(0xFF252524)],
          onColor: Color(0xFFEDEDEA),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF35352F), Color(0xFF2B2B26), Color(0xFF232320)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF080808),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6B251E), Color(0xFF511915), Color(0xFF421613)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFE8A33E),
      ),
    ),
  );

  /// 明度最高、最轻，最接近大众审美的干净
  static const harbour = AppPalette(
    id: 'harbour',
    name: '雾蓝',
    tagline: '明度最高、最轻，最接近大众审美的干净',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF1F5F8),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFE7EDF2),
        outline: Color(0xFF848D94),
        outlineVariant: Color(0xFFD8DCE1),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF141A1F),
        secondary: Color(0xFF54616B),
        tertiary: Color(0xFF8593A0),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF2C5A7C),
        primarySolid: Color(0xFF31648A),
        onPrimarySolid: Color(0xFFFFFFFF),
        primaryContainer: Color(0xFFE0EBF3),
        onPrimaryContainer: Color(0xFF234C67),
        secondary: Color(0xFF425E73),
        secondaryStrong: Color(0xFF425E73),
        secondaryContainer: Color(0xFFE8ECEE),
        tertiary: Color(0xFF806856),
        tertiaryStrong: Color(0xFF796251),
        tertiaryContainer: Color(0xFFF0EDEB),
      ),
      money: AppMoneyColors(
        income: Color(0xFF167A4E),
        expense: Color(0xFFB93B34),
        transfer: Color(0xFF2C7E8C),
        credit: Color(0xFF8B5AC4),
        warning: Color(0xFFA5731C),
        success: Color(0xFF167A4E),
        incomeStrong: Color(0xFF16784D),
        expenseStrong: Color(0xFFB93B34),
        transferStrong: Color(0xFF28727F),
        creditStrong: Color(0xFF844FC0),
        warningStrong: Color(0xFF8C6118),
        incomeContainer: Color(0xFFE1F0E8),
        expenseContainer: Color(0xFFF9E5E3),
        transferContainer: Color(0xFFE0EEF0),
        creditContainer: Color(0xFFF1EBF8),
        warningContainer: Color(0xFFF2EBDF),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFE2EBF3), Color(0xFFE6EDF2), Color(0xFFFFFFFF)],
          onColor: Color(0xFF141A1F),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF2E5372), Color(0xFF223E56), Color(0xFF1A2F42)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF223E56),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7A2E26), Color(0xFF5E211A), Color(0xFF4A1712)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0BC69),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF131820),
        surface: Color(0xFF1F262F),
        raised: Color(0xFF2D343D),
        sunken: Color(0xFF0E1319),
        outline: Color(0xFF6D7780),
        outlineVariant: Color(0xFF454E57),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFEAEEF2),
        secondary: Color(0xFFA6B1BB),
        tertiary: Color(0xFF828E99),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF9CC6E4),
        primarySolid: Color(0xFF82B6D9),
        onPrimarySolid: Color(0xFF0A1D2C),
        primaryContainer: Color(0xFF1F2E3B),
        onPrimaryContainer: Color(0xFFB4D5EC),
        secondary: Color(0xFFA2BACD),
        secondaryStrong: Color(0xFFA2BACD),
        secondaryContainer: Color(0xFF272F38),
        tertiary: Color(0xFFBAA597),
        tertiaryStrong: Color(0xFFBAA597),
        tertiaryContainer: Color(0xFF2E2F33),
      ),
      money: AppMoneyColors(
        income: Color(0xFF4FC28C),
        expense: Color(0xFFF0786C),
        transfer: Color(0xFF6FC0CE),
        credit: Color(0xFFA37CD0),
        warning: Color(0xFFDEA64C),
        success: Color(0xFF4FC28C),
        incomeStrong: Color(0xFF4FC28C),
        expenseStrong: Color(0xFFF0786C),
        transferStrong: Color(0xFF6FC0CE),
        creditStrong: Color(0xFFB698DA),
        warningStrong: Color(0xFFDEA64C),
        incomeContainer: Color(0xFF1A2F27),
        expenseContainer: Color(0xFF372120),
        transferContainer: Color(0xFF1A2E31),
        creditContainer: Color(0xFF39374F),
        warningContainer: Color(0xFF413D34),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2C3440), Color(0xFF202731), Color(0xFF242A33)],
          onColor: Color(0xFFEAEEF2),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF2C4A66), Color(0xFF20384E), Color(0xFF182B3C)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF090B0E),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6E2822), Color(0xFF531C18), Color(0xFF441915)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 暖陶土主色，支出主动退成绛红
  static const terracotta = AppPalette(
    id: 'terracotta',
    name: '陶土',
    tagline: '暖陶土主色，支出主动退成绛红',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF8F3EE),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFF0E8DF),
        outline: Color(0xFF928C85),
        outlineVariant: Color(0xFFDBD7D3),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF1E1915),
        secondary: Color(0xFF5F564C),
        tertiary: Color(0xFF8E8377),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF9A4E2F),
        primarySolid: Color(0xFFA1522F),
        onPrimarySolid: Color(0xFFFFF6EE),
        primaryContainer: Color(0xFFF6E2D4),
        onPrimaryContainer: Color(0xFF7E3D22),
        secondary: Color(0xFF7A523F),
        secondaryStrong: Color(0xFF7A523F),
        secondaryContainer: Color(0xFFEFEAE8),
        tertiary: Color(0xFF536F7C),
        tertiaryStrong: Color(0xFF4E6975),
        tertiaryContainer: Color(0xFFEAEEEF),
      ),
      money: AppMoneyColors(
        income: Color(0xFF2F7D4E),
        expense: Color(0xFF8E2F3E),
        transfer: Color(0xFF3A6B7C),
        credit: Color(0xFF8E5A9E),
        warning: Color(0xFF8A6A12),
        success: Color(0xFF2F7D4E),
        incomeStrong: Color(0xFF2C7549),
        expenseStrong: Color(0xFF8E2F3E),
        transferStrong: Color(0xFF3A6B7C),
        creditStrong: Color(0xFF865596),
        warningStrong: Color(0xFF826311),
        incomeContainer: Color(0xFFE3EFE5),
        expenseContainer: Color(0xFFF6E3E6),
        transferContainer: Color(0xFFE3EDEF),
        creditContainer: Color(0xFFF1EBF3),
        warningContainer: Color(0xFFEFEADE),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFF6E9DE), Color(0xFFF3E9E0), Color(0xFFFFFFFF)],
          onColor: Color(0xFF1E1915),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF5A3826), Color(0xFF432A1F), Color(0xFF33201A)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF432A1F),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF7A2733), Color(0xFF5D1C26), Color(0xFF48141C)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF1A1613),
        surface: Color(0xFF292420),
        raised: Color(0xFF37322E),
        sunken: Color(0xFF120F0D),
        outline: Color(0xFF7E746D),
        outlineVariant: Color(0xFF504841),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFF0E9E1),
        secondary: Color(0xFFB7AAA0),
        tertiary: Color(0xFF8F8278),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFE0A886),
        primarySolid: Color(0xFFD09673),
        onPrimarySolid: Color(0xFF2B1509),
        primaryContainer: Color(0xFF33251E),
        onPrimaryContainer: Color(0xFFEFC9AE),
        secondary: Color(0xFFC9A994),
        secondaryStrong: Color(0xFFC9A994),
        secondaryContainer: Color(0xFF322B25),
        tertiary: Color(0xFF97ADBA),
        tertiaryStrong: Color(0xFF97ADBA),
        tertiaryContainer: Color(0xFF2E2E2E),
      ),
      money: AppMoneyColors(
        income: Color(0xFF8AC98E),
        expense: Color(0xFFEF8A93),
        transfer: Color(0xFF7FB6C4),
        credit: Color(0xFFA87EB5),
        warning: Color(0xFFDFA94D),
        success: Color(0xFF8AC98E),
        incomeStrong: Color(0xFF8AC98E),
        expenseStrong: Color(0xFFEF8A93),
        transferStrong: Color(0xFF7FB6C4),
        creditStrong: Color(0xFFBA99C4),
        warningStrong: Color(0xFFDFA94D),
        incomeContainer: Color(0xFF24301F),
        expenseContainer: Color(0xFF38202A),
        transferContainer: Color(0xFF1E2C30),
        creditContainer: Color(0xFF42363E),
        warningContainer: Color(0xFF4A3C28),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF342E2A), Color(0xFF2B2623), Color(0xFF2B2623)],
          onColor: Color(0xFFF0E9E1),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF4E3225), Color(0xFF3A251C), Color(0xFF34251F)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF0C0A09),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF6B2531), Color(0xFF501923), Color(0xFF451B22)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFF0B455),
      ),
    ),
  );

  /// 黑蓝配香槟金，金只用在按钮和进度上
  static const midnight = AppPalette(
    id: 'midnight',
    name: '午夜',
    tagline: '黑蓝配香槟金，金只用在按钮和进度上',
    light: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFFF2F3F6),
        surface: Color(0xFFFFFFFF),
        raised: Color(0xFFFFFFFF),
        sunken: Color(0xFFE8EAEF),
        outline: Color(0xFF898C94),
        outlineVariant: Color(0xFFD9DADE),
      ),
      textColors: AppTextColors(
        primary: Color(0xFF14161C),
        secondary: Color(0xFF565A66),
        tertiary: Color(0xFF878B97),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFF1B2233),
        primarySolid: Color(0xFFA8823F),
        onPrimarySolid: Color(0xFF211605),
        primaryContainer: Color(0xFFE7E9EF),
        onPrimaryContainer: Color(0xFF1B2233),
        secondary: Color(0xFF3B414F),
        secondaryStrong: Color(0xFF3B414F),
        secondaryContainer: Color(0xFFE7E8EA),
        tertiary: Color(0xFF8A6A3A),
        tertiaryStrong: Color(0xFF7E6035),
        tertiaryContainer: Color(0xFFF1EDE7),
      ),
      money: AppMoneyColors(
        income: Color(0xFF147A4C),
        expense: Color(0xFFB93A34),
        transfer: Color(0xFF2E6E93),
        credit: Color(0xFFA374B4),
        warning: Color(0xFF9C6B18),
        success: Color(0xFF147A4C),
        incomeStrong: Color(0xFF14774A),
        expenseStrong: Color(0xFFB93A34),
        transferStrong: Color(0xFF2E6E93),
        creditStrong: Color(0xFF88549B),
        warningStrong: Color(0xFF8B6015),
        incomeContainer: Color(0xFFE1F0E8),
        expenseContainer: Color(0xFFF9E5E3),
        transferContainer: Color(0xFFE1EDF3),
        creditContainer: Color(0xFFF5EFF6),
        warningContainer: Color(0xFFF1EADF),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFFE6E9F0), Color(0xFFEAEBEE), Color(0xFFFFFFFF)],
          onColor: Color(0xFF14161C),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF222B3D), Color(0xFF19202F), Color(0xFF121825)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF19202F),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF752A24), Color(0xFF5A1D18), Color(0xFF47140F)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFD9B36B),
      ),
    ),
    dark: AppPaletteMode(
      surfaceColors: AppSurfaceColors(
        background: Color(0xFF111318),
        surface: Color(0xFF202329),
        raised: Color(0xFF2E3137),
        sunken: Color(0xFF0C0E12),
        outline: Color(0xFF71747C),
        outlineVariant: Color(0xFF454950),
      ),
      textColors: AppTextColors(
        primary: Color(0xFFECEDF0),
        secondary: Color(0xFFA7AAB4),
        tertiary: Color(0xFF82868F),
      ),
      brandColors: AppBrandColors(
        primary: Color(0xFFC3CBDD),
        primarySolid: Color(0xFFD9B36B),
        onPrimarySolid: Color(0xFF241A08),
        primaryContainer: Color(0xFF232935),
        onPrimaryContainer: Color(0xFFC8D2E5),
        secondary: Color(0xFFB4B9C6),
        secondaryStrong: Color(0xFFB4B9C6),
        secondaryContainer: Color(0xFF282A30),
        tertiary: Color(0xFFD3B27A),
        tertiaryStrong: Color(0xFFD3B27A),
        tertiaryContainer: Color(0xFF302C28),
      ),
      money: AppMoneyColors(
        income: Color(0xFF4FC28A),
        expense: Color(0xFFF0776F),
        transfer: Color(0xFF6FB2D4),
        credit: Color(0xFFA87BB8),
        warning: Color(0xFFDCA950),
        success: Color(0xFF4FC28A),
        incomeStrong: Color(0xFF4FC28A),
        expenseStrong: Color(0xFFF0776F),
        transferStrong: Color(0xFF6FB2D4),
        creditStrong: Color(0xFFB996C6),
        warningStrong: Color(0xFFDCA950),
        incomeContainer: Color(0xFF192F27),
        expenseContainer: Color(0xFF372120),
        transferContainer: Color(0xFF1A2B33),
        creditContainer: Color(0xFF3B3546),
        warningContainer: Color(0xFF423B30),
      ),
      hero: AppHeroGradients(
        netWorth: AppHeroGradient(
          colors: [Color(0xFF2A2D35), Color(0xFF24262E), Color(0xFF22252B)],
          onColor: Color(0xFFECEDF0),
        ),
        brand: AppHeroGradient(
          colors: [Color(0xFF2A3446), Color(0xFF212938), Color(0xFF1F2531)],
          onColor: Color(0xFFFFFFFF),
          shadowColor: Color(0xFF08090B),
        ),
        danger: AppHeroGradient(
          colors: [Color(0xFF692823), Color(0xFF4F1B17), Color(0xFF411713)],
          onColor: Color(0xFFFFFFFF),
        ),
        amber: Color(0xFFD9B36B),
      ),
    ),
  );
  static const all = <AppPalette>[
    azure,
    ink,
    violet,
    celadon,
    clay,
    graphite,
    harbour,
    terracotta,
    midnight,
  ];

  /// 按 id 取配色；未知 id（旧版本存下来的、手改过的）退回默认，
  /// 不让一个坏字符串把整个 App 的配色搞成黑白。
  static AppPalette byId(String? id) {
    if (id == null) {
      return byId(defaultId);
    }
    for (final palette in all) {
      if (palette.id == id) {
        return palette;
      }
    }
    for (final palette in all) {
      if (palette.id == defaultId) {
        return palette;
      }
    }
    return azure;
  }
}
