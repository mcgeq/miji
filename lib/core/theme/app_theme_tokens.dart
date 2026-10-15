import 'package:flutter/material.dart';

/// 主题色 token —— **A 晴空（Azure）**。
///
/// 来源：`docs/specs/theme-redesign-v2-mockup.html` 的 A 组（同目录 `theme-solver/tokens2.json`），
/// 对标钱迹的宝蓝 + 冷白灰底。它取代了上一版「暖纸 · 靛蓝」，不是为了换个心情，
/// 而是因为旧体系有三处结构性问题：
///
/// 1. **中性面靠四级明度分层，实际只差 4%**，肉眼分不出层级。新版把中性面做成近乎无彩
///    （背景 `#F3F6F9` 灰、卡片 `#FFFFFF` 白），层级交给「白浮在灰上」+ 阴影/描边，
///    所以 [_lightSurfaceRaised] 与 [_lightSurface] **刻意同色**。
/// 2. **主色有两套语义打架**：旧 `primary` 与 `primaryFill` 并存、深色下还互换。
///    新版拆成三个各管一件事的角色：[_lightPrimary] 只做文字/图标（surface 上 ≥4.5:1）、
///    [_lightPrimarySolid] 做实心按钮/FAB 底（配 [_lightOnPrimarySolid] —— 浅色是**深字**，
///    代码里不要写死白字）、[_lightPrimaryContainer] 做 chip 浅底。
/// 3. **语义色被按正文的 4.5:1 卡住，只能退成暗浊色**（旧值是 `#0D5900` 墨绿）。
///    金额是超大号粗体，WCAG 只要 **3:1**；放宽后才是 [_lightIncome] `#2B933E` 这种正绿。
///    小号语义文字另配一套深版（`*Strong`）仍然守 4.5:1，见 [AppMoneyColors]。
///
/// 所有数值都按 WCAG 对比度与 OKLab ΔE 校验过；校验断言落在
/// `test/core/theme/app_theme_contrast_test.dart`，求解脚本在 `docs/specs/theme-solver/`。
///
/// 注意：三个方向的「固有代价」是主色与某一个语义色的感知距离很近
/// （A 是 0.023，蓝↔转账青）。这不是求解失败——五个语义色几乎占满色环，主色放哪都会挨着谁，
/// 竞品的橙/绿主色同样如此。解法是**场景隔离**：主色只出现在按钮/导航/图标，
/// 语义色只出现在金额/tag，二者从不并置到需要互相判别。
class AppThemeTokens {
  const AppThemeTokens._();

  // ───────────── 浅色：晴空 · 宝蓝 ─────────────

