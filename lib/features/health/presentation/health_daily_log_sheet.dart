import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_form_widgets.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/features/health/presentation/health_theme.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

typedef HealthDailyLogSave = void Function(HealthDailyLogDraft draft);

/// 统一的每日记录表。
///
/// 取代原先「6 个各自复制整份 draft 的 dialog + 1 个空表单」的入口：
///   * 字段级 [HealthDailyLogDraft.copyWith]，从根上避免丢字段；
///   * 打开时用真实 [HealthDailyLog] 回填（修复「点开是空表单」的 P0）；
///   * 经量 / 症状 / 情绪 用一屏可选完的胶囊，睡眠支持小时+分钟。
class HealthDailyLogSheet extends StatefulWidget {
  const HealthDailyLogSheet({
    required this.initialDate,
    required this.initialLog,
    required this.onSave,
    super.key,
    this.periodTrackingEnabled = true,
    this.isPregnant = false,
  });

  final DateTime initialDate;
  final HealthDailyLog initialLog;
  final HealthDailyLogSave onSave;
  final bool periodTrackingEnabled;
  final bool isPregnant;

  @override
  State<HealthDailyLogSheet> createState() => HealthDailyLogSheetState();
}

class HealthDailyLogSheetState extends State<HealthDailyLogSheet> {
  late HealthDailyLogDraft _draft;
  late final Set<HealthSymptomType> _symptoms;
  late final Map<HealthSymptomType, HealthIntensity> _intensities;

  late final TextEditingController _temperatureController;
  late final TextEditingController _weightController;
  late final TextEditingController _waterController;
  late final TextEditingController _stressController;
  late final TextEditingController _notesController;

  int? _sleepHours;
  int? _sleepMinutesPart;

