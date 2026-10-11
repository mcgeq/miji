enum SensitiveAccessTtlOption {
  tenMinutes,
  oneHour,
  threeHours,
  twelveHours,
  thirtyDays,
  ninetyDays,
  forever;

  static const defaultOption = SensitiveAccessTtlOption.tenMinutes;

  static SensitiveAccessTtlOption fromStorageValue(String? value) {
    return switch (value) {
      '1h' => SensitiveAccessTtlOption.oneHour,
      '3h' => SensitiveAccessTtlOption.threeHours,
      '12h' => SensitiveAccessTtlOption.twelveHours,
      '30d' => SensitiveAccessTtlOption.thirtyDays,
      '90d' => SensitiveAccessTtlOption.ninetyDays,
      'forever' => SensitiveAccessTtlOption.forever,
      _ => SensitiveAccessTtlOption.defaultOption,
    };
  }

  String get storageValue {
    return switch (this) {
      SensitiveAccessTtlOption.tenMinutes => '10m',
      SensitiveAccessTtlOption.oneHour => '1h',
      SensitiveAccessTtlOption.threeHours => '3h',
      SensitiveAccessTtlOption.twelveHours => '12h',
      SensitiveAccessTtlOption.thirtyDays => '30d',
      SensitiveAccessTtlOption.ninetyDays => '90d',
      SensitiveAccessTtlOption.forever => 'forever',
    };
  }

  String get label {
    return switch (this) {
      SensitiveAccessTtlOption.tenMinutes => '10 分钟',
      SensitiveAccessTtlOption.oneHour => '1 小时',
      SensitiveAccessTtlOption.threeHours => '3 小时',
      SensitiveAccessTtlOption.twelveHours => '12 小时',
      SensitiveAccessTtlOption.thirtyDays => '30 天',
      SensitiveAccessTtlOption.ninetyDays => '90 天',
      SensitiveAccessTtlOption.forever => '永久',
    };
  }

  Duration? get duration {
    return switch (this) {
      SensitiveAccessTtlOption.tenMinutes => const Duration(minutes: 10),
      SensitiveAccessTtlOption.oneHour => const Duration(hours: 1),
      SensitiveAccessTtlOption.threeHours => const Duration(hours: 3),
      SensitiveAccessTtlOption.twelveHours => const Duration(hours: 12),
      SensitiveAccessTtlOption.thirtyDays => const Duration(days: 30),
      SensitiveAccessTtlOption.ninetyDays => const Duration(days: 90),
      SensitiveAccessTtlOption.forever => null,
    };
  }
}
