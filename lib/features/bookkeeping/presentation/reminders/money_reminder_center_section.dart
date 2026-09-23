import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';

import 'package:miji/core/presentation/app_page_layout.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/app_toast.dart';
import 'package:miji/core/presentation/components/app_badge.dart';
import 'package:miji/core/presentation/components/app_filter_strip.dart';
import 'package:miji/core/presentation/components/app_icon_action_button.dart';
import 'package:miji/core/presentation/components/app_list_item.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/core/presentation/components/app_sliding_segmented_control.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/domain/money_bill_reminder_entity.dart';
import 'package:miji/features/bookkeeping/domain/money_reminder_center_entity.dart';
import 'package:miji/features/bookkeeping/providers/bookkeeping_providers.dart';
import 'package:miji/features/bookkeeping/presentation/reminders/bill_reminder_form_dialog.dart';

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
  FToast? _toast;

  /// 多选：长按任意待处理提醒进入，底部出现批量操作条。
  final Set<String> _selectedKeys = <String>{};
  bool _busy = false;

  bool get _selectionMode => _selectedKeys.isNotEmpty;

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
        Row(
          children: [
            Expanded(
              child: Center(
                child: AppSlidingSegmentedControl<_ReminderCenterView>(
                  minSegmentWidth: 120,
                  value: _view,
                  onChanged: (value) => setState(() {
                    _view = value;
                    _selectedKeys.clear();
                  }),
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
            ),
            // 常驻新增入口。
            //
            // 提醒中心之前只能「完成/延后/忽略」，而唯一能创建账单提醒的
            // 旧页面（MoneyBillRemindersSection）没有任何引用。
            AppIconActionButton(
              tooltip: '新增提醒',
              onPressed: _openReminderForm,
              icon: Icons.add_alert_rounded,
              variant: AppIconActionVariant.filled,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: switch (_view) {
            _ReminderCenterView.pending => _buildPending(pending),
            _ReminderCenterView.history => _buildHistory(history),
          },
        ),
        if (_selectionMode && _view == _ReminderCenterView.pending)
          _BulkActionBar(
            selectedCount: _selectedKeys.length,
            busy: _busy,
            onComplete: () => _runBulk(_BulkAction.complete, pending),
            onSnooze: () => _runBulk(_BulkAction.snooze, pending),
            onIgnore: () => _runBulk(_BulkAction.ignore, pending),
            onClear: () => setState(_selectedKeys.clear),
          ),
      ],
    );
  }

  /// 对选中的提醒批量执行同一个动作。
  Future<void> _runBulk(
    _BulkAction action,
    AsyncValue<List<MoneyReminderCenterItem>> pending,
  ) async {
    final items = pending.maybeWhen(
      data: (value) => value,
      orElse: () => const <MoneyReminderCenterItem>[],
    );
    final targets = items
        .where((item) => _selectedKeys.contains(item.itemKey))
        .toList();
    if (targets.isEmpty) {
      setState(_selectedKeys.clear);
      return;
    }

    final actions = ref.read(currentUserReminderCenterActionsProvider);
    final toast = _toast ??= (FToast()..init(context));
    setState(() => _busy = true);
    var failed = 0;
    for (final item in targets) {
      try {
        switch (action) {
          case _BulkAction.complete:
            await actions.complete(item);
          case _BulkAction.snooze:
            await actions.snoozeOneDay(item);
          case _BulkAction.ignore:
            await actions.ignore(item);
        }
      } catch (_) {
        failed += 1;
      }
      if (!mounted) {
        return;
      }
    }
    setState(() {
      _busy = false;
      _selectedKeys.clear();
    });
    if (!mounted) {
      return;
    }
    if (failed == 0) {
      HapticFeedback.mediumImpact();
    }
    if (failed > 0) {
      AppToast.error(toast, context, '${targets.length} 项中有 $failed 项失败');
    } else {
      AppToast.success(toast, context, action.doneLabel(targets.length));
    }
  }

  void _startSelection(String itemKey) {
    setState(() => _selectedKeys.add(itemKey));
  }

  void _toggleSelection(String itemKey) {
    setState(() {
      if (!_selectedKeys.add(itemKey)) {
        _selectedKeys.remove(itemKey);
      }
    });
  }

  /// 新建 / 编辑账单提醒。
  Future<void> _openReminderForm([MoneyBillReminderEntity? reminder]) async {
    final result = await showAppResponsiveDialog<BillReminderFormResult>(
      context: context,
      expandCompactSheet: true,
      builder: (context) => BillReminderFormDialog(reminder: reminder),
    );
    if (result == null || !mounted) {
      return;
    }

    final toast = _toast ??= (FToast()..init(context));
    try {
      final actions = ref.read(currentUserMoneyBillReminderActionsProvider);
      if (reminder == null) {
        await actions.createReminder(result.toDraft());
      } else {
        await actions.updateReminder(result.toUpdate(reminder));
      }
      if (!mounted) return;
      AppToast.success(toast, context, reminder == null ? '提醒已创建' : '提醒已更新');
    } catch (error) {
      if (!mounted) return;
      AppToast.error(toast, context, '保存提醒失败');
    }
  }

  Widget _buildPending(AsyncValue<List<MoneyReminderCenterItem>> pending) {
    return pending.when(
      loading: () => const AppSkeletonList(),
      error: (_, _) => AppErrorState(
        title: '读取提醒失败',
        onRetry: () =>
            ref.invalidate(currentUserPendingReminderCenterItemsProvider),
      ),
      data: (items) {
        if (items.isEmpty) {
          return AppEmptyState(
            title: '暂无待处理提醒',
            message: '可以添加账单、还款或其他需要到期提示的事项。',
            icon: Icons.notifications_none_rounded,
            action: AppIconActionButton(
              tooltip: '新增提醒',
              onPressed: _openReminderForm,
              icon: Icons.add_alert_rounded,
              variant: AppIconActionVariant.filled,
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => refreshMoneyData(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final group in _groupByUrgency(items, DateTime.now())) ...[
                _PendingGroupHeader(
                  urgency: group.urgency,
                  count: group.items.length,
                ),
                for (final item in group.items) ...[
                  _PendingReminderCard(
                    item: item,
                    selected: _selectedKeys.contains(item.itemKey),
                    selectionMode: _selectionMode,
                    onToggleSelect: () => _toggleSelection(item.itemKey),
                    onLongPress: () => _startSelection(item.itemKey),
                    onEditReminder: _selectionMode ? null : _openReminderForm,
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 按紧急度分组。
  ///
  /// 原来是一条平铺列表，卡片内虽然用颜色区分了优先级但顺序不变——
  /// 逾期的几条会被埋在十几条里。
  List<_PendingGroup> _groupByUrgency(
    List<MoneyReminderCenterItem> items,
    DateTime today,
  ) {
    final current = DateTime(today.year, today.month, today.day);
    final buckets = <_PendingUrgency, List<MoneyReminderCenterItem>>{
      for (final urgency in _PendingUrgency.values)
        urgency: <MoneyReminderCenterItem>[],
    };
    for (final item in items) {
      final local = item.dueDate.toLocal();
      final due = DateTime(local.year, local.month, local.day);
      final urgency = due.isBefore(current)
          ? _PendingUrgency.overdue
          : due == current
          ? _PendingUrgency.today
          : due.difference(current).inDays <= 3
          ? _PendingUrgency.soon
          : _PendingUrgency.later;
      buckets[urgency]!.add(item);
    }
    return [
      for (final urgency in _PendingUrgency.values)
        if (buckets[urgency]!.isNotEmpty)
          _PendingGroup(urgency: urgency, items: buckets[urgency]!),
    ];
  }

  Widget _buildHistory(AsyncValue<List<MoneyReminderCenterItem>> history) {
    return history.when(
      loading: () => const AppSkeletonList(),
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
                  : RefreshIndicator(
                      onRefresh: () => refreshMoneyData(ref),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
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

enum _PendingUrgency {
  overdue('已逾期', 'od'),
  today('今天', 'td'),
  soon('3 天内', null),
  later('以后', null);

  const _PendingUrgency(this.label, this.tone);

  final String label;

  /// 分组头的强调色：逾期=红、今天=橙、其余=中性。
  final String? tone;
}

class _PendingGroup {
  const _PendingGroup({required this.urgency, required this.items});

  final _PendingUrgency urgency;
  final List<MoneyReminderCenterItem> items;
}

class _PendingGroupHeader extends StatelessWidget {
  const _PendingGroupHeader({required this.urgency, required this.count});

  final _PendingUrgency urgency;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = switch (urgency.tone) {
      'od' => colorScheme.error,
      'td' => theme.moneyColors.warning,
      _ => colorScheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(left: 2, top: 2, bottom: 8),
      child: Row(
        children: [
          Text(
            urgency.label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BulkAction {
  complete,
  snooze,
  ignore;

  String doneLabel(int count) {
    return switch (this) {
      _BulkAction.complete => '已完成 $count 项',
      _BulkAction.snooze => '已延后 $count 项',
      _BulkAction.ignore => '已忽略 $count 项',
    };
  }
}

/// 多选模式下的批量操作条。
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.busy,
    required this.onComplete,
    required this.onSnooze,
    required this.onIgnore,
    required this.onClear,
  });

  final int selectedCount;
  final bool busy;
  final VoidCallback onComplete;
  final VoidCallback onSnooze;
  final VoidCallback onIgnore;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: colorScheme.inverseSurface,
        borderRadius: BorderRadius.circular(theme.radiusTokens.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                '已选 $selectedCount 项',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: busy ? null : onSnooze,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('延后'),
              ),
              TextButton(
                onPressed: busy ? null : onIgnore,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('忽略'),
              ),
              TextButton(
                onPressed: busy ? null : onComplete,
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.onInverseSurface,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('完成'),
              ),
              AppIconActionButton(
                tooltip: '退出多选',
                onPressed: busy ? null : onClear,
                icon: Icons.close_rounded,
                iconSize: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingReminderCard extends ConsumerWidget {
  const _PendingReminderCard({
    required this.item,
    this.onEditReminder,
    this.onLongPress,
    this.onToggleSelect,
    this.selected = false,
    this.selectionMode = false,
  });

  final MoneyReminderCenterItem item;

  /// 账单提醒可以点进去编辑；预算 / 分期 / 账单等派生提醒没有表单。
  final void Function(MoneyBillReminderEntity reminder)? onEditReminder;

  /// 长按进入多选。
  final VoidCallback? onLongPress;
  final VoidCallback? onToggleSelect;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final actions = ref.read(currentUserReminderCenterActionsProvider);
    final editableReminder = _editableReminder(ref);
    final child = AppListItemPanel(
      padding: const EdgeInsets.all(12),
      selected: selected,
      child: Row(
        children: [
          if (selectionMode) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: _ReminderCardContent(
              item: item,
              onComplete: selectionMode ? null : () => actions.complete(item),
            ),
          ),
        ],
      ),
    );

    return AppSwipeActionTile(
      onLongPress: onLongPress,
      onTap: selectionMode
          ? onToggleSelect
          : editableReminder == null || onEditReminder == null
          ? null
          : () => onEditReminder!(editableReminder),
      actions: selectionMode
          ? const <AppSwipeAction>[]
          : [
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

  /// 这条提醒是不是可编辑的账单提醒（而不是预算/分期派生的）。
  MoneyBillReminderEntity? _editableReminder(WidgetRef ref) {
    if (item.sourceType != MoneyReminderCenterSourceType.billReminder) {
      return null;
    }
    final reminders = ref
        .watch(currentUserBillRemindersProvider)
        .maybeWhen(data: (items) => items, orElse: () => null);
    if (reminders == null) {
      return null;
    }
    for (final reminder in reminders) {
      if (reminder.id == item.sourceId) {
        return reminder;
      }
    }
    return null;
  }
}

class _ReminderCardContent extends StatelessWidget {
  const _ReminderCardContent({required this.item, this.onComplete});

  final MoneyReminderCenterItem item;

  /// 行内「完成」。
  ///
  /// 原来「完成 / 延后 / 忽略」全在左滑里，没有任何视觉提示；
  /// 最高频的「完成」提到行尾，左滑保留为快捷方式。
  final VoidCallback? onComplete;

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
        MoneyText(
          amountMinor: item.amountMinor,
          currencyCode: item.currencyCode,
          color: color,
          textStyle: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        if (onComplete != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: '标记完成',
            onPressed: onComplete,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(
              Icons.check_circle_outline_rounded,
              size: 20,
              color: colorScheme.secondary,
            ),
          ),
        ],
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
