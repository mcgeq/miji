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
      //
      // 高度按内容撑开（上限 85% 屏高）。原来是固定的 55% 拖拽面板：流水页
      // 把次要条件收进折叠区后只剩两行，底部会留下半屏空白，而内容一多又要
      // 在小窗里滚。改成「装得下就装、装不下才滚」后，短面板是短的。
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        return AppBottomSheetKeyboardInset(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: _FilterSheetScope(
              close: () => Navigator.of(sheetContext).pop(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  // `Flexible`（而不是 `Expanded`）：内容矮时收缩到内容高度，
                  // 撑到 85% 上限后才开始滚。
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
