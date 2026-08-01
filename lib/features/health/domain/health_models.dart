// ignore_for_file: prefer_initializing_formals

enum HealthTodayStatusKind { noPeriodHistory, cycleDay, periodDay, pregnancy }

enum HealthPredictionBasis { settings, history, pregnancy }

enum HealthFlowLevel { spotting, light, medium, heavy }

enum HealthSymptomType {
  pain,
  fatigue,
  moodSwing,
  bloating,
  headache,
  nausea,
  insomnia,
  appetiteChange,
  skinBreakout,
  breastTenderness,
  cramps,
  backPain,
  other,
}

enum HealthIntensity { light, medium, heavy }

enum HealthMood { happy, sad, angry, anxious, calm, irritable }

enum HealthExerciseIntensity { none, light, medium, heavy }

enum HealthTrendPhase { all, period, pms, fertileWindow, nonPeriod }

enum HealthContraceptionMethod { none, condom, pill, iud, other }

enum HealthOvulationTestResult { negative, positive, peak, invalid }

enum HealthTestLineIntensity { low, medium, high }

enum HealthPregnancyRecordStatus { active, completed, miscarriage, terminated }

enum HealthMedicationFrequency {
  once,
  daily,
  twiceDaily,
  threeTimesDaily,
  weekly,
  monthly,
  asNeeded,
}

enum HealthCalendarMarkerKind {
  actualPeriod,
  predictedPeriod,
  pms,
  fertileWindow,
  ovulationTest,
  medication,
  dailyLog,
}

class HealthPeriodSettingsModel {
  const HealthPeriodSettingsModel({
    required this.averageCycleLength,
    required this.averagePeriodLength,
    required this.periodTrackingEnabled,
    required this.periodReminderEnabled,
    required this.ovulationReminderEnabled,
    required this.pmsReminderEnabled,
    required this.reminderDays,
    required this.dataSyncEnabled,
    required this.analyticsEnabled,
  });

  final int averageCycleLength;
  final int averagePeriodLength;
  final bool periodTrackingEnabled;
  final bool periodReminderEnabled;
  final bool ovulationReminderEnabled;
  final bool pmsReminderEnabled;
  final int reminderDays;
  final bool dataSyncEnabled;
  final bool analyticsEnabled;
}

class HealthPeriodSettingsDraft extends HealthPeriodSettingsModel {
  const HealthPeriodSettingsDraft({
    required super.averageCycleLength,
    required super.averagePeriodLength,
    required super.periodTrackingEnabled,
    required super.periodReminderEnabled,
    required super.ovulationReminderEnabled,
    required super.pmsReminderEnabled,
    required super.reminderDays,
    required super.dataSyncEnabled,
    required super.analyticsEnabled,
  });
}

class HealthPeriodRecordModel {
  const HealthPeriodRecordModel({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.notes,
  });

  final String id;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;

  bool containsDate(DateTime date) {
    final day = HealthDate.dateOnly(date);
    final start = HealthDate.dateOnly(startDate);
    final end = endDate == null ? null : HealthDate.dateOnly(endDate!);
    return !day.isBefore(start) && (end == null || !day.isAfter(end));
  }
}

class HealthDate {
  const HealthDate._();

  static DateTime dateOnly(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  static int dayKey(DateTime date) {
    return dateOnly(date).millisecondsSinceEpoch;
  }

  static DateTime fromDayKey(int dayKey) {
    final date = DateTime.fromMillisecondsSinceEpoch(dayKey, isUtc: true);
    return dateOnly(date);
  }
}

class HealthPregnancyStatus {
  const HealthPregnancyStatus({
    required this.id,
    required this.startDate,
    required this.dueDate,
    required this.endDate,
    required this.status,
    required this.notes,
  });

  final String id;
  final DateTime startDate;
  final DateTime? dueDate;
  final DateTime? endDate;
  final HealthPregnancyRecordStatus status;
  final String? notes;
}

class HealthPregnancyDraft {
  const HealthPregnancyDraft({
    required this.startDate,
    required this.dueDate,
    required this.notes,
  });

