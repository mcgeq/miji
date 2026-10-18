// 打卡模块枚举定义

/// 计划分类。
///
/// 为什么从「自由字符串」收成枚举：表单只提供 6 个选项，但模型一直允许任意
/// 字符串，于是「按分类给默认图标 / 默认颜色」永远需要 fallback，导入的文件
/// 也能塞进一个谁都不认识的分类。枚举把它们钉住，同时**存储值仍是原来那六个
/// 中文串** —— 老数据、导出的 JSON 都不用改；认不出的值（历史脏数据）落到
/// 「其他」而不是崩掉。
enum CheckinPlanCategory {
  healthHabit('健康习惯'),
  study('学习成长'),
  exercise('运动'),
  lifeLog('生活记录'),
  anniversary('纪念日'),
  other('其他');

  const CheckinPlanCategory(this.storageValue);

  /// 落库与导出用的值，与旧数据完全一致。
  final String storageValue;

  /// 界面文案。
  String get label => storageValue;

  static CheckinPlanCategory fromStorageValue(String? raw) {
    for (final value in values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return other;
  }
}

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
