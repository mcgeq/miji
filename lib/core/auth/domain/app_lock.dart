enum AppLockMethod {
  pin,
  pattern;

  static AppLockMethod fromStorageValue(String? value) {
    return switch (value) {
      'pattern' => AppLockMethod.pattern,
      _ => AppLockMethod.pin,
    };
  }

  String get storageValue {
    return switch (this) {
      AppLockMethod.pin => 'pin',
      AppLockMethod.pattern => 'pattern',
    };
  }

  String get label {
    return switch (this) {
      AppLockMethod.pin => '6 位数字',
      AppLockMethod.pattern => '手势图案',
    };
  }
}

class AppLockSettings {
  const AppLockSettings({
    required this.enabled,
    required this.method,
    required this.hasCredential,
  });

  const AppLockSettings.disabled()
    : enabled = false,
      method = AppLockMethod.pin,
      hasCredential = false;

  final bool enabled;
  final AppLockMethod method;
  final bool hasCredential;

  bool get canLock => enabled && hasCredential;
}

enum AppLockValidationError {
  empty,
  pinMustBeSixDigits,
  patternTooShort,
  patternHasDuplicateNodes,
  patternHasInvalidNode,
}

String normalizeAppLockSecret(AppLockMethod method, String value) {
  return switch (method) {
    AppLockMethod.pin => value.trim(),
    AppLockMethod.pattern => _normalizePattern(value),
  };
}

AppLockValidationError? validateAppLockSecret(
  AppLockMethod method,
  String value,
) {
  final normalized = normalizeAppLockSecret(method, value);
  if (normalized.isEmpty) {
    return AppLockValidationError.empty;
  }

  return switch (method) {
    AppLockMethod.pin =>
      RegExp(r'^\d{6}$').hasMatch(normalized)
          ? null
          : AppLockValidationError.pinMustBeSixDigits,
    AppLockMethod.pattern => _validatePattern(normalized),
  };
}

String appLockValidationErrorText(AppLockValidationError error) {
  return switch (error) {
    AppLockValidationError.empty => '请先设置解锁方式',
    AppLockValidationError.pinMustBeSixDigits => '请输入 6 位数字 PIN',
    AppLockValidationError.patternTooShort => '手势至少连接 4 个点',
    AppLockValidationError.patternHasDuplicateNodes => '手势点不能重复连接',
    AppLockValidationError.patternHasInvalidNode => '手势点位不正确',
  };
}

String _normalizePattern(String value) {
  return value
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.trim().isNotEmpty)
      .join('-');
}

AppLockValidationError? _validatePattern(String normalized) {
  final nodes = normalized
      .split('-')
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);
  if (nodes.length < 4) {
    return AppLockValidationError.patternTooShort;
  }

  final seen = <String>{};
  for (final node in nodes) {
    final index = int.tryParse(node);
    if (index == null || index < 0 || index > 8) {
      return AppLockValidationError.patternHasInvalidNode;
    }
    if (!seen.add(node)) {
      return AppLockValidationError.patternHasDuplicateNodes;
    }
  }

  return null;
}
