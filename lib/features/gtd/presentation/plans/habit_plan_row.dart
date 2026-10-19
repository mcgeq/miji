import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/plan_checkin_progress.dart';
import 'package:miji/features/gtd/presentation/plans/checkin_plan_icon.dart';
import 'package:miji/features/gtd/presentation/plans/habit_checkin_actions.dart';
import 'package:miji/features/gtd/presentation/plans/habit_checkin_control.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 一行「习惯」：图标 + 名称 + 副行 + 右侧动作。
///
/// 「今日」混排行与「习惯」列表共用它 —— 同一个计划在两个页面长成两个样子，
/// 是之前最刺眼的问题（一边有勾选圈和进度条，另一边只有一枚 +1 圆钮）。
/// 差别只有 [dense] 决定的留白，其余全部一致。
class HabitPlanRow extends ConsumerWidget {
  const HabitPlanRow({super.key, required this.progress, this.dense = false});

  final PlanProgress progress;

  /// 「今日」混排行用紧凑留白，列表页用宽松一点。
  final bool dense;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plan = progress.plan;
    final completed = progress.completionRate >= 1.0;
    final timerState = ref.watch(checkinTimerProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: dense ? 8 : 10),
      child: Material(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(theme.radiusTokens.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(theme.radiusTokens.md),
          onTap: () => context.push('/app/gtd/plans/${plan.id}'),
          onLongPress: () => _showActions(context, ref, completed: completed),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              dense ? 10 : 12,
              8,
              dense ? 10 : 12,
            ),
            child: Row(
              children: [
                // 完成之后降饱和：今天这件事结束了，但明天还要做，所以不打删除线。
                Opacity(
                  opacity: completed ? 0.55 : 1,
                  child: CheckinPlanIcon.forPlan(plan, size: 30),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        plan.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 13.5,
                          height: 1.25,
                          letterSpacing: 0,
                          fontWeight: FontWeight.w600,
                          color: completed
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _SubLine(progress: progress, timerState: timerState),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                HabitCheckinControl(progress: progress),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 长按菜单：补满、撤销、看记录。
  ///
  /// 这三件事都是「偶尔才做一次」的，塞进常驻按钮只会把行挤变形；长按是移动端
  /// 对「次要动作」的通用位置。
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref, {
    required bool completed,
  }) async {
    final plan = progress.plan;
    final hasRecord = progress.currentCount > 0 || progress.currentValue > 0;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Row(
                  children: [
                    CheckinPlanIcon.forPlan(plan, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        plan.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('撤销一次打卡'),
                subtitle: hasRecord ? null : const Text('今天还没有记录'),
                enabled: hasRecord,
                onTap: () => Navigator.of(context).pop('undo'),
              ),
              ListTile(
                leading: const Icon(Icons.done_all_rounded),
                title: const Text('今天全部完成'),
                subtitle: Text(planTargetLabel(plan)),
                enabled: !completed,
                onTap: () => Navigator.of(context).pop('complete'),
              ),
              ListTile(
                leading: const Icon(Icons.list_alt_rounded),
                title: const Text('查看打卡记录'),
                onTap: () => Navigator.of(context).pop('records'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case 'undo':
        final undone = await undoPlanCheckIn(ref, plan);
        if (!undone || !context.mounted) return;
        AppToast.success(
          FToast()..init(context),
          context,
          '已撤销「${plan.name}」的一次打卡',
        );
      case 'complete':
        final changed = await completePlanToday(
          ref,
          plan,
          currentValue: progress.currentValue,
        );
        if (!changed || !context.mounted) return;
        AppToast.success(
          FToast()..init(context),
          context,
          '「${plan.name}」今日完成',
        );
      case 'records':
        context.push('/app/gtd/plans/${plan.id}');
    }
  }
}

/// 副行：连续天数 · 目标（或计时状态）。
class _SubLine extends StatelessWidget {
  const _SubLine({required this.progress, required this.timerState});

  final PlanProgress progress;
  final CheckinTimerState timerState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final plan = progress.plan;
    final completed = progress.completionRate >= 1.0;
    final streak = progress.streak ?? 0;

    final isThisPlanTimer = timerState.planId == plan.id;

    final baseStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: 11,
      height: 1.2,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: colorScheme.outline,
    );

    final items = <Widget>[];

    if (isThisPlanTimer) {
      final running = timerState is CheckinTimerRunning;
      items.add(
        Text(
          '${running ? '计时中' : '已暂停'} '
          '${formatTimerClock(timerElapsedSeconds(timerState))}',
          style: baseStyle?.copyWith(
            color: const Color(0xFFA9701A),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    if (streak > 0) {
      items.add(
        Text(
          '🔥$streak 天',
          style: baseStyle?.copyWith(
            color: const Color(0xFF776950),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    // 第三段只写一个结论：没完成写目标，完成了写「做够了多少」或「已完成」。
    // 之前完成态会同时写「1 / 1」、「今天已完成」和「🔥 N 天」，三个框挤在
    // 11px 的一行里，谁也读不完。
    if (completed && !isThisPlanTimer) {
      items.add(
        Text(
          plan.targetValue > 1
              ? planProgressLabel(plan, progress.currentValue)
              : '今天已完成',
          style: baseStyle?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    } else if (!isThisPlanTimer) {
      items.add(Text(planTargetLabel(plan), style: baseStyle));
    }

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
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
          Flexible(child: items[i]),
        ],
      ],
    );
  }
}
