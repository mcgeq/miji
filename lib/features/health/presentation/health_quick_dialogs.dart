import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_dialog_shell.dart';
import 'package:miji/features/health/presentation/health_dialog_widgets.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/features/health/presentation/health_theme.dart';
import 'package:miji/shared/widgets/app_text_field.dart';

/// 每个快捷按钮对应一个「只编辑单一字段」的专注弹窗。
///
/// 只有「完整记录」才打开整张 [HealthDailyLogSheet]。所有弹窗都基于
/// [HealthDailyLog.toDraft] + [HealthDailyLogDraft.copyWith] 合并，不会丢字段。
///
/// 界面统一走 [HealthEntryDialog]：顶部圆形图标 + 标题，中部大号选项卡，
/// 底部通栏「保存」。

// ============================================================
// 经期：开始 / 结束
// ============================================================

Future<void> showHealthPeriodDialog({
  required BuildContext context,
  required bool hasOpenPeriod,
  required DateTime initialDate,
  required void Function(DateTime date, String? notes) onSubmit,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => _PeriodDialog(
      hasOpenPeriod: hasOpenPeriod,
      initialDate: initialDate,
      onSubmit: onSubmit,
    ),
  );
}

class _PeriodDialog extends StatefulWidget {
  const _PeriodDialog({
    required this.hasOpenPeriod,
    required this.initialDate,
    required this.onSubmit,
  });

  final bool hasOpenPeriod;
  final DateTime initialDate;
  final void Function(DateTime date, String? notes) onSubmit;

  @override
  State<_PeriodDialog> createState() => _PeriodDialogState();
}

