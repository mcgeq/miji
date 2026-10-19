import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/auth_session_controller.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/presentation/plans/habit_plan_row.dart';
import 'package:miji/features/todo/domain/today_board.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/presentation/todo_quick_create_sheet.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';

/// 今日行动流视图（待办 + 习惯打卡，按一天的时间轴分段）。
///
/// 这一屏要回答三件事：**今天还剩几件**（HUD）、**什么时候做什么**（时间分段）、
/// **最紧的是哪件**（HUD 上的焦点行）。改版前它是一张「逾期 / 待完成 / 已完成」
/// 的平铺清单 ——「待完成」承载 90% 的行，等于没有分组，而 `dueAt` 只在行尾以
/// `18:00` 小字出现，布局上完全看不出一天的形状。
///
/// 段序固定为「逾期 → 随时 → 上午 → 下午 → 晚上 → 打卡 → 已完成」；「随时」紧跟
/// 逾期是刻意决策，打卡单独成段是因为它的完成方式是计数 / 计时 / 拍照。
class TodayActionListView extends ConsumerWidget {
  const TodayActionListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardAsync = ref.watch(todayBoardProvider);

    return boardAsync.when(
      data: (board) => _TodayBoardBody(ref: ref, board: board),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('加载失败: $error')),
    );
  }
}

/// 有状态的那部分单独拆出来，**外层必须是 `ConsumerWidget`**。
///
/// `ConsumerStatefulWidget` 的 element 会按 `TickerMode` 暂停 / 恢复 provider
/// 订阅：被路由盖住时暂停，回来时 `resume()`。而 resume 会同步 flush 依赖并
/// 触发 rebuild —— 那一刻框架正在 build 别的 widget（路由 transition 里的
/// `_OverlayEntryWidget`），于是 Riverpod 的 `scheduleRefresh` 抛
/// `setState() called during build`。把 watch 留在 ConsumerWidget 上、State 交给
/// 普通 StatefulWidget，就没有这条暂停链路了。
class _TodayBoardBody extends StatefulWidget {
  const _TodayBoardBody({required this.ref, required this.board});

  final WidgetRef ref;
  final TodayBoard board;

  @override
  State<_TodayBoardBody> createState() => _TodayBoardBodyState();
}

class _TodayBoardBodyState extends State<_TodayBoardBody> {
  final _addController = TextEditingController();
  final _addFocusNode = FocusNode();

  /// 长按进入多选后选中的待办 id。打卡不参与多选（它的「完成」是计数 / 计时，
  /// 语义与勾选不同）。
  final _selectedIds = <String>{};

  /// 「已完成」默认折叠：改成默认展开之后，每勾一条就把整块内容顶下来一次。
  var _completedExpanded = false;

