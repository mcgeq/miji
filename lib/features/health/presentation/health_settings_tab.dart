import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';

typedef HealthSettingsSave = void Function(HealthPeriodSettingsDraft draft);
typedef HealthPregnancyStart = void Function(HealthPregnancyDraft draft);
typedef HealthPregnancyEnd = void Function(HealthPregnancyEndDraft draft);

class HealthSettingsTab extends StatefulWidget {
  const HealthSettingsTab({
    required this.settings,
    required this.onSave,
    required this.onStartPregnancyMode,
    this.activePregnancy,
    this.onEndPregnancyMode,
    this.onCancelPregnancyMode,
    super.key,
  });

  final HealthPeriodSettingsModel settings;
  final HealthSettingsSave onSave;
  final HealthPregnancyStart onStartPregnancyMode;
  final HealthPregnancyStatus? activePregnancy;
  final HealthPregnancyEnd? onEndPregnancyMode;
  final VoidCallback? onCancelPregnancyMode;

  @override
  State<HealthSettingsTab> createState() => _HealthSettingsTabState();
}

class _HealthSettingsTabState extends State<HealthSettingsTab> {
  late int _cycleLength;
  late int _periodLength;
  late bool _periodTrackingEnabled;
  late bool _periodReminderEnabled;
  late bool _ovulationReminderEnabled;
  late bool _pmsReminderEnabled;
  late int _reminderDays;
  late bool _dataSyncEnabled;
  late bool _analyticsEnabled;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _cycleLength = settings.averageCycleLength;
    _periodLength = settings.averagePeriodLength;
    _periodTrackingEnabled = settings.periodTrackingEnabled;
    _periodReminderEnabled = settings.periodReminderEnabled;
    _ovulationReminderEnabled = settings.ovulationReminderEnabled;
    _pmsReminderEnabled = settings.pmsReminderEnabled;
    _reminderDays = settings.reminderDays;
    _dataSyncEnabled = settings.dataSyncEnabled;
    _analyticsEnabled = settings.analyticsEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activePregnancy = widget.activePregnancy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _SettingsGroup(
          title: '周期与经期',
          children: [
            AppSwitchField(
              title: '启用经期记录',
              subtitle: '关闭后隐藏日历标注与周期趋势，每日记录统计保留',
              value: _periodTrackingEnabled,
              onChanged: (value) {
                setState(() => _periodTrackingEnabled = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 4),
            _SliderRow(
              label: '平均周期长度',
              value: _cycleLength,
              min: 18,
              max: 45,
              suffix: '天',
              hint: '两次经期第一天的间隔，通常在 21–35 天',
              onChanged: (value) {
                setState(() => _cycleLength = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 6),
            _ChipRow(
              label: '平均经期长度',
              values: const [2, 3, 4, 5, 6, 7, 8],
              selected: _periodLength,
              suffix: '天',
              onSelected: (value) {
                setState(() => _periodLength = value);
                _autoSave();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: '提醒',
          children: [
            _ReminderRow(
              title: '经期提醒',
              subtitle: '预计经期前提醒',
              value: _periodReminderEnabled,
              preview: '提前 $_reminderDays 天提醒',
              onChanged: (value) {
                setState(() => _periodReminderEnabled = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 8),
            _ReminderRow(
              title: '排卵提醒',
              subtitle: '易孕期开始时提醒',
              value: _ovulationReminderEnabled,
              preview: '易孕期首日提醒',
              onChanged: (value) {
                setState(() => _ovulationReminderEnabled = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 8),
            _ReminderRow(
              title: '经前提醒',
              subtitle: '经前期开始前提醒',
              value: _pmsReminderEnabled,
              preview: '提前 $_reminderDays 天提醒',
              onChanged: (value) {
                setState(() => _pmsReminderEnabled = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 6),
            _SliderRow(
              label: '提醒提前天数',
              value: _reminderDays,
              min: 0,
              max: 7,
              suffix: '天',
              hint: '经期与经前提醒共用这个提前量',
              onChanged: (value) {
                setState(() => _reminderDays = value);
                _autoSave();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: '孕期',
          children: [
            if (activePregnancy != null)
              _ActivePregnancyCard(
                pregnancy: activePregnancy,
                onEnd: () => _confirmEndPregnancy(context),
              )
            else
              _PregnancyCard(
                colorScheme: colorScheme,
                onStart: () => _startPregnancyMode(context),
              ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: '数据与隐私',
          children: [
            AppSwitchField(
              title: '参与健康数据同步',
              subtitle: '随 WebDAV 备份一起同步经期记录',
              value: _dataSyncEnabled,
              onChanged: (value) {
                setState(() => _dataSyncEnabled = value);
                _autoSave();
              },
            ),
            const SizedBox(height: 8),
            AppSwitchField(
              title: '匿名使用统计',
              subtitle: '仅本地汇总，不上传任何明细',
              value: _analyticsEnabled,
              onChanged: (value) {
                setState(() => _analyticsEnabled = value);
                _autoSave();
              },
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _startPregnancyMode(BuildContext context) async {
    final today = DateTime.now().toUtc();
    var startDate = DateTime.utc(today.year, today.month, today.day);
    DateTime? dueDate;

    await showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialogScaffold(
              title: '开启孕期模式',
              maxWidth: 400,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('开启后暂停周期预测，可随时结束或删除。'),
                  const SizedBox(height: 14),
                  _PickerTile(
                    label: '开始日期',
                    value: startDate,
                    onPick: (picked) => setState(() => startDate = picked),
                  ),
                  const SizedBox(height: 10),
                  _PickerTile(
                    label: '预产期（可选）',
                    value: dueDate,
                    onPick: (picked) => setState(() => dueDate = picked),
                  ),
                ],
              ),
              actions: appDialogIconActions(
                onCancel: () => Navigator.of(ctx).pop(),
                onConfirm: () {
                  Navigator.of(ctx).pop();
                  widget.onStartPregnancyMode(
                    HealthPregnancyDraft(
                      startDate: startDate,
                      dueDate: dueDate,
                      notes: null,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmEndPregnancy(BuildContext context) async {
    await showAppResponsiveDialog<void>(
      context: context,
      expandCompactSheet: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final colorScheme = theme.colorScheme;
        return AppDialogScaffold(
          title: '结束孕期模式',
          maxWidth: 400,
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请选择结束原因：'),
              const SizedBox(height: 12),
              for (final status in const [
                HealthPregnancyRecordStatus.completed,
                HealthPregnancyRecordStatus.miscarriage,
                HealthPregnancyRecordStatus.terminated,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      widget.onEndPregnancyMode?.call(
                        HealthPregnancyEndDraft(
                          endDate: DateTime.now().toUtc(),
                          status: status,
                          notes: null,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(pregnancyEndStatusLabel(status)),
                  ),
                ),
              const Divider(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  widget.onCancelPregnancyMode?.call();
                },
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('误点，删除此记录'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
          actions: appDialogIconActions(
            onCancel: () => Navigator.of(ctx).pop(),
            onConfirm: null,
          ),
        );
      },
    );
  }

  void _autoSave() {
    widget.onSave(
      HealthPeriodSettingsDraft(
        averageCycleLength: _cycleLength,
        averagePeriodLength: _periodLength,
        periodTrackingEnabled: _periodTrackingEnabled,
        periodReminderEnabled: _periodReminderEnabled,
        ovulationReminderEnabled: _ovulationReminderEnabled,
        pmsReminderEnabled: _pmsReminderEnabled,
        reminderDays: _reminderDays,
        dataSyncEnabled: _dataSyncEnabled,
        analyticsEnabled: _analyticsEnabled,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 0.06,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.hint,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final String? hint;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ),
            Text(
              '$value $suffix',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.primary,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          label: '$value $suffix',
          onChanged: (next) => onChanged(next.round()),
        ),
        if (hint != null)
          Text(
            hint!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.suffix,
    required this.onSelected,
  });

  final String label;
  final List<int> values;
  final int selected;
  final String suffix;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text('$value$suffix'),
                selected: selected == value,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.preview,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final String preview;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      value ? preview : '已关闭',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: value
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _PregnancyCard extends StatelessWidget {
  const _PregnancyCard({required this.colorScheme, required this.onStart});

  final ColorScheme colorScheme;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
        color: colorScheme.tertiary.withValues(alpha: 0.06),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, color: colorScheme.tertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '孕期模式',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '开启后暂停周期预测，可设置开始日期与预产期',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.tonal(onPressed: onStart, child: const Text('开启')),
        ],
      ),
    );
  }
}

class _ActivePregnancyCard extends StatelessWidget {
  const _ActivePregnancyCard({required this.pregnancy, required this.onEnd});

  final HealthPregnancyStatus pregnancy;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final due = pregnancy.dueDate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.4)),
        color: colorScheme.tertiary.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded, color: colorScheme.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '孕期模式已开启',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
              FilledButton.tonal(onPressed: onEnd, child: const Text('结束')),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '开始于 ${pregnancy.startDate.month}月${pregnancy.startDate.day}日'
            '${due == null ? ' · 预产期未设置' : ' · 预产期 ${due.month}月${due.day}日'}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 2),
          );
          if (picked != null) {
            onPick(DateTime.utc(picked.year, picked.month, picked.day));
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
              Text(
                value == null
                    ? '未设置'
                    : '${value!.year}年${value!.month}月${value!.day}日',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
