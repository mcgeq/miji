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

/// 每个分类内置的 emoji。
///
/// 每个分类的第一个是**默认值**（新建时自动选中）。种子模板里用过的 emoji
/// 都在表里，这样「新建 → 选中 → 之后又改回默认」不会变成两套风格。
const Map<CheckinPlanCategory, List<String>> checkinPlanEmojis =
    <CheckinPlanCategory, List<String>>{
      CheckinPlanCategory.healthHabit: <String>[
        '💧',
        '🌙',
        '🍚',
        '🚽',
        '🚿',
        '💊',
        '🧘',
        '🏥',
      ],
      CheckinPlanCategory.study: <String>[
        '📖',
        '📚',
        '📝',
        '🎧',
        '🧠',
        '✍️',
        '🎓',
        '💡',
      ],
      CheckinPlanCategory.exercise: <String>[
        '🚶',
        '🏃',
        '🚴',
        '🏊',
        '🏋️',
        '🤸',
        '⚽',
        '🧗',
      ],
      CheckinPlanCategory.lifeLog: <String>[
        '📸',
        '🍜',
        '🗺️',
        '🎬',
        '🐾',
        '🧹',
        '☕',
        '🌱',
      ],
      CheckinPlanCategory.anniversary: <String>[
        '🎂',
        '💕',
        '💼',
        '🎁',
        '✨',
        '🥂',
        '📅',
        '🏆',
      ],
      CheckinPlanCategory.other: <String>[
        '⭐',
        '✅',
        '🎯',
        '🔔',
        '🌟',
        '📎',
        '🧩',
        '🕒',
      ],
    };

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
  return checkinPlanEmojis[category]!.first;
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
  return (checkinPlanEmojis[category] ?? const <String>[]).contains(icon);
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
