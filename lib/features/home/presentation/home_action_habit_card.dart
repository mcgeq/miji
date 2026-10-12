import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/features/home/application/home_action_brief_providers.dart';

/// 习惯打卡卡：进度 + 一键打卡。
class HomeActionHabitCard extends StatelessWidget {
  const HomeActionHabitCard({
    super.key,
    required this.habits,
    required this.onTapHabit,
    this.onManage,
  });

  final List<HomeHabitEntry> habits;
  final ValueChanged<HomeHabitEntry> onTapHabit;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '🔥 习惯打卡',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (onManage != null)
                TextButton(
                  onPressed: onManage,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('管理'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (habits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                '还没有打卡计划',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: habits.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (context, index) {
                  final habit = habits[index];
                  return _HabitTile(
                    habit: habit,
                    onTap: () => onTapHabit(habit),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.habit, required this.onTap});

  final HomeHabitEntry habit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SizedBox(
      width: 104,
      child: AppSurface(
        tone: AppSurfaceTone.subtle,
        onTap: onTap,
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              habit.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              habit.streak == null
                  ? habit.progressLabel
                  : '${habit.progressLabel} · 🔥${habit.streak}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: habit.ratio.clamp(0.0, 1.0),
                minHeight: 5,
                color: colorScheme.primary,
                backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
              ),
            ),
            const SizedBox(height: 7),
            Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: BoxDecoration(
                color: habit.isDone
                    ? Colors.transparent
                    : colorScheme.primary,
                borderRadius: BorderRadius.circular(9),
                border: habit.isDone
                    ? Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              child: Text(
                habit.isDone ? '✓ 已完成' : '打卡',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: habit.isDone ? colorScheme.primary : Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
