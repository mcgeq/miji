import 'package:miji/features/health/domain/health_models.dart';

enum HealthQuickAction {
  period,
  flow,
  symptoms,
  mood,
  temperatureSleep,
  ovulationTest,
  medication,
  more,
}

String healthMonthDayLabel(DateTime date) {
  return '${date.month}月${date.day}日';
}

String healthLockedLabel() => '健康数据已锁定';

String healthTabTodayLabel() => '今日';
String healthTabCalendarLabel() => '日历';
String healthTabTrendsLabel() => '趋势';
String healthTabSettingsLabel() => '设置';

String healthTodayRecordCountLabel(int count) => '今日共 $count 条记录';

String healthPredictionPeriodDayLabel(int periodDay) {
  return '经期第 $periodDay 天 · 记录经量和症状';
}

String healthPredictionCycleDayLabel(int currentCycleDay, int daysUntil) {
  return '周期第 $currentCycleDay 天 · 预计 $daysUntil 天后开始经期';
}

String healthPredictionPregnancyLabel(int week, DateTime? dueDate) {
  if (dueDate == null) {
    return '孕 $week 周 · 预产期未设置';
  }
  return '孕 $week 周 · 预产期 ${healthMonthDayLabel(dueDate)}';
}

String healthNextExpectedStartLabel(DateTime date) {
  return '预计下次开始：${healthMonthDayLabel(date)}';
}

String healthOpenPeriodActiveLabel() => '当前经期记录已开启';
String healthPregnancyModeActiveLabel() => '孕期模式已开启';

String healthQuickActionLabel(HealthQuickAction action, bool hasOpenPeriod) {
  return switch (action) {
    HealthQuickAction.period => hasOpenPeriod ? '结束经期' : '开始经期',
    HealthQuickAction.flow => '经量',
    HealthQuickAction.symptoms => '症状',
    HealthQuickAction.mood => '情绪',
    HealthQuickAction.temperatureSleep => '体温和睡眠',
    HealthQuickAction.ovulationTest => '排卵试纸',
    HealthQuickAction.medication => '用药',
    HealthQuickAction.more => '更多',
  };
}

String healthFlowLabel(HealthFlowLevel value) {
  return switch (value) {
    HealthFlowLevel.spotting => '点滴',
    HealthFlowLevel.light => '少量',
    HealthFlowLevel.medium => '中量',
    HealthFlowLevel.heavy => '大量',
  };
}

String healthMoodLabel(HealthMood value) {
  return switch (value) {
    HealthMood.happy => '开心',
    HealthMood.sad => '低落',
    HealthMood.angry => '生气',
    HealthMood.anxious => '焦虑',
    HealthMood.calm => '平静',
    HealthMood.irritable => '烦躁',
  };
}

String healthIntensityLabel(HealthIntensity value) {
  return switch (value) {
    HealthIntensity.light => '轻',
    HealthIntensity.medium => '中',
    HealthIntensity.heavy => '重',
  };
}

String healthPregnancyEndStatusLabel(HealthPregnancyRecordStatus status) {
  return switch (status) {
    HealthPregnancyRecordStatus.completed => '足月生产',
    HealthPregnancyRecordStatus.miscarriage => '自然流产',
    HealthPregnancyRecordStatus.terminated => '人工终止',
    HealthPregnancyRecordStatus.active => '进行中',
  };
}

String healthSymptomTypeLabel(HealthSymptomType value) {
  return switch (value) {
    HealthSymptomType.pain => '疼痛',
    HealthSymptomType.fatigue => '疲劳',
    HealthSymptomType.moodSwing => '情绪波动',
    HealthSymptomType.bloating => '腹胀',
    HealthSymptomType.headache => '头痛',
    HealthSymptomType.nausea => '恶心',
    HealthSymptomType.insomnia => '失眠',
    HealthSymptomType.appetiteChange => '食欲变化',
    HealthSymptomType.skinBreakout => '皮肤爆痘',
    HealthSymptomType.breastTenderness => '乳房胀痛',
    HealthSymptomType.cramps => '抽筋',
    HealthSymptomType.backPain => '背痛',
    HealthSymptomType.other => '其他',
  };
}

String healthOvulationResultLabel(HealthOvulationTestResult value) {
  return switch (value) {
    HealthOvulationTestResult.negative => '阴性',
    HealthOvulationTestResult.positive => '阳性',
    HealthOvulationTestResult.peak => '峰值',
    HealthOvulationTestResult.invalid => '无效',
  };
}

String healthCalendarMarkerLabel(HealthCalendarMarkerKind kind) {
  return switch (kind) {
    HealthCalendarMarkerKind.actualPeriod => '经期',
    HealthCalendarMarkerKind.predictedPeriod => '预计经期',
    HealthCalendarMarkerKind.pms => '经前综合征',
    HealthCalendarMarkerKind.fertileWindow => '易孕期',
    HealthCalendarMarkerKind.ovulationTest => '排卵试纸',
    HealthCalendarMarkerKind.medication => '用药',
    HealthCalendarMarkerKind.dailyLog => '日记录',
  };
}

String healthPredictionBasisLabel(HealthPredictionBasis basis) {
  return switch (basis) {
    HealthPredictionBasis.settings => '按设置',
    HealthPredictionBasis.history => '按历史',
    HealthPredictionBasis.pregnancy => '孕期',
  };
}

String healthTrendDaysListLabel(List<int> values) {
  if (values.isEmpty) {
    return '暂无数据';
  }
  return '${values.join('、')} 天';
}

String healthTrendLoggedDaysLabel(int count) => '近30天已记录 $count 天';

String healthRecentPeriodsTitleLabel() => '近期经期';
String healthNoRecentPeriodsLabel() => '暂无近期经期记录';
String healthSelectedDayTitleLabel() => '所选日期';
String healthNoSelectedDayMarkersLabel() => '所选日期暂无标记';

String healthPeriodRangeLabel(HealthPeriodRecordModel period) {
  final start = healthMonthDayLabel(period.startDate);
  final endDate = period.endDate;
  if (endDate == null) {
    return '$start · 进行中';
  }
  return '$start 至 ${healthMonthDayLabel(endDate)}';
}
