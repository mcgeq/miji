import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/health/domain/health_models.dart';

void main() {
  HealthDailyLog fullLog() {
    return HealthDailyLog(
      id: 'daily_1',
      date: DateTime.utc(2026, 7, 18),
      periodRecordId: 'period_1',
      flowLevel: HealthFlowLevel.medium,
      symptoms: const [
        HealthSymptomLog(
          id: 's1',
          type: HealthSymptomType.cramps,
          intensity: HealthIntensity.medium,
          notes: '午后明显',
        ),
      ],
      mood: HealthMood.calm,
      exerciseIntensity: HealthExerciseIntensity.light,
      sexualActivity: true,
      contraceptionMethod: HealthContraceptionMethod.condom,
      ovulationTest: HealthOvulationTestLog(
        id: 'o1',
        testDate: DateTime.utc(2026, 7, 18),
        result: HealthOvulationTestResult.negative,
        lineIntensity: HealthTestLineIntensity.low,
        notes: null,
      ),
      medications: [
        HealthMedicationLog(
          id: 'm1',
          name: '布洛芬',
          dosage: '200mg',
          frequency: HealthMedicationFrequency.once,
          startDate: DateTime.utc(2026, 7, 18),
          endDate: null,
          notes: null,
          periodRecordId: null,
        ),
      ],
      diet: '清淡',
      waterIntake: 1600,
      sleepMinutes: 430,
      weightGrams: 56000,
      temperatureCelsiusTenths: 365,
      stressLevel: 3,
      calories: 1800,
      notes: '备注',
    );
  }

  test('toDraft preserves every field of a daily log', () {
    final log = fullLog();
    final draft = log.toDraft();

    expect(draft.date, log.date);
    expect(draft.flowLevel, log.flowLevel);
    expect(draft.symptoms.length, 1);
    expect(draft.symptoms.first.type, HealthSymptomType.cramps);
    expect(draft.mood, log.mood);
    expect(draft.exerciseIntensity, log.exerciseIntensity);
    expect(draft.sexualActivity, log.sexualActivity);
    expect(draft.contraceptionMethod, log.contraceptionMethod);
    expect(draft.ovulationTest?.result, HealthOvulationTestResult.negative);
    expect(draft.medications.single.name, '布洛芬');
    expect(draft.diet, log.diet);
    expect(draft.waterIntake, log.waterIntake);
    expect(draft.sleepMinutes, log.sleepMinutes);
    expect(draft.weightGrams, log.weightGrams);
    expect(draft.temperatureCelsiusTenths, log.temperatureCelsiusTenths);
    expect(draft.stressLevel, log.stressLevel);
    expect(draft.calories, log.calories);
    expect(draft.notes, log.notes);
  });

  test('copyWith changes only the provided field', () {
    final draft = fullLog().toDraft();
    final updated = draft.copyWith(mood: HealthMood.happy);

    expect(updated.mood, HealthMood.happy);
    // 其余字段原样保留——这正是旧 dialog 会丢字段的地方。
    expect(updated.flowLevel, draft.flowLevel);
    expect(updated.symptoms.length, draft.symptoms.length);
    expect(updated.medications.single.name, draft.medications.single.name);
    expect(updated.notes, draft.notes);
    expect(updated.sleepMinutes, draft.sleepMinutes);
    expect(updated.temperatureCelsiusTenths, draft.temperatureCelsiusTenths);
  });

  test('copyWith can explicitly clear a nullable field', () {
    final draft = fullLog().toDraft();
    final cleared = draft.copyWith(flowLevel: null, mood: null, notes: null);

    expect(cleared.flowLevel, isNull);
    expect(cleared.mood, isNull);
    expect(cleared.notes, isNull);
    // 未传的字段仍然保留。
    expect(cleared.waterIntake, draft.waterIntake);
    expect(cleared.symptoms.length, draft.symptoms.length);
  });
}
