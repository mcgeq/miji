import 'package:flutter/material.dart';

Color appFieldFillColor(ColorScheme colorScheme, {required bool enabled}) {
  if (!enabled) {
    return colorScheme.surfaceContainerHighest.withValues(alpha: 0.46);
  }
  return colorScheme.surfaceContainerHigh.withValues(alpha: 0.78);
}

Color appFieldBorderColor(
  ColorScheme colorScheme, {
  required bool enabled,
  bool focused = false,
}) {
  if (!enabled) {
    return colorScheme.outlineVariant.withValues(alpha: 0.22);
  }
  if (focused) {
    return colorScheme.primary;
  }
  return colorScheme.outlineVariant.withValues(alpha: 0.46);
}
