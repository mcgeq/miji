import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 概览页的「接下来」紧凑待办：最多 3 条、可直接勾选。
///
/// 与「行动」页的完整待办卡共用同一份 [HomeActionBrief]；这里只做减法，
/// 避免和行动页完全重复。
class HomeUpNextCard extends StatelessWidget {
  const HomeUpNextCard({
    super.key,
    required this.brief,
    required this.onToggle,
    required this.onAdd,
    required this.onOpenAll,
    this.maxItems = 3,
  });

  final HomeActionBrief brief;
  final ValueChanged<TodoTask> onToggle;
  final VoidCallback? onAdd;
  final VoidCallback onOpenAll;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final todos = brief.todos.take(maxItems).toList(growable: false);

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '接下来',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 7),
              if (brief.totalCount > 0)
                Text(
                  '${brief.completedCount} / ${brief.totalCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              const Spacer(),
              TextButton(
                onPressed: onOpenAll,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('查看全部 ›'),
              ),
            ],
          ),
          if (todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '今天没有待办',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final entry in todos)
              _UpNextRow(
                task: entry.task,
                onToggle: () => onToggle(entry.task),
              ),
          if (onAdd != null) ...[
            const SizedBox(height: 2),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('添加待办'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpNextRow extends StatelessWidget {
  const _UpNextRow({required this.task, required this.onToggle});

  final TodoTask task;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final done = task.status == TodoTaskStatus.completed;
    final overdue = task.isOverdue && !done;
    final dotColor = switch (task.priority) {
      TodoTaskPriority.high => colorScheme.error,
      TodoTaskPriority.medium => colorScheme.tertiary,
      TodoTaskPriority.low => colorScheme.primary,
      TodoTaskPriority.none => null,
    };

    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(
          children: [
            Icon(
              done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: done ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 9),
            if (dotColor != null && !done) ...[
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? colorScheme.onSurfaceVariant : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (overdue)
              Text(
                '逾期',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
