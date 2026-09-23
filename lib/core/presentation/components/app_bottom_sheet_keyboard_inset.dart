import 'package:flutter/material.dart';
import 'package:miji/core/presentation/components/app_dialog_keyboard_scroll.dart';

/// 贴底面板（`showModalBottomSheet`）的键盘避让包装。
///
/// 为什么需要它：Flutter 的 `showModalBottomSheet` **不会**为键盘让位。面板贴底、
/// 内部又有输入框时，键盘一顶上来，下面那一截就被盖住 —— 搜索框 / 搜索结果是
/// 重灾区（分类叶子面板与筛选抽屉都踩过）。
///
/// 它做两件事：
/// 1. 整体上移 `viewInsets.bottom`，并随时间动画；
/// 2. 把高度上限压到「键盘上方的可用空间」（[maxHeight] 是内容自身的上限，
///    例如不希望面板长到占满全屏时传 560；传 null 表示不额外限制）。
///
/// 用法：
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   builder: (_) => AppBottomSheetKeyboardInset(
///     maxHeight: 560,
///     child: MySheetContent(),
///   ),
/// );
/// ```
class AppBottomSheetKeyboardInset extends StatelessWidget {
  const AppBottomSheetKeyboardInset({
    super.key,
    required this.child,
    this.maxHeight,
    this.minHeight = 180,
    this.topGap = 24,
  });

  final Widget child;

  /// 面板高度上限；null 表示只做键盘避让、不限制高度。
  final double? maxHeight;

  /// 高度下限，避免键盘很大时把面板压没。
  final double minHeight;

  /// 顶部预留（避免紧贴状态栏）。
  final double topGap;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight =
        media.size.height - keyboardInset - media.padding.top - topGap;
    final limit = maxHeight;
    final resolvedMaxHeight = limit == null
        ? (availableHeight < minHeight ? minHeight : availableHeight)
        : availableHeight.clamp(minHeight, limit).toDouble();

    return AnimatedPadding(
      duration: appDialogKeyboardTransitionDuration,
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: resolvedMaxHeight),
        child: child,
      ),
    );
  }
}
