import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';

class AppListItemPanel extends StatelessWidget {
  const AppListItemPanel({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.padding = const EdgeInsets.all(14),
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
              : colorScheme.outlineVariant.withValues(alpha: 0.48)),
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

class AppSwipeActionTile extends StatefulWidget {
  const AppSwipeActionTile({
    super.key,
    required this.child,
    this.actions = const <AppSwipeAction>[],
    this.onTap,
    this.closeSignal,
    this.borderRadius = 8,
    this.actionPaneWidth = 58,
    this.slideDuration = const Duration(milliseconds: 180),
  });

  final Widget child;
  final List<AppSwipeAction> actions;
  final VoidCallback? onTap;
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

  bool get _isOpen => _dragOffset <= -widget.actionPaneWidth / 2;

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
                width: widget.actionPaneWidth,
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
            onHorizontalDragUpdate: _handleHorizontalDragUpdate,
            onHorizontalDragEnd: _handleHorizontalDragEnd,
            child: AnimatedContainer(
              duration: widget.slideDuration,
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_dragOffset, 0, 0),
              child: widget.child,
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
          .clamp(-widget.actionPaneWidth, 0)
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
      _dragOffset = value ? -widget.actionPaneWidth : 0;
    });
  }
}

class _AppSwipeActionPane extends StatelessWidget {
  const _AppSwipeActionPane({required this.width, required this.actions});

  final double width;
  final List<AppSwipeAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actionCount = actions.length;
        if (actionCount == 0) {
          return SizedBox(width: width, height: double.infinity);
        }
        final spacing = actionCount <= 1
            ? 0.0
            : actionCount >= 3
            ? 4.0
            : 6.0;
        final verticalPadding =
            constraints.maxHeight.isFinite && constraints.maxHeight < 96
            ? 4.0
            : 8.0;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight -
                  verticalPadding * 2 -
                  spacing * (actionCount - 1)
            : 40.0;
        final buttonSize = availableHeight / actionCount;
        final resolvedButtonSize = buttonSize.clamp(0.0, 40.0).toDouble();

        return SizedBox(
          width: width,
          height: double.infinity,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) SizedBox(height: spacing),
                  _AppSwipeActionButton(
                    action: actions[index],
                    size: resolvedButtonSize,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppSwipeActionButton extends StatelessWidget {
  const _AppSwipeActionButton({required this.action, required this.size});

  final AppSwipeAction action;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.tooltip,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          color: action.background,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: action.onPressed,
            child: Center(
              child: Icon(
                action.icon,
                size: (size * 0.5).clamp(12.0, 20.0).toDouble(),
                color: action.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