  final DateTime startDate;
  final DateTime? dueDate;
  final String? notes;
}

class HealthPregnancyEndDraft {
  const HealthPregnancyEndDraft({
    required this.endDate,
    required this.status,
    required this.notes,
  });

  final DateTime endDate;
  final HealthPregnancyRecordStatus status;
  final String? notes;
}

class HealthCyclePrediction {
  const HealthCyclePrediction({
    required this.statusKind,
    required this.basis,
    required this.mainStatus,
    required List<String> indicators,
    required this.currentCycleDay,
    required this.currentPeriodDay,
    required this.pregnancyWeek,
    required this.nextPeriodStart,
    required this.nextPeriodEnd,
    required this.fertileWindowStart,
    required this.fertileWindowEnd,
    required this.pmsStart,
    required this.pmsEnd,
  }) : _indicators = indicators;

  const HealthCyclePrediction.noHistory({required String mainStatus})
    : this(
        statusKind: HealthTodayStatusKind.noPeriodHistory,
        basis: HealthPredictionBasis.settings,
        mainStatus: mainStatus,
        indicators: const [],
        currentCycleDay: null,
        currentPeriodDay: null,
        pregnancyWeek: null,
        nextPeriodStart: null,
        nextPeriodEnd: null,
        fertileWindowStart: null,
        fertileWindowEnd: null,
        pmsStart: null,
        pmsEnd: null,
      );

  const HealthCyclePrediction.cycleDay({
    required HealthPredictionBasis basis,
    required String mainStatus,
    required int currentCycleDay,
    required DateTime nextPeriodStart,
    required DateTime nextPeriodEnd,
    required DateTime fertileWindowStart,
    required DateTime fertileWindowEnd,
    required DateTime pmsStart,
    required DateTime pmsEnd,
    List<String> indicators = const [],
  }) : this(
         statusKind: HealthTodayStatusKind.cycleDay,
         basis: basis,
         mainStatus: mainStatus,
         indicators: indicators,
         currentCycleDay: currentCycleDay,
         currentPeriodDay: null,
         pregnancyWeek: null,
         nextPeriodStart: nextPeriodStart,
         nextPeriodEnd: nextPeriodEnd,
         fertileWindowStart: fertileWindowStart,
         fertileWindowEnd: fertileWindowEnd,
         pmsStart: pmsStart,
         pmsEnd: pmsEnd,
       );

  const HealthCyclePrediction.periodDay({
    required String mainStatus,
    required int currentPeriodDay,
    required HealthPredictionBasis basis,
    List<String> indicators = const [],
  }) : this(
         statusKind: HealthTodayStatusKind.periodDay,
         basis: basis,
         mainStatus: mainStatus,
         indicators: indicators,
         currentCycleDay: null,
         currentPeriodDay: currentPeriodDay,
         pregnancyWeek: null,
         nextPeriodStart: null,
         nextPeriodEnd: null,
         fertileWindowStart: null,
         fertileWindowEnd: null,
         pmsStart: null,
         pmsEnd: null,
       );

  const HealthCyclePrediction.pregnancy({
    required String mainStatus,
    required int pregnancyWeek,
    List<String> indicators = const [],
  }) : this(
         statusKind: HealthTodayStatusKind.pregnancy,
         basis: HealthPredictionBasis.pregnancy,
         mainStatus: mainStatus,
         indicators: indicators,
         currentCycleDay: null,
         currentPeriodDay: null,
         pregnancyWeek: pregnancyWeek,
         nextPeriodStart: null,
         nextPeriodEnd: null,
         fertileWindowStart: null,
         fertileWindowEnd: null,
         pmsStart: null,
         pmsEnd: null,
       );

  final HealthTodayStatusKind statusKind;
  final HealthPredictionBasis basis;
  final String mainStatus;
  final List<String> _indicators;

