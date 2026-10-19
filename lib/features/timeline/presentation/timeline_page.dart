import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:miji/core/auth/application/sensitive_access_controller.dart';
import 'package:miji/core/presentation/components/app_skeleton.dart';
import 'package:miji/core/presentation/components/app_surface.dart';
import 'package:miji/core/presentation/components/money_text.dart';
import 'package:miji/core/theme/app_design_tokens.dart';
import 'package:miji/features/bookkeeping/application/money_amount_formatter.dart';
import 'package:miji/features/timeline/application/timeline_providers.dart';
import 'package:miji/features/timeline/domain/timeline_assembler.dart';
import 'package:miji/features/timeline/domain/timeline_event.dart';
import 'package:miji/features/timeline/domain/timeline_history.dart';
import 'package:miji/features/timeline/presentation/timeline_style.dart';

/// 跨模块时间线：日程视图。
///
/// 只回答「这段时间里有什么」：按日分组、组内分「待发生 / 已发生」，
/// 容器（预算周期、经期）画成区间带，预测与事实不同形。
///
/// **只读**：这里没有左滑、没有长按、没有新建。加待办去「打卡」，记一笔去「记账」。
class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(timelineScopeProvider);
    final window = ref.watch(timelineWindowProvider);
    final result = ref.watch(timelineProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('时间线'),
        actions: [
          IconButton(
            tooltip: '回到今天',
            icon: const Icon(Icons.today_outlined),
            onPressed: () {
              final now = DateTime.now();
              ref
                  .read(timelineScopeProvider.notifier)
                  .selectDay(DateTime.utc(now.year, now.month, now.day));
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _ViewModeSwitch(selection: selection),
          ),
          if (selection.viewMode == TimelineViewMode.schedule) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _ScopeSwitch(selection: selection),
            ),
            _DayStrip(selection: selection, window: window),
            const SizedBox(height: 4),
          ] else
            _MonthHeader(selection: selection),
          Expanded(
            child: result.when(
              loading: () => const AppSkeletonList(rows: 6),
              error: (error, stackTrace) =>
                  _ErrorState(onRetry: () => ref.invalidate(timelineProvider)),
              data: (data) => selection.viewMode == TimelineViewMode.history
                  ? _HistoryBody(data: data)
                  : data.timeline.isEmpty
                  ? const _EmptyState()
                  : _TimelineBody(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewModeSwitch extends ConsumerWidget {
  const _ViewModeSwitch({required this.selection});

  final TimelineSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final mode in TimelineViewMode.values) ...[
          if (mode != TimelineViewMode.values.first) const SizedBox(width: 8),
          ChoiceChip(
            label: Text(mode.label),
            selected: selection.viewMode == mode,
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(timelineScopeProvider.notifier).setViewMode(mode),
          ),
        ],
      ],
    );
  }
}

/// 回顾的月份导航：‹ 2026 年 10 月 ›
class _MonthHeader extends ConsumerWidget {
  const _MonthHeader({required this.selection});

  final TimelineSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final anchor = selection.anchor;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: '上个月',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () => ref
                .read(timelineScopeProvider.notifier)
                .shift(-DateTime.utc(anchor.year, anchor.month, 0).day),
          ),
          Expanded(
            child: Text(
              '${anchor.year} 年 ${anchor.month} 月',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '下个月',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: () => ref
                .read(timelineScopeProvider.notifier)
                .shift(DateTime.utc(anchor.year, anchor.month + 1, 0).day),
          ),
        ],
      ),
    );
  }
}

class _ScopeSwitch extends ConsumerWidget {
  const _ScopeSwitch({required this.selection});

  final TimelineSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        for (final scope in TimelineScope.values) ...[
          if (scope != TimelineScope.values.first) const SizedBox(width: 8),
          ChoiceChip(
            label: Text(scope.label),
            selected: selection.scope == scope,
            showCheckmark: false,
            onSelected: (_) =>
                ref.read(timelineScopeProvider.notifier).setScope(scope),
          ),
        ],
      ],
    );
  }
}

/// 日期条：一周 7 天，点的大小表示条数（1–3 / 4–6 / >6），空心表示没有事件。
class _DayStrip extends ConsumerWidget {
  const _DayStrip({required this.selection, required this.window});

