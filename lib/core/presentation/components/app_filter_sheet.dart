import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_bottom_sheet_keyboard_inset.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';

/// A trigger button that opens a bottom sheet containing filter widgets.
class AppFilterSheetTrigger extends StatelessWidget {
  const AppFilterSheetTrigger({
    super.key,
    required this.title,
    required this.children,
    this.hasActiveFilters = false,
  });

  final String title;
  final List<Widget> children;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    return AppIconActionButton(
      tooltip: title,
      onPressed: _hasActive ? () => _open(context) : null,
      icon: Icons.filter_list_rounded,
      variant: hasActiveFilters
          ? AppIconActionVariant.filled
          : AppIconActionVariant.outlined,
    );
  }

  bool get _hasActive => true;

  /// Returns the callback that closes the nearest open filter sheet,
  /// or null when [context] is not part of an open filter sheet.
  static VoidCallback? maybeCloserOf(BuildContext context) {
    return _FilterSheetScope.maybeOf(context)?.close;
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      // 筛选内容里可能有输入框（关键词 / 商家），键盘避让交给共享组件
      // （整体上移 + 压缩高度），否则底部的输入框会被键盘盖住。
      builder: (sheetContext) => AppBottomSheetKeyboardInset(
        child: DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            final theme = Theme.of(context);
            return _FilterSheetScope(
              close: () => Navigator.of(context).pop(),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: theme.colorScheme.outlineVariant),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: children,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterSheetScope extends InheritedWidget {
  const _FilterSheetScope({required this.close, required super.child});

  final VoidCallback close;

  static _FilterSheetScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_FilterSheetScope>();
  }

  @override
  bool updateShouldNotify(_FilterSheetScope oldWidget) {
    return close != oldWidget.close;
  }
}
