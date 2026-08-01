import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/presentation/components/app_section_header.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

// ---------------------------------------------------------------------------
// 主壳页
// ---------------------------------------------------------------------------

enum _GtdPanel { today, calendar, statistics }

class GtdPage extends ConsumerStatefulWidget {
  const GtdPage({super.key});

  @override
  ConsumerState<GtdPage> createState() => _GtdPageState();
}

class _GtdPageState extends ConsumerState<GtdPage> {
  var _selectedPanel = _GtdPanel.today;

  @override
  Widget build(BuildContext context) {
    final panelSelector = AppSlidingSegmentedControl<_GtdPanel>(
      minSegmentWidth: 80,
      value: _selectedPanel,
      segments: const [
        AppSlidingSegment(
          value: _GtdPanel.today,
          icon: Icons.today_rounded,
          label: '今日',
        ),
        AppSlidingSegment(
          value: _GtdPanel.calendar,
          icon: Icons.calendar_month_rounded,
          label: '日历',
        ),
        AppSlidingSegment(
          value: _GtdPanel.statistics,
          icon: Icons.insights_rounded,
          label: '统计',
        ),
      ],
      onChanged: (panel) {
        setState(() => _selectedPanel = panel);
      },
    );

    return AppPageFrame(
      maxWidth: 760,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(flex: 3, child: panelSelector),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
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
                      // AppIconActionButton(
                      //   icon: Icons.download_rounded,
                      //   tooltip: '导出数据',
                      //   onPressed: () => _exportData(context, ref),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(child: _buildSelectedTab()),
        ],
      ),
    );
  }

  Widget _buildSelectedTab() {
    return switch (_selectedPanel) {
      _GtdPanel.today => const _TodayTab(),
      _GtdPanel.calendar => const _CalendarTab(),
      _GtdPanel.statistics => const _StatisticsTab(),
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
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index < progressList.length - 1 ? 10 : 0,
          ),
          child: _PlanProgressCard(progress: progressList[index]),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 计划进度卡片
// ---------------------------------------------------------------------------

class _PlanProgressCard extends ConsumerWidget {
  const _PlanProgressCard({required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plan = progress.plan;
    final rate = progress.completionRate;
    final isCompleted = rate >= 1.0;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.context.push('/app/gtd/plans/${plan.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：图标 + 名称 + +1 按钮
              Row(
                children: [
                  Text(plan.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      plan.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (plan.triggerMode == CheckinTriggerMode.button)
                    _QuickAddButton(plan: plan),
                  if (plan.triggerMode == CheckinTriggerMode.timer)
                    _TimerButton(plan: plan),
                  if (plan.triggerMode == CheckinTriggerMode.photo)
                    _PhotoButton(plan: plan),
                ],
              ),
              const SizedBox(height: 10),
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 6,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted
                        ? Colors.green.shade400
                        : Color(
                            int.parse(plan.color.replaceFirst('#', '0xff')),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 进度文字
              Row(
                children: [
                  Text(
                    _formatProgress(progress),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCompleted
                          ? Colors.green.shade600
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (progress.streak != null && progress.streak! > 1)
                    Text(
                      '🔥 ${progress.streak}天',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
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

  String _formatProgress(PlanProgress p) {
    if (p.plan.targetUnit == '分钟') {
      final totalMin = p.currentValue.toInt();
      final targetMin = p.plan.targetValue.toInt();
      return '$totalMin / $targetMin 分钟';
    }
    if (p.plan.targetUnit == '杯') {
      return '${p.currentValue.toInt()} / ${p.plan.targetValue.toInt()} 杯';
    }
    return '${p.currentValue.toInt()} / ${p.plan.targetValue.toInt()} ${p.plan.targetUnit}';
  }
}

// ---------------------------------------------------------------------------
// 快捷 +1 按钮
// ---------------------------------------------------------------------------

class _QuickAddButton extends ConsumerWidget {
  const _QuickAddButton({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _onTap(ref),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(
            Icons.add_rounded,
            size: 20,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(WidgetRef ref) async {
    final repo = ref.read(checkinRepositoryProvider);
    final draft = CheckinRecordDraft(
      planId: plan.id,
      recordDate: DateTime.now(),
      completedAt: DateTime.now(),
      count: 1,
      numericValue: 1,
    );
    await repo.upsertRecord(draft, plan.userId);
    ref.invalidate(todayProgressProvider);
    ref.invalidate(recordsByDateProvider);
    ref.invalidate(checkinStreakProvider);
  }
}

// ---------------------------------------------------------------------------
// 计时器按钮
// ---------------------------------------------------------------------------

class _TimerButton extends ConsumerWidget {
  const _TimerButton({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(checkinTimerProvider);
    final isThisPlan =
        timerState is CheckinTimerRunning && timerState.planId == plan.id ||
        timerState is CheckinTimerPaused && timerState.planId == plan.id;

    return Material(
      color: isThisPlan
          ? Colors.orange.shade100
          : Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _onTap(ref, timerState),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isThisPlan ? Icons.timer_rounded : Icons.play_arrow_rounded,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                isThisPlan ? _formatTime(timerState) : '开始',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(CheckinTimerState state) {
    final seconds = switch (state) {
      CheckinTimerRunning(
        startedAt: final startedAt,
        pausedDurationSeconds: final pd,
      ) =>
        DateTime.now().difference(startedAt).inSeconds - pd,
      CheckinTimerPaused(
        pausedDurationSeconds: final pd,
        pausedAt: final pausedAt,
      ) =>
        pd - DateTime.now().difference(pausedAt).inSeconds,
      _ => 0,
    };
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _onTap(WidgetRef ref, CheckinTimerState timerState) {
    final controller = ref.read(checkinTimerProvider.notifier);
    final isThisPlan =
        timerState is CheckinTimerRunning && timerState.planId == plan.id ||
        timerState is CheckinTimerPaused && timerState.planId == plan.id;

    if (isThisPlan) {
      // 结束计时器
      final seconds = controller.stop();
      _recordTime(ref, seconds);
    } else {
      // 如果有其他计时器在跑，先停掉
      if (timerState is! CheckinTimerIdle) {
        controller.stop();
      }
      controller.start(plan.id, plan.name);
    }
  }

  Future<void> _recordTime(WidgetRef ref, int seconds) async {
    final repo = ref.read(checkinRepositoryProvider);
    final draft = CheckinRecordDraft(
      planId: plan.id,
      recordDate: DateTime.now(),
      completedAt: DateTime.now(),
      count: 1,
      durationSeconds: seconds,
    );
    await repo.upsertRecord(draft, plan.userId);
    ref.invalidate(todayProgressProvider);
    ref.invalidate(recordsByDateProvider);
  }
}

// ---------------------------------------------------------------------------
// 拍照按钮
// ---------------------------------------------------------------------------

class _PhotoButton extends ConsumerWidget {
  const _PhotoButton({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppIconActionButton(
      icon: Icons.camera_alt_rounded,
      tooltip: '拍照打卡',
      onPressed: () {
        ref.context.push('/app/gtd/checkin/photo/${plan.id}');
      },
    );
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

    final summaryMap = <DateTime, DailyCheckinSummary>{};
    summariesAsync.whenData((list) {
      for (final s in list) {
        summaryMap[DateTime.utc(s.date.year, s.date.month, s.date.day)] = s;
      }
    });

    return Column(
      children: [
        // 月历
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
        // 当日打卡记录
        Expanded(
          child: recordsAsync.when(
            data: (records) {
              if (records.isEmpty) {
                return Center(
                  child: Text(
                    '当天没有打卡记录',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: records.length,
                itemBuilder: (context, index) {
                  return _RecordCard(record: records[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('加载失败: $err')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 打卡记录卡片（日历 tab 用）
// ---------------------------------------------------------------------------

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record});

  final CheckinRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Text(switch (record.plan?.triggerMode) {
              CheckinTriggerMode.photo => '📸',
              CheckinTriggerMode.timer => '⏱️',
              _ => record.plan?.icon ?? '📌',
            }, style: const TextStyle(fontSize: 20)),
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
    );
  }
}

// ---------------------------------------------------------------------------
// 统计 Tab
// ---------------------------------------------------------------------------

class _StatisticsTab extends ConsumerWidget {
  const _StatisticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(checkinStreakProvider);
    final categoryStatsAsync = ref.watch(categoryStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // 连续打卡天数
        streakAsync.when(
          data: (streak) => Row(
            children: [
              _StatCard(
                label: '当前连续',
                value: '${streak.currentStreak}',
                unit: '天',
                icon: Icons.local_fire_department_rounded,
                color: streak.currentStreak > 0
                    ? Colors.orange
                    : colorScheme.outline,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '最长连续',
                value: '${streak.longestStreak}',
                unit: '天',
                icon: Icons.emoji_events_rounded,
                color: streak.longestStreak > 0
                    ? Colors.amber.shade700
                    : colorScheme.outline,
              ),
            ],
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 24),
        // 分类统计
        AppSectionHeader(title: '本月分类统计'),
        const SizedBox(height: 10),
        categoryStatsAsync.when(
          data: (stats) {
            if (stats.isEmpty) {
              return Text(
                '暂无数据',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.outline,
                ),
              );
            }
            final total = stats.values.fold<int>(0, (a, b) => a + b);
            return Column(
              children: stats.entries.map((entry) {
                final rate = total > 0 ? entry.value / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: rate,
                            minHeight: 8,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${entry.value}',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('加载失败: $err'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 统计卡片
// ---------------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      text: value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: ' $unit',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
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
}
