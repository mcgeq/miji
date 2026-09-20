import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';

enum MoneyQuickActionFabPlacement { bottomRight, centerDocked }

/// 悬浮的快捷新增入口。动作实现全部委托给 [MoneyQuickActionLauncher]，
/// 这里只负责展示与分发。
class MoneyQuickActionFab extends ConsumerStatefulWidget {
  const MoneyQuickActionFab({
    super.key,
    this.placement = MoneyQuickActionFabPlacement.bottomRight,
  });

  final MoneyQuickActionFabPlacement placement;

  @override
  ConsumerState<MoneyQuickActionFab> createState() =>
      _MoneyQuickActionFabState();
}

class _MoneyQuickActionFabState extends ConsumerState<MoneyQuickActionFab> {
  FToast? _toast;
  OverlayEntry? _actionsOverlay;

  FToast _ensureToast() {
    return _toast ??= (FToast()..init(context));
  }

  late final MoneyQuickActionLauncher _launcher = MoneyQuickActionLauncher(
    context: context,
    ref: ref,
    ensureToast: _ensureToast,
  );

  /// 悬浮面板展示全部动作，顺序即优先级。
  static const _actions = <MoneyQuickAction>[
    MoneyQuickAction.expense,
    MoneyQuickAction.income,
    MoneyQuickAction.transfer,
    MoneyQuickAction.task,
    MoneyQuickAction.account,
    MoneyQuickAction.installment,
    MoneyQuickAction.budget,
    MoneyQuickAction.plan,
  ];

  @override
  void dispose() {
    _hideActions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDocked =
        widget.placement == MoneyQuickActionFabPlacement.centerDocked;

    return SafeArea(
      minimum: isDocked
          ? EdgeInsets.zero
          : const EdgeInsets.only(right: 18, bottom: 18),
      child: Tooltip(
        message: '快速新增',
        child: FloatingActionButton.small(
          heroTag: 'money_quick_action_fab',
          elevation: 6,
          shape: const CircleBorder(),
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          onPressed: _toggleActions,
          child: const Icon(Icons.add_rounded, size: 22),
        ),
      ),
    );
  }

  void _toggleActions() {
    if (_actionsOverlay != null) {
      _hideActions();
      return;
    }
    _showActions();
  }

  void _showActions() {
    final overlay = Overlay.of(context, rootOverlay: true);
    final isDocked =
        widget.placement == MoneyQuickActionFabPlacement.centerDocked;
    final entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: _MoneyQuickActionSheet(
          actions: _actions,
          onAction: _handleAction,
          onDismiss: _hideActions,
          docked: isDocked,
          alignment: isDocked ? Alignment.bottomCenter : Alignment.bottomRight,
          padding: isDocked
              ? const EdgeInsets.only(bottom: 68)
              : const EdgeInsets.only(right: 18, bottom: 68),
        ),
      ),
    );
    overlay.insert(entry);
    _actionsOverlay = entry;
  }

  void _hideActions() {
    _actionsOverlay?.remove();
    _actionsOverlay = null;
  }

  void _handleAction(MoneyQuickAction action) {
    _hideActions();
    unawaited(_launcher.run(action));
  }
}

class _MoneyQuickActionSheet extends StatelessWidget {
  const _MoneyQuickActionSheet({
    required this.actions,
    required this.onAction,
    required this.onDismiss,
    required this.docked,
    required this.alignment,
    required this.padding,
  });

  final List<MoneyQuickAction> actions;
  final ValueChanged<MoneyQuickAction> onAction;
  final VoidCallback onDismiss;
  final bool docked;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;

  static const _fabBottomInset = 18.0;
  static const _fabSize = 40.0;
  static const _panelGap = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (docked) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 92),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, (1 - value) * 12),
                        child: child,
                      ),
                    );
                  },
                  child: Material(
                    color: colorScheme.surface,
                    elevation: 18,
                    shadowColor: colorScheme.shadow.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 4,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.08,
                          children: [
                            for (final action in actions)
                              _QuickActionGridTile(
                                action: action,
                                onTap: () => onAction(action),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    const bottomInset = _fabBottomInset + _fabSize + _panelGap;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight - bottomInset - 24;
        final maxPanelHeight = availableHeight > 0
            ? availableHeight
            : constraints.maxHeight;

        return SafeArea(
          child: Align(
            alignment: alignment,
            child: Padding(
              padding: padding,
              child: Material(
                color: colorScheme.surface,
                elevation: 12,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelHeight),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final action in actions) ...[
                          _QuickActionTile(
                            action: action,
                            onTap: () => onAction(action),
                          ),
                          if (action != actions.last) const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickActionGridTile extends StatelessWidget {
  const _QuickActionGridTile({required this.action, required this.onTap});

  final MoneyQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final label = action.label;

    return Tooltip(
      message: label,
      child: Material(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            button: true,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      action.icon,
                      color: colorScheme.onPrimaryContainer,
                      size: 18,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final MoneyQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final label = action.label;

    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Semantics(
            button: true,
            label: label,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    action.icon,
                    color: colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
