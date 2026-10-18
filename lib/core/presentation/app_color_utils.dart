import 'package:flutter/material.dart';

Color appColorFromHex(
  String? hexColor, {
  Color fallback = const Color(0xFF64748B),
}) {
  final normalized = hexColor?.replaceFirst('#', '') ?? '';
  final value = int.tryParse(normalized, radix: 16);
  if (value == null || normalized.length != 6) {
    return fallback;
  }

  return Color(0xFF000000 | value);
}

Color appOnColor(Color color) {
  return color.computeLuminance() > 0.52 ? Colors.black : Colors.white;
}
