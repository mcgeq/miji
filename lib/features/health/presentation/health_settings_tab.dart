import 'package:flutter/material.dart';

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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activePregnancy = widget.activePregnancy;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsPanel(
          children: [
            AppSwitchField(
              title: '启用经期记录',
              subtitle: '关闭后保留每日记录统计，隐藏经期开始、结束和周期趋势',
              value: _periodTrackingEnabled,
              onChanged: (value) {
                setState(() => _periodTrackingEnabled = value);
                _autoSave();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _NumberStepper(
          label: '平均周期长度',
          value: _cycleLength,
          suffix: '天',
          min: 18,
          max: 45,
          onChanged: (value) {
            setState(() => _cycleLength = value);
            _autoSave();
          },
        ),
        const SizedBox(height: 10),
        _NumberStepper(
          label: '平均经期长度',
          value: _periodLength,
          suffix: '天',
          min: 2,
          max: 12,
          onChanged: (value) {
            setState(() => _periodLength = value);
            _autoSave();
          },
        ),
        const SizedBox(height: 14),
        _SettingsPanel(
          children: [
            AppSwitchField(
              title: '经期提醒',
              value: _periodReminderEnabled,
              onChanged: (value) {
                setState(() => _periodReminderEnabled = value);
                _autoSave();
              },
            ),
            AppSwitchField(
              title: '排卵提醒',
              value: _ovulationReminderEnabled,
              onChanged: (value) {
                setState(() => _ovulationReminderEnabled = value);
                _autoSave();
              },
            ),
            AppSwitchField(
              title: '经前提醒',
              value: _pmsReminderEnabled,
              onChanged: (value) {
                setState(() => _pmsReminderEnabled = value);
                _autoSave();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _NumberStepper(
          label: '提醒提前天数',
          value: _reminderDays,
          suffix: '天',
          min: 0,
          max: 7,
          onChanged: (value) {
            setState(() => _reminderDays = value);
            _autoSave();
          },
        ),
        const SizedBox(height: 14),
        _SettingsPanel(
          children: [
            if (activePregnancy != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.favorite_rounded,
                  color: colorScheme.primary,
                ),
                title: const Text('孕期模式已开启'),
                subtitle: Text(
                  '开始于 ${activePregnancy.startDate.month}月${activePregnancy.startDate.day}日',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
                trailing: FilledButton.tonalIcon(
                  onPressed: () => _confirmEndPregnancy(context),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('结束'),
                ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.favorite_border_rounded),
                title: const Text('孕期模式'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _startPregnancyMode,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirmEndPregnancy(BuildContext context) async {
    await showDialog<bool>(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return AlertDialog(
          title: const Text('结束孕期模式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请选择结束原因：'),
              const SizedBox(height: 12),
              for (final status in [
                HealthPregnancyRecordStatus.completed,
                HealthPregnancyRecordStatus.miscarriage,
                HealthPregnancyRecordStatus.terminated,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
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
                  Navigator.of(context).pop(true);
                  widget.onCancelPregnancyMode?.call();
                },
                icon: Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('误点，删除此记录'),
                style: TextButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
  }

  void _startPregnancyMode() {
    final today = DateTime.now().toUtc();
    widget.onStartPregnancyMode(
      HealthPregnancyDraft(
        startDate: DateTime.utc(today.year, today.month, today.day),
        dueDate: null,
        notes: null,
      ),
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
        dataSyncEnabled: widget.settings.dataSyncEnabled,
        analyticsEnabled: widget.settings.analyticsEnabled,
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.suffix,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final String suffix;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$value $suffix',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '减少 $label',
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 38,
            child: Text(
              value.toString(),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
          IconButton(
            tooltip: '增加 $label',
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}
