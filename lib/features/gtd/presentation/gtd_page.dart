import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/app_responsive.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/router/app_module_nav.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/presentation/checkin/record_detail_sheet.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';
import 'package:miji/features/todo/presentation/today_action_list_view.dart';
import 'package:miji/features/todo/presentation/todo_quick_create_sheet.dart';
import 'package:miji/features/todo/presentation/todo_task_list_view.dart';
import 'package:miji/features/todo/providers/todo_providers.dart';
import 'package:miji/features/gtd/presentation/plans/habit_plan_row.dart';
import 'package:miji/features/todo/domain/todo_models.dart';
import 'package:miji/features/todo/presentation/todo_stats_view.dart';

// ---------------------------------------------------------------------------
// 主壳页
// ---------------------------------------------------------------------------

/// 打卡的面板。名字与 `gtdModuleNav` 的 section id 一一对应（`panel.name` 就是
/// 写进 `?section=` 的值），顺序与 `_buildPageView()` 的 children 一一对应
/// （`panel.index` 就是 `PageView` 页码）。
enum _GtdPanel { today, tasks, habits, calendar, statistics }

/// 解析 `?section=`（含非法值）。名字对得上就用名字，不靠下标——
/// 只保证顺序与 `_buildPageView()` 的 children 一致。
_GtdPanel _panelFromSection(String? section) {
  final id = gtdModuleNav.resolveSectionId(section);
  return _GtdPanel.values.firstWhere(
    (panel) => panel.name == id,
    orElse: () => _GtdPanel.today,
  );
}

class GtdPage extends ConsumerStatefulWidget {
  const GtdPage({super.key, this.initialSection});

  /// 二级路由的入口：`/app/gtd?section=tasks`。
  ///
  /// 打卡以前把当前面板只存在 State 里，地址上没有痕迹：切走再切回一定回到
  /// 「今日」，通知 / 首页下钻也点不进具体面板。
  final String? initialSection;

  @override
  ConsumerState<GtdPage> createState() => _GtdPageState();
}

class _GtdPageState extends ConsumerState<GtdPage> {
  late _GtdPanel _selectedPanel = _panelFromSection(widget.initialSection);
  late final PageController _pageController = PageController(
    initialPage: _selectedPanel.index,
  );

