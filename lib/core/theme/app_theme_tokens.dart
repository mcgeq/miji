import 'package:flutter/material.dart';

/// 主题色 token。
///
/// 设计来源：`docs/theme-studio.html` 的 **D2 暖纸 · 靛蓝**（从零设计的一套配色，
/// 不复用旧的暖珊瑚体系）。构造规则：
///
/// 1. **中性层**负责“暖”：暖白纸感的色相 72°、彩度极低（0.010），只靠明度分 4 级
///    （sunken < bg < surface < raised）。暖感来自中性层，不来自品牌色。
/// 2. **强调层**分两个角色：`primary` 用于文字/图标（过 AA），`primaryFill` 用于填充
///    （更鲜亮，配深色前景 onPrimaryFill）。填充与前景是联合求解的 —— 中间明度的颜色
///    任何前景都到不了 4.5:1。
/// 3. **语义层**（AppMoneyColors）色相固定，明度按“色觉缺陷可辨梯度”求解：
///    五种语义色在红/绿/蓝色盲下两两 ΔE 仍 ≥0.06（等明度方案只有 0.015）。
/// 4. **描边**分两档：`outline` 是控件描边（≥3:1，WCAG 1.4.11），
///    `outlineVariant` 只用于分隔线。
///
/// 所有数值都由 `docs/theme_verify.py` 校验过：WCAG 对比度、APCA(Lc)、
/// OKLab ΔE、以及 Viénot/Brettel 色觉缺陷模拟。
class AppThemeTokens {
  const AppThemeTokens._();

  // ───────────── 浅色：暖纸 · 靛蓝 ─────────────

  /// 强调色（文字/图标版）：surface 上 4.66:1，配白字 4.86:1。
  static const lightPrimary = Color(0xFF4269D3);

  /// 强调色（填充版）：鲜亮，用于实心按钮/分段控件/大色块，配 [lightOnPrimaryFill]。
  static const lightPrimaryFill = Color(0xFF5E88F6);
  static const lightOnPrimaryFill = Color(0xFF03001F);

  /// 选中态配对（M3 的 container 语义）：实测 7.0:1。
  static const lightPrimaryContainer = Color(0xFFDDE8FF);
  static const lightOnPrimaryContainer = Color(0xFF2E488E);

  /// M3 语义修正：secondary 是 **弱化的品牌色**（同色相低彩度），不是“收入绿”。
  static const lightSecondary = Color(0xFF626E8A);
  static const lightTertiary = Color(0xFF8B608C);

  /// GTD 模块的专注色：独立的青，避免与强调色/语义色混同。
  static const lightFocus = Color(0xFF007C7D);
  static const lightFocusContainer = Color(0xFFCDE9E9);

  /// 中性层四级 + 两档描边。
  static const lightSurfaceSunken = Color(0xFFECE7E1);
  static const lightBackground = Color(0xFFF2EDE6);
  static const lightSurface = Color(0xFFFBF6F0);
  static const lightSurfaceRaised = Color(0xFFF6F1EB);
  static const lightOutline = Color(0xFF998D80);
  static const lightOutlineVariant = Color(0xFFDAD5CF);

  static const lightText = Color(0xFF1B1813);
  static const lightTextSecondary = Color(0xFF615D58);

  /// Hero 上的次级数字（“负债”），在净资产渐变上 4.63:1。
  static const lightHeroAmber = Color(0xFFFFE6BC);

  // ───────────── 深色：暖纸 · 靛蓝（暗色重定档，不是浅色调暗） ─────────────

  static const darkPrimary = Color(0xFF759DFF);
  static const darkPrimaryFill = Color(0xFFCADBFF);
  static const darkOnPrimaryFill = Color(0xFF03001F);
  static const darkPrimaryContainer = Color(0xFF1E2A4A);
  static const darkOnPrimaryContainer = Color(0xFFAEC6FF);

  static const darkSecondary = Color(0xFF919EBB);
  static const darkTertiary = Color(0xFFBE8FBE);

  static const darkFocus = Color(0xFF3DAEB0);
  static const darkFocusContainer = Color(0xFF0E3F40);

  static const darkSurfaceSunken = Color(0xFF090604);
  static const darkBackground = Color(0xFF0E0A07);
  static const darkSurface = Color(0xFF17130F);
  static const darkSurfaceRaised = Color(0xFF221D18);
  static const darkOutline = Color(0xFF6B6257);
  static const darkOutlineVariant = Color(0xFF322E2A);

  static const darkText = Color(0xFFE7E2DC);
  static const darkTextSecondary = Color(0xFF98938D);

  static const darkHeroAmber = Color(0xFFFFE6BC);
}
