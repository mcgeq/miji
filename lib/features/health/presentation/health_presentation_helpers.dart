import 'package:flutter/material.dart';

import 'package:miji/features/health/domain/health_models.dart';
import 'package:miji/features/health/health_text.dart' as health_text;

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
    health_text.HealthQuickAction.more => Icons.more_horiz_rounded,
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
  ColorScheme colorScheme,
) {
  return switch (action) {
    health_text.HealthQuickAction.period => colorScheme.error,
    health_text.HealthQuickAction.flow => colorScheme.tertiary,
    health_text.HealthQuickAction.symptoms => colorScheme.errorContainer,
    health_text.HealthQuickAction.mood => colorScheme.primary,
    health_text.HealthQuickAction.temperatureSleep => colorScheme.secondary,
    health_text.HealthQuickAction.ovulationTest => colorScheme.secondary,
    health_text.HealthQuickAction.medication => colorScheme.inversePrimary,
    health_text.HealthQuickAction.more => colorScheme.onSurfaceVariant,
  };
}

Color markerColor(HealthCalendarMarkerKind kind, ColorScheme colorScheme) {
  return switch (kind) {
    HealthCalendarMarkerKind.actualPeriod => colorScheme.error,
    HealthCalendarMarkerKind.predictedPeriod => colorScheme.errorContainer,
    HealthCalendarMarkerKind.pms => colorScheme.tertiary,
    HealthCalendarMarkerKind.fertileWindow => colorScheme.primary,
    HealthCalendarMarkerKind.ovulationTest => colorScheme.secondary,
    HealthCalendarMarkerKind.medication => colorScheme.inversePrimary,
    HealthCalendarMarkerKind.dailyLog => colorScheme.onSurfaceVariant,
  };
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
