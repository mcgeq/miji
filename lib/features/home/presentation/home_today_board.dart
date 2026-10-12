import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/home/application/home_today_board_providers.dart';
import 'package:miji/features/home/domain/home_block.dart';

/// 今日三宫格：钱 / 健康 / 计划同级。格子数 2–3，由布局决定。
///
/// 每格统一四层：模块名（这一格是什么）→ 主值（最重要的大数字）→
/// 主值口径（这个数字是什么）→ 次要指标。旧版只有「大数字 + 一行粘连的
/// 副文案」，用户看不出大数字属于哪一项，也分不清副文案里两个金额的主次。
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
    final textTheme = theme.textTheme;

    final valueColor = cell.valueAlert
        ? theme.moneyColors.expense
        : colorScheme.onSurface;

    final mutedStyle = textTheme.labelSmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      height: 1.25,
    );

    final noteLabel = cell.noteLabel;
    final noteValue = cell.noteValue;

    return AppSurface(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 第一层：这一格是什么。旧版只有一个 emoji，用户得靠猜。
          Row(
            children: [
              Text(cell.emoji, style: const TextStyle(fontSize: 13, height: 1)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  cell.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // 第二层：主值。
          Text(
            cell.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          // 第三层：主值口径。紧贴主值，字号更小，读作「<label>：<value>」。
          Text(
            cell.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: mutedStyle,
          ),
          if (noteLabel != null) ...[
            const SizedBox(height: 8),
            // 一条极淡的分隔线，把「主指标」和「次要指标」在视觉上分开。
            Container(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 7),
            if (noteValue == null)
              Text(
                noteLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: mutedStyle,
              )
            else ...[
              Text(
                noteLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mutedStyle,
              ),
              const SizedBox(height: 1),
              Text(
                noteValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                  height: 1.2,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
