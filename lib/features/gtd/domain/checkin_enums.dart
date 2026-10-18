// 打卡模块枚举定义

enum CheckinPlanType {
  cyclic('cyclic'),
  event('event');

  const CheckinPlanType(this.value);
  final String value;

  factory CheckinPlanType.fromValue(String value) {
    return CheckinPlanType.values.firstWhere((e) => e.value == value);
  }
}

enum CheckinFrequencyType {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly'),
  cron('cron'),
  once('once');

  const CheckinFrequencyType(this.value);
  final String value;

  factory CheckinFrequencyType.fromValue(String value) {
    return CheckinFrequencyType.values.firstWhere((e) => e.value == value);
  }
}

enum CheckinTriggerMode {
  button('button'),
  photo('photo'),
  timer('timer'),
  location('location');

  const CheckinTriggerMode(this.value);
  final String value;

  factory CheckinTriggerMode.fromValue(String value) {
    return CheckinTriggerMode.values.firstWhere((e) => e.value == value);
  }
}

enum CheckinRecordGranularity {
  merged('merged'),
  detailed('detailed');

  const CheckinRecordGranularity(this.value);
  final String value;

  factory CheckinRecordGranularity.fromValue(String value) {
    return CheckinRecordGranularity.values.firstWhere((e) => e.value == value);
  }
}

enum CheckinVisibility {
  private('private'),
  public('public');

  const CheckinVisibility(this.value);
  final String value;

  factory CheckinVisibility.fromValue(String value) {
    return CheckinVisibility.values.firstWhere((e) => e.value == value);
  }
}

/// 打卡计划模板分类标签
enum CheckinCategory {
  health('健康习惯'),
  study('学习成长'),
  exercise('运动'),
  lifestyle('生活记录'),
  anniversary('纪念日'),
  other('其他');

  const CheckinCategory(this.label);
  final String label;

  factory CheckinCategory.fromLabel(String label) {
    return CheckinCategory.values.firstWhere(
      (e) => e.label == label,
      orElse: () => CheckinCategory.other,
    );
  }
}