  List<String> get indicators {
    return List.unmodifiable(_indicators);
  }

  final int? currentCycleDay;
  final int? currentPeriodDay;
  final int? pregnancyWeek;
  final DateTime? nextPeriodStart;
  final DateTime? nextPeriodEnd;
  final DateTime? fertileWindowStart;
  final DateTime? fertileWindowEnd;
  final DateTime? pmsStart;
  final DateTime? pmsEnd;
}

class HealthSymptomLog {
  const HealthSymptomLog({
    required this.id,
    required this.type,
    required this.intensity,
    required this.notes,
  });

  final String? id;
  final HealthSymptomType type;
  final HealthIntensity intensity;
  final String? notes;
}

class HealthOvulationTestLog {
  const HealthOvulationTestLog({
    required this.id,
    required this.testDate,
    required this.result,
    required this.lineIntensity,
    required this.notes,
  });

  final String? id;
  final DateTime testDate;
  final HealthOvulationTestResult result;
  final HealthTestLineIntensity? lineIntensity;
  final String? notes;
}

class HealthMedicationLog {
  const HealthMedicationLog({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.periodRecordId,
  });

  final String id;
  final String name;
  final String? dosage;
  final HealthMedicationFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final String? periodRecordId;
}

class HealthMedicationDraft {
  const HealthMedicationDraft({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    required this.endDate,
    required this.notes,
    required this.periodRecordId,
  });

  final String? id;
  final String name;
  final String? dosage;
  final HealthMedicationFrequency frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final String? notes;
  final String? periodRecordId;
}

class HealthDailyLog {
  const HealthDailyLog({
    required this.id,
    required this.date,
    required this.periodRecordId,
    required this.flowLevel,
    required List<HealthSymptomLog> symptoms,
    required this.mood,
    required this.exerciseIntensity,
    required this.sexualActivity,
    required this.contraceptionMethod,
    required this.ovulationTest,
    required List<HealthMedicationLog> medications,
    required this.diet,
    required this.waterIntake,
    required this.sleepMinutes,
    required this.weightGrams,
    required this.temperatureCelsiusTenths,
    required this.stressLevel,
    required this.calories,
    required this.notes,
  }) : _symptoms = symptoms,
       _medications = medications;

  const HealthDailyLog.empty(DateTime date)
    : this(
        id: null,
        date: date,
        periodRecordId: null,
        flowLevel: null,
        symptoms: const [],
        mood: null,
        exerciseIntensity: null,
        sexualActivity: null,
        contraceptionMethod: null,
        ovulationTest: null,
        medications: const [],
        diet: null,
        waterIntake: null,
        sleepMinutes: null,
        weightGrams: null,
        temperatureCelsiusTenths: null,
        stressLevel: null,
        calories: null,
        notes: null,
      );

  final String? id;
  final DateTime date;
  final String? periodRecordId;
  final HealthFlowLevel? flowLevel;
  final List<HealthSymptomLog> _symptoms;

  List<HealthSymptomLog> get symptoms {
    return List.unmodifiable(_symptoms);
  }

  final HealthMood? mood;
  final HealthExerciseIntensity? exerciseIntensity;
  final bool? sexualActivity;
  final HealthContraceptionMethod? contraceptionMethod;
  final HealthOvulationTestLog? ovulationTest;
  final List<HealthMedicationLog> _medications;

  List<HealthMedicationLog> get medications {
    return List.unmodifiable(_medications);
  }

  final String? diet;
  final int? waterIntake;
  final int? sleepMinutes;
  final int? weightGrams;
  final int? temperatureCelsiusTenths;
  final int? stressLevel;
  final int? calories;
  final String? notes;

