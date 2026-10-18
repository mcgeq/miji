import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/presentation/plans/habit_plan_row.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 今日行动流视图（混排 Todo 和习惯打卡）
class TodayActionListView extends ConsumerWidget {
  const TodayActionListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionViewAsync = ref.watch(todayActionItemsProvider);

    return actionViewAsync.when(
      data: (view) {
        if (view.items.isEmpty) {
          return _buildEmptyState(context);
        }
        return _buildActionList(context, ref, view);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.today_rounded,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '今日没有待办事项',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建任务或打卡计划，开始行动吧',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionList(
    BuildContext context,
    WidgetRef ref,
    TodayActionView view,
  ) {
    final theme = Theme.of(context);

    // 分开展示逾期、待完成、已完成
    final overdue = view.items
        .where(
          (item) =>
              item is TodayTodoActionItem &&
              item.task.isOverdue &&
              !item.isCompleted,
        )
        .toList();
    final active = view.items
        .where((item) => !item.isCompleted && !overdue.contains(item))
        .toList();
    final completed = view.items.where((item) => item.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // 进度摘要
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                '已完成 ${view.completedCount} / ${view.totalCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (view.completionRate >= 1.0 && view.totalCount > 0)
                Text(
                  '🎉 全部完成',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.green.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        // 逾期任务
        if (overdue.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '逾期',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...overdue.map((item) => _TodayActionTile(item: item)),
          const SizedBox(height: 12),
        ],
        // 待完成
        if (active.isNotEmpty) ...[
          if (overdue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '待完成',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ...active.map((item) => _TodayActionTile(item: item)),
        ],
        // 已完成（可折叠）
        if (completed.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CompletedSection(completed: completed),
        ],
      ],
    );
  }
}

class _CompletedSection extends StatefulWidget {
  const _CompletedSection({required this.completed});

  final List<TodayActionItem> completed;

  @override
  State<_CompletedSection> createState() => _CompletedSectionState();
}

class _CompletedSectionState extends State<_CompletedSection> {
  /// 默认展开：打卡/完成任务之后那一条要立刻看得见。
  ///
  /// 之前这里是折叠的，于是点完进度环整行「消失」进折叠区 —— 没有任何东西
  /// 证明刚才那一下生效了。嫌吵就点一下折起来，选择在这一屏的生命周期里保留。
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant _CompletedSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 刚完成的那一刻自动展开：打卡之后行被折进「已完成」、什么都看不见，
    // 用户会怀疑刚才那一下有没有生效。折叠的价值在平时（不占地方），
    // 不在完成的瞬间。
    if (widget.completed.length > oldWidget.completed.length) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '已完成 (${widget.completed.length})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          ...widget.completed.map((item) => _TodayActionTile(item: item)),
      ],
    );
  }
}

class _TodayActionTile extends ConsumerWidget {
  const _TodayActionTile({required this.item});

  final TodayActionItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final it = item;
    if (it is TodayTodoActionItem) {
      return _TodoActionTile(task: it.task);
    }
    if (it is TodayHabitActionItem) {
      return _HabitActionTile(progress: it.progress);
    }
    return const SizedBox.shrink();
  }
}

class _TodoActionTile extends ConsumerWidget {
  const _TodoActionTile({required this.task});

  final TodoTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverdue = task.isOverdue;
    final isCompleted = task.status == TodoTaskStatus.completed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
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
                // Checkbox
                GestureDetector(
                  onTap: () async {
                    if (!isCompleted) {
                      final repo = ref.read(todoRepositoryProvider);
                      await repo.completeTask(task.id);
                      invalidateTodayActionData(ref);
                    }
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCompleted
                          ? Colors.green.shade400
                          : Colors.transparent,
                      border: Border.all(
                        color: isCompleted
                            ? Colors.green.shade400
                            : isOverdue
                            ? colorScheme.error
                            : colorScheme.outline,
                        width: 2,
                      ),
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                // 标题和标记
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                decoration: isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: isCompleted
                                    ? colorScheme.outline
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isOverdue && !isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '逾期',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // 任务标记
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.tertiaryContainer.withValues(
                                alpha: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '任务',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onTertiaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (task.priority == TodoTaskPriority.high) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.flag_rounded,
                              size: 14,
                              color: Colors.red.shade400,
                            ),
                          ],
                          if (task.dueAt != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: colorScheme.outline,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDueTime(task.dueAt!),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                          if (task.subTasks.isNotEmpty) ...[
                            const SizedBox(width: 6),
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
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDueTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _HabitActionTile extends StatelessWidget {
  const _HabitActionTile({required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context) {
    // 习惯行与「习惯」列表共用 `HabitPlanRow`：图标、副行、右侧动作（进度环 /
    // 计时 / 拍照）都在那一处实现，今日这边只负责它排在混排列表的第几个。
    return HabitPlanRow(progress: progress, dense: true);
  }
}
