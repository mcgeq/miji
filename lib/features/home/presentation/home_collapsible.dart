import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';

/// 记账区块的默认摘要折叠壳。
///
/// 折叠时只显示一行摘要，点一下展开真实面板（展开后本次会话保持展开）。
/// 不改动面板内部，避免碰 [HomeCategoryStructurePanel] 这类复杂组件。
class HomeCollapsible extends StatefulWidget {
  const HomeCollapsible({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<HomeCollapsible> createState() => _HomeCollapsibleState();
}

class _HomeCollapsibleState extends State<HomeCollapsible> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant HomeCollapsible oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 用 child 身份变化（面板集合变化）时重新折叠是过度反应，
    // 这里只在初次挂载时应用 initiallyExpanded。
  }

  @override
  Widget build(BuildContext context) {
    // 没有可摘要的数据时直接渲染真实面板（保留加载 / 空态），不折叠。
    if (_expanded || widget.subtitle == null) {
      return widget.child;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AppSurface(
      onTap: () => setState(() => _expanded = true),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.icon, size: 16, color: colorScheme.secondary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '展开 ›',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
