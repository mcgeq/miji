// 计划的内置 emoji 与配色。
//
// 为什么要有这一份常量：`CheckinPlan.icon` 是自由文本、默认 `'📌'`，于是每个
// 没挑过图标的计划前面都挂着一枚图钉 —— 它不表达任何信息，却比计划名还抢眼。
// 内置一套按分类的 emoji，创建时默认就选中一个「像那么回事」的。
//
// 为什么用 emoji 而不是 Material 图标：种子里的 17 个模板（喝水💧、早睡🌙、
// 散步🚶…）本来就有一套精选 emoji，用户换图标时应该在同一套词汇里挑，
// 而不是被塞进另一套视觉语言。
import 'package:flutter/foundation.dart';

import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/plan_color.dart';

/// 分类的固定顺序。表单的下拉、emoji 表、默认值都以它为准。
const List<CheckinPlanCategory> checkinPlanCategories =
    CheckinPlanCategory.values;

/// 历史默认值：等于「没选过图标」。渲染时会被替换成分类的默认 emoji。
const String legacyDefaultPlanIcon = '📌';

/// 一个内置 emoji 选项：表情 + 中文标签。
///
/// 为什么要标签：光看图钉 / 星星 / 碎片，没人知道它代表「收藏」还是「其他」；
/// 挑图标时得先读得懂。标签同时充当图标的 tooltip —— 列表里那枚小图也能解释。
@immutable
class PlanEmojiOption {
  const PlanEmojiOption(this.emoji, this.label);

  final String emoji;

  /// 中文标签（「喝水」「散步」这种，两三个字）。
  final String label;
}

/// 每个分类内置的 emoji。
///
/// 每个分类的第一个是**默认值**（新建时自动选中）。种子模板里用过的 emoji
/// 都在表里，这样「新建 → 选中 → 之后又改回默认」不会变成两套风格。
///
/// 「其他」这一组换过一轮：原来是 ⭐ ✅ 🎯 🔔 🌟 📎 🧩 🕒 —— 星、铃铛、碎片
/// 既不好看也说不清是什么。现在换成能看到具体事物的：打卡、兴趣、备忘、
/// 家务、联系、娱乐、采购、心情。它是新建计划的默认分类，第一眼看到的就是它。
const Map<CheckinPlanCategory, List<PlanEmojiOption>> checkinPlanEmojis =
    <CheckinPlanCategory, List<PlanEmojiOption>>{
      CheckinPlanCategory.healthHabit: <PlanEmojiOption>[
        PlanEmojiOption('💧', '喝水'),
        PlanEmojiOption('🌙', '早睡'),
        PlanEmojiOption('🍚', '吃饭'),
        PlanEmojiOption('🚽', '如厕'),
        PlanEmojiOption('🚿', '洗澡'),
        PlanEmojiOption('💊', '吃药'),
        PlanEmojiOption('🧘', '冥想'),
        PlanEmojiOption('🏥', '体检'),
      ],
      CheckinPlanCategory.study: <PlanEmojiOption>[
        PlanEmojiOption('📖', '阅读'),
        PlanEmojiOption('📚', '读书'),
        PlanEmojiOption('📝', '笔记'),
        PlanEmojiOption('✍️', '写作'),
        PlanEmojiOption('🎧', '听课'),
        PlanEmojiOption('🎓', '课程'),
        PlanEmojiOption('💡', '灵感'),
        PlanEmojiOption('🧮', '练习'),
      ],
      CheckinPlanCategory.exercise: <PlanEmojiOption>[
        PlanEmojiOption('🚶', '散步'),
        PlanEmojiOption('🏃', '跑步'),
        PlanEmojiOption('🚴', '骑行'),
        PlanEmojiOption('🏊', '游泳'),
        PlanEmojiOption('🏋️', '健身'),
        PlanEmojiOption('🤸', '拉伸'),
        PlanEmojiOption('⚽', '球类'),
        PlanEmojiOption('🏸', '羽毛球'),
      ],
      CheckinPlanCategory.lifeLog: <PlanEmojiOption>[
        PlanEmojiOption('📸', '拍照'),
        PlanEmojiOption('🍜', '美食'),
        PlanEmojiOption('🗺️', '出行'),
        PlanEmojiOption('🎬', '影音'),
        PlanEmojiOption('🐾', '宠物'),
        PlanEmojiOption('🧹', '打扫'),
        PlanEmojiOption('☕', '咖啡'),
        PlanEmojiOption('🌱', '植物'),
      ],
      CheckinPlanCategory.anniversary: <PlanEmojiOption>[
        PlanEmojiOption('🎂', '生日'),
        PlanEmojiOption('💕', '恋爱'),
        PlanEmojiOption('💼', '入职'),
        PlanEmojiOption('🎁', '礼物'),
        PlanEmojiOption('🥂', '庆祝'),
        PlanEmojiOption('🏆', '里程碑'),
        PlanEmojiOption('✨', '纪念'),
        PlanEmojiOption('📅', '周年'),
      ],
      CheckinPlanCategory.other: <PlanEmojiOption>[
        PlanEmojiOption('✅', '打卡'),
        PlanEmojiOption('🎈', '兴趣'),
        PlanEmojiOption('🔖', '备忘'),
        PlanEmojiOption('🧺', '家务'),
        PlanEmojiOption('📞', '联系'),
        PlanEmojiOption('🎵', '娱乐'),
        PlanEmojiOption('🛒', '采购'),
        PlanEmojiOption('🌈', '心情'),
      ],
    };

