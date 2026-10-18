import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_field_style.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

import 'package:miji/core/presentation/app_color_utils.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';

class AppColorPickerField extends StatelessWidget {
  const AppColorPickerField({
    super.key,
    required this.selectedColor,
    required this.onSelected,
    this.title = '颜色',
    this.sections = AppColorPicker.defaultSections,
    this.enabled = true,
  });

  final String selectedColor;
  final ValueChanged<String> onSelected;
  final String title;
  final List<AppColorPickerSection> sections;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controls = theme.controlTokens;
    final radius = theme.radiusTokens;
    final foregroundColor = enabled
        ? colorScheme.onSurface
        : colorScheme.onSurface.withValues(alpha: 0.38);
    final iconColor = enabled
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius.md),
        onTap: enabled ? () => _openPicker(context) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: controls.compactFieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: appFieldFillColor(colorScheme, enabled: enabled),
            borderRadius: BorderRadius.circular(radius.md),
            border: Border.all(
              color: appFieldBorderColor(colorScheme, enabled: enabled),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.palette_rounded, size: 18, color: iconColor),
              const SizedBox(width: 8),
              AppColorSwatch(color: selectedColor, isSelected: false, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$title · ${selectedColor.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foregroundColor,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showAppResponsiveDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AppDialogScaffold(
          title: '选择$title',
          maxWidth: 420,
          titleTextAlign: TextAlign.center,
          actionsAlignment: WrapAlignment.center,
          body: AppColorPicker(
            selectedColor: selectedColor,
            title: '当前$title',
            sections: sections,
            onSelected: (color) => Navigator.of(dialogContext).pop(color),
          ),
          actions: [
            AppIconActionButton(
              tooltip: '取消',
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: Icons.close_rounded,
              variant: AppIconActionVariant.outlined,
            ),
          ],
        );
      },
    );

    if (selected != null && context.mounted) {
      onSelected(selected);
    }
  }
}

class AppColorPicker extends StatelessWidget {
  const AppColorPicker({
    super.key,
    required this.selectedColor,
    required this.onSelected,
    this.title = '颜色',
    this.sections = defaultSections,
  });

  final String selectedColor;
  final ValueChanged<String> onSelected;
  final String title;
  final List<AppColorPickerSection> sections;

  static const defaultSections = <AppColorPickerSection>[
    AppColorPickerSection(
      label: '暖色',
      colors: ['#EF4444', '#F97316', '#F59E0B', '#EAB308', '#EC4899'],
    ),
    AppColorPickerSection(
      label: '冷色',
      colors: ['#0EA5E9', '#06B6D4', '#10B981', '#6366F1', '#8B5CF6'],
    ),
    AppColorPickerSection(
      label: '中性色',
      colors: ['#64748B', '#475569', '#334155', '#78716C', '#71717A'],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      tone: AppSurfaceTone.subtle,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppColorSwatch(color: selectedColor, isSelected: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedColor.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final section in sections) ...[
            Text(
              section.label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in section.colors)
                  AppColorSwatchButton(
                    color: color,
                    isSelected:
                        color.toUpperCase() == selectedColor.toUpperCase(),
                    onSelected: onSelected,
                  ),
              ],
            ),
            if (section != sections.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class AppColorPickerSection {
  const AppColorPickerSection({required this.label, required this.colors});

  final String label;
  final List<String> colors;
}

class AppColorSwatchButton extends StatelessWidget {
  const AppColorSwatchButton({
    super.key,
    required this.color,
    required this.isSelected,
    required this.onSelected,
  });

  final String color;
  final bool isSelected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: color.toUpperCase(),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelected(color),
        child: AppColorSwatch(color: color, isSelected: isSelected),
      ),
    );
  }
}

class AppColorSwatch extends StatelessWidget {
  const AppColorSwatch({
    super.key,
    required this.color,
    required this.isSelected,
    this.size = 32,
  });

  final String color;
  final bool isSelected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final swatchColor = appColorFromHex(color);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: swatchColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.onSurface : colorScheme.outline,
          width: isSelected ? 2.2 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: swatchColor.withValues(alpha: 0.36),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: isSelected
          ? Icon(
              Icons.check_rounded,
              color: appOnColor(swatchColor),
              size: size * 0.56,
            )
          : null,
    );
  }
}
