import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// 计划的颜色值对象。
///
/// 为什么不再用裸字符串：`#RRGGBB` 到处都是（表单、渲染、导出、种子），而
/// 拼错一个字符只有在屏幕上才会被发现。集中成一个类型之后，解析只发生一次、
/// 失败有明确出口（[tryParse] 返回 null），也不用每个调用点各写一遍
/// `int.parse(raw.replaceFirst('#', '0xff'))`。
///
/// 存储仍是 `#RRGGBB` 字符串，与旧数据、导出 JSON 完全一致。
@immutable
class PlanColor {
  const PlanColor._(this.value);

  /// 直接给定 0xRRGGBB 的常量构造（给代码里的常量色用，不做校验）。
  const PlanColor.rgb(this.value);

  /// 0xRRGGBB（不含 alpha）。
  final int value;

  static PlanColor? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    final text = raw.trim().replaceFirst('#', '');
    if (text.length != 6) {
      return null;
    }
    final parsed = int.tryParse(text, radix: 16);
    if (parsed == null) {
      return null;
    }
    return PlanColor._(parsed);
  }

  /// 解析失败回落用（调用方明确知道自己在兜底时才用）。
  factory PlanColor.parseOr(String? raw, PlanColor fallback) {
    return tryParse(raw) ?? fallback;
  }

  /// 从 HSV 构造。色相 0–360，饱和度与明度 0–1。
  ///
  /// 表单的自定义调色用它：滑杆操作的是 HSV，而人挑颜色时想的也是「偏蓝一点、
  /// 淡一点」，不是 RGB 三个通道各是多少。
  factory PlanColor.fromHsv({
    required double hue,
    required double saturation,
    required double value,
  }) {
    final hsv = HSVColor.fromAHSV(
      1,
      hue % 360,
      saturation.clamp(0.0, 1.0),
      value.clamp(0.0, 1.0),
    );
    final argb = hsv.toColor().toARGB32() & 0xFFFFFF;
    return PlanColor._(argb);
  }

  /// 给调色盘回填用的 HSV。
  HSVColor get hsv => HSVColor.fromColor(color);

  Color get color => Color(0xFF000000 | value);

  /// 落库 / 导出用的形式，与大写十六进制无关（解析是大小写不敏感的）。
  String get hex => '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// 在它上面写字该用黑还是白。给「色块 + 文字」的地方用。
  Color get onColor {
    final c = color;
    // 相对亮度的近似（sRGB 加权），阈值 0.55 对中间调够用。
    final luminance = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
    return luminance > 0.55 ? const Color(0xFF1B1A17) : const Color(0xFFFFFFFF);
  }

  @override
  bool operator ==(Object other) => other is PlanColor && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => hex;
}

/// 模型没显式给颜色时的默认值。
///
/// 与历史上写死的 `'#6366F1'` 保持一致：老数据、老导出读回来仍是同一个颜色，
/// 升级不会让任何一条计划换色。
const PlanColor defaultSeedPlanColor = PlanColor.rgb(0x6366F1);
