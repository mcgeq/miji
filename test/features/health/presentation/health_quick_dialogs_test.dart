import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/presentation/health_quick_dialogs.dart';

void main() {
  HealthDailyLog existingLog() {
    return HealthDailyLog(
      id: 'daily_1',
      date: DateTime.utc(2026, 7, 18),
      periodRecordId: null,
      flowLevel: null,
      symptoms: const [],
      mood: HealthMood.calm,
      exerciseIntensity: HealthExerciseIntensity.light,
      sexualActivity: null,
      contraceptionMethod: null,
      ovulationTest: null,
      medications: [
        HealthMedicationLog(
          id: 'm1',
          name: '布洛芬',
          dosage: null,
          frequency: HealthMedicationFrequency.once,
          startDate: DateTime.utc(2026, 7, 18),
          endDate: null,
          notes: null,
          periodRecordId: null,
        ),
      ],
      diet: null,
      waterIntake: 1600,
      sleepMinutes: 430,
      weightGrams: null,
      temperatureCelsiusTenths: null,
      stressLevel: null,
      calories: null,
      notes: '原备注',
    );
  }

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext context) show,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('flow dialog shows only flow options', (tester) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthFlowDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    expect(find.text('记录经量'), findsOneWidget);
    expect(find.text('中量'), findsOneWidget);
    // 不夹带其它字段。
    expect(find.text('记录情绪'), findsNothing);
    expect(find.text('记录症状'), findsNothing);
    expect(find.text('体温和睡眠'), findsNothing);

    await tester.tap(find.text('中量'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.flowLevel, HealthFlowLevel.medium);
    // 其余字段原样保留。
    expect(saved?.mood, HealthMood.calm);
    expect(saved?.sleepMinutes, 430);
    expect(saved?.waterIntake, 1600);
    expect(saved?.medications.single.name, '布洛芬');
    expect(saved?.notes, '原备注');
  });

  testWidgets('mood dialog shows only mood options', (tester) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthMoodDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    expect(find.text('记录情绪'), findsOneWidget);
    expect(find.text('开心'), findsOneWidget);
    expect(find.text('记录经量'), findsNothing);
    expect(find.text('记录症状'), findsNothing);

    await tester.tap(find.text('开心'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.mood, HealthMood.happy);
    expect(saved?.sleepMinutes, 430);
    expect(saved?.medications.single.name, '布洛芬');
  });

  testWidgets('symptoms dialog shows only symptom options', (tester) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthSymptomsDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    expect(find.text('记录症状'), findsOneWidget);
    expect(find.text('疼痛'), findsOneWidget);
    expect(find.text('记录经量'), findsNothing);
    expect(find.text('记录情绪'), findsNothing);

    await tester.tap(find.text('疼痛'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.symptoms.single.type, HealthSymptomType.pain);
    expect(saved?.mood, HealthMood.calm);
  });

  testWidgets('temperature dialog writes temperature and keeps the rest', (
    tester,
  ) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthTemperatureSleepDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    expect(find.text('体温和睡眠'), findsOneWidget);
    expect(find.text('基础体温'), findsOneWidget);
    expect(find.text('记录经量'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '36.5');
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.temperatureCelsiusTenths, 365);
    expect(saved?.sleepMinutes, 430);
    expect(saved?.mood, HealthMood.calm);
  });

  testWidgets('temperature stepper adjusts by 0.1', (tester) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthTemperatureSleepDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    await tester.enterText(find.byType(TextField).first, '36.5');
    await tester.tap(find.byTooltip('升高 0.1℃'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.temperatureCelsiusTenths, 366);
  });

  testWidgets('medication dialog appends instead of replacing', (tester) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthMedicationDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    expect(find.text('记录用药'), findsOneWidget);
    expect(find.text('记录经量'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '维生素');
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.medications.length, 2);
    expect(saved?.medications.first.name, '布洛芬');
    expect(saved?.medications.last.name, '维生素');
    expect(saved?.sleepMinutes, 430);
  });

  testWidgets('medication dialog can delete an existing medication', (
    tester,
  ) async {
    HealthDailyLogDraft? saved;
    await open(
      tester,
      (context) => showHealthMedicationDialog(
        context: context,
        existing: existingLog(),
        onSave: (draft) => saved = draft,
      ),
    );

    await tester.tap(find.byTooltip('删除'));
    await tester.pump();
    await tester.tap(find.byTooltip('保存'));
    await tester.pumpAndSettle();

    expect(saved?.medications, isEmpty);
  });

  testWidgets('period dialog saves the chosen date and notes', (tester) async {
    DateTime? savedDate;
    String? savedNotes;
    await open(
      tester,
      (context) => showHealthPeriodDialog(
        context: context,
        hasOpenPeriod: false,
        initialDate: DateTime.utc(2026, 7, 18),
        onSubmit: (date, notes) {
          savedDate = date;
          savedNotes = notes;
        },
      ),
    );

    expect(find.text('开始经期'), findsOneWidget);
    expect(find.text('开始日期'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '痛经');
    await tester.tap(find.byTooltip('开始经期'));
    await tester.pumpAndSettle();

    expect(savedDate, DateTime.utc(2026, 7, 18));
    expect(savedNotes, '痛经');
  });
}
