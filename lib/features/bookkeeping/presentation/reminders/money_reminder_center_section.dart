import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
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
import 'package:miji/core/router/app_routes.dart';
import 'package:miji/features/bookkeeping/presentation/quick_actions/money_quick_action_launcher.dart';
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
            // 提醒设置：推送时间与开关在「记账偏好」里，这里给个直达入口，
            // 否则用户想改个提醒时间得先退出记账模块再翻设置。
            AppIconActionButton(
              tooltip: '提醒设置',
              onPressed: _openReminderSettings,
              icon: Icons.tune_rounded,
            ),
            const SizedBox(width: 6),
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

  /// 处理一条提醒的唯一出口：**处理必然产生一笔流水**。
  ///
  /// 之前「完成」只是往 processing 表写一条状态，账本里什么都不发生——
  /// 提醒从待处理消失了，钱却没有下落。现在按来源分流到各自的写账动作，
  /// 写成功了才把提醒标记为已完成并把流水 id 回填到源头。
  Future<void> _runRecordFlow(MoneyReminderCenterItem item) async {
    if (_busy) {
      return;
    }
    final toast = _toast ??= (FToast()..init(context));
    final launcher = MoneyQuickActionLauncher(
      context: context,
      ref: ref,
      ensureToast: () => toast,
    );

    setState(() => _busy = true);
    var recorded = false;
    String? transactionId;
    try {
      switch (item.actionType) {
        case MoneyReminderCenterActionType.repay:
          recorded = await launcher.recordRepaymentFromReminder(item);
        case MoneyReminderCenterActionType.recordTransaction:
        case MoneyReminderCenterActionType.openReminder:
        case MoneyReminderCenterActionType.openInstallment:
          if (item.sourceType == MoneyReminderCenterSourceType.installment) {
            recorded = await launcher.postInstallmentFromReminder(item);
          } else {
            transactionId = await launcher.recordExpenseFromReminder(item);
            recorded = transactionId != null;
          }
        case MoneyReminderCenterActionType.viewBudget:
          // 预算超支是结果而不是待办：它随流水变化自动出现/消失，
          // 没有可以「结清」的动作，只能忽略。
          recorded = false;
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(toast, context, '操作失败');
      }
      return;
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
    if (!recorded || !mounted) {
      return;
    }

    try {
      await ref
          .read(currentUserReminderCenterActionsProvider)
          .complete(item, transactionId: transactionId);
      HapticFeedback.mediumImpact();
      if (!mounted) {
        return;
      }
      final message = switch (item.sourceType) {
        MoneyReminderCenterSourceType.installment => '${item.title} 已入账',
        MoneyReminderCenterSourceType.creditCardBill => '还款已记账',
        _ => '已记账',
      };
      AppToast.success(toast, context, message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      AppToast.error(toast, context, '流水已记录，但更新提醒状态失败');
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

  /// 点击卡片：走到该提醒对应的处理入口。
  ///
  /// 账单 / 分期提醒会直接打开预填好的记账表单（或直接过账），
  /// 预算提醒只能跳到预算面板查看——它没有可以「结清」的动作。
  void _handleItemAction(MoneyReminderCenterItem item) {
    switch (item.actionType) {
      case MoneyReminderCenterActionType.repay:
      case MoneyReminderCenterActionType.recordTransaction:
      case MoneyReminderCenterActionType.openReminder:
      case MoneyReminderCenterActionType.openInstallment:
        _runRecordFlow(item);
      case MoneyReminderCenterActionType.viewBudget:
        _goToBookkeepingSection('budgets');
    }
  }

  void _openReminderSettings() {
    context.push(AppRoutes.settingsBookkeeping);
  }

  void _goToBookkeepingSection(String section) {
    context.go(
      Uri(
        path: AppRoutes.bookkeeping,
        queryParameters: {'section': section},
      ).toString(),
    );
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
                    onOpen: _selectionMode
                        ? null
                        : () => _handleItemAction(item),
                    onRecord: _selectionMode
                        ? null
                        : () => _runRecordFlow(item),
                    // 删掉不可达的 openReminder 分支后，卡片点击变成了「记账」，
                    // 于是「点进去改提醒」彻底没人认领。这里把它挂到右键菜单上：
                    // 只有真正存在源头账单提醒的项才有这个功能。
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
  // 批量里刻意没有「完成」：完成必然要落到一笔流水上，而连弹 N 个记账表单
  // 不成立。真正的「不处理」出口是「忽略」。
  snooze,
  ignore;

  String doneLabel(int count) {
    return switch (this) {
      _BulkAction.snooze => '已延后 $count 项',
      // 明确「没有记账」，避免用户把忽略理解成「稍后自己补记」。
      _BulkAction.ignore => '已忽略 $count 项（未记账）',
    };
  }
}

/// 多选模式下的批量操作条。
class _BulkActionBar extends StatelessWidget {
  const _BulkActionBar({
    required this.selectedCount,
    required this.busy,
    required this.onSnooze,
    required this.onIgnore,
    required this.onClear,
  });

  final int selectedCount;
  final bool busy;
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '已选 $selectedCount 项',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                    // 批量条里刻意没有「完成」——完成必须先落到一笔流水上，
                    // 而连弹 N 个记账表单不成立。所以这里要说清楚退路是什么，
                    // 否则用户会把「忽略」理解成「稍后自己补记」。
                    Text(
                      '记账请逐条操作，忽略不会产生流水',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onInverseSurface.withValues(
                          alpha: 0.62,
                        ),
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
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
    this.onOpen,
    this.onRecord,
    this.onEditReminder,
    this.onLongPress,
    this.onToggleSelect,
    this.selected = false,
    this.selectionMode = false,
  });

  final MoneyReminderCenterItem item;

  /// 点击卡片：走到这条提醒的处理入口（记账 / 还款 / 分期入账 / 看预算）。
  final VoidCallback? onOpen;

  /// 行内「记账」：与点击卡片走同一个流程，只是按钮目标更明确。
  final VoidCallback? onRecord;

  /// 编辑源头账单提醒。预算 / 分期等派生提醒没有对应的表单，传 null 由卡片隐藏入口。
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
    final effectiveOnRecord = switch (item.actionType) {
      // 预算提醒没有可结清的动作：只能忽略，等超支状态自己消失。
      MoneyReminderCenterActionType.viewBudget => null,
      _ => onRecord,
    };
    final editableReminder = onEditReminder == null
        ? null
        : _editableReminder(ref);
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
              onRecord: selectionMode ? null : effectiveOnRecord,
            ),
          ),
          if (editableReminder != null)
            PopupMenuButton<_ReminderCardMenuAction>(
              tooltip: '更多',
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(
                Icons.more_vert_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              onSelected: (action) {
                if (action == _ReminderCardMenuAction.edit) {
                  onEditReminder!(editableReminder);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ReminderCardMenuAction>(
                  value: _ReminderCardMenuAction.edit,
                  child: Text('编辑提醒'),
                ),
              ],
            ),
        ],
      ),
    );

    return AppSwipeActionTile(
      onLongPress: onLongPress,
      onTap: selectionMode ? onToggleSelect : onOpen,
      actions: selectionMode
          ? const <AppSwipeAction>[]
          : [
              if (effectiveOnRecord != null)
                AppSwipeAction(
                  tooltip: '记账',
                  icon: Icons.receipt_long_rounded,
                  foreground: colorScheme.onTertiaryContainer,
                  background: colorScheme.tertiaryContainer,
                  onPressed: effectiveOnRecord,
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

  /// 这条提醒背后是否有一个可编辑的账单提醒实体。
  ///
  /// 只有账单提醒（sourceType == billReminder）才存在表单；预算、信用卡账单、
  /// 分期这些是从别的数据派生出来的，没有自己的提醒实体可编辑。
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

/// 卡片菜单项。只有「编辑」一项，先留枚举以便后续扩展（比如「查看管理列表」）。
enum _ReminderCardMenuAction { edit }

class _ReminderCardContent extends StatelessWidget {
  const _ReminderCardContent({required this.item, this.onRecord});

  final MoneyReminderCenterItem item;

  /// 行内「记账」。
  ///
  /// 原来这里是「标记完成」——点了之后提醒消失但账本没有任何变化。
  /// 现在它和左滑第一项跑同一个流程：打开预填表单，写成功才算处理完。
  final VoidCallback? onRecord;

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
        if (onRecord != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: '记账',
            onPressed: onRecord,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
            icon: Icon(
              Icons.receipt_long_rounded,
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
