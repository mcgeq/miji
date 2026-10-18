import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';

/// 创建/编辑计划时的「图标 + 颜色」选择器。
///
/// 为什么不是输入框：以前是一个要求用户打 emoji 的 `TextField`，默认 `📌` ——
/// 不打就是图钉，而打 emoji 在桌面端还得会输入法。现在是按分类给的一组内置
/// emoji，默认已经选中一个；「自定义」留给真想用别的 emoji 的人。
///
/// 联动规则（用户明确要的）：**换分类时跟着换默认图标，但用户手动选过就不动**。
/// 手动选过之后切换到新分类，原来的 emoji 仍显示为选中 —— 因为它在当前分类的
/// 集合里可能不存在，所以额外用一行小字说明「当前是自定义图标」。
class PlanStylePicker extends StatelessWidget {
  const PlanStylePicker({
    super.key,
    required this.category,
    required this.emoji,
    required this.colorHex,
    required this.customized,
    required this.onEmojiChanged,
    required this.onColorChanged,
    required this.customController,
    required this.onCustomToggled,
  });

  final CheckinPlanCategory category;
  final String emoji;
  final String colorHex;

  /// 当前 emoji 是否属于「用户自己选的」（内置集合之外或手动点过）。
  final bool customized;

  final ValueChanged<String> onEmojiChanged;
  final ValueChanged<String> onColorChanged;

  /// 自定义 emoji 的输入框（由外层持有，切走再切回不丢）。
  final TextEditingController customController;
  final VoidCallback onCustomToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = checkinPlanEmojis[category]!;
    final color = planColorValue(colorHex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '图标',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              customized ? '自定义 · $emoji' : '${category.label} 默认',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // 自定义的那个 emoji 也摆进来并保持选中：否则「我现在用的是哪个」
            // 只写在右上角的小字里，选中态在网格上看不见。
            if (customized && emoji.isNotEmpty)
              _EmojiChip(
                key: const ValueKey('plan-emoji-current'),
                emoji: emoji,
                selected: true,
                tooltip: '当前使用的 emoji',
                onTap: () {},
              ),
            for (final option in options)
              _EmojiChip(
                key: ValueKey('plan-emoji-$option'),
                emoji: option,
                selected: !customized && option == emoji,
                onTap: () => onEmojiChanged(option),
              ),
            _EmojiChip(
              key: const ValueKey('plan-emoji-custom'),
              emoji: '✏️',
              selected: customized,
              tooltip: '自定义 emoji',
              onTap: onCustomToggled,
            ),
          ],
        ),
        if (customized) ...[
          const SizedBox(height: 10),
          TextField(
            controller: customController,
            decoration: InputDecoration(
              isDense: true,
              labelText: '自定义 emoji',
              hintText: '粘贴或输入一个 emoji',
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (value) {
              if (value.trim().isNotEmpty) {
                onEmojiChanged(value.trim());
              }
            },
          ),
        ],
        const SizedBox(height: 14),
        Text(
          '颜色',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in checkinPlanColors)
              _ColorDot(
                key: ValueKey('plan-color-$hex'),
                hex: hex,
                selected: hex == colorHex,
                onTap: () => onColorChanged(hex),
              ),
          ],
        ),
        if (color == null) ...[
          const SizedBox(height: 6),
          Text(
            '当前颜色值无法识别，选一个上面的即可',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.error,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}

class _EmojiChip extends StatelessWidget {
  const _EmojiChip({
    super.key,
    required this.emoji,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chip = InkWell(
      borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
      ),
    );
    return tooltip == null ? chip : Tooltip(message: tooltip!, child: chip);
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({
    super.key,
    required this.hex,
    required this.selected,
    required this.onTap,
  });

  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = planColorValue(hex);
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? scheme.onSurface : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: value == null ? scheme.surfaceContainerHighest : Color(value),
          ),
        ),
      ),
    );
  }
}
