import 'package:flutter/material.dart';

import 'package:miji/core/presentation/components/app_responsive_dialog.dart';
import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_presentation_helpers.dart';
import 'package:miji/shared/widgets/app_form_layout.dart';
import 'package:miji/shared/widgets/app_text_field.dart';
import 'package:miji/shared/widgets/form_dropdown.dart';

void showFlowDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = existing.flowLevel;
  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '经量',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FormDropdown<HealthFlowLevel>(
                initialSelection: selected,
                label: '选择经量',
                width: double.infinity,
                onSelected: (value) => setState(() => selected = value),
                entries: [
                  for (final value in HealthFlowLevel.values)
                    DropdownMenuEntry(value: value, label: flowLabel(value)),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: selected == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      onSave(
                        HealthDailyLogDraft(
                          date: existing.date,
                          flowLevel: selected,
                          symptoms: existing.symptoms,
                          mood: existing.mood,
                          exerciseIntensity: existing.exerciseIntensity,
                          sexualActivity: existing.sexualActivity,
                          contraceptionMethod: existing.contraceptionMethod,
                          ovulationTest: existing.ovulationTest,
                          medications: existing.medications
                              .map(
                                (m) => HealthMedicationDraft(
                                  id: m.id,
                                  name: m.name,
                                  dosage: m.dosage,
                                  frequency: m.frequency,
                                  startDate: m.startDate,
                                  endDate: m.endDate,
                                  notes: m.notes,
                                  periodRecordId: m.periodRecordId,
                                ),
                              )
                              .toList(),
                          diet: existing.diet,
                          waterIntake: existing.waterIntake,
                          sleepMinutes: existing.sleepMinutes,
                          weightGrams: existing.weightGrams,
                          temperatureCelsiusTenths:
                              existing.temperatureCelsiusTenths,
                          stressLevel: existing.stressLevel,
                          calories: existing.calories,
                          notes: existing.notes,
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

void showMoodDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = existing.mood;
  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '情绪',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FormDropdown<HealthMood>(
                initialSelection: selected,
                label: '选择情绪',
                width: double.infinity,
                onSelected: (value) => setState(() => selected = value),
                entries: [
                  for (final value in HealthMood.values)
                    DropdownMenuEntry(value: value, label: moodLabel(value)),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: selected == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      onSave(
                        HealthDailyLogDraft(
                          date: existing.date,
                          flowLevel: existing.flowLevel,
                          symptoms: existing.symptoms,
                          mood: selected,
                          exerciseIntensity: existing.exerciseIntensity,
                          sexualActivity: existing.sexualActivity,
                          contraceptionMethod: existing.contraceptionMethod,
                          ovulationTest: existing.ovulationTest,
                          medications: existing.medications
                              .map(
                                (m) => HealthMedicationDraft(
                                  id: m.id,
                                  name: m.name,
                                  dosage: m.dosage,
                                  frequency: m.frequency,
                                  startDate: m.startDate,
                                  endDate: m.endDate,
                                  notes: m.notes,
                                  periodRecordId: m.periodRecordId,
                                ),
                              )
                              .toList(),
                          diet: existing.diet,
                          waterIntake: existing.waterIntake,
                          sleepMinutes: existing.sleepMinutes,
                          weightGrams: existing.weightGrams,
                          temperatureCelsiusTenths:
                              existing.temperatureCelsiusTenths,
                          stressLevel: existing.stressLevel,
                          calories: existing.calories,
                          notes: existing.notes,
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

void showSymptomsDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = Set<HealthSymptomType>.from(
    existing.symptoms.map((s) => s.type),
  );
  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '症状',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final value in HealthSymptomType.values)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(symptomTypeLabel(value)),
                      value: selected.contains(value),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            selected.add(value);
                          } else {
                            selected.remove(value);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: () {
                Navigator.of(ctx).pop();
                onSave(
                  HealthDailyLogDraft(
                    date: existing.date,
                    flowLevel: existing.flowLevel,
                    symptoms: selected
                        .map(
                          (type) => HealthSymptomLog(
                            id: null,
                            type: type,
                            intensity: HealthIntensity.medium,
                            notes: null,
                          ),
                        )
                        .toList(),
                    mood: existing.mood,
                    exerciseIntensity: existing.exerciseIntensity,
                    sexualActivity: existing.sexualActivity,
                    contraceptionMethod: existing.contraceptionMethod,
                    ovulationTest: existing.ovulationTest,
                    medications: existing.medications
                        .map(
                          (m) => HealthMedicationDraft(
                            id: m.id,
                            name: m.name,
                            dosage: m.dosage,
                            frequency: m.frequency,
                            startDate: m.startDate,
                            endDate: m.endDate,
                            notes: m.notes,
                            periodRecordId: m.periodRecordId,
                          ),
                        )
                        .toList(),
                    diet: existing.diet,
                    waterIntake: existing.waterIntake,
                    sleepMinutes: existing.sleepMinutes,
                    weightGrams: existing.weightGrams,
                    temperatureCelsiusTenths: existing.temperatureCelsiusTenths,
                    stressLevel: existing.stressLevel,
                    calories: existing.calories,
                    notes: existing.notes,
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

void showTemperatureSleepDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var temperatureTenths = existing.temperatureCelsiusTenths;
  var sleepMinutes = existing.sleepMinutes;
  final temperatureController = TextEditingController(
    text: temperatureTenths == null
        ? ''
        : (temperatureTenths / 10).toStringAsFixed(1),
  );

  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '体温和睡眠',
            maxWidth: 400,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AppFormColumn(
                children: [
                  AppTextField(
                    controller: temperatureController,
                    keyboardType: TextInputType.number,
                    labelText: '体温',
                    onChanged: (value) {
                      final parsed = double.tryParse(value.trim());
                      temperatureTenths = parsed == null
                          ? null
                          : (parsed * 10).round();
                    },
                  ),
                  FormDropdown<int>(
                    initialSelection: sleepMinutes,
                    label: '睡眠',
                    width: double.infinity,
                    onSelected: (value) => setState(() => sleepMinutes = value),
                    entries: const [
                      DropdownMenuEntry(value: 360, label: '6 小时'),
                      DropdownMenuEntry(value: 420, label: '7 小时'),
                      DropdownMenuEntry(value: 480, label: '8 小时'),
                      DropdownMenuEntry(value: 540, label: '9 小时'),
                    ],
                  ),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () {
                temperatureController.dispose();
                Navigator.of(ctx).pop();
              },
              onConfirm: () {
                temperatureController.dispose();
                Navigator.of(ctx).pop();
                onSave(
                  HealthDailyLogDraft(
                    date: existing.date,
                    flowLevel: existing.flowLevel,
                    symptoms: existing.symptoms,
                    mood: existing.mood,
                    exerciseIntensity: existing.exerciseIntensity,
                    sexualActivity: existing.sexualActivity,
                    contraceptionMethod: existing.contraceptionMethod,
                    ovulationTest: existing.ovulationTest,
                    medications: existing.medications
                        .map(
                          (m) => HealthMedicationDraft(
                            id: m.id,
                            name: m.name,
                            dosage: m.dosage,
                            frequency: m.frequency,
                            startDate: m.startDate,
                            endDate: m.endDate,
                            notes: m.notes,
                            periodRecordId: m.periodRecordId,
                          ),
                        )
                        .toList(),
                    diet: existing.diet,
                    waterIntake: existing.waterIntake,
                    sleepMinutes: sleepMinutes,
                    weightGrams: existing.weightGrams,
                    temperatureCelsiusTenths: temperatureTenths,
                    stressLevel: existing.stressLevel,
                    calories: existing.calories,
                    notes: existing.notes,
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

void showOvulationTestDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  var selected = existing.ovulationTest?.result;
  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '排卵试纸',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FormDropdown<HealthOvulationTestResult>(
                initialSelection: selected,
                label: '选择结果',
                width: double.infinity,
                onSelected: (value) => setState(() => selected = value),
                entries: [
                  for (final value in HealthOvulationTestResult.values)
                    DropdownMenuEntry(
                      value: value,
                      label: ovulationResultLabel(value),
                    ),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () => Navigator.of(ctx).pop(),
              onConfirm: selected == null
                  ? null
                  : () {
                      Navigator.of(ctx).pop();
                      onSave(
                        HealthDailyLogDraft(
                          date: existing.date,
                          flowLevel: existing.flowLevel,
                          symptoms: existing.symptoms,
                          mood: existing.mood,
                          exerciseIntensity: existing.exerciseIntensity,
                          sexualActivity: existing.sexualActivity,
                          contraceptionMethod: existing.contraceptionMethod,
                          ovulationTest: HealthOvulationTestLog(
                            id: existing.ovulationTest?.id,
                            testDate: existing.date,
                            result: selected!,
                            lineIntensity:
                                existing.ovulationTest?.lineIntensity,
                            notes: existing.ovulationTest?.notes,
                          ),
                          medications: existing.medications
                              .map(
                                (m) => HealthMedicationDraft(
                                  id: m.id,
                                  name: m.name,
                                  dosage: m.dosage,
                                  frequency: m.frequency,
                                  startDate: m.startDate,
                                  endDate: m.endDate,
                                  notes: m.notes,
                                  periodRecordId: m.periodRecordId,
                                ),
                              )
                              .toList(),
                          diet: existing.diet,
                          waterIntake: existing.waterIntake,
                          sleepMinutes: existing.sleepMinutes,
                          weightGrams: existing.weightGrams,
                          temperatureCelsiusTenths:
                              existing.temperatureCelsiusTenths,
                          stressLevel: existing.stressLevel,
                          calories: existing.calories,
                          notes: existing.notes,
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

void showMedicationDialog({
  required BuildContext context,
  required HealthDailyLog existing,
  required ValueChanged<HealthDailyLogDraft> onSave,
}) {
  final nameController = TextEditingController(
    text: existing.medications.isEmpty ? '' : existing.medications.first.name,
  );
  var frequency = existing.medications.isEmpty
      ? HealthMedicationFrequency.once
      : existing.medications.first.frequency;

  showAppResponsiveDialog<void>(
    context: context,
    expandCompactSheet: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AppDialogScaffold(
            title: '用药',
            maxWidth: 380,
            titleTextAlign: TextAlign.center,
            actionsAlignment: WrapAlignment.center,
            body: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AppFormColumn(
                children: [
                  AppTextField(
                    controller: nameController,
                    labelText: '药名',
                    autofocus: true,
                  ),
                  FormDropdown<HealthMedicationFrequency>(
                    initialSelection: frequency,
                    label: '频率',
                    width: double.infinity,
                    onSelected: (value) =>
                        setState(() => frequency = value ?? frequency),
                    entries: const [
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.once,
                        label: '一次',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.daily,
                        label: '每日',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.twiceDaily,
                        label: '每日两次',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.threeTimesDaily,
                        label: '每日三次',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.weekly,
                        label: '每周',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.monthly,
                        label: '每月',
                      ),
                      DropdownMenuEntry(
                        value: HealthMedicationFrequency.asNeeded,
                        label: '按需',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: appDialogIconActions(
              onCancel: () {
                nameController.dispose();
                Navigator.of(ctx).pop();
              },
              onConfirm: nameController.text.trim().isEmpty
                  ? null
                  : () {
                      final name = nameController.text.trim();
                      nameController.dispose();
                      Navigator.of(ctx).pop();
                      onSave(
                        HealthDailyLogDraft(
                          date: existing.date,
                          flowLevel: existing.flowLevel,
                          symptoms: existing.symptoms,
                          mood: existing.mood,
                          exerciseIntensity: existing.exerciseIntensity,
                          sexualActivity: existing.sexualActivity,
                          contraceptionMethod: existing.contraceptionMethod,
                          ovulationTest: existing.ovulationTest,
                          medications:
                              existing.medications
                                  .map(
                                    (m) => HealthMedicationDraft(
                                      id: m.id,
                                      name: m.name,
                                      dosage: m.dosage,
                                      frequency: m.frequency,
                                      startDate: m.startDate,
                                      endDate: m.endDate,
                                      notes: m.notes,
                                      periodRecordId: m.periodRecordId,
                                    ),
                                  )
                                  .toList()
                                ..add(
                                  HealthMedicationDraft(
                                    id: null,
                                    name: name,
                                    dosage: null,
                                    frequency: frequency,
                                    startDate: existing.date,
                                    endDate: null,
                                    notes: null,
                                    periodRecordId: null,
                                  ),
                                ),
                          diet: existing.diet,
                          waterIntake: existing.waterIntake,
                          sleepMinutes: existing.sleepMinutes,
                          weightGrams: existing.weightGrams,
                          temperatureCelsiusTenths:
                              existing.temperatureCelsiusTenths,
                          stressLevel: existing.stressLevel,
                          calories: existing.calories,
                          notes: existing.notes,
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
