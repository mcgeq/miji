import 'package:flutter/material.dart';

import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';
import 'package:miji/features/gtd/domain/plan_color.dart';

/// 创建/编辑计划时的「图标 + 颜色」选择器。
///
/// 为什么不是输入框：以前是一个要求用户打 emoji 的 `TextField`，默认 `📌` ——
/// 不打就是图钉，而打 emoji 在桌面端还得会输入法。现在是按分类给的一组内置
/// emoji，默认已经选中一个；「自定义」留给真想用别的 emoji 的人。
///
/// 颜色分两层：八枚快捷色 + 一个「自定义」入口（HSV 三根滑杆）。快捷色覆盖
/// 「随手挑一个」的场景，自定义覆盖「我要和别的计划区分开」的场景。
class PlanStylePicker extends StatelessWidget {
  const PlanStylePicker({
    super.key,
    required this.category,
    required this.emoji,
    required this.color,
    required this.customized,
    required this.onEmojiChanged,
    required this.onColorChanged,
    required this.customController,
    required this.onCustomToggled,
  });

  final CheckinPlanCategory category;
  final String emoji;
  final PlanColor color;

  /// 当前 emoji 是否属于「用户自己选的」（内置集合之外或手动点过）。
  final bool customized;

  final ValueChanged<String> onEmojiChanged;
  final ValueChanged<PlanColor> onColorChanged;

  /// 自定义 emoji 的输入框（由外层持有，切走再切回不丢）。
  final TextEditingController customController;
  final VoidCallback onCustomToggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final options = checkinPlanEmojis[category]!;

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
        Row(
          children: [
            Text(
              '颜色',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            Text(
              color.hex,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in checkinPlanColors)
              _ColorDot(
                key: ValueKey('plan-color-${preset.hex}'),
                color: preset,
                selected: preset == color,
                onTap: () => onColorChanged(preset),
              ),
            _CustomColorDot(
              key: const ValueKey('plan-color-custom'),
              color: color,
              // 自定义色与快捷色相同时不重复高亮。
              selected: !checkinPlanColors.contains(color),
              onTap: () => _pickCustomColor(context),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickCustomColor(BuildContext context) async {
    final picked = await showModalBottomSheet<PlanColor>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PlanColorSheet(initial: color),
    );
    if (picked != null) {
      onColorChanged(picked);
    }
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
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final PlanColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
            color: color.color,
          ),
        ),
      ),
    );
  }
}

/// 自定义色入口：一枚彩色圆点，里面写着「+」。
class _CustomColorDot extends StatelessWidget {
  const _CustomColorDot({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final PlanColor color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: '自定义颜色',
      child: InkWell(
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
              color: color.color,
            ),
            child: Icon(Icons.add_rounded, size: 14, color: color.onColor),
          ),
        ),
      ),
    );
  }
}

/// 自定义调色板：HSV 三根滑杆 + 预览。
///
/// 为什么用 HSV 而不是 RGB 或输入 hex：人挑颜色时想的是「偏蓝一点、淡一点」，
/// 对应色相与饱和度；让人去调三个通道或背十六进制是把机器的表示塞给用户。
/// hex 只在角落显示，方便抄给别人。
class PlanColorSheet extends StatefulWidget {
  const PlanColorSheet({super.key, required this.initial});

  final PlanColor initial;

  @override
  State<PlanColorSheet> createState() => _PlanColorSheetState();
}

class _PlanColorSheetState extends State<PlanColorSheet> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    final hsv = widget.initial.hsv;
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  PlanColor get _color => PlanColor.fromHsv(
    hue: _hue,
    saturation: _saturation,
    value: _value,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '自定义颜色',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: _color.onColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Slider(
              key: const ValueKey('plan-color-hue'),
              label: '色相',
              value: _hue,
              max: 360,
              gradient: const [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
              onChanged: (v) => setState(() => _hue = v),
            ),
            _Slider(
              key: const ValueKey('plan-color-saturation'),
              label: '饱和度',
              value: _saturation,
              max: 1,
              gradient: [
                HSVColor.fromAHSV(1, _hue, 0, _value).toColor(),
                HSVColor.fromAHSV(1, _hue, 1, _value).toColor(),
              ],
              onChanged: (v) => setState(() => _saturation = v),
            ),
            _Slider(
              key: const ValueKey('plan-color-value'),
              label: '明度',
              value: _value,
              max: 1,
              gradient: [
                const Color(0xFF000000),
                HSVColor.fromAHSV(1, _hue, _saturation, 1).toColor(),
              ],
              onChanged: (v) => setState(() => _value = v),
            ),
            const SizedBox(height: 6),
            Text(
              '存下来的值：${_color.hex}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_color),
                  child: const Text('用这个颜色'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: gradient),
                ),
              ),
            ),
            Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: onChanged,
            ),
          ],
        ),
      ],
    );
  }
}
