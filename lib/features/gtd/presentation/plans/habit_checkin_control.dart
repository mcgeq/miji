import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/domain/checkin_plan_style.dart';
import 'package:miji/features/gtd/domain/plan_checkin_progress.dart';
import 'package:miji/features/gtd/presentation/plans/habit_checkin_actions.dart';
import 'package:miji/features/gtd/presentation/plans/habit_checkin_ring.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 今日行右侧的动作区：进度环 / 计时 / 拍照。
///
/// 三种触发方式在数据模型里本来就是三个字段（`triggerMode`），但之前「今日」
/// 行把差别吞掉了 —— 计时型计划看起来和普通点击型一模一样。这里按触发方式
/// 给出各自的控件，位置固定在行尾同一条竖线上。
class HabitCheckinControl extends ConsumerWidget {
  const HabitCheckinControl({super.key, required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = progress.plan;
    return switch (plan.triggerMode) {
      CheckinTriggerMode.timer => _TimerPill(plan: plan),
      CheckinTriggerMode.photo => _PhotoPill(plan: plan),
      // 定位打卡还没做专门的入口，先给进度环：至少「今天做了没有」能在这里点。
      CheckinTriggerMode.button ||
      CheckinTriggerMode.location => _RingButton(progress: progress),
    };
  }
}

// ---------------------------------------------------------------------------
// 进度环（点一下 = 打卡一次）
// ---------------------------------------------------------------------------

class _RingButton extends ConsumerWidget {
  const _RingButton({required this.progress});

  final PlanProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = progress.plan;
    final completed = progress.completionRate >= 1.0;
    final visual = planVisualFor(
      icon: plan.icon,
      category: plan.category,
      color: plan.color,
    );
    final label = planRingLabel(plan, progress.currentValue);

    return HabitCheckinRing(
      key: ValueKey('habit-ring-${plan.id}'),
      rate: progress.completionRate,
      label: label,
      color: visual.color.color,
      completed: completed,
      semanticLabel: completed
          ? '${plan.name}，今天已完成'
          : '${plan.name}，今天 ${planProgressLabel(plan, progress.currentValue)}，点一下打卡',
      onTap: () => _onTap(context, ref, completed),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool completed,
  ) async {
    final plan = progress.plan;

    // 完成之后不能再往上加：只剩「撤销」这一个合理动作，先问一句再动数据。
    if (completed) {
      await _confirmUndo(context, ref, plan);
      return;
    }

    final step = math.min(
      planQuickStep(plan),
      planRemainingToTarget(plan, progress.currentValue),
    );
    final changed = await checkInPlanOnce(
      ref,
      plan,
      currentValue: progress.currentValue,
    );
    if (!changed || !context.mounted) return;

    final nowCompleted = progress.currentValue + step >= plan.targetValue;
    if (nowCompleted) {
      // 点错了要能立刻退回来：完成提示里带一个「撤销」，比让用户去长按找菜单快。
      // 用 toast 而不是 SnackBar：SnackBar 会紧贴底部导航条常驻（无障碍导航
      // 开启时甚至不会自动消失），既挡内容又关不掉。
      AppToast.undo(
        toast: FToast()..init(context),
        context: context,
        message: '「${plan.name}」今日完成',
        actionLabel: '撤销',
        onAction: () => undoPlanCheckIn(ref, plan),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// 计时
// ---------------------------------------------------------------------------

class _TimerPill extends ConsumerWidget {
  const _TimerPill({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(checkinTimerProvider);
    final running = state is CheckinTimerRunning && state.planId == plan.id;
    final paused = state is CheckinTimerPaused && state.planId == plan.id;
    final mine = running || paused;

    final (label, icon, fg, bg) = switch ((mine, running)) {
      (true, true) => (
        formatTimerClock(timerElapsedSeconds(state)),
        Icons.pause_rounded,
        const Color(0xFFA9701A),
        const Color(0xFFF3EBDF),
      ),
      (true, false) => (
        '继续',
        Icons.play_arrow_rounded,
        theme.colorScheme.onTertiaryContainer,
        theme.colorScheme.tertiaryContainer,
      ),
      _ => (
        '开始',
        Icons.play_arrow_rounded,
        theme.colorScheme.onTertiaryContainer,
        theme.colorScheme.tertiaryContainer,
      ),
    };

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: ValueKey('habit-timer-${plan.id}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () =>
            _onTap(context, ref, state, running: running, paused: paused),
        // 长按结束并落记录：计时器在别的页面跑着的时候，这里是最快的收尾方式。
        onLongPress: mine ? () => _finish(context, ref, state) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 3),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    CheckinTimerState state, {
    required bool running,
    required bool paused,
  }) async {
    final controller = ref.read(checkinTimerProvider.notifier);

    if (running) {
      controller.pause();
      return;
    }
    if (paused) {
      controller.resume();
      return;
    }

    // 别的计划正在计时：先把那段时间落库再切过来，不能默默丢掉。
    final otherPlanId = state.planId;
    if (otherPlanId != null) {
      final seconds = controller.stop();
      await _recordOtherPlan(ref, otherPlanId, seconds);
    }
    controller.start(plan.id, plan.name);
  }

  Future<void> _finish(
    BuildContext context,
    WidgetRef ref,
    CheckinTimerState state,
  ) async {
    final seconds = ref.read(checkinTimerProvider.notifier).stop();
    final recorded = await recordPlanTimer(ref, plan, seconds: seconds);
    if (!recorded || !context.mounted) return;
    AppToast.success(
      FToast()..init(context),
      context,
      '「${plan.name}」记下 ${formatTimerClock(seconds)}',
    );
  }

  /// 给「被我打断的那个计划」补一条记录。
  Future<void> _recordOtherPlan(
    WidgetRef ref,
    String planId,
    int seconds,
  ) async {
    final repo = ref.read(checkinRepositoryProvider);
    final other = await repo.getPlan(planId);
    if (other == null) return;
    await recordPlanTimer(ref, other, seconds: seconds);
  }
}

// ---------------------------------------------------------------------------
// 拍照
// ---------------------------------------------------------------------------

class _PhotoPill extends StatelessWidget {
  const _PhotoPill({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: ValueKey('habit-photo-${plan.id}'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => context.push('/app/gtd/checkin/photo/${plan.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.camera_alt_rounded,
                size: 15,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                '拍照',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 撤销确认（点已完成行的环）
// ---------------------------------------------------------------------------

Future<void> _confirmUndo(
  BuildContext context,
  WidgetRef ref,
  CheckinPlan plan,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('撤销今天的打卡？'),
      content: Text('「${plan.name}」今天已经完成，撤销会把最后一次打卡减掉。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('habit-undo-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('撤销'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final undone = await undoPlanCheckIn(ref, plan);
  if (!undone || !context.mounted) return;
  AppToast.success(FToast()..init(context), context, '已撤销「${plan.name}」的一次打卡');
}
