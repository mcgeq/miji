import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

/// 列表行内边距（与 [AppSpacingTokens.listItemPadding] 对齐）。
const double _listItemPadding = 14;

class AppListItemPanel extends StatelessWidget {
  const AppListItemPanel({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(_listItemPadding),
    this.bordered = true,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final EdgeInsetsGeometry padding;
  final bool bordered;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppSurface(
      padding: padding,
      onTap: onTap,
      selected: selected,
      bordered: bordered,
      backgroundColor:
          backgroundColor ??
          (selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.46)
              : colorScheme.surfaceContainerLow),
      borderColor:
          borderColor ??
          (selected
              ? colorScheme.primary.withValues(alpha: 0.42)
              // 与 AppSurface 默认边框保持一致（原来这里是 0.48，视觉上更重）。
              : colorScheme.outlineVariant.withValues(alpha: 0.42)),
      child: child,
    );
  }
}

class AppListItemIcon extends StatelessWidget {
  const AppListItemIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 38,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = Theme.of(context).radiusTokens;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius.md),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

class AppSwipeAction {
  const AppSwipeAction({
    required this.tooltip,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color foreground;
  final Color background;
  final VoidCallback onPressed;
}

/// 两列布局下每个格子的高度下限。
///
/// 28 是「还点得中」的下限：再小就回到原来那种十几像素的圆点了。行高不够时
/// 由 `AppSwipeActionTile` 给 child 加最小高度来保证。
const double _minCellHeight = 32;

class AppSwipeActionTile extends StatefulWidget {
  const AppSwipeActionTile({
    super.key,
    required this.child,
    this.actions = const <AppSwipeAction>[],
    this.onTap,
    this.onLongPress,
    this.closeSignal,
    this.borderRadius = 8,
    this.actionPaneWidth = 58,
    this.slideDuration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final List<AppSwipeAction> actions;
  final VoidCallback? onTap;

  /// 长按（例如进入多选模式）。
  final VoidCallback? onLongPress;
  final Object? closeSignal;
  final double borderRadius;
  final double actionPaneWidth;
  final Duration slideDuration;

  @override
  State<AppSwipeActionTile> createState() => _AppSwipeActionTileState();
}

class _AppSwipeActionTileState extends State<AppSwipeActionTile> {
  double _dragOffset = 0;

  bool get _hasActions => widget.actions.isNotEmpty;

  /// 一个动作时保持单列（面板窄、不抢宽度），两个及以上排成两列。
  ///
  /// 为什么要分列：面板高度就是**行高**，而一列里塞四个动作时每个按钮只剩
  /// 十几像素 —— 圆点小到点不中。竖着排还会随着动作数量继续变小；横着排，
  /// 每个格子都能占满行高，动作多只会多一行。
  int get _columns => widget.actions.length <= 1 ? 1 : 2;

  int get _rows => (widget.actions.length / _columns).ceil();

  /// 面板实际宽度：每列 `actionPaneWidth`。
  double get _paneWidth => widget.actionPaneWidth * _columns;

  bool get _isOpen => _dragOffset <= -_paneWidth / 2;

  @override
  void didUpdateWidget(covariant AppSwipeActionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldClose =
        !_hasActions || oldWidget.closeSignal != widget.closeSignal;
    if (shouldClose && _dragOffset != 0) {
      _dragOffset = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasActions) {
      return GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: widget.child,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: _AppSwipeActionPane(
                width: _paneWidth,
                columns: _columns,
                actions: [
                  for (final action in widget.actions)
                    AppSwipeAction(
                      tooltip: action.tooltip,
                      icon: action.icon,
                      foreground: action.foreground,
                      background: action.background,
                      onPressed: _runAction(action.onPressed),
                    ),
                ],
              ),
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onTap: _isOpen ? _closeIfOpen : widget.onTap,
            onLongPress: widget.onLongPress,
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            child: AnimatedContainer(
              duration: widget.slideDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              // 两列两行时给行一个下限：格子高度 = 行高 / 行数，行太矮的话
              // 换列也只是把「一列四个小圆点」变成「两列两个小方块」。
              // 单个动作不受影响（它本来就占满整行高度）。
              child: _rows <= 1
                  ? widget.child
                  : ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: _rows * _minCellHeight + (_rows - 1) * 4 + 8,
                      ),
                      child: widget.child,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  VoidCallback _runAction(VoidCallback action) {
    return () {
      _setOpen(false);
      action();
    };
  }

  void _closeIfOpen() {
    if (_isOpen) {
      _setOpen(false);
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx)
          .clamp(-_paneWidth, 0)
          .toDouble();
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -240) {
      _setOpen(true);
      return;
    }

    if (velocity > 240) {
      _setOpen(false);
      return;
    }

    _setOpen(_isOpen);
  }

  void _setOpen(bool value) {
    setState(() {
      _dragOffset = value ? -_paneWidth : 0;
    });
  }
}

class _AppSwipeActionPane extends StatelessWidget {
  const _AppSwipeActionPane({
    required this.width,
    required this.columns,
    required this.actions,
  });

  final double width;
  final int columns;
  final List<AppSwipeAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionCount = actions.length;
        if (actionCount == 0) {
          return SizedBox(width: width, height: double.infinity);
        }

        final rows = (actionCount / columns).ceil();
        const spacing = 4.0;
        // 上下各留 4px 的呼吸位；算格子时必须把它扣掉，否则 Column 会比
        // 可用高度多出 8px（溢出）。
        const verticalPadding = 4.0;
        // 约束可能无限（列表项在 Column 里布局时），给一个保底高度，
        // 免得算出 Infinity 的格子。
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight - verticalPadding * 2
            : rows * _minCellHeight + (rows - 1) * spacing;
        final cellWidth = (width - spacing * (columns - 1)) / columns;
        final cellHeight = (height - spacing * (rows - 1)) / rows;

        return SizedBox(
          width: width,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: verticalPadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var row = 0; row < rows; row++) ...[
                  if (row > 0) const SizedBox(height: spacing),
                  Row(
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: spacing),
                        _cellFor(row, column, cellWidth, cellHeight),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// 格子按「行优先」填：第 n 个动作落在 `n ~/ columns` 行。
  Widget _cellFor(int row, int column, double cellWidth, double cellHeight) {
    final index = row * columns + column;
    if (index >= actions.length) {
      // 动作数不是列数的整数倍时，最后一行留空位，格子不会撑变形。
      return SizedBox(width: cellWidth, height: cellHeight);
    }
    return _AppSwipeActionButton(
      action: actions[index],
      width: cellWidth,
      height: cellHeight,
    );
  }
}

class _AppSwipeActionButton extends StatelessWidget {
  const _AppSwipeActionButton({
    required this.action,
    required this.width,
    required this.height,
  });

  final AppSwipeAction action;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      (height / 2).clamp(8.0, 14.0).toDouble(),
    );
    return Tooltip(
      message: action.tooltip,
      child: SizedBox(
        width: width,
        height: height,
        child: Material(
          color: action.background,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: radius,
            onTap: action.onPressed,
            child: Center(
              child: Icon(
                action.icon,
                // 图标随格子走，但不必跟着缩到看不见。
                size: (height * 0.55).clamp(18.0, 22.0).toDouble(),
                color: action.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
