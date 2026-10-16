import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/router/app_module_nav.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

const _kPickerKey = ValueKey('module-section-picker');
const _kTileExtent = 84.0;

/// 弹出某个一级模块的面板选择器（二级路由的选择层）。
///
/// 窄屏从底部升出、宽屏居中：两者复用同一套内容与同一个
/// [showAppResponsiveDialog]，不额外维护第二份布局。
///
/// 返回用户选中的面板 id；点空白处或关闭按钮取消时返回 null。
Future<String?> showAppModuleSectionPicker(
  BuildContext context, {
  required AppModuleNavSpec spec,
  required String? currentSectionId,
  Map<String, String> badges = const <String, String>{},
}) {
  return showAppResponsiveDialog<String>(
    context: context,
    builder: (dialogContext) => _ModuleSectionPicker(
      spec: spec,
      currentSectionId: spec.resolveSectionId(currentSectionId),
      badges: badges,
      onPick: (sectionId) => Navigator.of(dialogContext).pop(sectionId),
    ),
  );
}

/// 弹出选择器并把选中的面板落到地址上。
///
/// 外壳（底栏 / 侧栏）走这条：模块内换面板一律写回 `?section=`，由页面自己的
/// `didUpdateWidget` 接住——外壳不需要认识任何模块的内部状态。
Future<void> openAppModuleSection(
  BuildContext context, {
  required AppModuleNavSpec spec,
  required String? currentSectionId,
  Map<String, String> badges = const <String, String>{},
}) async {
  final current = spec.resolveSectionId(currentSectionId);
  final picked = await showAppModuleSectionPicker(
    context,
    spec: spec,
    currentSectionId: current,
    badges: badges,
  );
  if (picked == null || picked == current || !context.mounted) {
    return;
  }
  context.go(spec.uriFor(picked).toString());
}

/// 工具行左端的「我在哪个面板」入口：显示当前面板名，点开就是选择器。
///
/// 宽屏（`prefersRailNavigation` 恒 true）没有底栏，页内必须有这一枚入口；
/// 它与账本选择器同排，不新增行高、不覆盖任何内容——这正是它取代原来那颗
/// 「浮在内容右上角」的胶囊的原因。
class AppModuleSectionChip extends StatelessWidget {
  const AppModuleSectionChip({
    super.key,
    required this.spec,
    required this.sectionId,
    required this.onTap,
  });

  final AppModuleNavSpec spec;
  final String sectionId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final section = spec.resolveSection(sectionId);

    return Tooltip(
      message: '切换${spec.title}面板，当前在${section.label}',
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
        child: InkWell(
          key: ValueKey('module-section-chip-${spec.id}'),
          borderRadius: BorderRadius.circular(theme.radiusTokens.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(section.icon, size: 15, color: colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 17,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleSectionPicker extends StatelessWidget {
  const _ModuleSectionPicker({
    required this.spec,
    required this.currentSectionId,
    required this.badges,
    required this.onPick,
  });

  final AppModuleNavSpec spec;
  final String currentSectionId;
  final Map<String, String> badges;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = theme.radiusTokens;
    final spacing = theme.spacingTokens;
    final compact = AppResponsive.of(context).isCompact;
    final sheetRadius = BorderRadius.vertical(top: Radius.circular(radius.lg));
    final panelRadius = BorderRadius.circular(radius.lg);

    final content = Material(
      key: _kPickerKey,
      color: colorScheme.surfaceContainerLow,
      borderRadius: compact ? sheetRadius : panelRadius,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: compact ? double.infinity : theme.controlTokens.dialogWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.cardPadding,
                spacing.cardPadding,
                spacing.fieldGap,
                4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          spec.title,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '选择要查看的面板',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.cardPadding,
                8,
                spacing.cardPadding,
                spacing.cardPadding,
              ),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: spec.pickerColumns,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 6,
                  mainAxisExtent: _kTileExtent,
                ),
                itemCount: spec.sections.length,
                itemBuilder: (context, index) {
                  final section = spec.sections[index];
                  return _ModuleSectionTile(
                    section: section,
                    selected: section.id == currentSectionId,
                    badge: badges[section.id],
                    onTap: () => onPick(section.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (compact) {
      return content;
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: panelRadius),
      child: content,
    );
  }
}

class _ModuleSectionTile extends StatelessWidget {
  const _ModuleSectionTile({
    required this.section,
    required this.selected,
    required this.badge,
    required this.onTap,
  });

  final AppModuleSection section;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = BorderRadius.circular(theme.radiusTokens.md);
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: badge == null ? section.label : '${section.label}，$badge 条待处理',
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey('module-section-item-${section.id}'),
          borderRadius: radius,
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? colorScheme.primaryContainer
                          : colorScheme.surfaceContainerHighest.withValues(
                              alpha: 0.72,
                            ),
                      borderRadius: radius,
                    ),
                    child: Icon(section.icon, size: 21, color: foreground),
                  ),
                  // 角标只挂在图标上：面板名可能占满整格（如「自动记账」），
                  // 挂在文字上会把名字挤成省略号。
                  if (badge != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: colorScheme.surfaceContainerLow,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onError,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  section.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? colorScheme.primary : foreground,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