  int get visibleRecordCount {
    return [
      flowLevel,
      if (symptoms.isNotEmpty) symptoms,
      mood,
      exerciseIntensity,
      diet,
      waterIntake,
      sleepMinutes,
      weightGrams,
      temperatureCelsiusTenths,
      stressLevel,
      calories,
      notes,
      if (medications.isNotEmpty) medications,
    ].where((value) => value != null).length;
  }
}

class HealthDailyLogDraft {
  const HealthDailyLogDraft({
    required this.date,
    required this.flowLevel,
    required List<HealthSymptomLog> symptoms,
    required this.mood,
    required this.exerciseIntensity,
    required this.sexualActivity,
    required this.contraceptionMethod,
    required this.ovulationTest,
    required List<HealthMedicationDraft> medications,
    required this.diet,
    required this.waterIntake,
    required this.sleepMinutes,
    required this.weightGrams,
    required this.temperatureCelsiusTenths,
    required this.stressLevel,
    required this.calories,
    required this.notes,
  }) : _symptoms = symptoms,
       _medications = medications;

  final DateTime date;
  final HealthFlowLevel? flowLevel;
  final List<HealthSymptomLog> _symptoms;

  List<HealthSymptomLog> get symptoms {
    return List.unmodifiable(_symptoms);
  }

  final HealthMood? mood;
  final HealthExerciseIntensity? exerciseIntensity;
  final bool? sexualActivity;
  final HealthContraceptionMethod? contraceptionMethod;
  final HealthOvulationTestLog? ovulationTest;
  final List<HealthMedicationDraft> _medications;

  List<HealthMedicationDraft> get medications {
    return List.unmodifiable(_medications);
  }

  final String? diet;
  final int? waterIntake;
  final int? sleepMinutes;
  final int? weightGrams;
  final int? temperatureCelsiusTenths;
  final int? stressLevel;
  final int? calories;
  final String? notes;
}

class HealthTodaySnapshot {
  const HealthTodaySnapshot({
    required this.date,
    required this.settings,
    required this.prediction,
    required this.activePeriod,
    required this.dailyLog,
    required this.activePregnancy,
  });

  final DateTime date;
  final HealthPeriodSettingsModel settings;
  final HealthCyclePrediction prediction;
  final HealthPeriodRecordModel? activePeriod;
  final HealthDailyLog dailyLog;
  final HealthPregnancyStatus? activePregnancy;
}

class HealthCalendarMarker {
  const HealthCalendarMarker({
    required this.date,
    required this.kind,
    required this.label,
  });

  final DateTime date;
  final HealthCalendarMarkerKind kind;
  final String label;
}

class HealthTrendQuery {
  const HealthTrendQuery({
    this.startDate,
    this.phase = HealthTrendPhase.all,
    this.defaultCompletedPeriodCount = 3,
  });

  final DateTime? startDate;
  final HealthTrendPhase phase;
  final int defaultCompletedPeriodCount;
}

class HealthTrendPoint {
  const HealthTrendPoint({
    required this.date,
    required this.value,
    required this.label,
  });

  final DateTime date;
  final int value;
  final String label;
}

class HealthTrendBucket<T> {
  const HealthTrendBucket({required this.value, required this.count});

  final T value;
  final int count;
}

class HealthTrendMetricAverages {
  const HealthTrendMetricAverages({
    required this.loggedDays,
    this.averageSleepMinutes,
    this.averageWaterIntake,
    this.averageWeightGrams,
    this.averageTemperatureCelsiusTenths,
    this.averageStressLevel,
    this.averageCalories,
  });

  final int loggedDays;
  final int? averageSleepMinutes;
  final int? averageWaterIntake;
  final int? averageWeightGrams;
  final int? averageTemperatureCelsiusTenths;
  final int? averageStressLevel;
  final int? averageCalories;
}

class HealthTrendCompleteness {
  const HealthTrendCompleteness({
    required this.expectedDays,
    required this.loggedDays,
    required this.moodDays,
    required this.symptomDays,
    required this.metricDays,
  });

  final int expectedDays;
  final int loggedDays;
  final int moodDays;
  final int symptomDays;
  final int metricDays;