  final TimelineSelection selection;
  final TimelineWindow window;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(timelineProvider).asData?.value;
    final counts = <DateTime, int>{
      for (final day in result?.timeline.days ?? const <TimelineDay>[])
        day.day: day.total,
    };
    // 固定展示 7 天：以窗口起点那一周为基准，月窗口也用它做导航。
    final weekStart = TimelineWindow.weekOf(selection.anchor).start;
    final days = [
      for (var i = 0; i < 7; i++)
        DateTime.utc(weekStart.year, weekStart.month, weekStart.day + i),
    ];
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          IconButton(
            tooltip: '上一周',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_left_rounded, size: 20),
            onPressed: () => ref.read(timelineScopeProvider.notifier).shift(-7),
          ),
          for (var i = 0; i < days.length; i++)
            Expanded(
              child: _DayCell(
                day: days[i],
                label: weekdays[i],
                count: counts[days[i]] ?? 0,
                selected: days[i] == selection.anchor,
              ),
            ),
          IconButton(
            tooltip: '下一周',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.chevron_right_rounded, size: 20),
            onPressed: () => ref.read(timelineScopeProvider.notifier).shift(7),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends ConsumerWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.count,
    required this.selected,
  });

  final DateTime day;
  final String label;
  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dotSize = count == 0
        ? 6.0
        : (count <= 3 ? 5.0 : (count <= 6 ? 6.0 : 7.0));
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ref.read(timelineScopeProvider.notifier).selectDay(day),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? scheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? scheme.onPrimary : scheme.onSurface,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: count == 0
                    ? Colors.transparent
                    : (selected ? scheme.onPrimary : scheme.onSurfaceVariant),
                border: count == 0
                    ? Border.all(color: scheme.outlineVariant)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineBody extends ConsumerWidget {
  const _TimelineBody({required this.data});

  final TimelineResult data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locked = !ref.watch(sensitiveAccessControllerProvider).isVerified;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final failure in data.failures)
          _SourceFailureRow(
            module: failure.module,
            onRetry: () => ref.invalidate(timelineProvider),
          ),
        for (final day in data.timeline.days) ...[
          _DayHeader(day: day),
          for (final event in day.commitments)
            _EventTile(event: event, locked: locked),
          for (final event in day.predictions)
            _EventTile(event: event, locked: locked),
          if (day.facts.isNotEmpty) ...[
            _FactsSection(day: day, locked: locked),
          ],
          if (day.hiddenCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '还有 ${day.hiddenCount} 条',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0,
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day});

  final TimelineDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekday = const [
      '一',
      '二',
      '三',
      '四',
      '五',
      '六',
      '日',
    ][day.day.weekday - 1];
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '${day.day.month} 月 ${day.day.day} 日 周$weekday',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '待发生 ${day.commitments.length + day.predictions.length} · '
            '已发生 ${day.facts.length}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// 已发生：默认折成一行，点开才展开。
class _FactsSection extends StatefulWidget {
  const _FactsSection({required this.day, required this.locked});

  final TimelineDay day;
  final bool locked;

  @override
  State<_FactsSection> createState() => _FactsSectionState();
}

class _FactsSectionState extends State<_FactsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  '已发生 ${widget.day.facts.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const Spacer(),
                Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          for (final event in widget.day.facts)
            _EventTile(event: event, locked: widget.locked, dimmed: true),
      ],
    );
  }
}

