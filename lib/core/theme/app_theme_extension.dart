import 'package:flutter/material.dart';

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({required this.focus, required this.focusContainer});

  final Color focus;
  final Color focusContainer;

  @override
  AppSemanticColors copyWith({Color? focus, Color? focusContainer}) {
    return AppSemanticColors(
      focus: focus ?? this.focus,
      focusContainer: focusContainer ?? this.focusContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) {
      return this;
    }

    return AppSemanticColors(
      focus: Color.lerp(focus, other.focus, t) ?? focus,
      focusContainer:
          Color.lerp(focusContainer, other.focusContainer, t) ?? focusContainer,
    );
  }
}
