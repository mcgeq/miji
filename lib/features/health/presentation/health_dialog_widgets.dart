import 'package:flutter/material.dart';

enum HealthOptionAxis { horizontal, vertical }

/// 大号可选项卡片：图标/表情 + 标题 + 说明，选中时整块着色并出现对勾。
class HealthOptionCard extends StatelessWidget {
  const HealthOptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    super.key,
    this.leading,
    this.caption,
    this.axis = HealthOptionAxis.horizontal,
  });

  final String label;
  final String? caption;
  final Widget? leading;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final HealthOptionAxis axis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(16);

    return Material(
      color: selected ? accent.withValues(alpha: 0.12) : colorScheme.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? accent
                  : colorScheme.outlineVariant.withValues(alpha: 0.7),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: axis == HealthOptionAxis.vertical
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ?leading,
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? accent : colorScheme.onSurface,
                        letterSpacing: 0,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ],
                )
              : Row(
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected ? accent : colorScheme.onSurface,
                              letterSpacing: 0,
                            ),
                          ),
                          if (caption != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              caption!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 140),
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: accent,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// 小号图标胶囊，用于症状等一屏多选。
class HealthIconChip extends StatelessWidget {
  const HealthIconChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    super.key,
    this.icon,
    this.onLongPress,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected ? accent : colorScheme.onSurface;

    return Material(
      color: selected ? accent.withValues(alpha: 0.13) : colorScheme.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? accent
                  : colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: foreground,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 轻 / 中 / 重 三段强度选择。
class HealthIntensityPicker extends StatelessWidget {
  const HealthIntensityPicker({
    required this.value,
    required this.onChanged,
    required this.accent,
    super.key,
    this.labels = const ['轻', '中', '重'],
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Color accent;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final label in labels)
            GestureDetector(
              onTap: () => onChanged(label),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: value == label ? accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                    color: value == label
                        ? (ThemeData.estimateBrightnessForColor(accent) ==
                                  Brightness.dark
                              ? Colors.white
                              : Colors.black)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 弹窗内带标题（可选说明）的一段内容。
class HealthDialogSection extends StatelessWidget {
  const HealthDialogSection({
    required this.title,
    required this.child,
    super.key,
    this.hint,
    this.trailing,
  });

  final String title;
  final String? hint;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const Spacer(),
            ?trailing,
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

/// 圆形加减按钮。
class HealthStepButton extends StatelessWidget {
  const HealthStepButton({
    required this.icon,
    required this.onPressed,
    super.key,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final button = Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : colorScheme.onSurface,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// 两列自适应网格（避免在弹窗里嵌套第二层滚动）。
class HealthOptionGrid extends StatelessWidget {
  const HealthOptionGrid({
    required this.children,
    super.key,
    this.columns = 2,
    this.spacing = 10,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}