  @override
  void didUpdateWidget(covariant GtdPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection == widget.initialSection) {
      return;
    }
    // 面板自己写回 URL 时会再走到这里，此时 section 已经等于当前面板。
    final nextPanel = _panelFromSection(widget.initialSection);
    if (nextPanel == _selectedPanel) {
      return;
    }
    setState(() => _selectedPanel = nextPanel);
    // 宽屏用的是 `_buildSelectedTab()`，没有 PageView：控制器没挂上时
    // `jumpToPage` 会在 debug 下断言失败（这也是原先宽屏点分段会崩的原因）。
    if (_pageController.hasClients) {
      _pageController.jumpToPage(nextPanel.index);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppPageFrame(
      maxWidth: 760,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final responsive = AppResponsive.of(
            context,
            width: constraints.maxWidth,
          );
          if (responsive.isCompact) {
            return _buildCompactLayout();
          }
          return _buildExpandedLayout();
        },
      ),
    );
  }

  /// 工具行：只有当前面板自己的页级动作。
  ///
  /// 左端原本有一枚「面板 chip」（显示当前面板名、点开是选择器），已按要求移除。
  /// 换面板现在只有一条路：底栏 / 侧栏点当前模块再点一次（两态唤出）——
  /// 外壳的 `_openModule` 就是为这件事存在的，所以这不构成死胡同。
  ///
  /// 代价写在这里：面板自身没有标题栏，移除 chip 之后页内没有「我在哪个面板」
  /// 的文字标识。若要补，应该补在各面板自己的标题上，而不是把这个 chip 加回来。
  Widget _buildToolbarRow() {
    return Row(children: [const Spacer(), ..._buildToolbarActions()]);
  }

  /// Mobile: 工具行 + PageView。
  ///
  /// 页面级动作（新建任务 / 新建计划 / 管理计划）也要出现在手机上：
  /// 它们在宽屏版一直在，手机版以前整排不渲染，于是「任务」面板的新建入口
  /// 在手机上根本不存在（只能借全局 FAB）。
  Widget _buildCompactLayout() {
    return Column(
      children: [
        const SizedBox(height: 6),
        _buildToolbarRow(),
        const SizedBox(height: 12),
        Expanded(child: _buildPageView()),
      ],
    );
  }

  /// Tablet/desktop: 工具行 + 只渲染当前面板。
  ///
  /// 宽屏不用 `PageView`：这一档没有横向手势的诉求，而且原先按面板切
  /// `jumpToPage` 时控制器还没挂上会直接断言失败（宽屏点分段的崩溃点）。
  Widget _buildExpandedLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _buildToolbarRow(),
        ),
        const SizedBox(height: 14),
        Expanded(child: _buildSelectedTab()),
      ],
    );
  }

  Widget _buildPageView() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        final panel = _GtdPanel.values[index];
        setState(() => _selectedPanel = panel);
        _syncSectionToUrl(panel);
      },
      // 「今日」是有状态视图（常驻输入框 / 多选），不能再放在 const 列表里。
      children: [
        TodayActionListView(),
        TodoTaskListView(),
        _TodayTab(),
        _CalendarTab(),
        V2StatisticsTab(),
      ],
    );
  }

  /// 换面板（工具行 chip）。

  /// 工具行 chip：弹出面板选择器并落到选中的面板。
  ///
  /// 与底栏「打卡」的两态唤出走的是同一张选择器，差别只是这里一次点击到位
  /// （已经知道自己在这个模块里，不必先判断「在不在模块内」）。
  /// 把当前面板写回 `?section=`。
  ///
  /// 以前打卡的面板只活在 State 里，地址永远是 `/app/gtd`：从首页 / 通知进来
  /// 只能落在「今日」，底栏切走再切回也回不到原面板，系统返回键更不认面板。
  void _syncSectionToUrl(_GtdPanel panel) {
    final route = GoRouterState.of(context);
    if (route.uri.queryParameters['section'] == panel.name) {
      return;
    }
    context.go(gtdModuleNav.uriFor(panel.name).toString());
  }

  Widget _buildSelectedTab() {
    return switch (_selectedPanel) {
      _GtdPanel.today => TodayActionListView(),
      _GtdPanel.tasks => const TodoTaskListView(),
      _GtdPanel.habits => const _TodayTab(),
      _GtdPanel.calendar => const _CalendarTab(),
      _GtdPanel.statistics => const V2StatisticsTab(),
    };
  }

  /// 「新建任务」打开与全局 FAB「任务」同一个快速创建面板。
  Future<void> _openTaskQuickCreate() async {
    final created = await showTodoQuickCreateSheet(context);
    if (created == true && mounted) {
      AppToast.success(FToast()..init(context), context, '任务已创建');
    }
  }

  List<Widget> _buildToolbarActions() {
    return switch (_selectedPanel) {
      // 「今日」以前只有「新建计划」：想往今天加一件要做的事，得先切到
      // 「任务」面板。对每天进出十几次的页面来说这是最贵的一次切页，
      // 所以这里把两枚新建按钮都给上（任务在左、计划在右）。
      _GtdPanel.today => [
        AppIconActionButton(
          icon: Icons.checklist_rounded,
          tooltip: '新建任务',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: _openTaskQuickCreate,
        ),
        AppIconActionButton(
          icon: Icons.add_rounded,
          tooltip: '新建计划',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: () {
            context.push('/app/gtd/plans/create');
          },
        ),
      ],
      _GtdPanel.tasks => [
        AppIconActionButton(
          icon: Icons.add_rounded,
          tooltip: '新建任务',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: _openTaskQuickCreate,
        ),
      ],
      _GtdPanel.habits => [
        AppIconActionButton(
          icon: Icons.add_rounded,
          tooltip: '新建计划',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: () {
            context.push('/app/gtd/plans/create');
          },
        ),
        AppIconActionButton(
          icon: Icons.list_rounded,
          tooltip: '管理计划',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: () {
            context.push('/app/gtd/plans');
          },
        ),
      ],
      _GtdPanel.calendar || _GtdPanel.statistics => [
        AppIconActionButton(
          icon: Icons.add_rounded,
          tooltip: '新建计划',
          size: 36,
          iconSize: 20,
          padding: const EdgeInsets.all(4),
          onPressed: () {
            context.push('/app/gtd/plans/create');
          },
        ),
      ],
    };
  }
}

