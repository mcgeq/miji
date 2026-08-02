import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/gtd/domain/checkin_enums.dart';
import 'package:miji/features/gtd/domain/checkin_models.dart';
import 'package:miji/features/gtd/providers/checkin_providers.dart';

/// 计划列表页（管理/归档/排序）
class PlanListPage extends ConsumerWidget {
  const PlanListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(allPlansProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('计划管理')),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_rounded,
                    size: 48,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '还没有计划',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          final active = plans.where((p) => !p.isArchived).toList();
          final archived = plans.where((p) => p.isArchived).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (active.isNotEmpty) ...[
                _SectionLabel(text: '进行中 (${active.length})'),
                ...active.map((plan) => _PlanTile(plan: plan)),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionLabel(text: '已归档 (${archived.length})'),
                ...archived.map((plan) => _PlanTile(plan: plan)),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlanTile extends ConsumerWidget {
  const _PlanTile({required this.plan});

  final CheckinPlan plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArchived = plan.isArchived;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        leading: Text(plan.icon, style: const TextStyle(fontSize: 24)),
        title: Text(
          plan.name,
          style: theme.textTheme.titleSmall?.copyWith(
            color: isArchived
                ? colorScheme.onSurfaceVariant
                : colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          '${plan.category} · ${_freqLabel(plan.frequencyType)} · ${plan.triggerMode == CheckinTriggerMode.timer
              ? '计时'
              : plan.triggerMode == CheckinTriggerMode.photo
              ? '拍照'
              : '计数'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _onAction(ref, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Center(
                child: Tooltip(
                  message: '编辑',
                  child: Icon(
                    Icons.edit_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            PopupMenuItem(
              value: isArchived ? 'unarchive' : 'archive',
              child: Center(
                child: Tooltip(
                  message: isArchived ? '取消归档' : '归档',
                  child: Icon(
                    isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
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
        onTap: () {
          context.push('/app/gtd/plans/${plan.id}');
        },
      ),
    );
  }

  String _freqLabel(CheckinFrequencyType type) {
    return switch (type) {
      CheckinFrequencyType.daily => '每天',
      CheckinFrequencyType.weekly => '每周',
      CheckinFrequencyType.monthly => '每月',
      CheckinFrequencyType.cron => '自定义',
      CheckinFrequencyType.once => '一次性',
    };
  }

  Future<void> _onAction(WidgetRef ref, String action) async {
    final repo = ref.read(checkinRepositoryProvider);
    switch (action) {
      case 'edit':
        ref.context.push('/app/gtd/plans/create?edit=${plan.id}');
        break;
      case 'archive':
        await repo.archivePlan(plan.id, true);
        ref.read(appNotificationServiceProvider).cancelCheckinReminder(plan.id);
        invalidateCheckinData(ref);
        break;
      case 'unarchive':
        await repo.archivePlan(plan.id, false);
        if (plan.reminderEnabled && plan.reminderTime != null) {
          ref
              .read(appNotificationServiceProvider)
              .scheduleDailyCheckinReminder(
                planId: plan.id,
                planName: plan.name,
                timeString: plan.reminderTime!,
              );
        }
        invalidateCheckinData(ref);
        break;
      case 'delete':
        await repo.deletePlan(plan.id);
        ref.read(appNotificationServiceProvider).cancelCheckinReminder(plan.id);
        invalidateCheckinData(ref);
        break;
    }
  }
}