/// 某个分类的可选 emoji 列表。
List<PlanEmojiOption> planEmojiOptionsFor(CheckinPlanCategory category) {
  return checkinPlanEmojis[category]!;
}

/// 把 emoji 归一到「基字符」再比较。
///
/// 同一个意思有多个写法：`🏃‍♂️` 是「🏃 + ZWJ + ♂」、`🗺️` 带变体选择符。用户从
/// 种子里拿到的、从系统输入法打出来的可能是任一种，直接字符串比较会把它们
/// 当成两个不同的图标。
String _baseEmoji(String emoji) {
  final buffer = StringBuffer();
  for (final rune in emoji.runes) {
    // ZWJ 及其后的修饰符（性别、肤色）都不参与比较。
    if (rune == 0x200D) {
      break;
    }
    // FE0F / FE0E 是变体选择符，不改变含义。
    if (rune == 0xFE0F || rune == 0xFE0E) {
      continue;
    }
    buffer.writeCharCode(rune);
  }
  return buffer.toString();
}

/// 某个 emoji 的中文标签。认不出来返回 null（用户自定义的 emoji 就属于这种）。
String? planEmojiLabel(String emoji) {
  final target = _baseEmoji(emoji);
  for (final options in checkinPlanEmojis.values) {
    for (final option in options) {
      if (_baseEmoji(option.emoji) == target) {
        return option.label;
      }
    }
  }
  return null;
}

/// 新建计划时给的默认配色（按分类取同序下标，保持每类风格稳定）。
///
/// 这八枚只是**快捷色**：表单里另有「自定义」入口，用 HSV 调任意颜色。
final List<PlanColor> checkinPlanColors = <PlanColor>[
  PlanColor.tryParse('#0EA5E9')!, // 天蓝
  PlanColor.tryParse('#8B5CF6')!, // 紫
  PlanColor.tryParse('#EF4444')!, // 红
  PlanColor.tryParse('#F59E0B')!, // 琥珀
  PlanColor.tryParse('#EC4899')!, // 粉
  PlanColor.tryParse('#10B981')!, // 绿
  PlanColor.tryParse('#14B8A6')!, // 青
  PlanColor.tryParse('#6366F1')!, // 靛
];

/// 兜底色：分类默认也算不出来时用它（理论上不会发生，防御而已）。
final PlanColor fallbackPlanColor = checkinPlanColors.last;

