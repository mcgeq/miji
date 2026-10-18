import 'package:flutter/material.dart';

import 'package:miji/features/todo/domain/todo_models.dart';

/// 重复规则的编辑器。
///
/// 为什么现在才有：重复任务本来只能在**创建时**设一次（模板 + 规则一起建），
/// 建完之后没有任何入口能改。跨模块时间线上「改这一次 / 改整条规则」里的
/// 第二个选项因此无处可去 —— 这一页补的就是那个目的地。
///
/// 只负责编辑**已有规则**：给一个没有规则的任务凭空加规则，要同时处理
/// 「把这条任务从实例变成模板」，那是另一件事（见文档里的未做项）。
class TodoRecurrenceEditor extends StatefulWidget {
  const TodoRecurrenceEditor({super.key, required this.rule});

  final TodoRecurrenceRule rule;

  @override
  State<TodoRecurrenceEditor> createState() => _TodoRecurrenceEditorState();
}

class _TodoRecurrenceEditorState extends State<TodoRecurrenceEditor> {
  late RecurrenceFrequencyType _frequency;
  late int _interval;
  late Set<int> _weekdays;
  late int _dayOfMonth;
  DateTime? _endsAt;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _frequency = rule.frequencyType;
    _interval = rule.interval_ <= 0 ? 1 : rule.interval_;
    _weekdays = {...?rule.daysOfWeek};
    _dayOfMonth = rule.dayOfMonth ?? 1;
    _endsAt = rule.endsAt;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '重复规则',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '改这里影响**以后所有**重复出来的任务；只想改这一次，回到任务本身。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<RecurrenceFrequencyType>(
              segments: const [
                ButtonSegment(
                  value: RecurrenceFrequencyType.daily,
                  label: Text('每天'),
                ),
                ButtonSegment(
                  value: RecurrenceFrequencyType.weekly,
                  label: Text('每周'),
                ),
                ButtonSegment(
                  value: RecurrenceFrequencyType.monthly,
                  label: Text('每月'),
                ),
              ],
              selected: {_frequency},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                setState(() => _frequency = selection.first);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '每',
                  style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
                ),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _interval,
                  items: [
                    for (var i = 1; i <= 12; i++)
                      DropdownMenuItem(value: i, child: Text('$i')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _interval = value);
                    }
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  switch (_frequency) {
                    RecurrenceFrequencyType.daily => '天',
                    RecurrenceFrequencyType.weekly => '周',
                    RecurrenceFrequencyType.monthly => '个月',
                    RecurrenceFrequencyType.yearly => '年',
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0),
                ),
              ],
            ),
            if (_frequency == RecurrenceFrequencyType.weekly) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                children: [
                  for (var day = 1; day <= 7; day++)
                    FilterChip(
                      label: Text(_weekdayLabels[day - 1]),
                      selected: _weekdays.contains(day),
                      showCheckmark: false,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _weekdays.add(day);
                          } else {
                            _weekdays.remove(day);
                          }
                        });
                      },
                    ),
                ],
              ),
            ],
            if (_frequency == RecurrenceFrequencyType.monthly) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    '每月 ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      letterSpacing: 0,
                    ),
                  ),
                  DropdownButton<int>(
                    value: _dayOfMonth,
                    items: [
                      for (var day = 1; day <= 31; day++)
                        DropdownMenuItem(value: day, child: Text('$day 日')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _dayOfMonth = value);
                      }
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickEndDate,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _endsAt == null
                          ? '一直重复'
                          : '重复到 ${_endsAt!.year}-${_endsAt!.month}-${_endsAt!.day}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        letterSpacing: 0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _endsAt == null ? '设结束日期' : '改',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _canSave ? _submit : null,
                  child: const Text('保存规则'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 每周必须至少选一天，否则规则等于不生效。
  bool get _canSave =>
      _frequency != RecurrenceFrequencyType.weekly || _weekdays.isNotEmpty;

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _endsAt = picked);
    }
  }

  void _submit() {
    Navigator.of(context).pop(_draft);
  }

  /// 「不重复」用 null 表示 —— 与「取消」区分开。
  TodoRecurrenceRule get _draft {
    return widget.rule.copyWith(
      frequencyType: _frequency,
      interval_: _interval,
      daysOfWeek: _frequency == RecurrenceFrequencyType.weekly
          ? (_weekdays.toList()..sort())
          : null,
      dayOfMonth: _frequency == RecurrenceFrequencyType.monthly
          ? _dayOfMonth
          : null,
      endsAt: _endsAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// 规则的一句话摘要：「每周一、三 · 到 2026-12-31」。
String describeRecurrenceRule(TodoRecurrenceRule rule) {
  const labels = ['一', '二', '三', '四', '五', '六', '日'];
  final every = rule.interval_ <= 1 ? null : rule.interval_;
  final unit = switch (rule.frequencyType) {
    RecurrenceFrequencyType.daily => '天',
    RecurrenceFrequencyType.weekly => '周',
    // 「每月」而不是「每个月」：后者读起来像「一个月一次」的量词，
    // 而这里说的是频率。间隔 > 1 时才补上「个」。
    RecurrenceFrequencyType.monthly => '月',
    RecurrenceFrequencyType.yearly => '年',
  };
  final prefix = every == null ? '每$unit' : '每 $every $unit';
  final base = switch (rule.frequencyType) {
    RecurrenceFrequencyType.daily => prefix,
    RecurrenceFrequencyType.weekly =>
      rule.daysOfWeek == null || rule.daysOfWeek!.isEmpty
          ? prefix
          : '$prefix${rule.daysOfWeek!.map((d) => labels[(d - 1).clamp(0, 6)]).join('、')}',
    RecurrenceFrequencyType.monthly =>
      rule.dayOfMonth == null ? prefix : '$prefix ${rule.dayOfMonth} 日',
    RecurrenceFrequencyType.yearly => prefix,
  };
  final endsAt = rule.endsAt;
  return endsAt == null
      ? base
      : '$base · 到 ${endsAt.year}-${endsAt.month}-${endsAt.day}';
}