/// 一行事件。
class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.locked,
    this.dimmed = false,
  });

  final TimelineEvent event;

  /// 未通过二次验证：健康类事件连标题都不给。
  final bool locked;

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final masked = MoneyPrivacy.of(context);
    final hidden = locked && event.sensitive;
    final color = timelineModuleColor(theme, event.module);
    final predicted = event.nature.isPrediction;

    final timeText = event.isTimed
        ? '${event.at!.toLocal().hour.toString().padLeft(2, '0')}:'
              '${event.at!.toLocal().minute.toString().padLeft(2, '0')}'
        : '全天';

    final target = event.target;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 34,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: predicted ? Colors.transparent : color,
              border: predicted
                  ? Border(left: BorderSide(color: color, width: 2))
                  : null,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 42,
            child: Text(
              timeText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: event.isTimed ? scheme.onSurfaceVariant : scheme.outline,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hidden ? timelineLockedHealthTitle : event.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: dimmed ? scheme.onSurfaceVariant : scheme.onSurface,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _subtitleFor(event, hidden: hidden, masked: masked),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          if (event.amountMinor != null) ...[
            const SizedBox(width: 8),
            Text(
              masked ? '••••' : formatMoneyMinor(event.amountMinor!, 'CNY'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: event.amountMinor! < 0
                    ? theme.moneyColors.expense
                    : theme.moneyColors.income,
                letterSpacing: 0,
              ),
            ),
          ] else if (event.emphasis == TimelineEmphasis.attention)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 7),
              decoration: BoxDecoration(
                color: scheme.error,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
    return Opacity(
      opacity: predicted ? 0.72 : 1,
      child: target == null
          ? row
          // 行可点：跳到来源（待办详情 / 模块面板）。时间线本身仍然只读。
          : InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openTarget(context, target),
              child: row,
            ),
    );
  }

  /// 来自重复规则的事件先问一句：改这一次，还是改整条规则。
  ///
  /// 「改整条」跳到任务详情的规则编辑器（`?focus=recurrence`）—— 在那里改的
  /// 东西影响以后所有实例，这个区别值得一次点击。
  Future<void> _openTarget(BuildContext context, TimelineTarget target) async {
    if (target.askRuleScope) {
      final whole = await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.event_repeat_rounded),
                title: const Text('只能改这一次'),
                subtitle: const Text('打开任务本身，只动这一条'),
                onTap: () => Navigator.of(sheetContext).pop(false),
              ),
              ListTile(
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('改整条规则'),
                subtitle: const Text('以后重复出来的都变'),
                onTap: () => Navigator.of(sheetContext).pop(true),
              ),
            ],
          ),
        ),
      );
      if (whole == null || !context.mounted) {
        return;
      }
      if (whole) {
        context.push('${target.route}?focus=recurrence');
        return;
      }
    }
    context.push(target.route);
  }

  String _subtitleFor(
    TimelineEvent event, {
    required bool hidden,
    required bool masked,
  }) {
    if (hidden) {
      return '解锁后显示这一天的健康安排';
    }
    final nature = switch (event.nature) {
      TimelineNature.commitment => '计划',
      TimelineNature.prediction => '预测',
      TimelineNature.fact => '',
      TimelineNature.container => '',
    };
    final parts = <String>[
      if (event.subtitle != null && event.subtitle!.trim().isNotEmpty)
        event.subtitle!.trim(),
      if (nature.isNotEmpty) nature,
    ];
    return parts.join(' · ');
  }
}

/// 回顾：一个月的每天一行摘要。
///
/// 只含事实（见 `buildHistory`）。点一行回到那一天的日程 —— 回顾用来「发现」，
/// 日程用来「看细节」。
class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.data});

  final TimelineResult data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final masked = MoneyPrivacy.of(context);
    final history = buildHistory(data.timeline);
    if (history.isEmpty) {
      return const _EmptyHistory();
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        AppSurface(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本月发生了什么',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _summaryLine(history),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final day in history.days)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              ref.read(timelineScopeProvider.notifier)
                ..selectDay(
                  DateTime.utc(day.day.year, day.day.month, day.day.day),
                )
                ..setViewMode(TimelineViewMode.schedule)
                ..setScope(TimelineScope.day);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${day.day.month.toString().padLeft(2, '0')}/'
                      '${day.day.day.toString().padLeft(2, '0')}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _dayLine(day, masked),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        letterSpacing: 0,
                        height: 1.4,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _summaryLine(TimelineHistory history) {
    final parts = <String>[
      if (history.totalExpenseMinor > 0)
        '支出 ${formatMoneyMinor(history.totalExpenseMinor, 'CNY')}',
      if (history.totalCheckinCount > 0) '打卡 ${history.totalCheckinCount} 次',
      if (history.totalTaskCompletedCount > 0)
        '任务完成 ${history.totalTaskCompletedCount}',
    ];
    return parts.isEmpty ? '这个月还没有记录' : parts.join(' · ');
  }

  /// 「支出 ¥158 · 打卡 3 次 · 任务 1 · 经期」
  String _dayLine(TimelineHistoryDay day, bool masked) {
    final parts = <String>[
      if (day.expenseMinor > 0)
        masked ? '支出 ••••' : '支出 ${formatMoneyMinor(day.expenseMinor, 'CNY')}',
      if (day.checkinCount > 0) '打卡 ${day.checkinCount} 次',
      if (day.taskCompletedCount > 0) '任务 ${day.taskCompletedCount}',
      if (day.hasPeriod) '经期',
    ];
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          '这个月还没有可回顾的记录。\n回顾只包含已经发生的事。',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

/// 一路读取失败：只占一行，不整页报错。
class _SourceFailureRow extends StatelessWidget {
  const _SourceFailureRow({required this.module, required this.onRetry});

  final TimelineModule module;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${module.label}读取失败',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('读取时间线失败', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '这段时间没有安排',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '时间线只读 —— 加待办去「打卡」，记一笔去「记账」。',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