/// 某个分类的默认 emoji（未知分类落到「其他」）。
String defaultPlanEmojiFor(CheckinPlanCategory category) {
  return checkinPlanEmojis[category]!.first.emoji;
}

/// 某个分类的默认颜色。
PlanColor defaultPlanColorFor(CheckinPlanCategory category) {
  final index = checkinPlanCategories.indexOf(category);
  return checkinPlanColors[index % checkinPlanColors.length];
}

/// 渲染时该用哪个 emoji。
///
/// 三条规则，顺序不能反：
/// 1. `📌` / 空 → 分类默认（历史上「没选过」就是图钉）；
/// 2. 用户自己挑的 emoji → 原样保留（包括不在内置表里的）；
/// 3. 其余（内置表里的值）→ 原样。
String resolvePlanEmoji({
  required String icon,
  required CheckinPlanCategory category,
}) {
  final value = icon.trim();
  if (value.isEmpty || value == legacyDefaultPlanIcon) {
    return defaultPlanEmojiFor(category);
  }
  return value;
}

/// 这个 emoji 是否属于该分类的内置集合（用来区分「默认」与「自定义」）。
bool isBuiltInPlanEmoji(String icon, CheckinPlanCategory category) {
  final target = _baseEmoji(icon);
  return (checkinPlanEmojis[category] ?? const <PlanEmojiOption>[]).any(
    (option) => _baseEmoji(option.emoji) == target,
  );
}

/// 把 `#RRGGBB` 解析成颜色；解析不了返回 null，由调用方决定兜底。
int? planColorValue(String? hex) {
  if (hex == null) {
    return null;
  }
  final raw = hex.replaceFirst('#', '');
  if (raw.length != 6) {
    return null;
  }
  return int.tryParse('ff$raw', radix: 16);
}

/// 一个计划该显示的 emoji 与颜色（展示层共用，避免各处各算一遍）。
@immutable
class PlanVisual {
  const PlanVisual({required this.emoji, required this.color});

  final String emoji;
  final PlanColor color;
}

PlanVisual planVisualFor({
  required String icon,
  required CheckinPlanCategory category,
  PlanColor? color,
}) {
  return PlanVisual(
    emoji: resolvePlanEmoji(icon: icon, category: category),
    color: color ?? defaultPlanColorFor(category),
  );
}

/// 表单里「图标 + 颜色」的当前状态。
@immutable
class PlanStyleSelection {
  const PlanStyleSelection({
    required this.emoji,
    required this.color,
    required this.customized,
  });

  final String emoji;
  final PlanColor color;

  /// 用户是否手动选过（选过之后切换分类不再覆盖）。
  final bool customized;

  /// 换分类时该变成什么样。
  ///
  /// **规则（用户明确要的）**：换分类时默认图标跟着换；但用户手动选过就不动。
  /// 抽成纯函数是因为这条规则以前写在 `setState` 里，只能靠点界面试——
  /// 而那个下拉菜单在测试里很不稳（过滤输入框会抢焦点），规则本身反而没被钉住。
  PlanStyleSelection onCategoryChanged(CheckinPlanCategory nextCategory) {
    if (customized) {
      return this;
    }
    return PlanStyleSelection(
      emoji: defaultPlanEmojiFor(nextCategory),
      color: defaultPlanColorFor(nextCategory),
      customized: false,
    );
  }

  /// 用户点了某个 emoji。
  PlanStyleSelection withEmoji(String next) =>
      PlanStyleSelection(emoji: next, color: color, customized: true);

  /// 用户换了颜色（不动「自定义图标」的标记）。
  PlanStyleSelection withColor(PlanColor next) =>
      PlanStyleSelection(emoji: emoji, color: next, customized: customized);

  /// 编辑一条已有计划时的初始状态。
  factory PlanStyleSelection.fromPlan({
    required String icon,
    required CheckinPlanCategory category,
    required PlanColor? color,
  }) {
    return PlanStyleSelection(
      emoji: icon,
      color: color ?? defaultPlanColorFor(category),
      customized: !isBuiltInPlanEmoji(icon, category),
    );
  }
}
