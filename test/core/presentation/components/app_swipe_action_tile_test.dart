import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/core/theme/app_theme.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';

/// 左滑动作的**可点性**。
///
/// 之前的布局是「一列竖排」：四个动作挤在 56px 行高里，每个按钮只剩十几像素，
/// 圆点小到点不中。现在两个以上动作排成两列两行 —— 格子跟着行高走，还给行设了
/// 高度下限，所以动作多只会多一行，不会把每个按钮继续压小。
void main() {
  AppSwipeAction action(String tooltip, IconData icon) {
    return AppSwipeAction(
      tooltip: tooltip,
      icon: icon,
      foreground: Colors.white,
      background: Colors.blueGrey,
      onPressed: () {},
    );
  }

  Future<void> pumpTile(
    WidgetTester tester, {
    required List<AppSwipeAction> actions,
    double rowHeight = 56,
  }) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              AppSwipeActionTile(
                actions: actions,
                child: SizedBox(
                  height: rowHeight,
                  child: const Center(child: Text('一行流水')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('四个动作：两列两行，每个格子的可点面积够大', (tester) async {
    await pumpTile(
      tester,
      actions: [
        action('确认入账', Icons.check_rounded),
        action('编辑', Icons.edit_outlined),
        action('复制', Icons.copy_rounded),
        action('删除', Icons.delete_outline_rounded),
      ],
    );

    // 左滑打开。
    await tester.drag(find.text('一行流水'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    for (final (tooltip, row, column) in const [
      ('确认入账', 0, 0),
      ('编辑', 0, 1),
      ('复制', 1, 0),
      ('删除', 1, 1),
    ]) {
      final rect = tester.getRect(find.byTooltip(tooltip));
      // 目标尺寸下限：宽 >= 44、高 >= 28（两列两行时约 50×32）。
      expect(rect.width, greaterThanOrEqualTo(44), reason: '$tooltip 太窄');
      expect(rect.height, greaterThanOrEqualTo(28), reason: '$tooltip 太矮');
      // 位置：第一行在上、第二行在下；左右按列排。
      final other = tester.getRect(find.text('一行流水'));
      expect(rect.center.dx, greaterThan(other.center.dx + 200));
      if (row == 0) {
        expect(rect.center.dy, lessThan(other.center.dy + 40));
      }
      // 同一行的两个格子高度一致（不是一列小圆点）。
      if (column == 1) {
        final left = tester.getRect(find.byTooltip(row == 0 ? '确认入账' : '复制'));
        expect(rect.height, closeTo(left.height, 0.5));
      }
    }
  });

  testWidgets('第一列不贴卡片边缘：左右都留出空隙，格子也收窄了一点', (tester) async {
    await pumpTile(
      tester,
      rowHeight: 72,
      actions: [
        action('编辑', Icons.edit_outlined),
        action('删除', Icons.delete_outline_rounded),
      ],
    );
    await tester.drag(find.text('一行流水'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    final card = tester.getRect(find.text('一行流水'));
    final edit = tester.getRect(find.byTooltip('编辑'));
    final delete = tester.getRect(find.byTooltip('删除'));

    // 卡片滑开后的右边缘与第一列之间至少留 4px。
    expect(
      edit.left - card.right,
      greaterThanOrEqualTo(4),
      reason: '第一列不能紧贴卡片的边框',
    );
    // 整行宽度仍是 2×58 = 116，扣掉左右各 6 的留白与 4 的间距 → 每格 50。
    expect(edit.width, closeTo(50, 1));
    expect(delete.width, closeTo(edit.width, 0.5));
  });

  testWidgets('两个动作：并排两列，各自占满整行高度', (tester) async {
    await pumpTile(
      tester,
      rowHeight: 72,
      actions: [
        action('编辑', Icons.edit_outlined),
        action('删除', Icons.delete_outline_rounded),
      ],
    );
    await tester.drag(find.text('一行流水'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    final edit = tester.getRect(find.byTooltip('编辑'));
    final delete = tester.getRect(find.byTooltip('删除'));
    expect(edit.height, greaterThanOrEqualTo(56));
    expect(delete.height, greaterThanOrEqualTo(56));
    expect(edit.center.dy, closeTo(delete.center.dy, 0.5), reason: '并排而不是上下');
  });

  testWidgets('一个动作：保持单列，不额外占宽', (tester) async {
    await pumpTile(
      tester,
      actions: [action('删除', Icons.delete_outline_rounded)],
    );
    await tester.drag(find.text('一行流水'), const Offset(-200, 0));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byTooltip('删除'));
    expect(rect.width, lessThanOrEqualTo(60), reason: '单动作面板只有一列宽');
    expect(tester.takeException(), isNull);
  });
}
