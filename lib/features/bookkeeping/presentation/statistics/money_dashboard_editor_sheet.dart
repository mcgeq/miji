import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:miji/features/bookkeeping/application/money_dashboard_layout.dart';

/// 打开「自定义看板」：控制统计页显示哪些卡、以什么顺序显示。
///
/// 统计页有 22 张卡，但每个人常用的可能只有三五张。与其让用户每次滑到
/// 第 5 页去找信用使用率，不如让他把自己的三张拖到最前面。
Future<void> showMoneyDashboardEditorSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _MoneyDashboardEditorSheet(),
  );
}

class _MoneyDashboardEditorSheet extends ConsumerWidget {
  const _MoneyDashboardEditorSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final layoutAsync = ref.watch(moneyDashboardLayoutProvider);
    final layout = layoutAsync.value ?? MoneyDashboardLayout.defaults;
    final controller = ref.read(moneyDashboardLayoutProvider.notifier);
    final hiddenCount = layout.hidden.length;

    // 故意不用 DraggableScrollableSheet：它自己也要吃竖直拖拽手势，
    // 和列表内的长按重排会抢手势，表现是「拖不动 / 拖着拖着整块面板跟着走」。
    // 固定高度 + 内部滚动最稳。
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '自定义看板',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '拖动排序 · 开关控制是否显示'
                        '${hiddenCount > 0 ? ' · 已隐藏 $hiddenCount 张' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => controller.reset(),
                  child: const Text('恢复默认'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
              itemCount: layout.order.length,
              // 用 onReorderItem 而不是已弃用的 onReorder：前者的 newIndex
              // 已经是「移除旧项之后」的下标，正好是 List.insert 需要的语义，
              // 不用再手动 `if (newIndex > oldIndex) newIndex -= 1`。
              onReorderItem: (oldIndex, newIndex) {
                controller.reorder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final card = layout.order[index];
                final visible = layout.isVisible(card);
                return _DashboardCardTile(
                  key: ValueKey<String>('dashboard-card-${card.id}'),
                  card: card,
                  visible: visible,
                  onChanged: (value) => controller.toggle(card, value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardTile extends StatelessWidget {
  const _DashboardCardTile({
    super.key,
    required this.card,
    required this.visible,
    required this.onChanged,
  });

  final MoneyDashboardCard card;
  final bool visible;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Opacity(
      opacity: visible ? 1 : 0.45,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Icon(
          Icons.drag_indicator_rounded,
          size: 20,
          color: colorScheme.onSurfaceVariant,
        ),
        title: Text(
          card.label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        subtitle: Text(
          card.group,
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0,
          ),
        ),
        trailing: Switch(value: visible, onChanged: onChanged),
      ),
    );
  }
}