  WidgetRef get ref => widget.ref;

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: _buildBody(context, widget.board)),
        if (_selecting)
          _BulkBar(
            count: _selectedIds.length,
            onComplete: () => _completeSelected(),
            onMoveToToday: () => _moveSelectedToToday(),
            onClear: () => setState(_selectedIds.clear),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, TodayBoard board) {
    if (board.isEmpty) {
      return _EmptyState(
        onQuickCreate: () => _openQuickCreate(),
        onPickUnscheduled: () => _openUnscheduledPicker(),
      );
    }

    final sections = board.visibleSections.toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        _TodayHud(board: board),
        const SizedBox(height: 10),
        _QuickAddBar(
          controller: _addController,
          focusNode: _addFocusNode,
          onSubmit: () => _createFromBar(),
        ),
        for (final section in sections) ...[
          if (section.kind == TodaySectionKind.completed)
            _CompletedSection(
              items: section.items,
              expanded: _completedExpanded,
              onToggle: () =>
                  setState(() => _completedExpanded = !_completedExpanded),
            )
          else
            _OpenSection(
              section: section,
              selecting: _selecting,
              selectedIds: _selectedIds,
              onToggleComplete: _toggleTodo,
              onOpen: _openTodoDetail,
              onLongPress: _toggleSelection,
              onMore: _showRowActions,
              onMoveAllToToday: () => _moveAllToToday(section),
            ),
        ],
        if (board.isAllDone) const _AllDonePanel(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // 动作
  // -------------------------------------------------------------------------

  Future<void> _createFromBar() async {
    final title = _addController.text.trim();
    if (title.isEmpty) return;

    final session = ref.read(authSessionControllerProvider);
    final userId = session.userId;
    if (userId == null) return;

    await ref
        .read(todoRepositoryProvider)
        .createTask(
          TodoTaskDraft(title: title, scheduledDate: DateTime.now()),
          userId,
        );

    if (!mounted) return;
    _addController.clear();
    _addFocusNode.unfocus();
    invalidateTodayActionData(ref);
  }

  Future<void> _toggleTodo(TodoTask task) async {
    final repo = ref.read(todoRepositoryProvider);
    if (task.status == TodoTaskStatus.completed) {
      await repo.reopenTask(task.id);
    } else {
      await repo.completeTask(task.id);
    }
    invalidateTodayActionData(ref);
  }

  void _openTodoDetail(TodoTask task) {
    context.push('/app/gtd/tasks/${task.id}');
  }

  void _toggleSelection(TodoTask task) {
    setState(() {
      if (!_selectedIds.remove(task.id)) {
        _selectedIds.add(task.id);
      }
    });
  }

  Future<void> _completeSelected() async {
    final repo = ref.read(todoRepositoryProvider);
    for (final id in _selectedIds) {
      await repo.completeTask(id);
    }
    if (!mounted) return;
    setState(_selectedIds.clear);
    invalidateTodayActionData(ref);
    AppToast.success(
      FToast()..init(context),
      context,
      '已完成 ${_selectedIds.length} 项',
    );
  }

  Future<void> _moveSelectedToToday() async {
    final ids = _selectedIds.toList(growable: false);
    final moved = await _moveToDay(ids, DateTime.now());
    if (!mounted) return;
    setState(_selectedIds.clear);
    if (moved > 0) {
      AppToast.success(FToast()..init(context), context, '已把 $moved 项改到今天');
    }
  }

  Future<void> _moveAllToToday(TodaySection section) async {
    final ids = section.items
        .whereType<TodayTodoActionItem>()
        .map((item) => item.task.id)
        .toList(growable: false);
    final moved = await _moveToDay(ids, DateTime.now());
    if (!mounted || moved == 0) return;
    AppToast.success(FToast()..init(context), context, '已把 $moved 项改到今天');
  }

  /// 把一批任务挪到 [day]。
  ///
  /// `dueAt` 必须一起挪，否则「改到今天」只是改了 `scheduledDate`，而
  /// `isOverdueAt` 优先看 `dueAt` —— 任务会原封不动留在逾期段里。有具体时间的
  /// 保留时刻（18:00 到期改成今天 18:00），没有时间的只改排期日。
  Future<int> _moveToDay(List<String> ids, DateTime day) async {
    final repo = ref.read(todoRepositoryProvider);
    var moved = 0;
    for (final id in ids) {
      final task = await repo.getTask(id);
      if (task == null) continue;
      final due = task.dueAt;
      await repo.updateTask(
        task.copyWith(
          scheduledDate: day,
          dueAt: due == null
              ? null
              : DateTime(day.year, day.month, day.day, due.hour, due.minute),
        ),
      );
      moved++;
    }
    invalidateTodayActionData(ref);
    return moved;
  }

  /// 左滑 / 长按唤出的行内动作。
  Future<void> _showRowActions(TodoTask task) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RowActionsSheet(task: task),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case 'today':
        await _moveToDay([task.id], DateTime.now());
      case 'reschedule':
        await _reschedule(task);
      case 'delete':
        await ref.read(todoRepositoryProvider).softDeleteTask(task.id);
        invalidateTodayActionData(ref);
        if (!mounted) return;
        AppToast.success(FToast()..init(context), context, '已删除');
      case 'open':
        _openTodoDetail(task);
    }
  }

  Future<void> _reschedule(TodoTask task) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: task.dueAt ?? task.scheduledDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _moveToDay([task.id], picked);
  }

  Future<void> _openQuickCreate() async {
    final created = await showTodoQuickCreateSheet(context);
    if (created == true && mounted) {
      AppToast.success(FToast()..init(context), context, '任务已创建');
    }
  }

  Future<void> _openUnscheduledPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _UnscheduledSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// HUD：今天还剩几件
// ---------------------------------------------------------------------------

class _TodayHud extends StatelessWidget {
  const _TodayHud({required this.board});

  final TodayBoard board;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();

    final done = board.isAllDone;
    final progress = board.totalCount == 0
        ? 0.0
        : (board.completedCount / board.totalCount).clamp(0.0, 1.0);