  double get coverageRatio {
    if (expectedDays == 0) return 0;
    return loggedDays / expectedDays;
  }
}

class HealthTrendSummary {
  const HealthTrendSummary({
    required List<int> cycleLengths,
    required List<int> periodDurations,
    required List<HealthPeriodRecordModel> recentPeriods,
    required this.loggedDaysInLast30Days,
    required this.predictionBasis,
    required this.query,
    required this.periodTrackingEnabled,
    required this.rangeStart,
    required this.rangeEnd,
    required List<HealthTrendPoint> cycleLengthSeries,
    required List<HealthTrendPoint> periodDurationSeries,
    required List<HealthTrendBucket<HealthFlowLevel>> flowDistribution,
    required List<HealthTrendBucket<HealthMood>> moodDistribution,
    required List<HealthTrendBucket<HealthSymptomType>> symptomDistribution,
    required List<HealthTrendBucket<HealthExerciseIntensity>>
    exerciseDistribution,
    required this.healthMetrics,
    required List<HealthTrendBucket<HealthSymptomType>> pmsSymptomDistribution,
    required this.completeness,
  }) : _cycleLengths = cycleLengths,
       _periodDurations = periodDurations,
       _recentPeriods = recentPeriods,
       _cycleLengthSeries = cycleLengthSeries,
       _periodDurationSeries = periodDurationSeries,
       _flowDistribution = flowDistribution,
       _moodDistribution = moodDistribution,
       _symptomDistribution = symptomDistribution,
       _exerciseDistribution = exerciseDistribution,
       _pmsSymptomDistribution = pmsSymptomDistribution;

  final HealthTrendQuery query;
  final bool periodTrackingEnabled;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final HealthTrendMetricAverages healthMetrics;
  final HealthTrendCompleteness completeness;

  final List<int> _cycleLengths;
  final List<int> _periodDurations;

  List<int> get cycleLengths {
    return List.unmodifiable(_cycleLengths);
  }

  List<int> get periodDurations {
    return List.unmodifiable(_periodDurations);
  }

  final List<HealthPeriodRecordModel> _recentPeriods;

  List<HealthPeriodRecordModel> get recentPeriods {
    return List.unmodifiable(_recentPeriods);
  }

  final List<HealthTrendPoint> _cycleLengthSeries;

  List<HealthTrendPoint> get cycleLengthSeries {
    return List.unmodifiable(_cycleLengthSeries);
  }

  final List<HealthTrendPoint> _periodDurationSeries;

  List<HealthTrendPoint> get periodDurationSeries {
    return List.unmodifiable(_periodDurationSeries);
  }

  final List<HealthTrendBucket<HealthFlowLevel>> _flowDistribution;

  List<HealthTrendBucket<HealthFlowLevel>> get flowDistribution {
    return List.unmodifiable(_flowDistribution);
  }

  final List<HealthTrendBucket<HealthMood>> _moodDistribution;

  List<HealthTrendBucket<HealthMood>> get moodDistribution {
    return List.unmodifiable(_moodDistribution);
  }

  final List<HealthTrendBucket<HealthSymptomType>> _symptomDistribution;

  List<HealthTrendBucket<HealthSymptomType>> get symptomDistribution {
    return List.unmodifiable(_symptomDistribution);
  }

  final List<HealthTrendBucket<HealthExerciseIntensity>> _exerciseDistribution;

  List<HealthTrendBucket<HealthExerciseIntensity>> get exerciseDistribution {
    return List.unmodifiable(_exerciseDistribution);
  }

  final List<HealthTrendBucket<HealthSymptomType>> _pmsSymptomDistribution;

  List<HealthTrendBucket<HealthSymptomType>> get pmsSymptomDistribution {
    return List.unmodifiable(_pmsSymptomDistribution);
  }

  final int loggedDaysInLast30Days;
  final HealthPredictionBasis predictionBasis;
}
