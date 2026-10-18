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
    final groups = _groupTasks(tasks);
    final rows = <Widget>[];
    for (final group in groups) {
      rows.add(_TaskGroupHeader(label: group.label, count: group.tasks.length));
      for (final task in group.tasks) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TodoTaskTile(task: task),
          ),
        );
      }
      rows.add(const SizedBox(height: 6));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: rows,
    );
  }

  /// 按「什么时候该做」分组。
  ///
  /// 先前是一张平铺的长列表：逾期和下周的事混在一起，用户看不出「今天欠了什么」。
  /// 分组只依赖 `dueAt`/`scheduledDate`，不改任何数据。
  List<_TaskGroup> _groupTasks(List<TodoTask> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final overdue = <TodoTask>[];
    final todayTasks = <TodoTask>[];
    final tomorrowTasks = <TodoTask>[];
    final later = <TodoTask>[];
    final noDate = <TodoTask>[];
    final done = <TodoTask>[];

    for (final task in tasks) {
      if (task.status != TodoTaskStatus.todo) {
        done.add(task);
        continue;
      }
      final due = task.dueAt ?? task.scheduledDate;
      if (due == null) {
        noDate.add(task);
        continue;
      }
      final day = DateTime(due.year, due.month, due.day);
      if (day.isBefore(today)) {
        overdue.add(task);
      } else if (day == today) {
        todayTasks.add(task);
      } else if (day == tomorrow) {
        tomorrowTasks.add(task);
      } else {
        later.add(task);
      }
    }

    // 组内排序：逾期最久的在前，其余按日期近的在前，无日期的按创建时间倒序。
    overdue.sort(
      (a, b) =>
          (a.dueAt ?? a.scheduledDate!).compareTo(b.dueAt ?? b.scheduledDate!),
    );
    int byDue(TodoTask a, TodoTask b) =>
        (a.dueAt ?? a.scheduledDate!).compareTo(b.dueAt ?? b.scheduledDate!);
    todayTasks.sort(byDue);
    tomorrowTasks.sort(byDue);
    later.sort(byDue);

    return [
      if (overdue.isNotEmpty) _TaskGroup('逾期', overdue),
      if (todayTasks.isNotEmpty) _TaskGroup('今天', todayTasks),
      if (tomorrowTasks.isNotEmpty) _TaskGroup('明天', tomorrowTasks),
      if (later.isNotEmpty) _TaskGroup('之后', later),
      if (noDate.isNotEmpty) _TaskGroup('没有日期', noDate),
      if (done.isNotEmpty) _TaskGroup('已结束', done),
    ];
  }
}

class _TaskGroup {
  const _TaskGroup(this.label, this.tasks);

  final String label;
  final List<TodoTask> tasks;
}

class _TaskGroupHeader extends StatelessWidget {
  const _TaskGroupHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = label == '逾期';
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: danger ? scheme.error : scheme.onSurface,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoTaskTile extends ConsumerWidget {
  const _TodoTaskTile({required this.task});

  final TodoTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCompleted = task.status == TodoTaskStatus.completed;
    final isCancelled = task.status == TodoTaskStatus.cancelled;
    final settled = isCompleted || isCancelled;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/app/gtd/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 勾选：22px 圆环 + 44px 可点区域（视觉小、手感大）。
              SizedBox(
                width: 34,
                height: 34,
                child: settled
                    ? Icon(
                        isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 22,
                        color: isCompleted ? scheme.primary : scheme.outline,
                      )
                    : InkResponse(
                        radius: 20,
                        onTap: () async {
                          final repo = ref.read(todoRepositoryProvider);
                          await repo.completeTask(task.id);
                          invalidateTodoData(ref);
                          invalidateTodayActionData(ref);
                        },
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: scheme.outline,
                                width: 1.6,
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        decoration: settled ? TextDecoration.lineThrough : null,
                        color: settled ? scheme.outline : scheme.onSurface,
                        letterSpacing: 0,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_hasMeta) ...[
                      const SizedBox(height: 4),
                      // 元信息一律进 Wrap：日期、标签、子任务、重复、优先级
                      // 挤在一个 Row 里在 390 宽上会溢出（标签多时尤其明显）。
                      Wrap(
                        spacing: 6,
                        runSpacing: 3,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: _metaChips(context, theme, scheme),
                      ),
                    ],
                  ],
                ),
              ),
              if (!settled)
                PopupMenuButton<String>(
                  tooltip: '更多',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    size: 18,
                    color: scheme.outline,
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
                        await repo.updateTask(
                          task.copyWith(scheduledDate: DateTime.now()),
                        );
                    }
                    invalidateTodoData(ref);
                    invalidateTodayActionData(ref);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'schedule_today',
                      child: Text('安排到今天'),
                    ),
                    PopupMenuItem(value: 'cancel', child: Text('取消任务')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _hasMeta =>
      task.dueAt != null ||
      task.scheduledDate != null && task.dueAt == null ||
      task.category != null ||
      task.tags.isNotEmpty ||
      task.subTasks.isNotEmpty ||
      task.recurrenceRuleId != null ||
      task.priority != TodoTaskPriority.none;

  /// 元信息：日期 / 分类 / 子任务 / 重复 / 优先级 / 标签。
  ///
  /// 顺序按「决定要不要现在做」排列：日期最前，其次分类与进度，标签放最后。
  List<Widget> _metaChips(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    final overdue = task.isOverdue && task.status == TodoTaskStatus.todo;
    final due = task.dueAt ?? task.scheduledDate;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: overdue ? scheme.error : scheme.onSurfaceVariant,
      fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
      letterSpacing: 0,
    );

    return [
      if (due != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              task.dueAt != null ? Icons.schedule_rounded : Icons.event_rounded,
              size: 12,
              color: overdue ? scheme.error : scheme.outline,
            ),
            const SizedBox(width: 3),
            Text(
              task.dueAt != null ? _formatDate(task.dueAt!) : _formatDay(due),
              style: style,
            ),
          ],
        ),
      if (task.category != null)
        _MetaChip(label: task.category!.name, color: scheme.onSurfaceVariant),
      if (task.subTasks.isNotEmpty)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checklist_rounded, size: 12, color: scheme.outline),
            const SizedBox(width: 3),
            Text(
              '${task.subTasks.where((s) => s.status == TodoTaskStatus.completed).length}/${task.subTasks.length}',
              style: style,
            ),
          ],
        ),
      if (task.recurrenceRuleId != null)
        Icon(Icons.repeat_rounded, size: 12, color: scheme.tertiary),
      if (task.priority == TodoTaskPriority.high)
        _MetaChip(label: '高', color: scheme.error),
      if (task.priority == TodoTaskPriority.medium)
        _MetaChip(label: '中', color: scheme.tertiary),
      for (final tag in task.tags.take(2))
        _MetaChip(label: tag.name, color: _parseColor(tag.color, scheme)),
      if (task.tags.length > 2) Text('+${task.tags.length - 2}', style: style),
    ];
  }

  Color _parseColor(String raw, ColorScheme scheme) {
    final value = int.tryParse(raw.replaceFirst('#', '0xff'));
    return value == null ? scheme.onSurfaceVariant : Color(value);
  }

  String _formatDay(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天';
    }
    return '${dt.month}.${dt.day}';
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

/// 一枚 11px 的小标签：分类、优先级、标签共用。
class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
