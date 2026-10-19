import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';
import 'package:miji/features/todo/domain/todo_models.dart';

/// 今日待办卡：可直接完成 / 新增 / 编辑 / 删除，不必跳 GTD。
class HomeActionTodoCard extends StatelessWidget {
  const HomeActionTodoCard({
    super.key,
    required this.brief,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenAll,
  });

  final HomeActionBrief brief;
  final ValueChanged<TodoTask> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<TodoTask> onEdit;
  final ValueChanged<TodoTask> onDelete;
  final VoidCallback onOpenAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final total = brief.totalCount;
    final progress = total > 0
        ? (brief.completedCount / total).clamp(0.0, 1.0)
        : 0.0;

    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '✅ 今日待办',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (brief.streakDays > 0)
                Text(
                  '🔥 连续 ${brief.streakDays} 天',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${brief.completedCount} / $total',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
            ),
          ),
          const SizedBox(height: 6),
          if (brief.todos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '今天没有待办',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final entry in brief.todos)
              _TodoRow(
                task: entry.task,
                onToggle: () => onToggle(entry.task),
                onEdit: () => onEdit(entry.task),
                onDelete: () => onDelete(entry.task),
              ),
          const SizedBox(height: 4),
          Row(
            children: [
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加待办'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
        ],
      ),
    );
  }
}

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final TodoTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
      onTap: onEdit,
      onLongPress: onDelete,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onToggle,
              icon: Icon(
                done
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: done ? colorScheme.primary : colorScheme.outline,
              ),
            ),
            if (dotColor != null && !done) ...[
              Container(
                width: 7,
                height: 7,
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
                task.overdueLabelAt(DateTime.now()),
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