    return AppSurface(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          // 环内写「还剩几件」而不是完成百分比：看今日是要知道还要做多少。
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: colorScheme.outlineVariant.withValues(
                      alpha: 0.35,
                    ),
                    color: done ? Colors.green.shade600 : colorScheme.primary,
                  ),
                ),
                Text(
                  done ? '✓' : '${board.remainingCount}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: done ? Colors.green.shade600 : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  done ? '今天全做完了' : '今天还剩 ${board.remainingCount} 件',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${now.month} 月 ${now.day} 日 ${_weekdayOf(now)} · '
                  '已完成 ${board.completedCount} / ${board.totalCount}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [],
                  ),
                ),
                if (board.focus != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _focusText(board.focus!, now),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: board.focus!.isOverdue
                          ? colorScheme.error
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _focusText(TodayFocus focus, DateTime now) {
    final item = focus.item;
    if (item is TodayTodoActionItem) {
      final title = item.task.title;
      if (focus.isOverdue) {
        final days = item.task.overdueDaysAt(now);
        return days > 0 ? '最紧：$title · 逾期 $days 天' : '最紧：$title · 逾期';
      }
      final due = item.task.dueAt;
      return due == null ? '接下来：$title' : '接下来：$title · ${_hhmm(due)}';
    }
    if (item is TodayHabitActionItem) {
      return '接下来：${item.progress.plan.name}';
    }
    return '';
  }
}

String _weekdayOf(DateTime date) {
  const names = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return names[date.weekday - 1];
}

