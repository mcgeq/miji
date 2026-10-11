import 'package:miji/features/gtd/domain/checkin_enums.dart';

// ---------------------------------------------------------------------------
// Extra JSON 子模型
// ---------------------------------------------------------------------------

class DrinkExtra {
  const DrinkExtra({this.drinkType = 'water', this.cupSizeMl = 250});

  final String drinkType;
  final int cupSizeMl;

  Map<String, dynamic> toJson() => {
    'drinkType': drinkType,
    'cupSizeMl': cupSizeMl,
  };

  factory DrinkExtra.fromJson(Map<String, dynamic> json) => DrinkExtra(
    drinkType: json['drinkType'] as String? ?? 'water',
    cupSizeMl: (json['cupSizeMl'] as num?)?.toInt() ?? 250,
  );

  DrinkExtra copyWith({String? drinkType, int? cupSizeMl}) => DrinkExtra(
    drinkType: drinkType ?? this.drinkType,
    cupSizeMl: cupSizeMl ?? this.cupSizeMl,
  );
}

class StoolExtra {
  const StoolExtra({
    this.bristolType,
    this.color,
    this.blood = false,
    this.durationMinutes,
  });

  final int? bristolType;
  final String? color;
  final bool blood;
  final int? durationMinutes;

  Map<String, dynamic> toJson() => {
    'bristolType': bristolType,
    'color': color,
    'blood': blood,
    'durationMinutes': durationMinutes,
  };

  factory StoolExtra.fromJson(Map<String, dynamic> json) => StoolExtra(
    bristolType: (json['bristolType'] as num?)?.toInt(),
    color: json['color'] as String?,
    blood: json['blood'] as bool? ?? false,
    durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
  );
}

class StudyExtra {
  const StudyExtra({
    this.subject,
    this.focusMode = false,
    this.interruptions = 0,
    this.pomodoroCount = 0,
  });

  final String? subject;
  final bool focusMode;
  final int interruptions;
  final int pomodoroCount;

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'focusMode': focusMode,
    'interruptions': interruptions,
    'pomodoroCount': pomodoroCount,
  };

  factory StudyExtra.fromJson(Map<String, dynamic> json) => StudyExtra(
    subject: json['subject'] as String?,
    focusMode: json['focusMode'] as bool? ?? false,
    interruptions: (json['interruptions'] as num?)?.toInt() ?? 0,
    pomodoroCount: (json['pomodoroCount'] as num?)?.toInt() ?? 0,
  );
}

class ExerciseExtra {
  const ExerciseExtra({
    this.exerciseType,
    this.calories,
    this.avgHeartRate,
    this.distanceKm,
  });

  final String? exerciseType;
  final int? calories;
  final int? avgHeartRate;
  final double? distanceKm;

  Map<String, dynamic> toJson() => {
    'exerciseType': exerciseType,
    'calories': calories,
    'avgHeartRate': avgHeartRate,
    'distanceKm': distanceKm,
  };

  factory ExerciseExtra.fromJson(Map<String, dynamic> json) => ExerciseExtra(
    exerciseType: json['exerciseType'] as String?,
    calories: (json['calories'] as num?)?.toInt(),
    avgHeartRate: (json['avgHeartRate'] as num?)?.toInt(),
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  );
}

class PhotoExtra {
  const PhotoExtra({this.poiName, this.city, this.altitudeM});

  final String? poiName;
  final String? city;
  final double? altitudeM;

  Map<String, dynamic> toJson() => {
    'poiName': poiName,
    'city': city,
    'altitudeM': altitudeM,
  };

  factory PhotoExtra.fromJson(Map<String, dynamic> json) => PhotoExtra(
    poiName: json['poiName'] as String?,
    city: json['city'] as String?,
    altitudeM: (json['altitudeM'] as num?)?.toDouble(),
  );
}

class AnniversaryExtra {
  const AnniversaryExtra({
    this.person,
    this.occasion,
    this.gifted = false,
    this.giftIdea,
  });

  final String? person;
  final String? occasion;
  final bool gifted;
  final String? giftIdea;

  Map<String, dynamic> toJson() => {
    'person': person,
    'occasion': occasion,
    'gifted': gifted,
    'giftIdea': giftIdea,
  };

