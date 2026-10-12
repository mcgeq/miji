import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

/// 今日三宫格：钱 / 健康 / 行动同级。格子数 2–3，由布局决定。
class HomeTodayBoard extends StatelessWidget {
  const HomeTodayBoard({
    super.key,
    required this.data,
    required this.onTapCell,
  });

  final HomeTodayBoardData data;
  final ValueChanged<HomeBlockId> onTapCell;

  @override
  Widget build(BuildContext context) {
    final cells = data.cells;
    if (cells.isEmpty) {
      return const SizedBox.shrink();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(
              child: _BoardCellTile(
                cell: cells[i],
                onTap: () => onTapCell(cells[i].id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BoardCellTile extends StatelessWidget {
  const _BoardCellTile({required this.cell, required this.onTap});

  final HomeBoardCell cell;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(cell.emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 7),
          Text(
            cell.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cell.sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