// Future<void> _exportData(BuildContext context, WidgetRef ref) async {
//   final session = ref.read(authSessionControllerProvider);
//   final userId = session.userId;
//   if (userId == null) return;
//
//   try {
//     final repo = ref.read(checkinRepositoryProvider);
//     final json = await repo.exportAllJson(userId);
//
//     final dir = await getTemporaryDirectory();
//     final file = File(
//       '${dir.path}/miji_checkin_${DateTime.now().millisecondsSinceEpoch}.json',
//     );
//     await file.writeAsString(json);
//
//     await SharePlus.instance.share(
//       ShareParams(files: [XFile(file.path)], subject: 'Miji 打卡数据导出'),
//     );
//   } catch (e) {
//     if (context.mounted) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text('导出失败: $e')));
//     }
//   }
// }

// ---------------------------------------------------------------------------
// 今日打卡 Tab
// ---------------------------------------------------------------------------

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(todayProgressProvider);

    return progressAsync.when(
      data: (progressList) {
        if (progressList.isEmpty) {
          return _buildEmptyState(context, ref);
        }
        return _buildProgressList(context, ref, progressList);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('加载失败: $err')),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.checklist_rounded,
            size: 64,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '还没有打卡计划',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建一个计划，开始打卡吧',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => ref.context.push('/app/gtd/plans/create'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('创建计划'),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressList(
    BuildContext context,
    WidgetRef ref,
    List<PlanProgress> progressList,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: progressList.length,
      // 行间距由 `HabitPlanRow` 自己负责，这里不再补一层，否则两行之间会
      // 出现 20px 的空档。
      itemBuilder: (context, index) =>
          _PlanProgressCard(progress: progressList[index]),
    );
  }
}

// ---------------------------------------------------------------------------
// 计划进度卡片（「习惯」列表）
// ---------------------------------------------------------------------------