  factory AnniversaryExtra.fromJson(Map<String, dynamic> json) =>
      AnniversaryExtra(
        person: json['person'] as String?,
        occasion: json['occasion'] as String?,
        gifted: json['gifted'] as bool? ?? false,
        giftIdea: json['giftIdea'] as String?,
      );
}

class GeneralExtra {
  const GeneralExtra({this.weather, this.temperatureC, this.customFields});

  final String? weather;
  final double? temperatureC;
  final Map<String, dynamic>? customFields;

  Map<String, dynamic> toJson() => {
    'weather': weather,
    'temperatureC': temperatureC,
    'customFields': customFields,
  };

  factory GeneralExtra.fromJson(Map<String, dynamic> json) => GeneralExtra(
    weather: json['weather'] as String?,
    temperatureC: (json['temperatureC'] as num?)?.toDouble(),
    customFields: json['customFields'] as Map<String, dynamic>?,
  );
}

// ---------------------------------------------------------------------------
// 打卡计划模型
// ---------------------------------------------------------------------------

class CheckinPlan {
  const CheckinPlan({
    required this.id,
    required this.userId,
    required this.name,
    this.icon = '📌',
    this.color = '#6366F1',
    this.category = '其他',
    this.planType = CheckinPlanType.cyclic,
    this.frequencyType = CheckinFrequencyType.daily,
    this.frequencyConfig,
    this.targetValue = 1,
    this.targetUnit = '次',
    this.triggerMode = CheckinTriggerMode.button,
    this.recordGranularity = CheckinRecordGranularity.merged,
    this.defaultVisibility = CheckinVisibility.private,
    this.reminderEnabled = false,
    this.reminderTime,
    this.reminderDaysBefore,
    this.isArchived = false,
    this.sortOrder = 0,
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String name;
  final String icon;
  final String color;
  final String category;
  final CheckinPlanType planType;
  final CheckinFrequencyType frequencyType;
  final String? frequencyConfig;
  final double targetValue;
  final String targetUnit;
  final CheckinTriggerMode triggerMode;
  final CheckinRecordGranularity recordGranularity;
  final CheckinVisibility defaultVisibility;
  final bool reminderEnabled;
  final String? reminderTime;
  final int? reminderDaysBefore;
  final bool isArchived;
  final int sortOrder;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckinPlan copyWith({
    String? id,
    String? userId,
    String? name,
    String? icon,
    String? color,
    String? category,
    CheckinPlanType? planType,
    CheckinFrequencyType? frequencyType,
    String? frequencyConfig,
    double? targetValue,
    String? targetUnit,
    CheckinTriggerMode? triggerMode,
    CheckinRecordGranularity? recordGranularity,
    CheckinVisibility? defaultVisibility,
    bool? reminderEnabled,
    String? reminderTime,
    int? reminderDaysBefore,
    bool? isArchived,
    int? sortOrder,
    String? deviceId,
    int? version,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckinPlan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      category: category ?? this.category,
      planType: planType ?? this.planType,
      frequencyType: frequencyType ?? this.frequencyType,
      frequencyConfig: frequencyConfig ?? this.frequencyConfig,
      targetValue: targetValue ?? this.targetValue,
      targetUnit: targetUnit ?? this.targetUnit,
      triggerMode: triggerMode ?? this.triggerMode,
      recordGranularity: recordGranularity ?? this.recordGranularity,
      defaultVisibility: defaultVisibility ?? this.defaultVisibility,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderTime: reminderTime ?? this.reminderTime,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      deviceId: deviceId ?? this.deviceId,
      version: version ?? this.version,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class CheckinPlanDraft {
  const CheckinPlanDraft({
    required this.name,
    this.icon = '📌',
    this.color = '#6366F1',
    this.category = '其他',
    this.planType = CheckinPlanType.cyclic,
    this.frequencyType = CheckinFrequencyType.daily,
    this.frequencyConfig,
    this.targetValue = 1,
    this.targetUnit = '次',
    this.triggerMode = CheckinTriggerMode.button,
    this.recordGranularity = CheckinRecordGranularity.merged,
    this.defaultVisibility = CheckinVisibility.private,
    this.reminderEnabled = false,
    this.reminderTime,
    this.reminderDaysBefore,
  });

  final String name;
  final String icon;
  final String color;
  final String category;
  final CheckinPlanType planType;
  final CheckinFrequencyType frequencyType;
  final String? frequencyConfig;
  final double targetValue;
  final String targetUnit;
  final CheckinTriggerMode triggerMode;
  final CheckinRecordGranularity recordGranularity;
  final CheckinVisibility defaultVisibility;
  final bool reminderEnabled;
  final String? reminderTime;
  final int? reminderDaysBefore;
}

// ---------------------------------------------------------------------------
// 打卡记录模型
// ---------------------------------------------------------------------------

class CheckinRecord {
  const CheckinRecord({
    required this.id,
    required this.userId,
    required this.planId,
    required this.recordDate,
    required this.completedAt,
    this.count = 1,
    this.numericValue,
    this.durationSeconds,
    this.mood,
    this.notes,
    this.visibility = CheckinVisibility.private,
    this.locationJson,
    this.extraJson,
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
    this.photos = const [],
  });

  final String id;
  final String userId;
  final String planId;
  final DateTime recordDate;
  final DateTime completedAt;
  final int count;
  final double? numericValue;
  final int? durationSeconds;
  final int? mood;
  final String? notes;
  final CheckinVisibility visibility;
  final String? locationJson;
  final String? extraJson;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final CheckinPlan? plan;
  final List<CheckinPhoto> photos;
}

class CheckinRecordDraft {
  const CheckinRecordDraft({
    required this.planId,
    required this.recordDate,
    required this.completedAt,
    this.count = 1,
    this.numericValue,
    this.durationSeconds,
    this.mood,
    this.notes,
    this.visibility = CheckinVisibility.private,
    this.locationJson,
    this.extraJson,
  });

  final String planId;
  final DateTime recordDate;
  final DateTime completedAt;
  final int count;
  final double? numericValue;
  final int? durationSeconds;
  final int? mood;
  final String? notes;
  final CheckinVisibility visibility;
  final String? locationJson;
  final String? extraJson;
}

// ---------------------------------------------------------------------------
// 打卡照片模型
// ---------------------------------------------------------------------------

class CheckinPhoto {
  const CheckinPhoto({
    required this.id,
    required this.userId,
    required this.recordId,
    required this.localPath,
    this.takenAt,
    this.gpsJson,
    this.deviceId,
    this.version = 1,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String recordId;
  final String localPath;
  final DateTime? takenAt;
  final String? gpsJson;
  final String? deviceId;
  final int version;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
}

// ---------------------------------------------------------------------------
// 打卡统计模型
// ---------------------------------------------------------------------------

class CheckinStreak {
  const CheckinStreak({this.currentStreak = 0, this.longestStreak = 0});

  final int currentStreak;
  final int longestStreak;
}

class DailyCheckinSummary {
  const DailyCheckinSummary({
    required this.date,
    this.totalPlans = 0,
    this.completedPlans = 0,
    this.totalCheckins = 0,
  });

  final DateTime date;
  final int totalPlans;
  final int completedPlans;
  final int totalCheckins;
}

class PlanProgress {
  const PlanProgress({
    required this.plan,
    this.currentCount = 0,
    this.currentValue = 0,
    this.lastCheckinAt,
    this.streak,
  });

  final CheckinPlan plan;
  final int currentCount;
  final double currentValue;
  final DateTime? lastCheckinAt;
  final int? streak;

  double get completionRate => plan.targetValue > 0
      ? (currentValue / plan.targetValue).clamp(0.0, 1.0)
      : (currentCount > 0 ? 1.0 : 0.0);
}

// ---------------------------------------------------------------------------
// 计时器模型
// ---------------------------------------------------------------------------

sealed class CheckinTimerState {
  const CheckinTimerState();
}

class CheckinTimerIdle extends CheckinTimerState {
  const CheckinTimerIdle();
}

class CheckinTimerRunning extends CheckinTimerState {
  const CheckinTimerRunning({
    required this.planId,
    required this.planName,
    required this.startedAt,
    this.pausedDurationSeconds = 0,
    this.pausedAt,
  });

  final String planId;
  final String planName;
  final DateTime startedAt;
  final int pausedDurationSeconds;
  final DateTime? pausedAt;
}

class CheckinTimerPaused extends CheckinTimerState {
  const CheckinTimerPaused({
    required this.planId,
    required this.planName,
    required this.startedAt,
    required this.pausedDurationSeconds,
    required this.pausedAt,
  });

  final String planId;
  final String planName;
  final DateTime startedAt;
  final int pausedDurationSeconds;
  final DateTime pausedAt;
}