  @override
  void initState() {
    super.initState();
    final log = widget.initialLog;
    _draft = log.toDraft();
    _symptoms = {for (final symptom in log.symptoms) symptom.type};
    _intensities = {
      for (final symptom in log.symptoms) symptom.type: symptom.intensity,
    };

    _temperatureController = TextEditingController(
      text: log.temperatureCelsiusTenths == null
          ? ''
          : (log.temperatureCelsiusTenths! / 10).toStringAsFixed(1),
    );
    _weightController = TextEditingController(
      text: log.weightGrams == null
          ? ''
          : (log.weightGrams! / 1000).toStringAsFixed(1),
    );
    _waterController = TextEditingController(
      text: log.waterIntake?.toString() ?? '',
    );
    _stressController = TextEditingController(
      text: log.stressLevel?.toString() ?? '',
    );
    _notesController = TextEditingController(text: log.notes ?? '');

    final totalMinutes = log.sleepMinutes;
    if (totalMinutes != null) {
      _sleepHours = totalMinutes ~/ 60;
      _sleepMinutesPart = totalMinutes % 60;
    }
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _weightController.dispose();
    _waterController.dispose();
    _stressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = HealthPalette.of(context);
    final showPeriodFields = widget.periodTrackingEnabled && !widget.isPregnant;

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Section(
            title: '经期与身体',
            children: [
              if (showPeriodFields) ...[
                HealthFieldLabel(text: '经量', trailing: '点一下选中，再点取消'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final level in HealthFlowLevel.values)
                      HealthChoicePill(
                        label: flowLabel(level),
                        selected: _draft.flowLevel == level,
                        accent: palette.period,
                        onTap: () => setState(() {
                          _draft = _draft.copyWith(
                            flowLevel: _draft.flowLevel == level ? null : level,
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _temperatureController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      labelText: '体温（℃）',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      labelText: '体重（kg）',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: '状态与习惯',
            children: [
              HealthFieldLabel(text: '情绪'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mood in HealthMood.values)
                    HealthChoicePill(
                      label: moodLabel(mood),
                      selected: _draft.mood == mood,
                      accent: palette.follicular,
                      onTap: () => setState(() {
                        _draft = _draft.copyWith(
                          mood: _draft.mood == mood ? null : mood,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              HealthFieldLabel(text: '症状', trailing: '可多选 · 长按调整强度'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in HealthSymptomType.values)
                    HealthChoicePill(
                      label: _symptomLabel(type),
                      selected: _symptoms.contains(type),
                      accent: palette.luteal,
                      onTap: () => setState(() {
                        if (!_symptoms.remove(type)) {
                          _symptoms.add(type);
                          _intensities[type] = HealthIntensity.medium;
                        }
                      }),
                      onLongPress: _symptoms.contains(type)
                          ? () => _cycleIntensity(type)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              HealthFieldLabel(text: '睡眠'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberDropdown(
                      label: '小时',
                      value: _sleepHours,
                      values: List.generate(13, (index) => index),
                      onChanged: (value) => setState(() => _sleepHours = value),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberDropdown(
                      label: '分钟',
                      value: _sleepMinutesPart,
                      values: const [0, 10, 20, 30, 40, 50],
                      onChanged: (value) =>
                          setState(() => _sleepMinutesPart = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _waterController,
                      keyboardType: TextInputType.number,
                      labelText: '饮水（ml）',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _stressController,
                      keyboardType: TextInputType.number,
                      labelText: '压力（0-5）',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: '用药与备注',
            children: [
              AppTextField(
                controller: _notesController,
                minLines: 2,
                maxLines: 4,
                labelText: '备注',
              ),
            ],
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.54),
              ),
            ),
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('私密生殖健康'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                if (showPeriodFields) ...[
                  FormDropdown<HealthOvulationTestResult>(
                    initialSelection: _draft.ovulationTest?.result,
                    label: '排卵试纸',
                    width: double.infinity,
                    onSelected: (value) => setState(() {
                      _draft = _draft.copyWith(
                        ovulationTest: value == null
                            ? null
                            : HealthOvulationTestLog(
                                id: _draft.ovulationTest?.id,
                                testDate: widget.initialDate,
                                result: value,
                                lineIntensity:
                                    _draft.ovulationTest?.lineIntensity,
                                notes: _draft.ovulationTest?.notes,
                              ),
                      );
                    }),
                    entries: [
                      for (final value in HealthOvulationTestResult.values)
                        DropdownMenuEntry(
                          value: value,
                          label: ovulationResultLabel(value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('性生活'),
                  value: _draft.sexualActivity ?? false,
                  onChanged: (value) => setState(() {
                    _draft = _draft.copyWith(sexualActivity: value);
                  }),
                ),
                const SizedBox(height: 6),
                FormDropdown<HealthContraceptionMethod>(
                  initialSelection: _draft.contraceptionMethod,
                  label: '避孕方式',
                  width: double.infinity,
                  onSelected: (value) => setState(() {
                    _draft = _draft.copyWith(contraceptionMethod: value);
                  }),
                  entries: const [
                    DropdownMenuEntry(
                      value: HealthContraceptionMethod.none,
                      label: '无',
                    ),
                    DropdownMenuEntry(
                      value: HealthContraceptionMethod.condom,
                      label: '避孕套',
                    ),
                    DropdownMenuEntry(
                      value: HealthContraceptionMethod.pill,
                      label: '避孕药',
                    ),
                    DropdownMenuEntry(
                      value: HealthContraceptionMethod.iud,
                      label: '宫内节育器',
                    ),
                    DropdownMenuEntry(
                      value: HealthContraceptionMethod.other,
                      label: '其他',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _symptomLabel(HealthSymptomType type) {
    final label = symptomTypeLabel(type);
    if (!_symptoms.contains(type)) {
      return label;
    }
    final intensity = _intensities[type] ?? HealthIntensity.medium;
    return '$label·${intensityLabel(intensity)}';
  }

  void _cycleIntensity(HealthSymptomType type) {
    final current = _intensities[type] ?? HealthIntensity.medium;
    final next = switch (current) {
      HealthIntensity.light => HealthIntensity.medium,
      HealthIntensity.medium => HealthIntensity.heavy,
      HealthIntensity.heavy => HealthIntensity.light,
    };
    setState(() => _intensities[type] = next);
  }

  void save() {
    final sleepMinutes = _sleepHours == null && _sleepMinutesPart == null
        ? null
        : (_sleepHours ?? 0) * 60 + (_sleepMinutesPart ?? 0);
    final notes = _notesController.text.trim();
    final weight = _parseDecimal(_weightController.text);
    final temperature = _parseDecimal(_temperatureController.text);

    widget.onSave(
      _draft.copyWith(
        symptoms: [
          for (final type in _symptoms)
            HealthSymptomLog(
              id: null,
              type: type,
              intensity: _intensities[type] ?? HealthIntensity.medium,
              notes: null,
            ),
        ],
        sleepMinutes: sleepMinutes,
        waterIntake: int.tryParse(_waterController.text.trim()),
        stressLevel: int.tryParse(_stressController.text.trim()),
        weightGrams: weight == null ? null : weight * 100,
        temperatureCelsiusTenths: temperature,
        notes: notes.isEmpty ? null : notes,
      ),
    );
  }

  int? _parseDecimal(String value) {
    final parsed = double.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }
    return (parsed * 10).round();
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.44),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _NumberDropdown extends StatelessWidget {
  const _NumberDropdown({
    required this.label,
    required this.value,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final int? value;
  final List<int> values;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return FormDropdown<int>(
      initialSelection: value,
      label: label,
      width: double.infinity,
      onSelected: (selected) {
        if (selected != null) {
          onChanged(selected);
        }
      },
      entries: [
        for (final item in values)
          DropdownMenuEntry(value: item, label: '$item'),
      ],
    );
  }
}