/// 「习惯」列表里的一行。
///
/// 这里以前自成一派：+1 圆钮、计时胶囊、6px 进度条、进度文字各画一遍，而
/// 「今日」的混排行又是另一套（勾选圈 + 4px 细条 + 没有按钮）。同一个计划在
/// 两个页面长成两个样子，点一下的效果还不一样。现在两边都是 [HabitPlanRow]，
/// 打卡逻辑也只有一份（`habit_checkin_actions.dart`）。
class _PlanProgressCard extends StatelessWidget {
  const _PlanProgressCard({required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context) {
    return HabitPlanRow(progress: progress);
  }
}

// ---------------------------------------------------------------------------
// 日历 Tab
// ---------------------------------------------------------------------------

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab();

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedDay = DateTime.utc(now.year, now.month, now.day);
    _selectedDay = _focusedDay;
    // 设置选中日期到 provider
    Future.microtask(() {
      ref.read(selectedCheckinDateProvider.notifier).setDate(_focusedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summariesAsync = ref.watch(dailySummariesProvider);
    final recordsAsync = ref.watch(recordsByDateProvider);
    // V1.1: selected day Todo tasks
    final sel = _selectedDay ?? _focusedDay;
    final todoTasksAsync = ref.watch(todoTasksByDateProvider(sel));

    final summaryMap = <DateTime, DailyCheckinSummary>{};
    summariesAsync.whenData((list) {
      for (final s in list) {
        summaryMap[DateTime.utc(s.date.year, s.date.month, s.date.day)] = s;
      }
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar(
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.utc(2100),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) {
              setState(() => _calendarFormat = format);
            },
            onPageChanged: (day) {
              _focusedDay = day;
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              ref
                  .read(selectedCheckinDateProvider.notifier)
                  .setDate(selectedDay);
            },
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              titleTextStyle: (theme.textTheme.titleSmall ?? const TextStyle())
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              markerDecoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final key = DateTime.utc(day.year, day.month, day.day);
                final summary = summaryMap[key];
                if (summary == null || summary.completedPlans == 0) return null;
                final rate = summary.totalPlans > 0
                    ? summary.completedPlans / summary.totalPlans
                    : 0.0;
                final color = rate >= 1.0
                    ? Colors.green
                    : rate >= 0.5
                    ? Colors.orange
                    : theme.colorScheme.outline;
                return Positioned(
                  bottom: 1,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const Divider(height: 1),
        // V1.1: Todo + 习惯详情
        Expanded(
          child: _SelectedDayContent(
            recordsAsync: recordsAsync,
            todoTasksAsync: todoTasksAsync,
          ),
        ),
      ],
    );
  }
}

// V1.1: 日历日期详情（Todo + 习惯）
class _SelectedDayContent extends ConsumerWidget {
  const _SelectedDayContent({
    required this.recordsAsync,
    required this.todoTasksAsync,
  });
  final AsyncValue<List<CheckinRecord>> recordsAsync;
  final AsyncValue<List<TodoTask>> todoTasksAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    if (todoTasksAsync.isLoading || recordsAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final todoTasks = todoTasksAsync.maybeWhen(
      data: (t) => t,
      orElse: () => <TodoTask>[],
    );
    final records = recordsAsync.maybeWhen(
      data: (r) => r,
      orElse: () => <CheckinRecord>[],
    );
    if (todoTasks.isEmpty && records.isEmpty) {
      return Center(
        child: Text(
          '当天没有任务或打卡记录',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.outline,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        if (todoTasks.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '任务',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...todoTasks.map((task) => _TodoDayCard(task: task)),
          if (records.isNotEmpty) const SizedBox(height: 12),
        ],
        if (records.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '习惯',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.tertiary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...records.map((record) => _RecordCard(record: record)),
        ],
      ],
    );
  }
}

class _TodoDayCard extends ConsumerWidget {
  const _TodoDayCard({required this.task});
  final TodoTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCompleted = task.status == TodoTaskStatus.completed;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/app/gtd/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : task.priority == TodoTaskPriority.high
                    ? Icons.flag_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: isCompleted
                    ? Colors.green.shade400
                    : task.isOverdue
                    ? colorScheme.error
                    : colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted
                        ? colorScheme.outline
                        : colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (task.tags.isNotEmpty)
                ...task.tags
                    .take(1)
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(tag.color.replaceFirst('#', '0xff')),
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          tag.name,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: Color(
                              int.parse(tag.color.replaceFirst('#', '0xff')),
                            ),
                          ),
                        ),
                      ),
                    ),
              if (task.dueAt != null) ...[
                const SizedBox(width: 6),
                Text(
                  '${task.dueAt!.hour.toString().padLeft(2, '0')}:${task.dueAt!.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 打卡记录卡片（日历 tab 用）
// ---------------------------------------------------------------------------

class _RecordCard extends ConsumerWidget {
  const _RecordCard({required this.record});

  final CheckinRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showCheckinRecordDetailSheet(context, ref, record),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 触发方式用图标表达，比把 emoji 放大到 20px 干净；计划本身
              // 有没有自定义图标由 CheckinPlanIcon 决定（旧默认图钉会被换掉）。
              Icon(
                switch (record.plan?.triggerMode) {
                  CheckinTriggerMode.photo => Icons.photo_camera_outlined,
                  CheckinTriggerMode.timer => Icons.timer_outlined,
                  _ => Icons.check_circle_outline_rounded,
                },
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.plan?.name ?? '未知计划',
                      style: theme.textTheme.titleSmall,
                    ),
                    if (record.notes != null && record.notes!.isNotEmpty)
                      Text(
                        record.notes!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              Text(
                '${record.completedAt.hour}:${record.completedAt.minute.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