String _hhmm(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// 常驻快速添加
// ---------------------------------------------------------------------------

/// 今日页顶部常驻的输入行。
///
/// 以前这一屏**加不了任务**——工具栏上只有「新建计划」，「新建任务」只挂在
/// 「任务」面板。对一个每天要进出十几次的页面来说，这是最贵的一次切页。
class _QuickAddBar extends StatelessWidget {
  const _QuickAddBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 6, 4),
          child: Row(
            children: [
              Icon(
                Icons.add_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    hintText: '添加任务到今天…',
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.outline,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              IconButton(
                onPressed: onSubmit,
                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                visualDensity: VisualDensity.compact,
                tooltip: '添加',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 未完成的段
// ---------------------------------------------------------------------------

class _OpenSection extends StatelessWidget {
  const _OpenSection({
    required this.section,
    required this.selecting,
    required this.selectedIds,
    required this.onToggleComplete,
    required this.onOpen,
    required this.onLongPress,
    required this.onMore,
    required this.onMoveAllToToday,
  });

  final TodaySection section;
  final bool selecting;
  final Set<String> selectedIds;

  /// 完成是异步的：右滑松手要等写入落库再刷新，否则列表会先闪回原状。
  final Future<void> Function(TodoTask) onToggleComplete;
  final ValueChanged<TodoTask> onOpen;
  final ValueChanged<TodoTask> onLongPress;
  final ValueChanged<TodoTask> onMore;
  final VoidCallback onMoveAllToToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOverdue = section.kind == TodaySectionKind.overdue;
    final timeHint = section.kind.timeRangeHint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
          child: Row(
            children: [
              Text(
                section.kind.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isOverdue
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '${section.items.length}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (timeHint != null) ...[
                const SizedBox(width: 5),
                Text(
                  timeHint,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const Spacer(),
              // 批量入口长在最需要它的地方：逾期堆了一堆时不用一条条点。
              if (isOverdue && !selecting)
                TextButton(
                  onPressed: onMoveAllToToday,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('全部改到今天'),
                ),
            ],
          ),
        ),
        for (final item in section.items) _buildRow(item),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildRow(TodayActionItem item) {
    if (item is TodayHabitActionItem) {
      return HabitPlanRow(progress: item.progress, dense: true);
    }
    final task = (item as TodayTodoActionItem).task;
    return _TodoRow(
      key: ValueKey('todo-${task.id}'),
      task: task,
      selecting: selecting,
      selected: selectedIds.contains(task.id),
      onToggleComplete: () => onToggleComplete(task),
      onOpen: () => onOpen(task),
      onLongPress: () => onLongPress(task),
      onMore: () => onMore(task),
    );
  }
}

// ---------------------------------------------------------------------------
// 待办行
// ---------------------------------------------------------------------------

class _TodoRow extends StatelessWidget {
  const _TodoRow({
    super.key,
    required this.task,
    required this.selecting,
    required this.selected,
    required this.onToggleComplete,
    required this.onOpen,
    required this.onLongPress,
    required this.onMore,
  });

  final TodoTask task;
  final bool selecting;
  final bool selected;
  final Future<void> Function() onToggleComplete;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = DateTime.now();
    final overdue = task.isOverdueAt(now);
    final overdueLabel = task.overdueLabelAt(now);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Dismissible(
        key: ValueKey('dismiss-${task.id}-${task.status.value}'),
        // 多选时关掉滑动：这时候手指在做选择，误滑完成会很难受。
        direction: selecting
            ? DismissDirection.none
            : DismissDirection.horizontal,
        // 右滑：完成。左滑：改期 / 删除（次要动作，不占行内空间）。
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: Colors.green.shade600,
          icon: Icons.check_rounded,
          label: '完成',
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: colorScheme.surfaceContainerHighest,
          icon: Icons.more_horiz_rounded,
          label: '更多',
          foreground: colorScheme.onSurfaceVariant,
        ),
        // 一律返回 false：让**数据**决定这一行的去留，而不是让 Dismissible 把它
        // 从树上摘掉。完成的待办会移到「已完成」段，同一条数据换个段重新出现，
        // 若此时返回 true，Dismissible 会因为「已消失的 widget 仍在树里」而断言。
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            await onToggleComplete();
          } else {
            onMore();
          }
          return false;
        },
        child: AppSurface(
          padding: const EdgeInsets.fromLTRB(8, 8, 10, 8),
          onTap: selecting ? onLongPress : onOpen,
          child: Row(
            children: [
              _CheckCircle(
                overdue: overdue,
                selected: selected,
                selecting: selecting,
                onTap: selecting ? () async => onLongPress() : onToggleComplete,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    _TodoMetaLine(task: task, overdueLabel: overdueLabel),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (task.priority == TodoTaskPriority.high)
                Icon(Icons.flag_rounded, size: 15, color: Colors.red.shade400)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 勾选圈。
///
/// 命中区撑到 44×44（视觉上仍是 24px 的圈）—— 改版前它是裸的 22px
/// `GestureDetector`，嵌在整行的 `InkWell` 里，想勾中却进了详情页是这一屏
/// 最常见的误触。
class _CheckCircle extends StatelessWidget {
  const _CheckCircle({
    required this.overdue,
    required this.selecting,
    required this.selected,
    required this.onTap,
  });

  final bool overdue;
  final bool selecting;
  final bool selected;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filled = selecting ? selected : false;

    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: filled
                  ? colorScheme.primary
                  : overdue
                  ? colorScheme.error
                  : colorScheme.outline,
              width: 1.6,
            ),
          ),
          child: filled
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}

/// 第二行 meta：分类色点 · 时间 · 子任务。
///
/// 最多三段，绝不换行 —— 换行会让同一段里的行高参差不齐。改版前这里挂的是一枚
/// 「任务」标签，整页都是任务，那枚标签零信息量；分类才是有筛选价值的东西。
class _TodoMetaLine extends StatelessWidget {
  const _TodoMetaLine({required this.task, required this.overdueLabel});

  final TodoTask task;
  final String overdueLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final base = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.2,
      letterSpacing: 0,
      color: colorScheme.outline,
      fontFeatures: const [],
    );

    final category = task.category;
    final children = <Widget>[];

    children.add(
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _categoryColor(category, colorScheme),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category?.name ?? '未分类',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: base,
            ),
          ),
        ],
      ),
    );

    if (task.dueAt != null) {
      children.add(Text(_hhmm(task.dueAt!), style: base));
    }

    if (overdueLabel.isNotEmpty) {
      children.add(
        Text(
          overdueLabel,
          style: base?.copyWith(
            color: colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (task.subTasks.isNotEmpty) {
      final done = task.subTasks
          .where((s) => s.status == TodoTaskStatus.completed)
          .length;
      children.add(Text('子任务 $done/${task.subTasks.length}', style: base));
    }

    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.outlineVariant,
                ),
              ),
            ),
          Flexible(child: children[i]),
        ],
      ],
    );
  }

  Color _categoryColor(TodoCategory? category, ColorScheme colorScheme) {
    final hex = category?.color;
    if (hex == null || hex.isEmpty) return colorScheme.outline;
    final value = int.tryParse(hex.replaceFirst('#', '0xFF'));
    if (value == null) return colorScheme.outline;
    return Color(value);
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    this.foreground = Colors.white,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 已完成
// ---------------------------------------------------------------------------

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({
    required this.items,
    required this.expanded,
    required this.onToggle,
  });

  final List<TodayActionItem> items;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(theme.radiusTokens.sm),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 17,
                  color: colorScheme.outline,
                ),
                const SizedBox(width: 4),
                Text(
                  '已完成 ${items.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.outline,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          for (final item in items)
            switch (item) {
              // 打卡项保留完整行：它的环既是进度也是「撤销一次打卡」的入口，
              // 压成一行就把今日页上唯一的撤销路径弄没了。
              TodayHabitActionItem(:final progress) => HabitPlanRow(
                progress: progress,
                dense: true,
              ),
              // 待办压成一行：只留标题，不再显示 meta。
              _ => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AppSurface(
                  tone: AppSurfaceTone.subtle,
                  padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 17,
                        color: Colors.green.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            color: colorScheme.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            },
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 空态 / 全完成
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onQuickCreate,
    required this.onPickUnscheduled,
  });

  final VoidCallback onQuickCreate;
  final VoidCallback onPickUnscheduled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primaryContainer,
              ),
              child: const Center(
                child: Text('🌤', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '今天还没有安排',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '写下第一件想做的事，或者从「待安排」里挑几件拉进今天。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: onQuickCreate,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('新建任务'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onPickUnscheduled,
                  child: const Text('从待安排挑'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AllDonePanel extends ConsumerWidget {
  const _AllDonePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final upcomingAsync = ref.watch(todoTasksByDateProvider(tomorrow));

    final titles =
        upcomingAsync.asData?.value
            .take(3)
            .map((task) => task.title)
            .toList(growable: false) ??
        const <String>[];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('🎉', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Text(
                  '今天没有待办了',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              titles.isEmpty
                  ? '明天还没有安排，可以早点休息。'
                  : '明天已有 ${upcomingAsync.asData?.value.length ?? 0} 件事：'
                        '${titles.join('、')}。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 底部批量条
// ---------------------------------------------------------------------------

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.onComplete,
    required this.onMoveToToday,
    required this.onClear,
  });

  final int count;
  final VoidCallback onComplete;
  final VoidCallback onMoveToToday;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.primary,
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        ),
        child: Row(
          children: [
            Text(
              '已选 $count 项',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            _BulkAction(label: '完成', onTap: onComplete),
            _BulkAction(label: '改到今天', onTap: onMoveToToday),
            _BulkAction(label: '取消', onTap: onClear),
          ],
        ),
      ),
    );
  }
}