class _PeriodDialogState extends State<_PeriodDialog> {
  late DateTime _date;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final date = widget.initialDate;
    _date = DateTime.utc(date.year, date.month, date.day);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = HealthPalette.of(context);
    return HealthEntryDialog(
      icon: Icons.water_drop_rounded,
      accent: palette.period,
      title: widget.hasOpenPeriod ? '结束经期' : '开始经期',
      subtitle: widget.hasOpenPeriod ? '记录这次经期的结束日期' : '记录这次经期的开始日期',
      saveLabel: widget.hasOpenPeriod ? '结束经期' : '开始经期',
      onSave: () {
        Navigator.of(context).pop();
        final notes = _notesController.text.trim();
        widget.onSubmit(_date, notes.isEmpty ? null : notes);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthDialogSection(
            title: widget.hasOpenPeriod ? '结束日期' : '开始日期',
            child: _DateField(
              date: _date,
              accent: palette.period,
              onChanged: (picked) => setState(() => _date = picked),
            ),
          ),
          const SizedBox(height: 20),
          HealthDialogSection(
            title: '备注（可选）',
            hint: '留下一点线索，之后看趋势时更有意义',
            child: AppTextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 3,
              labelText: '例如：第一天量多、痛经',
            ),
          ),
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.date,
    required this.accent,
    required this.onChanged,
  });

  final DateTime date;
  final Color accent;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: accent.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(now.year - 3),
            lastDate: DateTime(now.year + 1),
          );
          if (picked != null) {
            onChanged(DateTime.utc(picked.year, picked.month, picked.day));
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 20, color: accent),
              const SizedBox(width: 12),
              Text(
                '${date.year}年${date.month}月${date.day}日',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const Spacer(),
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

// ============================================================
// 经量
// ============================================================

class _FlowOption {
  const _FlowOption(this.level, this.drops, this.caption);

  final HealthFlowLevel level;
  final int drops;
  final String caption;
}

const _flowOptions = [
  _FlowOption(HealthFlowLevel.spotting, 1, '点滴 / 血丝'),
  _FlowOption(HealthFlowLevel.light, 2, '护垫即可'),
  _FlowOption(HealthFlowLevel.medium, 3, '正常流量'),
  _FlowOption(HealthFlowLevel.heavy, 4, '需要勤换'),
];

Future<void> showHealthFlowDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = existing.flowLevel;
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final accent = HealthPalette.of(context).period;
        return HealthEntryDialog(
          icon: Icons.invert_colors_rounded,
          accent: accent,
          title: '记录经量',
          subtitle: '选一个最接近今天的量',
          saveEnabled: selected != null,
          onClear: existing.flowLevel == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onSave(existing.toDraft().copyWith(flowLevel: null));
                },
          onSave: () {
            Navigator.of(ctx).pop();
            onSave(existing.toDraft().copyWith(flowLevel: selected));
          },
          child: HealthOptionGrid(
            children: [
              for (final option in _flowOptions)
                HealthOptionCard(
                  label: flowLabel(option.level),
                  caption: option.caption,
                  selected: selected == option.level,
                  accent: accent,
                  leading: _FlowDrops(count: option.drops, color: accent),
                  onTap: () => setState(
                    () => selected = selected == option.level
                        ? null
                        : option.level,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _FlowDrops extends StatelessWidget {
  const _FlowDrops({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 26,
      child: Column(
        children: [
          for (var i = 0; i < 4; i += 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Icon(
                Icons.water_drop_rounded,
                size: 11,
                color: i < count
                    ? color
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 情绪
// ============================================================

const _moodEmoji = {
  HealthMood.happy: '😄',
  HealthMood.calm: '😌',
  HealthMood.sad: '😢',
  HealthMood.anxious: '😰',
  HealthMood.angry: '😠',
  HealthMood.irritable: '😤',
};

Future<void> showHealthMoodDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = existing.mood;
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final accent = HealthPalette.of(context).follicular;
        return HealthEntryDialog(
          icon: Icons.mood_rounded,
          accent: accent,
          title: '记录情绪',
          subtitle: '今天整体感觉怎么样？',
          saveEnabled: selected != null,
          onClear: existing.mood == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onSave(existing.toDraft().copyWith(mood: null));
                },
          onSave: () {
            Navigator.of(ctx).pop();
            onSave(existing.toDraft().copyWith(mood: selected));
          },
          child: HealthOptionGrid(
            columns: 3,
            children: [
              for (final entry in _moodEmoji.entries)
                HealthOptionCard(
                  label: moodLabel(entry.key),
                  selected: selected == entry.key,
                  accent: accent,
                  axis: HealthOptionAxis.vertical,
                  leading: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 24),
                  ),
                  onTap: () => setState(
                    () => selected = selected == entry.key ? null : entry.key,
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

// ============================================================
// 症状
// ============================================================

Future<void> showHealthSymptomsDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  final selected = {for (final symptom in existing.symptoms) symptom.type};
  final intensities = {
    for (final symptom in existing.symptoms) symptom.type: symptom.intensity,
  };

  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final accent = HealthPalette.of(context).luteal;

        return HealthEntryDialog(
          icon: Icons.healing_rounded,
          accent: accent,
          title: '记录症状',
          subtitle: '可多选，选中的可调整强度',
          onSave: () {
            Navigator.of(ctx).pop();
            onSave(
              existing.toDraft().copyWith(
                symptoms: [
                  for (final type in selected)
                    HealthSymptomLog(
                      id: null,
                      type: type,
                      intensity: intensities[type] ?? HealthIntensity.medium,
                      notes: null,
                    ),
                ],
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selected.isNotEmpty) ...[
                HealthDialogSection(
                  title: '已选 ${selected.length} 项',
                  child: Column(
                    children: [
                      for (final type in selected)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SelectedSymptomRow(
                            type: type,
                            intensity:
                                intensities[type] ?? HealthIntensity.medium,
                            accent: accent,
                            onIntensityChanged: (value) =>
                                setState(() => intensities[type] = value),
                            onRemove: () => setState(() {
                              selected.remove(type);
                              intensities.remove(type);
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              HealthDialogSection(
                title: '常见症状',
                hint: '点一下添加，再点取消',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in HealthSymptomType.values)
                      HealthIconChip(
                        label: symptomTypeLabel(type),
                        icon: _symptomIcon(type),
                        selected: selected.contains(type),
                        accent: accent,
                        onTap: () => setState(() {
                          if (!selected.remove(type)) {
                            selected.add(type);
                            intensities[type] = HealthIntensity.medium;
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _SelectedSymptomRow extends StatelessWidget {
  const _SelectedSymptomRow({
    required this.type,
    required this.intensity,
    required this.accent,
    required this.onIntensityChanged,
    required this.onRemove,
  });

  final HealthSymptomType type;
  final HealthIntensity intensity;
  final Color accent;
  final ValueChanged<HealthIntensity> onIntensityChanged;
  final VoidCallback onRemove;

  static const _labels = {
    HealthIntensity.light: '轻',
    HealthIntensity.medium: '中',
    HealthIntensity.heavy: '重',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(_symptomIcon(type), size: 17, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              symptomTypeLabel(type),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          HealthIntensityPicker(
            value: _labels[intensity]!,
            accent: accent,
            onChanged: (value) => onIntensityChanged(
              _labels.entries.firstWhere((entry) => entry.value == value).key,
            ),
          ),
          IconButton(
            tooltip: '移除',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _symptomIcon(HealthSymptomType type) {
  return switch (type) {
    HealthSymptomType.pain => Icons.healing_rounded,
    HealthSymptomType.fatigue => Icons.battery_2_bar_rounded,
    HealthSymptomType.moodSwing => Icons.mood_bad_rounded,
    HealthSymptomType.bloating => Icons.bubble_chart_rounded,
    HealthSymptomType.headache => Icons.psychology_rounded,
    HealthSymptomType.nausea => Icons.sick_rounded,
    HealthSymptomType.insomnia => Icons.bedtime_rounded,
    HealthSymptomType.appetiteChange => Icons.restaurant_rounded,
    HealthSymptomType.skinBreakout => Icons.face_retouching_natural,
    HealthSymptomType.breastTenderness => Icons.favorite_border_rounded,
    HealthSymptomType.cramps => Icons.bolt_rounded,
    HealthSymptomType.backPain => Icons.accessibility_new_rounded,
    HealthSymptomType.other => Icons.more_horiz_rounded,
  };
}

// ============================================================
// 体温和睡眠
// ============================================================

Future<void> showHealthTemperatureSleepDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) =>
        _TemperatureSleepDialog(existing: existing, onSave: onSave),
  );
}

class _TemperatureSleepDialog extends StatefulWidget {
  const _TemperatureSleepDialog({required this.existing, required this.onSave});

  final HealthDailyLog existing;
  final ValueChanged<HealthDailyLogDraft> onSave;

  @override
  State<_TemperatureSleepDialog> createState() =>
      _TemperatureSleepDialogState();
}

class _TemperatureSleepDialogState extends State<_TemperatureSleepDialog> {
  late final TextEditingController _temperatureController;
  int? _sleepMinutes;

  static const _sleepPresets = [360, 420, 480, 540];

  @override
  void initState() {
    super.initState();
    final tenths = widget.existing.temperatureCelsiusTenths;
    _temperatureController = TextEditingController(
      text: tenths == null ? '' : (tenths / 10).toStringAsFixed(1),
    );
    _sleepMinutes = widget.existing.sleepMinutes;
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    super.dispose();
  }

  void _stepTemperature(double delta) {
    final current = double.tryParse(_temperatureController.text.trim()) ?? 36.5;
    final next = (current + delta).clamp(34.0, 42.0);
    _temperatureController.text = next.toStringAsFixed(1);
    setState(() {});
  }

  void _stepSleep(int deltaMinutes) {
    final current = _sleepMinutes ?? 0;
    final next = (current + deltaMinutes).clamp(0, 16 * 60);
    setState(() => _sleepMinutes = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = HealthPalette.of(context).follicular;

    return HealthEntryDialog(
      icon: Icons.thermostat_rounded,
      accent: accent,
      title: '体温和睡眠',
      subtitle: '用于观察基础体温与休息情况',
      onClear: () {
        Navigator.of(context).pop();
        widget.onSave(
          widget.existing.toDraft().copyWith(
            temperatureCelsiusTenths: null,
            sleepMinutes: null,
          ),
        );
      },
      onSave: () {
        Navigator.of(context).pop();
        widget.onSave(
          widget.existing.toDraft().copyWith(
            temperatureCelsiusTenths: _parseTenths(_temperatureController.text),
            sleepMinutes: _sleepMinutes,
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthDialogSection(
            title: '基础体温',
            hint: '通常在 36.0–37.0℃，用 ± 以 0.1℃ 调整',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  HealthStepButton(
                    icon: Icons.remove_rounded,
                    tooltip: '降低 0.1℃',
                    onPressed: () => _stepTemperature(-0.1),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _temperatureController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: '--',
                        suffixText: '℃',
                        suffixStyle: theme.textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  HealthStepButton(
                    icon: Icons.add_rounded,
                    tooltip: '升高 0.1℃',
                    onPressed: () => _stepTemperature(0.1),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          HealthDialogSection(
            title: '睡眠时长',
            hint: '点常用时长，或用 ± 以 30 分钟微调',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _sleepPresets)
                      HealthIconChip(
                        label: '${preset ~/ 60} 小时',
                        icon: Icons.bedtime_rounded,
                        selected: _sleepMinutes == preset,
                        accent: accent,
                        onTap: () => setState(() => _sleepMinutes = preset),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.45,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      HealthStepButton(
                        icon: Icons.remove_rounded,
                        tooltip: '减少 30 分钟',
                        onPressed: () => _stepSleep(-30),
                      ),
                      Expanded(
                        child: Text(
                          _sleepLabel(),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                      HealthStepButton(
                        icon: Icons.add_rounded,
                        tooltip: '增加 30 分钟',
                        onPressed: () => _stepSleep(30),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sleepLabel() {
    final minutes = _sleepMinutes;
    if (minutes == null) {
      return '--';
    }
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours 小时' : '$hours 小时 $rest 分';
  }
}

// ============================================================
// 排卵试纸
// ============================================================

const _ovulationCaptions = {
  HealthOvulationTestResult.negative: '只有对照线',
  HealthOvulationTestResult.positive: '接近强阳',
  HealthOvulationTestResult.peak: '强阳，即将排卵',
  HealthOvulationTestResult.invalid: '试纸失效',
};

const _lineIntensityOptions = {
  HealthTestLineIntensity.low: '弱',
  HealthTestLineIntensity.medium: '中',
  HealthTestLineIntensity.high: '强',
};

Future<void> showHealthOvulationTestDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var result = existing.ovulationTest?.result;
  var lineIntensity = existing.ovulationTest?.lineIntensity;

  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setState) {
        final accent = HealthPalette.of(context).ovulation;
        return HealthEntryDialog(
          icon: Icons.science_rounded,
          accent: accent,
          title: '排卵试纸',
          subtitle: '记录今天的测试结果',
          saveEnabled: result != null,
          onClear: existing.ovulationTest == null
              ? null
              : () {
                  Navigator.of(ctx).pop();
                  onSave(existing.toDraft().copyWith(ovulationTest: null));
                },
          onSave: () {
            Navigator.of(ctx).pop();
            onSave(
              existing.toDraft().copyWith(
                ovulationTest: result == null
                    ? null
                    : HealthOvulationTestLog(
                        id: existing.ovulationTest?.id,
                        testDate: existing.date,
                        result: result!,
                        lineIntensity: lineIntensity,
                        notes: existing.ovulationTest?.notes,
                      ),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HealthDialogSection(
                title: '测试结果',
                child: HealthOptionGrid(
                  children: [
                    for (final value in HealthOvulationTestResult.values)
                      HealthOptionCard(
                        label: ovulationResultLabel(value),
                        caption: _ovulationCaptions[value],
                        selected: result == value,
                        accent: accent,
                        onTap: () => setState(
                          () => result = result == value ? null : value,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              HealthDialogSection(
                title: '试纸深浅',
                hint: '可选，用来观察颜色变化趋势',
                child: HealthOptionGrid(
                  columns: 3,
                  children: [
                    for (final entry in _lineIntensityOptions.entries)
                      HealthOptionCard(
                        label: entry.value,
                        selected: lineIntensity == entry.key,
                        accent: accent,
                        axis: HealthOptionAxis.vertical,
                        leading: _LineBars(
                          count:
                              _lineIntensityOptions.keys.toList().indexOf(
                                entry.key,
                              ) +
                              1,
                          color: accent,
                        ),
                        onTap: () => setState(
                          () => lineIntensity = lineIntensity == entry.key
                              ? null
                              : entry.key,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _LineBars extends StatelessWidget {
  const _LineBars({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i += 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.5),
            child: Container(
              width: 6,
              height: 20,
              decoration: BoxDecoration(
                color: i < count
                    ? color
                    : theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.25,
                      ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================
// 用药
// ============================================================

const _medicationSuggestions = ['布洛芬', '对乙酰氨基酚', '维生素B6', '益母草颗粒'];

Future<void> showHealthMedicationDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  return showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) => _MedicationDialog(existing: existing, onSave: onSave),
  );
}

class _MedicationDialog extends StatefulWidget {
  const _MedicationDialog({required this.existing, required this.onSave});

  final HealthDailyLog existing;
  final ValueChanged<HealthDailyLogDraft> onSave;

  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  late final TextEditingController _nameController;
  late final List<HealthMedicationDraft> _existing;
  var _frequency = HealthMedicationFrequency.once;
  var _existingChanged = false;

  @override
  void initState() {
    super.initState();
    _existing = [...widget.existing.toDraft().medications];
    if (_existing.isNotEmpty) {
      _frequency = _existing.first.frequency;
    }
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty || _existingChanged;

  void _save() {
    Navigator.of(context).pop();
    final name = _nameController.text.trim();
    final medications = [
      ..._existing,
      if (name.isNotEmpty)
        HealthMedicationDraft(
          id: null,
          name: name,
          dosage: null,
          frequency: _frequency,
          startDate: widget.existing.date,
          endDate: null,
          notes: null,
          periodRecordId: null,
        ),
    ];
    widget.onSave(widget.existing.toDraft().copyWith(medications: medications));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = HealthPalette.of(context).medication;

    return HealthEntryDialog(
      icon: Icons.medication_rounded,
      accent: accent,
      title: '记录用药',
      subtitle: '添加今天的药物；已有记录可删除',
      saveLabel: '保存',
      saveEnabled: _canSave,
      onSave: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HealthDialogSection(
            title: '药名',
            child: AppTextField(
              controller: _nameController,
              autofocus: true,
              labelText: '例如：布洛芬',
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final suggestion in _medicationSuggestions)
                HealthIconChip(
                  label: suggestion,
                  selected: _nameController.text.trim() == suggestion,
                  accent: accent,
                  onTap: () => setState(() {
                    _nameController.text = suggestion;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 22),
          HealthDialogSection(
            title: '频率',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in HealthMedicationFrequency.values)
                  HealthIconChip(
                    label: _frequencyLabel(value),
                    selected: _frequency == value,
                    accent: accent,
                    onTap: () => setState(() => _frequency = value),
                  ),
              ],
            ),
          ),
          if (_existing.isNotEmpty) ...[
            const SizedBox(height: 22),
            HealthDialogSection(
              title: '已有用药',
              hint: '删除后会随本次保存一起生效',
              child: Column(
                children: [
                  for (final medication in _existing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withValues(
                            alpha: 0.45,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 17,
                              color: accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                medication.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: '删除',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() {
                                _existing.remove(medication);
                                _existingChanged = true;
                              }),
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _frequencyLabel(HealthMedicationFrequency value) {
  return switch (value) {
    HealthMedicationFrequency.once => '一次',
    HealthMedicationFrequency.daily => '每日',
    HealthMedicationFrequency.twiceDaily => '每日两次',
    HealthMedicationFrequency.threeTimesDaily => '每日三次',
    HealthMedicationFrequency.weekly => '每周',
    HealthMedicationFrequency.monthly => '每月',
    HealthMedicationFrequency.asNeeded => '按需',
  };
}

int? _parseTenths(String value) {
  final parsed = double.tryParse(value.trim());
  if (parsed == null) {
    return null;
  }
  return (parsed * 10).round();
}
