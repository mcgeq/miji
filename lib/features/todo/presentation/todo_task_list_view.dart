import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 任务列表视图（全部任务 / 已完成）
class TodoTaskListView extends ConsumerStatefulWidget {
  const TodoTaskListView({super.key, this.showCompleted = false});

  final bool showCompleted;

  @override
  ConsumerState<TodoTaskListView> createState() => _TodoTaskListViewState();
}

class _TodoTaskListViewState extends ConsumerState<TodoTaskListView> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final query = _searchController.text.trim();
    final tasksAsync = query.isNotEmpty
        ? ref.watch(todoSearchProvider(query))
        : widget.showCompleted
        ? ref.watch(completedTodoTasksProvider)
        : ref.watch(allTodoTasksProvider);

    return Column(
      children: [
        // V1.1: 搜索栏
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索任务...',
              prefixIcon: Icon(
                Icons.search_rounded,
                color: colorScheme.outline,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: colorScheme.outline,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                setState(() {});
              });
            },
          ),
        ),
        Expanded(
          child: tasksAsync.when(
            data: (tasks) {
              if (tasks.isEmpty) {
                return _buildEmptyState(context);
              }
              return _buildTaskList(context, ref, tasks);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('加载失败: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.showCompleted
                ? Icons.task_alt_rounded
                : Icons.assignment_rounded,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            widget.showCompleted ? '还没有完成的任务' : '还没有任务',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (!widget.showCompleted) ...[
            const SizedBox(height: 8),
            Text(
              '点击右下角 + 创建任务',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTaskList(
    BuildContext context,
    WidgetRef ref,
    List<TodoTask> tasks,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index < tasks.length - 1 ? 8 : 0),
          child: _TodoTaskTile(task: task),
        );
      },
    );
  }
}

class _TodoTaskTile extends ConsumerWidget {
  const _TodoTaskTile({required this.task});

  final TodoTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = task.status == TodoTaskStatus.completed;
    final isCancelled = task.status == TodoTaskStatus.cancelled;
    final isRecurring = task.recurrenceRuleId != null;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.push('/app/gtd/tasks/${task.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (!isCompleted && !isCancelled)
                GestureDetector(
                  onTap: () async {
                    final repo = ref.read(todoRepositoryProvider);
                    await repo.completeTask(task.id);
                    invalidateTodoData(ref);
                    invalidateTodayActionData(ref);
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: colorScheme.outline, width: 2),
                    ),
                  ),
                )
              else
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 22,
                  color: isCompleted
                      ? colorScheme.primary
                      : colorScheme.outline,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        decoration: (isCompleted || isCancelled)
                            ? TextDecoration.lineThrough
                            : null,
                        color: (isCompleted || isCancelled)
                            ? colorScheme.outline
                            : colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isRecurring) ...[
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: colorScheme.tertiary,
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (task.priority == TodoTaskPriority.high)
                          Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: colorScheme.error,
                          ),
                        if (task.priority == TodoTaskPriority.medium)
                          Icon(
                            Icons.flag_rounded,
                            size: 14,
                            color: colorScheme.tertiary,
                          ),
                        if (task.priority != TodoTaskPriority.none &&
                            task.priority != TodoTaskPriority.low)
                          const SizedBox(width: 4),
                        if (task.dueAt != null) ...[
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: task.isOverdue && !isCompleted
                                ? colorScheme.error
                                : colorScheme.outline,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _formatDate(task.dueAt!),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: task.isOverdue && !isCompleted
                                  ? colorScheme.error
                                  : colorScheme.outline,
                              fontWeight: task.isOverdue && !isCompleted
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                        if (task.subTasks.isNotEmpty) ...[
                          if (task.dueAt != null) const SizedBox(width: 8),
                          Icon(
                            Icons.checklist_rounded,
                            size: 12,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${task.subTasks.where((s) => s.status == TodoTaskStatus.completed).length}/${task.subTasks.length}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.outline,
                            ),
                          ),
                        ],
                        // V1.1: 标签
                        if (task.tags.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          ...task.tags
                              .take(2)
                              .map(
                                (tag) => Container(
                                  margin: const EdgeInsets.only(right: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(
                                      int.parse(
                                        tag.color.replaceFirst('#', '0xff'),
                                      ),
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    tag.name,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: Color(
                                        int.parse(
                                          tag.color.replaceFirst('#', '0xff'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          if (task.tags.length > 2)
                            Text(
                              '+${task.tags.length - 2}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (!isCompleted && !isCancelled)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: colorScheme.outline,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (action) async {
                    final repo = ref.read(todoRepositoryProvider);
                    switch (action) {
                      case 'cancel':
                        await repo.cancelTask(task.id);
                      case 'delete':
                        await repo.softDeleteTask(task.id);
                      case 'schedule_today':
                        final updated = task.copyWith(
                          scheduledDate: DateTime.now(),
                        );
                        await repo.updateTask(updated);
                    }
                    invalidateTodoData(ref);
                    invalidateTodayActionData(ref);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'schedule_today',
                      child: Center(
                        child: Tooltip(
                          message: '安排到今天',
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.outline,
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              '今',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Center(
                        child: Tooltip(
                          message: '取消任务',
                          child: Icon(
                            Icons.cancel_rounded,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Center(
                        child: Tooltip(
                          message: '删除',
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (dt.year == tomorrow.year &&
        dt.month == tomorrow.month &&
        dt.day == tomorrow.day) {
      return '明天';
    }
    return '${dt.month}.${dt.day}';
  }
}
