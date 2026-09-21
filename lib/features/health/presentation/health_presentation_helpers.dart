import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart' as health_text;
import 'package:miji/features/health/presentation/health_theme.dart';

export 'package:miji/features/health/health_text.dart' show HealthQuickAction;

IconData quickActionIcon(health_text.HealthQuickAction action) {
  return switch (action) {
    health_text.HealthQuickAction.period => Icons.water_drop_outlined,
    health_text.HealthQuickAction.flow => Icons.invert_colors_outlined,
    health_text.HealthQuickAction.symptoms => Icons.healing_outlined,
    health_text.HealthQuickAction.mood => Icons.mood_outlined,
    health_text.HealthQuickAction.temperatureSleep => Icons.thermostat_outlined,
    health_text.HealthQuickAction.ovulationTest => Icons.science_outlined,
    health_text.HealthQuickAction.medication => Icons.medication_outlined,
    health_text.HealthQuickAction.more => Icons.edit_note_rounded,
  };
}

/// 磁贴上的短标签（非「开始/结束经期」这种带状态的文案）。
String quickActionTileLabel(health_text.HealthQuickAction action) {
  return switch (action) {
    health_text.HealthQuickAction.period => '经期',
    health_text.HealthQuickAction.flow => '经量',
    health_text.HealthQuickAction.symptoms => '症状',
    health_text.HealthQuickAction.mood => '情绪',
    health_text.HealthQuickAction.temperatureSleep => '体温睡眠',
    health_text.HealthQuickAction.ovulationTest => '排卵试纸',
    health_text.HealthQuickAction.medication => '用药',
    health_text.HealthQuickAction.more => '完整记录',
  };
}

String quickActionLabel(
  health_text.HealthQuickAction action,
  bool hasOpenPeriod,
) {
  return health_text.healthQuickActionLabel(action, hasOpenPeriod);
}

Color quickActionColor(
  health_text.HealthQuickAction action,
  BuildContext context,
) {
  return HealthPalette.of(context).actionColor(action);
}

Color markerColor(HealthCalendarMarkerKind kind, BuildContext context) {
  return HealthPalette.of(context).marker(kind);
}

String flowLabel(HealthFlowLevel value) {
  return health_text.healthFlowLabel(value);
}

String moodLabel(HealthMood value) {
  return health_text.healthMoodLabel(value);
}

String intensityLabel(HealthIntensity value) {
  return health_text.healthIntensityLabel(value);
}

String ovulationResultLabel(HealthOvulationTestResult value) {
  return health_text.healthOvulationResultLabel(value);
}

String pregnancyEndStatusLabel(HealthPregnancyRecordStatus value) {
  return health_text.healthPregnancyEndStatusLabel(value);
}

String symptomTypeLabel(HealthSymptomType value) {
  return health_text.healthSymptomTypeLabel(value);
}
