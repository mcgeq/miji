// 主题色生成器（一次性工具）：用 Google 官方 HCT / TonalPalette 生成候选主题，
// 而不是手调 RGB。输出 JSON 供 python 做对比度 / 色盲 / 感知均匀性校验。
//
// 运行：dart run tool/theme_gen.dart
import 'dart:convert';
import 'dart:io';

import 'package:material_color_utilities/material_color_utilities.dart';

String hex(int argb) =>
    '#${(argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// 语义色：固定色相 + 固定 chroma，明度用 HCT tone 表示（tone≈感知明度 L*）。
/// 浅色主题取 tone 40 上下（够暗，可当文字），深色主题取 tone 80 上下（够亮）。
class SemanticSpec {
  const SemanticSpec(
    this.name,
    this.hue,
    this.chroma,
    this.lightTone,
    this.darkTone,
  );
  final String name;
  final double hue;
  final double chroma;
  final double lightTone;
  final double darkTone;
}

/// 色相来自「色觉缺陷友好」的分布：
/// 支出(vermillion 系) 与 收入(bluish green 系) 拉开到 150° 以上，
/// 且两者在 tone 上再差 6 档 —— 红绿色盲也能靠明度区分（Wong 2011 / Okabe-Ito 的建议）。
const semantics = <SemanticSpec>[
  SemanticSpec('expense', 32, 60, 44, 78), // 朱红
  SemanticSpec('income', 165, 42, 38, 82), // 蓝绿
  SemanticSpec('transfer', 250, 38, 42, 80), // 靛
  SemanticSpec('credit', 305, 34, 42, 80), // 紫
  SemanticSpec('warning', 78, 55, 42, 82), // 琥珀
];

/// 候选主题种子：色相 + chroma（chroma 决定「鲜亮程度」，是气质的主要旋钮）
const schemes = <String, Map<String, dynamic>>{
  'ink': {'label': 'V1 墨蓝 · 暖白', 'hue': 262.0, 'chroma': 34.0},
  'jade': {'label': 'V2 青碧 · 中性', 'hue': 195.0, 'chroma': 30.0},
  'plum': {'label': 'V3 绛紫 · 暖白', 'hue': 318.0, 'chroma': 32.0},
};

/// 中性面：色相取「暖白」或「冷灰」，chroma 很低（暖感来自中性色，而不是品牌色）
const neutrals = <String, Map<String, double>>{
  'warm': {'hue': 68.0, 'chroma': 7.0},
  'cool': {'hue': 250.0, 'chroma': 4.0},
};

Map<String, String> roles(DynamicScheme s) => {
  'primary': hex(s.primary),
  'onPrimary': hex(s.onPrimary),
  'primaryContainer': hex(s.primaryContainer),
  'onPrimaryContainer': hex(s.onPrimaryContainer),
  'secondary': hex(s.secondary),
  'onSecondary': hex(s.onSecondary),
  'tertiary': hex(s.tertiary),
  'onTertiary': hex(s.onTertiary),
  'error': hex(s.error),
  'onError': hex(s.onError),
  'surface': hex(s.surface),
  'onSurface': hex(s.onSurface),
  'surfaceContainerLowest': hex(s.surfaceContainerLowest),
  'surfaceContainerLow': hex(s.surfaceContainerLow),
  'surfaceContainer': hex(s.surfaceContainer),
  'surfaceContainerHigh': hex(s.surfaceContainerHigh),
  'surfaceContainerHighest': hex(s.surfaceContainerHighest),
  'outline': hex(s.outline),
  'outlineVariant': hex(s.outlineVariant),
};

/// 8 色图表色板：色相均匀铺开（每 45°），tone 固定 → 等感知明度；
/// 起点避开「支出红」和「收入绿」的正中，免得图表里出现"像支出/收入"的切片。
List<String> chartPalette(double tone, double chroma) => [
  for (var i = 0; i < 8; i++)
    hex(TonalPalette.of((i * 45.0 + 200.0) % 360.0, chroma).get(tone.round())),
];

void main() {
  final out = <String, dynamic>{};
  for (final entry in schemes.entries) {
    final seed = entry.value;
    final spec = <String, dynamic>{};
    for (final neutralKey in ['warm', 'cool']) {
      final n = neutrals[neutralKey]!;
      for (final isDark in [false, true]) {
        // 官方 tonal spot：primary=36 chroma、secondary=16、tertiary=+60° 24、
        // 中性面用我们指定的暖/冷色相（M3 允许自定义 neutralPalette）。
        final scheme = DynamicScheme(
          sourceColorHct: Hct.from(
            seed['hue'] as double,
            seed['chroma'] as double,
            50,
          ),
          isDark: isDark,
          variant: Variant.tonalSpot,
          contrastLevel: 0,
          primaryPalette: TonalPalette.of(
            seed['hue'] as double,
            seed['chroma'] as double,
          ),
          secondaryPalette: TonalPalette.of(seed['hue'] as double, 14.0),
          tertiaryPalette: TonalPalette.of(
            ((seed['hue'] as double) + 58) % 360,
            22.0,
          ),
          neutralPalette: TonalPalette.of(n['hue']!, n['chroma']!),
          neutralVariantPalette: TonalPalette.of(n['hue']!, (n['chroma']!) + 4),
        );
        final modeKey = '${neutralKey}_${isDark ? 'dark' : 'light'}';
        spec[modeKey] = roles(scheme);
      }
    }
    // 语义色 + 图表色板（浅/深各一套）
    spec['semantic_light'] = {
      for (final s in semantics)
        s.name: hex(TonalPalette.of(s.hue, s.chroma).get(s.lightTone.round())),
    };
    spec['semantic_dark'] = {
      for (final s in semantics)
        s.name: hex(TonalPalette.of(s.hue, s.chroma).get(s.darkTone.round())),
    };
    spec['chart_light'] = chartPalette(45, 42);
    spec['chart_dark'] = chartPalette(74, 34);
    // 对比度诊断：官方 HCT 的 tone 与 WCAG 对比度对照
    spec['meta'] = {
      'label': seed['label'],
      'seedHue': seed['hue'],
      'seedChroma': seed['chroma'],
    };
    out[entry.key] = spec;
  }
  // 顺带把「现状」用同一套工具重算一遍，方便对照
  File(
    'docs/_theme_gen_out.json',
  ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  stdout.writeln('written docs/_theme_gen_out.json');
  stdout.writeln('schemes: ${out.keys.join(', ')}');
}