  /// 中性面。surface 与 raised 同色，层级靠阴影/描边，不靠明度微差。
  static const lightBackground = Color(0xFFF3F6F9);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFFFFFFF);
  static const lightSurfaceSunken = Color(0xFFEBEDF0);

  /// 描边两档：`outline` 是控件描边（≥3:1，WCAG 1.4.11），`outlineVariant` 只用于分隔线。
  static const lightOutline = Color(0xFF848C94);
  static const lightOutlineVariant = Color(0xFFD9DDE1);

  /// 文字三档。`textSecondary` 在 surface 与 sunken 上都 ≥4.5:1；
  /// `textTertiary` 是提示/占位层（4.36:1），只用于可省的辅助信息。
  static const lightText = Color(0xFF15171A);
  static const lightTextSecondary = Color(0xFF585B5E);
  static const lightTextTertiary = Color(0xFF797C7F);

  /// 主色：文字/图标版，在 surface 上 6.4:1。
  static const lightPrimary = Color(0xFF006AB1);

  /// 主色：填充版。用于实心按钮 / FAB / 分段控件，配 [lightOnPrimarySolid]。
  static const lightPrimarySolid = Color(0xFF008EE9);
  static const lightOnPrimarySolid = Color(0xFF001830);

  /// 主色：选中态浅底（chip、导航高亮）。
  static const lightPrimaryContainer = Color(0xFFDFEFFF);
  static const lightOnPrimaryContainer = Color(0xFF004D83);

  /// M3 语义修正：secondary 是**弱化的品牌色**（同色相低彩度），不是「收入绿」。
  static const lightSecondary = Color(0xFF5D7791);

  /// 第三强调色：给「第三类东西」用（登录页的介绍条目、次要 badge）。
  /// A 方向下它是青，与主色蓝、次要蓝灰都分得开。
  static const lightTertiary = Color(0xFF438883);

  /// 供 badge / 小号文字用的第三、次要强调色深版（在 [lightSurfaceSunken] 上仍 ≥4.5:1）。
  static const lightSecondaryStrong = Color(0xFF3F566E);
  static const lightTertiaryStrong = Color(0xFF275E5A);

  /// 次要 / 第三强调色的浅底。
  ///
  /// A 的 token 表只给了这两个色的本色，容器得自己定：`ColorScheme` 的
  /// `secondaryContainer` / `tertiaryContainer` 由 FlexColorScheme 推导，
  /// 实测浅色 tertiary 那对只有 4.13:1。这里按「本色混入 surface，底色上的字用
  /// Strong 档」补齐，并保证字底 ≥4.5:1。
  static const lightSecondaryContainer = Color(0xFFE5E9ED);
  static const lightTertiaryContainer = Color(0xFFE1ECEB);

  /// Hero 三张卡的正文色。**不是每张卡都能配白字**：净资产卡是亮蓝渐变，
  /// 白字只有 2.2~3.3:1，必须配深字（[lightOnNetWorth]）；品牌/超支卡是深卡，白字才成立。
  static const lightOnNetWorth = Color(0xFF10152C);
  static const lightOnBrand = Color(0xFFFFFFFF);
  static const lightOnDanger = Color(0xFFFFFFFF);

  /// Hero 卡上的琥珀小字（品牌卡的告警数字、超支进度）。
  ///
  /// 它是暖色，而 A 的中性面是冷色——但只出现在**深卡内部**（石墨 / 深红），
  /// 与冷色底不同框，所以不冲突；换成冷色反而丢掉「告警」的语义。
  static const lightHeroAmber = Color(0xFFFFE6BC);

  // ───────────── 深色：晴空 · 宝蓝（暗色重定档，不是浅色调暗） ─────────────

  /// 深灰蓝底，越上层越亮。旧版是 `#0E0A07` 近黑，压在暗环境里太硬。
  static const darkSurfaceSunken = Color(0xFF181A1C);
  static const darkBackground = Color(0xFF222426);
  static const darkSurface = Color(0xFF303234);
  static const darkSurfaceRaised = Color(0xFF3D3F42);

  static const darkOutline = Color(0xFF838A92);
  static const darkOutlineVariant = Color(0xFF494E52);

  static const darkText = Color(0xFFEBEDEE);
  static const darkTextSecondary = Color(0xFFACAFB2);
  static const darkTextTertiary = Color(0xFF898C90);

  static const darkPrimary = Color(0xFF89C5FF);
  static const darkPrimarySolid = Color(0xFF74BCFF);
  static const darkOnPrimarySolid = Color(0xFF001B33);
  static const darkPrimaryContainer = Color(0xFF093050);
  static const darkOnPrimaryContainer = Color(0xFFAFD7FF);

  static const darkSecondary = Color(0xFFA6C1DC);
  static const darkTertiary = Color(0xFF7CD3CD);

  static const darkSecondaryStrong = Color(0xFFCFE4FA);
  static const darkTertiaryStrong = Color(0xFF9FE8E2);

  /// 深色容器比卡片更深（往 background 混），这样彩色底在卡片上是「陷下去」的。
  static const darkSecondaryContainer = Color(0xFF3C434A);
  static const darkTertiaryContainer = Color(0xFF344747);

  static const darkOnNetWorth = Color(0xFF10152C);
  static const darkOnBrand = Color(0xFFFFFFFF);
  static const darkOnDanger = Color(0xFFFFFFFF);

  static const darkHeroAmber = Color(0xFFFFE6BC);
}
