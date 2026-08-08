import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_filter_strip.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';

enum _ReminderCenterView { pending, history }

enum _HistoryFilter { all, completed, ignored }

class MoneyReminderCenterSection extends ConsumerStatefulWidget {
  const MoneyReminderCenterSection({super.key});

  @override
  ConsumerState<MoneyReminderCenterSection> createState() =>
      _MoneyReminderCenterSectionState();
}

class _MoneyReminderCenterSectionState
    extends ConsumerState<MoneyReminderCenterSection> {
  _ReminderCenterView _view = _ReminderCenterView.pending;
  _HistoryFilter _historyFilter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    final pending = ref.watch(currentUserPendingReminderCenterItemsProvider);
    final history = ref.watch(currentUserReminderCenterHistoryProvider);
    final pendingCount = pending.maybeWhen(
      data: (items) => items.length,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: AppSlidingSegmentedControl<_ReminderCenterView>(
            minSegmentWidth: 120,
            value: _view,
            onChanged: (value) => setState(() => _view = value),
            segments: [
              AppSlidingSegment(
                value: _ReminderCenterView.pending,
                icon: Icons.notifications_active_rounded,
                label: pendingCount == null ? '待处理' : '待处理 $pendingCount',
              ),
              const AppSlidingSegment(
                value: _ReminderCenterView.history,
                icon: Icons.history_rounded,
                label: '处理历史',
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: switch (_view) {
            _ReminderCenterView.pending => _buildPending(pending),
            _ReminderCenterView.history => _buildHistory(history),
          },
        ),
      ],
    );
  }

  Widget _buildPending(AsyncValue<List<MoneyReminderCenterItem>> pending) {
    return pending.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => AppErrorState(
        title: '读取提醒失败',
        onRetry: () =>
            ref.invalidate(currentUserPendingReminderCenterItemsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const AppEmptyState(title: '暂无待处理提醒');
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _PendingReminderCard(item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHistory(AsyncValue<List<MoneyReminderCenterItem>> history) {
    return history.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => AppErrorState(
        title: '读取历史失败',
        onRetry: () => ref.invalidate(currentUserReminderCenterHistoryProvider),
      ),
      data: (items) {
        final filtered = [
          for (final item in items)
            if (_historyFilter == _HistoryFilter.all ||
                item.state == _historyFilter.state)
              item,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFilterStrip(
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                for (final filter in _HistoryFilter.values)
                  _HistoryFilterChip(
                    label: filter.label,
                    selected: _historyFilter == filter,
                    onTap: () => setState(() => _historyFilter = filter),
                  ),
              ],
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const AppEmptyState(title: '暂无处理历史')
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 12),
                      children: [
                        for (
                          var index = 0;
                          index < filtered.length;
                          index++
                        ) ...[
                          _HistoryReminderCard(item: filtered[index]),
                          if (index != filtered.length - 1)
                            const SizedBox(height: 10),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _PendingReminderCard extends ConsumerWidget {
  const _PendingReminderCard({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.read(currentUserReminderCenterActionsProvider);
    final child = AppListItemPanel(
      padding: const EdgeInsets.all(12),
      child: _ReminderCardContent(item: item),
    );

    return AppSwipeActionTile(
      actions: [
        AppSwipeAction(
          tooltip: '完成',
          icon: Icons.check_circle_outline_rounded,
          foreground: colorScheme.onTertiaryContainer,
          background: colorScheme.tertiaryContainer,
          onPressed: () => actions.complete(item),
        ),
        AppSwipeAction(
          tooltip: '延后一天',
          icon: Icons.schedule_rounded,
          foreground: colorScheme.onSecondaryContainer,
          background: colorScheme.secondaryContainer,
          onPressed: () => actions.snoozeOneDay(item),
        ),
        AppSwipeAction(
          tooltip: '忽略',
          icon: Icons.block_rounded,
          foreground: colorScheme.onErrorContainer,
          background: colorScheme.errorContainer,
          onPressed: () => actions.ignore(item),
        ),
      ],
      child: child,
    );
  }
}

class _ReminderCardContent extends StatelessWidget {
  const _ReminderCardContent({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priority = item.priority(today: DateTime.now());
    final color = _priorityColor(colorScheme, priority);
    final subtitle =
        item.state == MoneyReminderCenterState.snoozed &&
            item.snoozedUntil != null
        ? '已延后至 ${DateFormat('MM-dd').format(item.snoozedUntil!)}'
        : '${_priorityLabel(priority)} · 到期 ${DateFormat('MM-dd').format(item.dueDate)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppListItemIcon(icon: _sourceIcon(item.sourceType), color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          formatMoneyMinor(item.amountMinor, item.currencyCode),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _HistoryReminderCard extends StatelessWidget {
  const _HistoryReminderCard({required this.item});

  final MoneyReminderCenterItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final result = switch (item.state) {
      MoneyReminderCenterState.completed => (
        label: '已完成',
        icon: Icons.check_rounded,
        tone: AppBadgeTone.secondary,
      ),
      MoneyReminderCenterState.ignored => (
        label: '已忽略',
        icon: Icons.block_rounded,
        tone: AppBadgeTone.neutral,
      ),
      _ => (
        label: '已处理',
        icon: Icons.history_rounded,
        tone: AppBadgeTone.neutral,
      ),
    };
    final processedAt = item.processedAt ?? item.dueDate;

    return AppListItemPanel(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppListItemIcon(
            icon: _sourceIcon(item.sourceType),
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '处理于 ${DateFormat('MM-dd HH:mm').format(processedAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppBadge(label: result.label, icon: result.icon, tone: result.tone),
        ],
      ),
    );
  }
}

IconData _sourceIcon(MoneyReminderCenterSourceType sourceType) {
  return switch (sourceType) {
    MoneyReminderCenterSourceType.budget => Icons.flag_rounded,
    MoneyReminderCenterSourceType.creditCardBill => Icons.credit_card_rounded,
    MoneyReminderCenterSourceType.installment => Icons.calendar_month_rounded,
    MoneyReminderCenterSourceType.recurringExpense => Icons.repeat_rounded,
    MoneyReminderCenterSourceType.billReminder =>
      Icons.notifications_active_rounded,
  };
}

String _priorityLabel(MoneyReminderCenterPriority priority) {
  return switch (priority) {
    MoneyReminderCenterPriority.overdue => '已逾期',
    MoneyReminderCenterPriority.dueWithinThreeDays => '3 天内到期',
    MoneyReminderCenterPriority.budgetExceeded => '预算提醒',
    MoneyReminderCenterPriority.normal => '普通提醒',
  };
}

Color _priorityColor(
  ColorScheme colorScheme,
  MoneyReminderCenterPriority priority,
) {
  return switch (priority) {
    MoneyReminderCenterPriority.overdue => colorScheme.error,
    MoneyReminderCenterPriority.dueWithinThreeDays => colorScheme.primary,
    MoneyReminderCenterPriority.budgetExceeded => colorScheme.tertiary,
    MoneyReminderCenterPriority.normal => colorScheme.secondary,
  };
}

extension on _HistoryFilter {
  MoneyReminderCenterState? get state => switch (this) {
    _HistoryFilter.all => null,
    _HistoryFilter.completed => MoneyReminderCenterState.completed,
    _HistoryFilter.ignored => MoneyReminderCenterState.ignored,
  };

  String get label => switch (this) {
    _HistoryFilter.all => '全部',
    _HistoryFilter.completed => '已完成',
    _HistoryFilter.ignored => '已忽略',
  };
}
