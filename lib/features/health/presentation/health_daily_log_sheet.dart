import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_switch_field.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

typedef HealthDailyLogSave = void Function(HealthDailyLogDraft draft);

class HealthDailyLogSheet extends StatefulWidget {
  const HealthDailyLogSheet({
    required this.initialDate,
    required this.initialLog,
    required this.onSave,
    super.key,
  });

  final DateTime initialDate;
  final HealthDailyLog initialLog;
  final HealthDailyLogSave onSave;

  @override
  State<HealthDailyLogSheet> createState() => HealthDailyLogSheetState();
}

class HealthDailyLogSheetState extends State<HealthDailyLogSheet> {
  late HealthFlowLevel? _flowLevel;
  late HealthMood? _mood;
  late int? _sleepMinutes;
  late bool? _sexualActivity;
  late HealthContraceptionMethod? _contraceptionMethod;
  late HealthOvulationTestResult? _ovulationResult;

  late final TextEditingController _temperatureController;
  late final TextEditingController _weightController;
  late final TextEditingController _stressController;
  late final TextEditingController _waterController;
  late final TextEditingController _medicationController;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final log = widget.initialLog;
    _flowLevel = log.flowLevel;
    _mood = log.mood;
    _sleepMinutes = log.sleepMinutes;
    _sexualActivity = log.sexualActivity;
    _contraceptionMethod = log.contraceptionMethod;
    _ovulationResult = log.ovulationTest?.result;
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
    _stressController = TextEditingController(
      text: log.stressLevel?.toString() ?? '',
    );
    _waterController = TextEditingController(
      text: log.waterIntake?.toString() ?? '',
    );
    _medicationController = TextEditingController(
      text: log.medications.isEmpty ? '' : log.medications.first.name,
    );
    _notesController = TextEditingController(text: log.notes ?? '');
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _weightController.dispose();
    _stressController.dispose();
    _waterController.dispose();
    _medicationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        _Section(
          title: '经期与身体',
          children: [
            FormDropdown<HealthFlowLevel>(
              initialSelection: _flowLevel,
              label: '经量',
              width: double.infinity,
              onSelected: (value) => setState(() => _flowLevel = value),
              entries: [
                for (final value in HealthFlowLevel.values)
                  DropdownMenuEntry(value: value, label: flowLabel(value)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _temperatureController,
                    keyboardType: TextInputType.number,
                    labelText: '体温',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    labelText: '体重',
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
            FormDropdown<HealthMood>(
              initialSelection: _mood,
              label: '情绪',
              width: double.infinity,
              onSelected: (value) => setState(() => _mood = value),
              entries: [
                for (final value in HealthMood.values)
                  DropdownMenuEntry(value: value, label: moodLabel(value)),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: FormDropdown<int>(
                    initialSelection: _sleepMinutes,
                    label: '睡眠',
                    width: double.infinity,
                    onSelected: (value) =>
                        setState(() => _sleepMinutes = value),
                    entries: const [
                      DropdownMenuEntry(value: 360, label: '6 小时'),
                      DropdownMenuEntry(value: 420, label: '7 小时'),
                      DropdownMenuEntry(value: 480, label: '8 小时'),
                      DropdownMenuEntry(value: 540, label: '9 小时'),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextField(
                    controller: _stressController,
                    keyboardType: TextInputType.number,
                    labelText: '压力',
                  ),
                ),
              ],
            ),
            AppTextField(
              controller: _waterController,
              keyboardType: TextInputType.number,
              labelText: '饮水',
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Section(
          title: '用药与备注',
          children: [
            AppTextField(controller: _medicationController, labelText: '用药'),
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
            borderRadius: BorderRadius.circular(8),
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
              FormDropdown<HealthOvulationTestResult>(
                initialSelection: _ovulationResult,
                label: '排卵试纸',
                width: double.infinity,
                onSelected: (value) => setState(() => _ovulationResult = value),
                entries: [
                  for (final value in HealthOvulationTestResult.values)
                    DropdownMenuEntry(
                      value: value,
                      label: ovulationResultLabel(value),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              AppSwitchField(
                title: '性生活',
                value: _sexualActivity ?? false,
                onChanged: (value) => setState(() => _sexualActivity = value),
              ),
              const SizedBox(height: 10),
              FormDropdown<HealthContraceptionMethod>(
                initialSelection: _contraceptionMethod,
                label: '避孕方式',
                width: double.infinity,
                onSelected: (value) =>
                    setState(() => _contraceptionMethod = value),
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
    );
  }

  void save() {
    final medicationName = _medicationController.text.trim();
    widget.onSave(
      HealthDailyLogDraft(
        date: widget.initialDate,
        flowLevel: _flowLevel,
        symptoms: widget.initialLog.symptoms,
        mood: _mood,
        exerciseIntensity: widget.initialLog.exerciseIntensity,
        sexualActivity: _sexualActivity,
        contraceptionMethod: _contraceptionMethod,
        ovulationTest: _ovulationResult == null
            ? null
            : HealthOvulationTestLog(
                id: widget.initialLog.ovulationTest?.id,
                testDate: widget.initialDate,
                result: _ovulationResult!,
                lineIntensity: widget.initialLog.ovulationTest?.lineIntensity,
                notes: widget.initialLog.ovulationTest?.notes,
              ),
        medications: medicationName.isEmpty
            ? const []
            : [
                HealthMedicationDraft(
                  id: widget.initialLog.medications.isEmpty
                      ? null
                      : widget.initialLog.medications.first.id,
                  name: medicationName,
                  dosage: widget.initialLog.medications.isEmpty
                      ? null
                      : widget.initialLog.medications.first.dosage,
                  frequency: widget.initialLog.medications.isEmpty
                      ? HealthMedicationFrequency.once
                      : widget.initialLog.medications.first.frequency,
                  startDate: widget.initialDate,
                  endDate: widget.initialLog.medications.isEmpty
                      ? null
                      : widget.initialLog.medications.first.endDate,
                  notes: widget.initialLog.medications.isEmpty
                      ? null
                      : widget.initialLog.medications.first.notes,
                  periodRecordId: widget.initialLog.medications.isEmpty
                      ? null
                      : widget.initialLog.medications.first.periodRecordId,
                ),
              ],
        diet: widget.initialLog.diet,
        waterIntake: int.tryParse(_waterController.text.trim()),
        sleepMinutes: _sleepMinutes,
        weightGrams: _parseDecimalTenths(_weightController.text) == null
            ? null
            : _parseDecimalTenths(_weightController.text)! * 100,
        temperatureCelsiusTenths: _parseDecimalTenths(
          _temperatureController.text,
        ),
        stressLevel: int.tryParse(_stressController.text.trim()),
        calories: widget.initialLog.calories,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      ),
    );
  }

  int? _parseDecimalTenths(String value) {
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
        borderRadius: BorderRadius.circular(8),
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
            AppFormColumn(gap: 10, children: children),
          ],
        ),
      ),
    );
  }
}