class _BulkAction extends StatelessWidget {
  const _BulkAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.onPrimary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label),
    );
  }
}

// ---------------------------------------------------------------------------
// 行内动作 / 待安排选择
// ---------------------------------------------------------------------------

class _RowActionsSheet extends StatelessWidget {
  const _RowActionsSheet({required this.task});

  final TodoTask task;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.today_rounded),
            title: const Text('改到今天'),
            onTap: () => Navigator.of(context).pop('today'),
          ),
          ListTile(
            leading: const Icon(Icons.event_rounded),
            title: const Text('改期'),
            onTap: () => Navigator.of(context).pop('reschedule'),
          ),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('编辑详情'),
            onTap: () => Navigator.of(context).pop('open'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded),
            title: const Text('删除'),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 「从待安排挑」：把收集箱里没归到某一天的任务拉进今天。
///
/// 空态只给「新建任务」是不够的 —— 多数时候人不是没任务，是有一堆没排期的
/// 任务躺在收集箱里。
class _UnscheduledSheet extends ConsumerWidget {
  const _UnscheduledSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(todayUnscheduledProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '从待安排挑几件',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '这些任务既没有排期日，也没有截止时间。点一下就安排到今天。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 12),
            async.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('待安排里是空的')),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final task in tasks)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.add_circle_outline_rounded),
                        title: Text(task.title),
                        onTap: () async {
                          await ref
                              .read(todoRepositoryProvider)
                              .updateTask(
                                task.copyWith(scheduledDate: DateTime.now()),
                              );
                          invalidateTodayActionData(ref);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('加载失败: $error'),
            ),
          ],
        ),
      ),
    );
  }
}
